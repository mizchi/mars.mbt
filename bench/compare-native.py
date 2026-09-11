#!/usr/bin/env python3
"""Alternate native HTTP binaries and normalize CPU work by requests served."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import platform
import re
import statistics
import subprocess
import sys

parser = argparse.ArgumentParser()
parser.add_argument('--baseline', required=True)
parser.add_argument('--patched', required=True)
parser.add_argument('--runs', type=int, default=5)
parser.add_argument('--duration', type=int, default=5)
parser.add_argument('--profiles', default='profiles')
parser.add_argument('--output', default='results/profile-review-native.json')
parser.add_argument('--patch', default='patches/async-0.21.3-response-head.patch')
parser.add_argument('--summarize-only', action='store_true')
args = parser.parse_args()
assert args.runs > 0 and args.duration > 0
cwd = Path(__file__).resolve().parent
profiles = cwd / args.profiles
variants = [('baseline', Path(args.baseline).resolve()), ('async-patched', Path(args.patched).resolve())]
hashes = {name: hashlib.sha256(exe.read_bytes()).hexdigest() for name, exe in variants}
for run in range(1, args.runs + 1):
    for name, exe in (variants if run % 2 else variants[::-1]):
        output = profiles / name / f'native-mars-time-{run}'
        if not args.summarize_only:
            subprocess.run([sys.executable, str(cwd / 'profile-native.py'), '--exe', str(exe),
                            '--capture', 'time', '--duration', str(args.duration), '--output', str(output)], check=True)

results = []
for name, _exe in variants:
    samples = []
    for run in range(1, args.runs + 1):
        raw = profiles / name / f'native-mars-time-{run}.json'
        data = json.loads(raw.read_text())
        assert data['exe_sha256'] == hashes[name], f'Binary changed: {raw}'
        assert data['duration_seconds'] == args.duration
        assert data['capture'] == 'time' and data['layer'] == 'mars'
        count = sum(int(re.search(r'(\d+) requests in', data[key])[1]) for key in ['warmup', 'measured']) + 1
        log = data['server_log']
        user = float(re.search(r'user\s+([\d.]+)', log)[1])
        system = float(re.search(r'sys\s+([\d.]+)', log)[1])
        instructions = re.search(r'(\d+)\s+instructions retired', log)
        samples.append({
            'run': run, 'rps': float(re.search(r'Requests/sec:\s+([\d.]+)', data['measured'])[1]),
            'total_requests_including_warmup': count,
            'user_us_per_request': user * 1e6 / count, 'cpu_us_per_request': (user + system) * 1e6 / count,
            **({'instructions_per_request': int(instructions[1]) / count} if instructions else {}),
            'raw': str(raw.relative_to(cwd)) if raw.is_relative_to(cwd) else str(raw),
        })
    metrics = ['rps', 'user_us_per_request', 'cpu_us_per_request']
    if all('instructions_per_request' in sample for sample in samples):
        metrics.append('instructions_per_request')
    results.append({'variant': name, 'exe_sha256': hashes[name], 'samples': samples,
                    'median': {key: statistics.median(sample[key] for sample in samples) for key in metrics}})

patch = cwd / args.patch
report = {
    'summarized_at': datetime.now(timezone.utc).isoformat(),
    'environment': {'platform': platform.platform(), 'arch': platform.machine(),
                    'moon': subprocess.check_output(['moon', 'version'], text=True).strip()},
    'reference_patch': {'base_async_tag': 'v0.21.3', 'path': str(patch.relative_to(cwd)),
                        'sha256': hashlib.sha256(patch.read_bytes()).hexdigest(),
                        'note': 'Build provenance must be recorded separately; binary hashes identify the compared inputs.'},
    'settings': {'runs': args.runs, 'order': 'alternating baseline/patched each round',
                 'duration_seconds': args.duration, 'warmup_seconds': 1, 'connections': 64, 'wrk_threads': 4,
                 'route': 'GET /api/users/123', 'response': '200 text/plain; charset=utf-8, body 123',
                 'build': 'native release', 'profiler': 'none; /usr/bin/time -lp measures server process only',
                 'note': 'CPU and instruction normalization includes warmup and one readiness request. Shared developer machine: other active workloads caused substantial RPS variance. These are exploratory results, not isolated throughput claims.'},
    'results': results,
}
output = cwd / args.output
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps([{result['variant']: result['median']} for result in results], indent=2))
