#!/usr/bin/env python3
"""Compare independent async patches on a chosen Git revision (macOS).

Uninstrumented native binaries provide elapsed times. A separately linked copy
counts exact allocation requests with the calibrated buffer-memory probe.
"""
import argparse
from datetime import datetime, timezone
import importlib.util
import io
import json
import os
from pathlib import Path
import platform
import shutil
import statistics
import subprocess
import tarfile
import tempfile

HERE = Path(__file__).resolve().parent
BASE = 'fcc109cc2cb82cbd122974b4e4718b3670ee04b6'
VARIANTS = ['baseline', 'body', 'parser', 'scheduler', 'buffer']
EXTRA_VARIANTS = ['parser-pr', 'buffer-growth', 'header-map']
spec = importlib.util.spec_from_file_location('memory_probe', HERE.parent / 'buffer-memory/measure.py')
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)
run, digest = probe.run, probe.digest


def parse(output, instrumented):
    tests = [json.loads(line) for line in output.splitlines()
             if line.startswith('{"type":"result"')]
    assert len(tests) == 4 and all(t['message'] == '' for t in tests), output
    memory = {row['scenario']: row for row in
              (json.loads(line[len('BUFFER_MEMORY '):]) for line in output.splitlines()
               if line.startswith('BUFFER_MEMORY '))}
    if instrumented:
        calibration = memory[-1]
        assert calibration['allocations'] == 1 and calibration['allocated_bytes'] == 266, calibration
        assert calibration['live_bytes_at_end'] == 0, calibration
    rows = []
    for line in output.splitlines():
        if not line.startswith('TUNING '):
            continue
        scenario, iterations, ns, count, size = map(int, line.split()[1:])
        row = {'scenario': scenario, 'iterations': iterations}
        if scenario < 10:
            row.update(body_size=[3, 1024, 65536, 1048576][scenario // 2],
                       framing='fixed' if scenario % 2 else 'chunked',
                       writer_calls=count, wire_bytes=size)
        elif scenario < 20:
            row.update(retained_read_capacity=count, request_bytes=size)
        if instrumented:
            row.update(memory[scenario])
            row['allocated_bytes_per_op'] = row['allocated_bytes'] / iterations
            row['allocations_per_op'] = row['allocations'] / iterations
        else:
            row.update(elapsed_ns=ns, ns_per_op=ns / iterations)
        rows.append(row)
    assert len(rows) == 15, rows
    return rows


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--async-repo', type=Path, required=True)
    p.add_argument('--base', default=BASE, help='Common async Git revision for every variant')
    p.add_argument('--repeats', type=int, default=5)
    p.add_argument('--memory-repeats', type=int, default=3)
    p.add_argument('--variants', nargs='+', choices=VARIANTS + EXTRA_VARIANTS, default=VARIANTS)
    p.add_argument('--output', type=Path, default=HERE.parent / 'results/async-tuning.json')
    args = p.parse_args()
    assert args.repeats > 0 and args.memory_repeats > 0
    temporary = Path(tempfile.mkdtemp(prefix='mars-async-tuning-'))
    print(f'Build directory: {temporary}', flush=True)
    base = run(['git', 'rev-parse', args.base + '^{commit}'], args.async_repo.resolve()).strip()
    archive = subprocess.check_output(['git', '-C', str(args.async_repo.resolve()), 'archive', base])
    moon_home = Path(os.environ.get('MOON_HOME', Path.home() / '.moon'))
    report = {
        'measured_at': datetime.now(timezone.utc).isoformat(),
        'async_base': base, 'platform': platform.platform(),
        'moon': run(['moon', 'version', '--all'], HERE),
        'temporary_builds': str(temporary),
        'sources_sha256': {str(p.relative_to(HERE.parent)): digest(p) for p in
                           [HERE / 'tuning_probe_wbtest.mbt', HERE / 'clock.c',
                            probe.HERE / 'probe.c', probe.HERE / 'probe.h']},
        'runtime_sha256': digest(moon_home / 'lib/runtime/runtime.c'),
        'method': 'Native release; reverse variant order every other round. '
                  'Elapsed times use binaries without allocator interception. '
                  'Memory uses separate instrumented binaries and counts requested bytes '
                  'including object headers, excluding allocator rounding and RSS. '
                  'Body inputs and reusable Sender are precreated; a counting Writer '
                  'accepts every write immediately (these are not syscall counts). '
                  'Header inputs are precreated; each parse uses a fresh connection. '
                  'Scenario 20 executes the post-IO yield expression without a syscall. '
                  'Shared developer machine; microbenchmarks do not predict service throughput.',
        'variants': {},
    }
    binaries = {}
    for variant in args.variants:
        print(f'Building {variant}', flush=True)
        root = temporary / variant
        root.mkdir()
        with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
            # Trusted local git archive, not user-supplied tar input.
            tar.extractall(root)
        (root / 'moon.work').write_text('members = ["."]\n')
        result = {'timing_runs': [], 'memory_runs': []}
        if variant != 'baseline':
            patch = HERE.parent / f'patches/async-tuning-{variant}.patch'
            run(['git', 'apply', str(patch)], root)
            result['patch_sha256'] = digest(patch)
        source = (HERE / 'tuning_probe_wbtest.mbt').read_text()
        if variant == 'scheduler':
            source = source.replace('@coroutine.protect_from_cancel(() => @coroutine.pause())',
                                    '@coroutine.pause_after_io()')
        (root / 'src/http/tuning_probe_wbtest.mbt').write_text(source)
        shutil.copyfile(HERE / 'clock.c', root / 'src/http/clock.c')
        shutil.copyfile(probe.HERE / 'probe.c', root / 'src/http/probe.c')
        manifest = root / 'src/http/moon.pkg'
        manifest.write_text(manifest.read_text().replace(
            'options(', 'options(\n  "native-stub": ["probe.c", "clock.c"],').replace(
            'targets: {', 'targets: {\n    "tuning_probe_wbtest.mbt": ["native"],').replace(
            '"moonbitlang/core/test",',
            '"moonbitlang/core/test",\n  "moonbitlang/async/internal/coroutine",'))
        output = run(['moon', 'test', 'src/http', '--release', '--target', 'native', '--build-only'], root)
        (root / 'build.log').write_text(output)
        plain = next((root / '_build/native/release/test').rglob('http.whitebox_test.exe'))
        instrumented = probe.instrument(root, moon_home)
        binaries[variant] = (plain, instrumented)
        result.update(exe_sha256=digest(plain), instrumented_exe_sha256=digest(instrumented))
        report['variants'][variant] = result
    for kind, count in [('timing', args.repeats), ('memory', args.memory_repeats)]:
        for repeat in range(count):
            order = args.variants if repeat % 2 == 0 else args.variants[::-1]
            for variant in order:
                print(f'{kind} {repeat + 1}/{count}: {variant}', flush=True)
                root = temporary / variant
                exe = binaries[variant][kind == 'memory']
                output = run([str(exe), 'tuning_probe_wbtest.mbt:0-4'], root)
                (root / f'{kind}-{repeat}.log').write_text(output)
                report['variants'][variant][kind + '_runs'].append(parse(output, kind == 'memory'))
    for name, result in report['variants'].items():
        assert all(rows == result['memory_runs'][0] for rows in result['memory_runs']), name
        result['median_ns_per_op'] = {
            str(row['scenario']): statistics.median(
                rows[i]['ns_per_op'] for rows in result['timing_runs'])
            for i, row in enumerate(result['timing_runs'][0])}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    print(f'Results: {args.output}', flush=True)


if __name__ == '__main__':
    main()
