#!/usr/bin/env python3
"""Profile only the HTTP server process; wrk runs as a separate load generator."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import socket
import subprocess
import time
import urllib.request

parser = argparse.ArgumentParser()
parser.add_argument('--layer', choices=['mars', 'x', 'async'], default='mars')
parser.add_argument('--capture', choices=['cpu', 'alloc', 'time'], default='cpu')
parser.add_argument('--output')
parser.add_argument('--duration', type=int, default=5)
parser.add_argument('--connections', type=int, default=64)
parser.add_argument('--exe', default='_build/native/release/build/mizchi/mars_bench/http_server/http_server.exe')
args = parser.parse_args()
assert args.duration > 0 and args.connections > 0
cwd = Path(__file__).resolve().parent
exe = (cwd / args.exe).resolve()
output = (cwd / (args.output or f'profiles/native-{args.layer}-{args.capture}')).resolve()
output.parent.mkdir(parents=True, exist_ok=True)
env = dict(os.environ)
if os.uname().sysname == 'Darwin':
    env['DYLD_LIBRARY_PATH'] = ':'.join(filter(None, ['/usr/lib', env.get('DYLD_LIBRARY_PATH')]))
with socket.socket() as probe:
    probe.bind(('127.0.0.1', 0))
    port = probe.getsockname()[1]
server_args = [args.layer, str(port), str((args.duration + 4) * 1000)]
if args.capture == 'cpu':
    command = ['samply', 'record', '--save-only', '--unstable-presymbolicate', '--main-thread-only', '--rate', '1000', '--output', str(output) + '.firefox.json', str(exe), *server_args]
elif args.capture == 'alloc':
    command = ['moon-pprof', 'memprofile-native', str(exe), '--sample-rate', '100', '--out', str(output) + '.pb.gz', '--', *server_args]
else:
    command = ['/usr/bin/time', '-lp', str(exe), *server_args]
url = f'http://127.0.0.1:{port}/api/users/123'
with open(str(output) + '.server.log', 'w') as log:
    process = subprocess.Popen(command, cwd=cwd, env=env, stdout=log, stderr=log)
    try:
        deadline = time.monotonic() + 120
        while True:
            if process.poll() is not None:
                raise RuntimeError(f'Server exited ({process.returncode}); see {output}.server.log')
            try:
                with urllib.request.urlopen(url, timeout=0.2) as response:
                    assert response.status == 200
                    assert response.read() == b'123'
                    assert response.headers['Content-Type'] == 'text/plain; charset=utf-8'
                break
            except (OSError, TimeoutError):
                if time.monotonic() > deadline:
                    raise
                time.sleep(0.025)
        wrk = ['wrk', '-t', '4', '-c', str(args.connections)]
        warmup = subprocess.check_output([*wrk, '-d', '1s', url], env=env, text=True)
        measured = subprocess.check_output([*wrk, '-d', f'{args.duration}s', '--latency', url], env=env, text=True)
        for result in [warmup, measured]:
            assert 'Non-2xx or 3xx responses' not in result, result
            assert 'Socket errors:' not in result, result
        process.wait(timeout=30)
        assert process.returncode == 0, process.returncode
    finally:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
Path(str(output) + '.wrk.txt').write_text(measured)
if args.capture == 'cpu':
    subprocess.run(['moon-pprof', 'firefox2pprof', str(output) + '.firefox.json', str(output) + '.pb.gz', '--source', 'samply', '--syms', str(output) + '.firefox.syms.json'], env=env, check=True)
if args.capture != 'time':
    summary = subprocess.check_output(['moon-pprof', 'summary', str(output) + '.pb.gz'], env=env, text=True)
    Path(str(output) + '.txt').write_text(summary.rstrip() + '\n')
    print(summary)
Path(str(output) + '.json').write_text(json.dumps({
    'layer': args.layer, 'capture': args.capture, 'duration_seconds': args.duration,
    'connections': args.connections, 'threads': 4, 'warmup_seconds': 1,
    'exe_sha256': hashlib.sha256(exe.read_bytes()).hexdigest(),
    'command': command, 'warmup': warmup, 'measured': measured,
    'server_log': Path(str(output) + '.server.log').read_text(),
    'note': 'Only time captures represent uninstrumented throughput. CPU/allocation captures include startup, readiness, warmup, measured load, and trailing idle time. Lower layers return the same response without Mars routing/context work.',
}, indent=2) + '\n')
print(measured)
