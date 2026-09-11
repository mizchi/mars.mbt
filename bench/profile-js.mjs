import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { Session } from 'node:inspector/promises';
import { cpus } from 'node:os';
import { dirname, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { parseArgs } from 'node:util';
import { matchCases } from './cases.mjs';

const cwd = dirname(fileURLToPath(import.meta.url));
const { values } = parseArgs({ allowNegative: true, options: {
  scenario: { type: 'string', default: 'fetch' },
  module: { type: 'string', default: '_build/js/release/build/mizchi/mars_bench/mars_bench.js' },
  duration: { type: 'string', default: '5000' },
  output: { type: 'string', default: 'profiles/js-fetch' },
  profile: { type: 'boolean', default: true },
} });
const duration = Number(values.duration);
assert(Number.isFinite(duration) && duration > 0);
const modulePath = resolve(cwd, values.module);
const mars = await import(pathToFileURL(modulePath));
const isFetch = values.scenario.startsWith('fetch');
let invoke;
if (isFetch) {
  assert(['fetch', 'fetch-middleware'].includes(values.scenario));
  const middleware = values.scenario === 'fetch-middleware';
  const handler = mars.new_app(middleware);
  const response = await handler(new Request('http://localhost/api/users/123'));
  assert.equal(response.status, 200);
  assert.equal(await response.text(), '123');
  assert.equal(response.headers.get('x-bench'), middleware ? '1' : null);
  invoke = async (i) => {
    const response = await handler(new Request(`http://localhost/api/users/${i % 2 ? '123' : '456'}`));
    globalThis.__marsProfileSink = await response.text();
  };
} else {
  const scenario = matchCases.find(({ name }) => name === values.scenario);
  assert(scenario, `Unknown scenario: ${values.scenario}`);
  const router = mars.new_router();
  scenario.routes.forEach(([method, path], i) => mars.add_route(router, method, path, i + 1));
  const expected = scenario.paths.map((path) => JSON.parse(mars.match_json(router, scenario.method, path)).length);
  assert(expected.every((count) => count > 0));
  invoke = (i) => { globalThis.__marsProfileSink = mars.match_count(router, scenario.method, scenario.paths[i % scenario.paths.length]); };
}
const batch = async (count) => {
  if (isFetch) {
    for (let i = 0; i < count; i++) await invoke(i);
  } else {
    for (let i = 0; i < count; i++) invoke(i);
  }
};
await batch(isFetch ? 20000 : 100000);
global.gc?.();
const session = new Session();
if (values.profile) {
  session.connect();
  await session.post('Profiler.enable');
  await session.post('Profiler.setSamplingInterval', { interval: 100 });
  await session.post('Profiler.start');
}
const batchSize = isFetch ? 1000 : 10000;
const start = performance.now();
let operations = 0;
do {
  await batch(batchSize);
  operations += batchSize;
} while (performance.now() - start < duration);
const elapsedMs = performance.now() - start;
const output = resolve(cwd, values.output);
mkdirSync(dirname(output), { recursive: true });
if (values.profile) {
  const { profile } = await session.post('Profiler.stop');
  session.disconnect();
  writeFileSync(`${output}.cpuprofile`, JSON.stringify(profile));
  const env = { ...process.env };
  if (process.platform === 'darwin') env.DYLD_LIBRARY_PATH = ['/usr/lib', env.DYLD_LIBRARY_PATH].filter(Boolean).join(':');
  execFileSync('moon-pprof', ['cpuprofile2pprof', `${output}.cpuprofile`, `${output}.pb.gz`], { env, stdio: 'inherit' });
  const summary = execFileSync('moon-pprof', ['summary', `${output}.pb.gz`], { env, encoding: 'utf8' });
  writeFileSync(`${output}.txt`, `${summary.trimEnd()}\n`);
  console.log(summary);
}
const metadata = {
  scenario: values.scenario, measured_at: new Date().toISOString(),
  node: process.version, cpu: cpus()[0].model, arch: process.arch,
  module_sha256: createHash('sha256').update(readFileSync(modulePath)).digest('hex'),
  operations, elapsed_ms: elapsedMs, ns_per_op: elapsedMs * 1e6 / operations,
  profile: values.profile, sampling_interval_us: values.profile ? 100 : null,
  note: 'Warmup excluded. Profiled timing includes sampling overhead; use the paired benchmark for performance comparisons.',
};
writeFileSync(`${output}.json`, `${JSON.stringify(metadata, null, 2)}\n`);
console.log(metadata);
