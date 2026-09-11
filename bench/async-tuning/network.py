#!/usr/bin/env python3
"""Validate the independent async experiments through a real native Mars server.

Run measure.py first: its disposable, patched async trees are the build inputs.
This runner embeds every wrk/time result in JSON and checks HTTP response bytes.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import io
import json
from pathlib import Path
import platform
import re
import socket
import statistics
import subprocess
import tarfile
import time
import urllib.error
import urllib.request

HERE = Path(__file__).resolve().parent
MARS = HERE.parent.parent
MARS_BASE = '66277d49502626d8c2f477d63d7eb285d1ba5157'


def run(command, cwd):
    result = subprocess.run(command, cwd=cwd, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT)
    if result.returncode:
        raise RuntimeError(result.stdout)
    return result.stdout


def measure(exe, root, case, duration):
    with socket.socket() as probe:
        probe.bind(('127.0.0.1', 0))
        port = probe.getsockname()[1]
    command = ['/usr/bin/time', '-lp', str(exe), str(port), str((duration + 4) * 1000),
               str(case['size']), case['framing'], str(case['headers'])]
    url = f'http://127.0.0.1:{port}/bench'
    headers = {f'X-{i}': 'x' * 40 for i in range(case['headers'])}
    with (root / 'server.log').open('w') as log:
        process = subprocess.Popen(command, cwd=root, stdout=log, stderr=log)
        try:
            deadline = time.monotonic() + 30
            while True:
                if process.poll() is not None:
                    raise RuntimeError((root / 'server.log').read_text())
                try:
                    request = urllib.request.Request(url, headers=headers)
                    with urllib.request.urlopen(request, timeout=1) as response:
                        assert response.status == 200
                        assert response.read() == b'x' * case['size']
                        assert response.headers['Content-Type'] == 'text/plain; charset=utf-8'
                        if case['framing'] == 'fixed':
                            assert response.headers['Content-Length'] == str(case['size'])
                        else:
                            assert response.headers['Transfer-Encoding'] == 'chunked'
                    break
                except (urllib.error.HTTPError, AssertionError):
                    raise
                except (OSError, TimeoutError):
                    if time.monotonic() > deadline:
                        raise
                    time.sleep(0.025)
            wrk = ['wrk', '-t', '4', '-c', str(case['connections'])]
            for key, value in headers.items():
                wrk.extend(['-H', f'{key}: {value}'])
            if case['size'] >= 65536:
                warmup = run(['node', str(HERE / 'load.mjs'), url, '1', str(case['connections'])], root)
                measured = run(['node', str(HERE / 'load.mjs'), url, str(duration), str(case['connections'])], root)
                for output in [warmup, measured]:
                    data = json.loads(output)
                    assert data['requests'] > 0 and data['body_bytes'] == data['requests'] * case['size'], data
            else:
                warmup = run([*wrk, '-d', '1s', url], root)
                measured = run([*wrk, '-d', f'{duration}s', '--latency', url], root)
            for output in [warmup, measured]:
                assert 'Non-2xx or 3xx responses' not in output, output
                assert 'Socket errors:' not in output, output
            process.wait(timeout=30)
            assert process.returncode == 0, (root / 'server.log').read_text()
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
    log = (root / 'server.log').read_text()
    if case['size'] >= 65536:
        count = sum(json.loads(s)['requests'] for s in [warmup, measured]) + 1
        rps = json.loads(measured)['rps']
    else:
        count = sum(int(re.search(r'(\d+) requests in', s)[1]) for s in [warmup, measured]) + 1
        rps = float(re.search(r'Requests/sec:\s+([\d.]+)', measured)[1])
    user = float(re.search(r'user\s+([\d.]+)', log)[1])
    system = float(re.search(r'sys\s+([\d.]+)', log)[1])
    return {
        'warmup': warmup, 'measured': measured, 'server_log': log, 'command': command,
        'load_generator': 'node-drained' if case['size'] >= 65536 else 'wrk',
        'total_requests_including_warmup': count,
        'rps': rps,
        'user_us_per_request': user * 1e6 / count,
        'cpu_us_per_request': (user + system) * 1e6 / count,
        'instructions_per_request': int(re.search(r'(\d+)\s+instructions retired', log)[1]) / count,
    }


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--micro-results', type=Path, default=HERE.parent / 'results/async-tuning.json')
    p.add_argument('--output', type=Path, default=HERE.parent / 'results/async-tuning-network.json')
    p.add_argument('--runs', type=int, default=3)
    p.add_argument('--duration', type=int, default=3)
    p.add_argument('--cases', nargs='+', choices=['small', 'body-64k', 'body-1m-fixed', 'headers-64'])
    args = p.parse_args()
    assert args.runs > 0 and args.duration > 0
    micro = json.loads(args.micro_results.read_text())
    assert 'baseline' in micro['variants'] and len(micro['variants']) > 1
    for variant, result in micro['variants'].items():
        if variant != 'baseline':
            patch = HERE.parent / f'patches/async-tuning-{variant}.patch'
            assert hashlib.sha256(patch.read_bytes()).hexdigest() == result['patch_sha256'], variant
    temporary = Path(micro['temporary_builds'])
    archive = subprocess.check_output(['git', '-C', str(MARS), 'archive', MARS_BASE])
    binaries = {}
    for variant in micro['variants']:
        print(f'Building Mars + {variant}', flush=True)
        root = temporary / f'network-{variant}'
        mars = root / 'mars'
        mars.mkdir(parents=True, exist_ok=True)
        with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
            tar.extractall(mars)
        module = root / 'bench'
        package = module / 'server'
        package.mkdir(parents=True, exist_ok=True)
        (root / 'moon.work').write_text('members = ["mars", "bench", ' +
                                      json.dumps(str(temporary / variant)) + ']\n')
        (module / 'moon.mod').write_text('name = "mizchi/mars_tuning"\nversion = "0.0.0"\n'
                                       'import { "mizchi/mars@0.3.12", "mizchi/x@0.6.1", '
                                       '"moonbitlang/async@0.21.3" }\npreferred_target = "native"\n')
        (package / 'moon.pkg').write_text('import { "moonbitlang/core/string", "mizchi/mars", '
                                        '"mizchi/x/http" @xhttp, "mizchi/x/sys", "moonbitlang/async" }\n'
                                        'supported_targets = "native"\noptions("is-main": true)\n')
        (package / 'main.mbt').write_text((HERE / 'server.mbt').read_text())
        (root / 'build.log').write_text(run(['moon', 'build', 'bench/server', '--target', 'native', '--release'], root))
        binaries[variant] = next((root / '_build/native/release/build').rglob('server.exe'))
    cases = [
        {'name': 'small', 'size': 3, 'framing': 'chunked', 'headers': 0, 'connections': 64,
         'variants': list(micro['variants'])},
        {'name': 'body-64k', 'size': 65536, 'framing': 'chunked', 'headers': 0, 'connections': 16,
         'variants': ['baseline', 'body']},
        {'name': 'body-1m-fixed', 'size': 1048576, 'framing': 'fixed', 'headers': 0, 'connections': 16,
         'variants': ['baseline', 'body']},
        {'name': 'headers-64', 'size': 3, 'framing': 'chunked', 'headers': 64, 'connections': 64,
         'variants': ['baseline', 'parser', 'parser-pr', 'buffer', 'buffer-growth', 'header-map']},
    ]
    report = {
        'measured_at': datetime.now(timezone.utc).isoformat(), 'platform': platform.platform(),
        'mars_base': MARS_BASE, 'async_base': micro['async_base'], 'duration_seconds': args.duration,
        'runs': args.runs, 'warmup_seconds': 1, 'wrk_threads': 4,
        'source_sha256': hashlib.sha256((HERE / 'server.mbt').read_bytes()).hexdigest(),
        'server_source': (HERE / 'server.mbt').read_text(),
        'load_generator_sha256': hashlib.sha256((HERE / 'load.mjs').read_bytes()).hexdigest(),
        'variants': {v: {'exe_sha256': hashlib.sha256(exe.read_bytes()).hexdigest(),
                         'patch_sha256': micro['variants'][v].get('patch_sha256')} for v, exe in binaries.items()},
        'method': 'Native release, server-only /usr/bin/time -lp; reverse variant order every other round. '
                  'Normalize CPU/instructions by wrk completed requests including warmup + readiness. '
                  'Outstanding requests at wrk shutdown are not included. Bulk cases use a Node HTTP '
                  'load generator that drains responses before closing; all completed requests are counted. '
                  'This avoids the existing Mars SIGABRT when fallback sends a second response after '
                  'a partially sent body encounters EPIPE. Shared developer machine; '
                  'short exploratory runs, not isolated throughput claims. Response bytes and framing '
                  'validated before each run; wrk checks HTTP/socket errors during load.',
        'cases': [],
    }
    for case in cases:
        if args.cases and case['name'] not in args.cases:
            continue
        case['variants'] = [v for v in case['variants'] if v in binaries]
        if len(case['variants']) < 2:
            continue
        result = {**case, 'samples': {v: [] for v in case['variants']}}
        report['cases'].append(result)
        for repeat in range(args.runs):
            order = case['variants'] if repeat % 2 == 0 else case['variants'][::-1]
            for variant in order:
                print(f'{case["name"]} {repeat + 1}/{args.runs}: {variant}', flush=True)
                result['samples'][variant].append(measure(binaries[variant], temporary / f'network-{variant}', case, args.duration))
        result['median'] = {v: {key: statistics.median(row[key] for row in rows)
                                for key in ['rps', 'user_us_per_request', 'cpu_us_per_request', 'instructions_per_request']}
                            for v, rows in result['samples'].items()}
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2) + '\n')
    print(f'Results: {args.output}', flush=True)


if __name__ == '__main__':
    main()
