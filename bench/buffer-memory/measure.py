#!/usr/bin/env python3
"""Count response-send allocations in disposable native async builds (macOS).

Both generated C and runtime.c use an allocator macro override. The original
reference-count initialization is preserved, including array/string allocation.
The probe is compiled separately with the same underlying allocator.
"""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import platform
import shlex
import shutil
import subprocess
import tarfile
import tempfile

HERE = Path(__file__).resolve().parent
BASE = '3e54be1f084b320aad774d6bb450f04bce560509'
CASES = [(0, 0), (1, 40), (1, 128), (1, 4096), (1, 65536), (64, 64), (1, 1048576)]
BLOCKED_CASES = [(1, 40), (64, 64), (1, 65536)]


def run(command, cwd):
    result = subprocess.run(command, cwd=cwd, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT)
    if result.returncode:
        raise RuntimeError(f'{shlex.join(command)}\n{result.stdout}')
    return result.stdout


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def instrument(root, moon_home):
    dry_run = run(['moon', 'test', '--release', '--target', 'native', '--package',
                   'moonbitlang/async/http', '--dry-run'], root)
    commands = [shlex.split(line.replace('$MOON_HOME', str(moon_home)))
                for line in dry_run.splitlines() if line.startswith('/usr/bin/cc ')]
    runtime = next(c for c in commands if c[-1].endswith('/runtime/runtime.c'))
    runtime[runtime.index('-o') + 1] = str(root / 'instrumented-runtime.o')
    runtime.extend(['-include', str(HERE / 'probe.h')])
    run(runtime, root)
    link = next(c for c in commands if any(x.endswith('http.whitebox_test.c') for x in c))
    allocator = next(x for x in link if x.startswith('-DMOONBIT_ALLOCATOR='))
    run(['/usr/bin/cc', '-c', '-O2', '-I' + str(moon_home / 'include'), allocator,
         str(HERE / 'probe.c'), '-o', str(root / 'instrumented-probe.o')], root)
    exe = root / 'memory-probe.exe'
    link[link.index('-o') + 1] = str(exe)
    # Place our objects before their original archives so the linker does not
    # pull the original runtime.o / probe.o. Other archive members stay intact.
    index = next(i for i, x in enumerate(link) if x.endswith('http.whitebox_test.c'))
    link[index + 1:index + 1] = [str(root / 'instrumented-probe.o'),
                               str(root / 'instrumented-runtime.o')]
    link.extend(['-include', str(HERE / 'probe.h')])
    run(link, root)
    (root / 'instrumentation-commands.json').write_text(json.dumps(
        {'runtime': runtime, 'link': link}, indent=2) + '\n')
    return exe


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--async-repo', type=Path, required=True)
    parser.add_argument('--patch', type=Path,
                        default=HERE.parent / 'patches/async-0.21.3-response-head.patch')
    parser.add_argument('--output', type=Path,
                        default=HERE.parent / 'results/buffer-memory.json')
    parser.add_argument('--repeats', type=int, default=3)
    args = parser.parse_args()
    assert args.repeats > 0
    moon_home = Path(os.environ.get('MOON_HOME', Path.home() / '.moon'))
    temporary = Path(tempfile.mkdtemp(prefix='mars-buffer-memory-'))
    archive = subprocess.check_output(['git', '-C', str(args.async_repo.resolve()),
                                       'archive', BASE])
    report = {
        'async_base': BASE, 'patch_sha256': digest(args.patch),
        'moon_version': run(['moon', 'version', '--all'], HERE),
        'platform': platform.platform(), 'temporary_builds': str(temporary),
        'runtime_sha256': digest(moon_home / 'lib/runtime/runtime.c'),
        'buffer_source_sha256': digest(moon_home / 'lib/core/buffer/buffer.mbt'),
        'probe_sources_sha256': {p.name: digest(p) for p in
                                [HERE / 'probe.c', HERE / 'probe.h',
                                 HERE / 'send_memory_wbtest.mbt']},
        'scope': 'Native release, exact requested bytes including object headers; '
                 'excludes allocator rounding/RSS, precreated request headers and '
                 'reused Sender/1024-byte send buffer. Serial Writer consumes synchronously; '
                 'blocked cases suspend 64 senders at their first underlying write. '
                 'Peak is maximum concurrently live allocations, not cumulative bytes.',
        'variants': {},
    }
    for variant in ['baseline', 'buffer']:
        print(f'Building {variant} in {temporary / variant}', flush=True)
        root = temporary / variant
        root.mkdir()
        # Archive comes from a trusted local Git commit, not an uploaded tarball.
        with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
            tar.extractall(root)
        (root / 'moon.work').write_text('members = ["."]\n')
        if variant == 'buffer':
            run(['git', 'apply', str(args.patch.resolve())], root)
        for name in ['send_memory_wbtest.mbt', 'probe.c']:
            shutil.copyfile(HERE / name, root / 'src/http' / name)
        manifest = root / 'src/http/moon.pkg'
        manifest.write_text(manifest.read_text().replace(
            'options(', 'options(\n  "native-stub": ["probe.c"],').replace(
            'targets: {', 'targets: {\n    "send_memory_wbtest.mbt": ["native"],'))
        build = run(['moon', 'test', '--release', '--target', 'native', '--package',
                     'moonbitlang/async/http', '--build-only'], root)
        (root / 'build.log').write_text(build)
        exe = instrument(root, moon_home)
        runs = []
        for repeat in range(args.repeats):
            output = run([str(exe), 'send_memory_wbtest.mbt:0-3'], root)
            (root / f'run-{repeat}.log').write_text(output)
            test_results = [json.loads(line) for line in output.splitlines()
                            if line.startswith('{"type":"result"')]
            assert len(test_results) == 3 and all(
                row['message'] == '' for row in test_results), output
            rows = [json.loads(line[len('BUFFER_MEMORY '):])
                    for line in output.splitlines() if line.startswith('BUFFER_MEMORY ')]
            calibration = next(row for row in rows if row['scenario'] == -1)
            assert calibration['allocations'] == 1, calibration
            # 257 payload bytes + one trailing NUL + eight-byte object header.
            assert calibration['allocated_bytes'] == 266, calibration
            assert calibration['live_bytes_at_end'] == 0, calibration
            wire = {int(line.split()[1]): int(line.split()[2])
                    for line in output.splitlines() if line.startswith('BUFFER_WIRE ')}
            case_count = len(CASES) + len(BLOCKED_CASES)
            assert len(rows) == case_count + 1 and len(wire) == case_count, output
            for row in rows:
                if row['scenario'] < 0:
                    continue
                blocked = row['scenario'] >= 100
                count, size = (BLOCKED_CASES[row['scenario'] - 100] if blocked
                               else CASES[row['scenario']])
                row.update(header_count=count, value_size=size,
                           mode='blocked' if blocked else 'serial',
                           wire_bytes=wire[row['scenario']],
                           allocations_per_response=row['allocations'] / row['iterations'],
                           allocated_bytes_per_response=row['allocated_bytes'] / row['iterations'])
            runs.append(rows)
        assert all(rows == runs[0] for rows in runs), 'Allocation counts changed between repeats'
        report['variants'][variant] = {'exe_sha256': digest(exe), 'runs': runs}
        print(json.dumps(runs[0], indent=2), flush=True)
    baseline = report['variants']['baseline']['runs'][0]
    buffered = report['variants']['buffer']['runs'][0]
    assert all(a.get('wire_bytes') == b.get('wire_bytes')
               for a, b in zip(baseline, buffered)), 'Wire lengths changed'
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    print(f'Results: {args.output}')


if __name__ == '__main__':
    main()
