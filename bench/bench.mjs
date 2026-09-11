import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { cpus, platform, release, totalmem } from 'node:os';
import { dirname, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { parseArgs } from 'node:util';
import { Hono } from 'hono';
import { TrieRouter } from 'hono/router/trie-router';
import { matchCases, registrationCases } from './cases.mjs';

const cwd = dirname(fileURLToPath(import.meta.url));
const { values } = parseArgs({ options: {
  output: { type: 'string', default: 'results/latest.json' },
  label: { type: 'string', default: 'working-tree' },
  runs: { type: 'string', default: '9' },
  iterations: { type: 'string', default: '100000' },
  warmup: { type: 'string', default: '20000' },
  'fetch-iterations': { type: 'string', default: '5000' },
  'allow-invalid-fetch': { type: 'boolean', default: false },
  'baseline-module': { type: 'string' },
  'baseline-revision': { type: 'string' },
} });
const positive = (name) => {
  const value = Number(values[name]);
  assert(Number.isSafeInteger(value) && value > 0, `${name} must be a positive integer`);
  return value;
};
const runs = positive('runs');
const iterations = positive('iterations');
const warmup = positive('warmup');
const fetchIterations = positive('fetch-iterations');
assert(global.gc, 'Run with node --expose-gc');
execFileSync('moon', ['build', '--target', 'js', '--release'], { cwd, stdio: ['ignore', 'ignore', 'inherit'] });
const mars = await import('./_build/js/release/build/mizchi/mars_bench/mars_bench.js');
const baseline = values['baseline-module'] ? await import(pathToFileURL(resolve(values['baseline-module']))) : null;

// Validate metadata before spending time on measurements. Registry packages
// can still use either manifest format.
const dependencies = Object.fromEntries([
  'moonbitlang/async', 'moonbitlang/x', 'mizchi/x', 'moonbitlang/regexp',
].map((name) => {
  const path = resolve(cwd, '.mooncakes', name, 'moon.mod');
  const version = existsSync(path)
    ? readFileSync(path, 'utf8').match(/^version\s*=\s*"([^"]+)"/m)?.[1]
    : JSON.parse(readFileSync(`${path}.json`, 'utf8')).version;
  assert(version, `Missing resolved version for ${name}`);
  return [name, version];
}));

const moonAdapter = (module) => ({
  create: module.new_router,
  add: module.add_route,
  count: module.match_count,
  entries: (router, method, path) => JSON.parse(module.match_json(router, method, path)),
});

const adapters = {
  ...(baseline ? { baseline: moonAdapter(baseline) } : {}),
  mars: moonAdapter(mars),
  hono: {
    create: () => new TrieRouter(),
    add: (router, method, path, id) => router.add(method, path, id),
    count: (router, method, path) => router.match(method, path)[0].length,
    entries: (router, method, path) => JSON.parse(JSON.stringify(router.match(method, path)[0])),
  },
};

function setup(adapter, routes) {
  const router = adapter.create();
  routes.forEach(([method, path], i) => adapter.add(router, method, path, i + 1));
  return router;
}

function statistics(samples) {
  const sorted = [...samples].sort((a, b) => a - b);
  const mean = samples.reduce((a, b) => a + b, 0) / samples.length;
  return {
    median_ns: (sorted[Math.floor((sorted.length - 1) / 2)] + sorted[Math.floor(sorted.length / 2)]) / 2,
    mean_ns: mean,
    stddev_ns: Math.sqrt(samples.reduce((sum, x) => sum + (x - mean) ** 2, 0) / samples.length),
    min_ns: sorted[0], max_ns: sorted.at(-1), samples_ns: samples,
  };
}

const results = [];
const failures = [];
async function measure(name, kind, functions, count, isAsync = false) {
  const engines = Object.keys(functions);
  const samples = Object.fromEntries(engines.map((name) => [name, []]));
  const invoke = async (fn, n) => {
    if (isAsync) {
      for (let i = 0; i < n; i++) globalThis.__marsBenchSink = await fn(i);
    } else {
      for (let i = 0; i < n; i++) globalThis.__marsBenchSink = fn(i);
    }
  };
  for (const fn of Object.values(functions)) await invoke(fn, isAsync ? Math.min(warmup, 1000) : warmup);
  for (let run = 0; run < runs; run++) {
    // Rotate engine order so every implementation occupies every position.
    const offset = run % engines.length;
    for (const engine of [...engines.slice(offset), ...engines.slice(0, offset)]) {
      global.gc();
      const start = performance.now();
      await invoke(functions[engine], count);
      samples[engine].push((performance.now() - start) * 1e6 / count);
    }
  }
  const row = { name, kind, iterations: count, ...Object.fromEntries(engines.map((engine) => [engine, statistics(samples[engine])])) };
  results.push(row);
  console.log(`${kind.padEnd(8)} ${name.padEnd(25)} ${engines.map((engine) => `${engine} ${row[engine].median_ns.toFixed(1)} ns`).join(' | ')}`);
}

for (const scenario of registrationCases) {
  await measure(scenario.name, 'register', Object.fromEntries(Object.entries(adapters).map(([name, adapter]) => [
    name, () => setup(adapter, scenario.routes),
  ])), iterations);
}

for (const scenario of matchCases) {
  const routers = Object.fromEntries(Object.entries(adapters).map(([name, adapter]) => [name, setup(adapter, scenario.routes)]));
  for (const path of scenario.paths) {
    for (const engine of Object.keys(adapters)) {
      assert.deepEqual(adapters[engine].entries(routers[engine], scenario.method, path), adapters.hono.entries(routers.hono, scenario.method, path), `${engine}: ${scenario.name}: ${path}`);
    }
  }
  await measure(scenario.name, 'match', Object.fromEntries(Object.entries(adapters).map(([name, adapter]) => [
    name, (i) => adapter.count(routers[name], scenario.method, scenario.paths[i % scenario.paths.length]),
  ])), iterations);
}

for (const middleware of [false, true]) {
  const hono = new Hono();
  if (middleware) hono.use('*', async (ctx, next) => { ctx.header('x-bench', '1'); await next(); });
  hono.get('/api/users/:id', (ctx) => ctx.text(ctx.req.param('id')));
  const handlers = { ...(baseline ? { baseline: baseline.new_app(middleware) } : {}), mars: mars.new_app(middleware), hono: (request) => hono.fetch(request) };
  let valid = true;
  for (const [engine, handler] of Object.entries(handlers)) {
    try {
      const response = await handler(new Request('http://localhost/api/users/123'));
      assert.equal(response.status, 200);
      assert.equal(await response.text(), '123');
      assert.equal(response.headers.get('x-bench'), middleware ? '1' : null);
    } catch (error) {
      if (engine !== 'baseline') valid = false;
      delete handlers[engine];
      failures.push({ kind: 'fetch', middleware, engine, error: String(error) });
      console.error(`Skipping invalid fetch case (${engine}): ${error}`);
    }
  }
  if (!valid) continue;
  await measure(middleware ? 'dynamic + middleware' : 'dynamic response', 'fetch', Object.fromEntries(Object.entries(handlers).map(([name, handler]) => [
    name, async (i) => {
      const response = await handler(new Request(`http://localhost/api/users/${i % 2 ? '123' : '456'}`));
      return response.text();
    },
  ])), fetchIterations, true);
}

const git = (...args) => execFileSync('git', args, { cwd, encoding: 'utf8' }).trim();
const hash = (text) => createHash('sha256').update(text).digest('hex');
const report = {
  schema: 1, label: values.label, measured_at: new Date().toISOString(),
  environment: { node: process.version, moon: execFileSync('moon', ['version'], { encoding: 'utf8' }).trim(), platform: platform(), release: release(), arch: process.arch, cpu: cpus()[0].model, memory_bytes: totalmem(), hono: JSON.parse(readFileSync(resolve(cwd, 'node_modules/hono/package.json'))).version },
  source: { commit: git('rev-parse', 'HEAD'), implementation_diff_sha256: hash(git('diff', '--no-ext-diff', 'HEAD', '--', '../src')), harness_sha256: hash(['bench.mjs', 'cases.mjs', 'bridge/bridge.mbt', 'bridge/moon.pkg'].map((path) => readFileSync(resolve(cwd, path), 'utf8')).join('\n')), mars_module_sha256: hash(readFileSync(resolve(cwd, '_build/js/release/build/mizchi/mars_bench/mars_bench.js'))), baseline_revision: values['baseline-revision'] ?? null, baseline_module_sha256: baseline ? hash(readFileSync(resolve(values['baseline-module']))) : null },
  settings: { runs, iterations, warmup, fetch_iterations: fetchIterations, gc: 'before each measured batch', order: 'rotating engine order within each case', unit: 'ns/op', build: 'release', fetch: 'in-process, fresh Request and consumed response body; no network' },
  dependencies, results, failures,
};
const output = resolve(cwd, values.output);
mkdirSync(dirname(output), { recursive: true });
writeFileSync(output, `${JSON.stringify(report, null, 2)}\n`);
console.log(`Saved ${output}`);
if (failures.some(({ engine }) => engine !== 'baseline') && !values['allow-invalid-fetch']) process.exitCode = 1;
