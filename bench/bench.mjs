import { TrieRouter } from 'hono/router/trie-router';

// Simple benchmark helper
function bench(name, fn, iterations = 100000) {
  // Warmup
  for (let i = 0; i < 1000; i++) fn();

  if (global.gc) global.gc();

  const times = [];
  const runs = 10;

  for (let run = 0; run < runs; run++) {
    const start = performance.now();
    for (let i = 0; i < iterations; i++) fn();
    const end = performance.now();
    times.push((end - start) / iterations * 1000); // Convert to µs
  }

  const mean = times.reduce((a, b) => a + b, 0) / times.length;
  const std = Math.sqrt(times.reduce((a, b) => a + (b - mean) ** 2, 0) / times.length);
  const min = Math.min(...times);
  const max = Math.max(...times);

  console.log(`[hono] ${name}`);
  console.log(`  time (mean ± σ)         range (min … max)`);
  console.log(`  ${mean.toFixed(2)} µs ± ${std.toFixed(2)} µs     ${min.toFixed(2)} µs … ${max.toFixed(2)} µs  in ${runs} × ${iterations} runs`);
  console.log();

  return mean;
}

const handler = () => new Response('ok');

console.log('=== Hono TrieRouter Benchmarks ===\n');

// Route registration benchmarks
bench('bench: add static route', () => {
  const router = new TrieRouter();
  router.add('GET', '/api/users', handler);
});

bench('bench: add dynamic route', () => {
  const router = new TrieRouter();
  router.add('GET', '/api/users/:id', handler);
});

bench('bench: add wildcard route', () => {
  const router = new TrieRouter();
  router.add('GET', '/api/*', handler);
});

bench('bench: add regex route', () => {
  const router = new TrieRouter();
  router.add('GET', '/api/users/:id{[0-9]+}', handler);
});

// Match benchmarks - static routes
{
  const router = new TrieRouter();
  router.add('GET', '/', handler);
  router.add('GET', '/api', handler);
  router.add('GET', '/api/users', handler);
  bench('bench: match static route (short)', () => {
    router.match('GET', '/api');
  });
}

{
  const router = new TrieRouter();
  router.add('GET', '/api/v1/users/profile/settings', handler);
  bench('bench: match static route (long)', () => {
    router.match('GET', '/api/v1/users/profile/settings');
  });
}

// Match benchmarks - dynamic routes
{
  const router = new TrieRouter();
  router.add('GET', '/api/users/:id', handler);
  bench('bench: match dynamic route (:id)', () => {
    router.match('GET', '/api/users/123');
  });
}

{
  const router = new TrieRouter();
  router.add('GET', '/api/users/:user_id/posts/:post_id', handler);
  bench('bench: match nested dynamic routes', () => {
    router.match('GET', '/api/users/123/posts/456');
  });
}

// Match benchmarks - wildcard
{
  const router = new TrieRouter();
  router.add('GET', '/api/*', handler);
  bench('bench: match wildcard route', () => {
    router.match('GET', '/api/users/123/posts');
  });
}

// Match benchmarks - regex
{
  const router = new TrieRouter();
  router.add('GET', '/api/users/:id{[0-9]+}', handler);
  bench('bench: match regex route', () => {
    router.match('GET', '/api/users/123');
  });
}

{
  const router = new TrieRouter();
  router.add('GET', '/api/items/:uuid{[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}}', handler);
  bench('bench: match regex route (UUID)', () => {
    router.match('GET', '/api/items/550e8400-e29b-41d4-a716-446655440000');
  });
}

// Multi-match (middleware pattern)
{
  const router = new TrieRouter();
  router.add('ALL', '*', handler);
  router.add('GET', '/api/*', handler);
  router.add('GET', '/api/users', handler);
  router.add('GET', '/api/users/:id', handler);
  bench('bench: multi-match (middleware pattern)', () => {
    router.match('GET', '/api/users/123');
  });
}

// No match
{
  const router = new TrieRouter();
  router.add('GET', '/api/users', handler);
  router.add('GET', '/api/posts', handler);
  bench('bench: no match', () => {
    router.match('GET', '/not/found');
  });
}

// Large router benchmarks
{
  const router = new TrieRouter();
  for (let i = 0; i < 100; i++) {
    router.add('GET', `/api/resource${i}`, handler);
  }
  bench('bench: large router (100 routes) static match', () => {
    router.match('GET', '/api/resource50');
  });
}

{
  const router = new TrieRouter();
  for (let i = 0; i < 100; i++) {
    router.add('GET', `/api/resource${i}/:id`, handler);
  }
  bench('bench: large router (100 routes) dynamic match', () => {
    router.match('GET', '/api/resource50/123');
  });
}

// Mixed routes
{
  const router = new TrieRouter();
  router.add('GET', '/users/profile', handler);
  router.add('GET', '/users/:id', handler);
  router.add('GET', '/users/:id/settings', handler);
  router.add('GET', '/users/*', handler);
  bench('bench: mixed routes priority', () => {
    router.match('GET', '/users/profile');
  });
}

// Optional parameter
{
  const router = new TrieRouter();
  router.add('GET', '/api/items/:id?', handler);
  bench('bench: optional parameter', () => {
    router.match('GET', '/api/items');
  });
}

{
  const router = new TrieRouter();
  router.add('GET', '/api/items/:id?', handler);
  bench('bench: optional parameter with value', () => {
    router.match('GET', '/api/items/123');
  });
}

// Deep nesting
{
  const router = new TrieRouter();
  router.add('GET', '/a/b/c/d/e', handler);
  router.add('GET', '/a/b/c/d/:e', handler);
  router.add('GET', '/a/b/c/:d/:e', handler);
  router.add('GET', '/a/b/:c/:d/:e', handler);
  router.add('GET', '/a/:b/:c/:d/:e', handler);
  bench('bench: deep nesting (5 levels)', () => {
    router.match('GET', '/a/b/c/d/e');
  });
}

// ALL method
{
  const router = new TrieRouter();
  router.add('ALL', '/api/users', handler);
  bench('bench: ALL method matching', () => {
    router.match('POST', '/api/users');
  });
}

// Router creation
bench('bench: router creation', () => {
  new TrieRouter();
});

// Typical REST API setup
bench('bench: typical REST API setup', () => {
  const router = new TrieRouter();
  router.add('GET', '/api/users', handler);
  router.add('POST', '/api/users', handler);
  router.add('GET', '/api/users/:id', handler);
  router.add('PUT', '/api/users/:id', handler);
  router.add('DELETE', '/api/users/:id', handler);
  router.add('GET', '/api/posts', handler);
  router.add('POST', '/api/posts', handler);
  router.add('GET', '/api/posts/:id', handler);
  router.add('PUT', '/api/posts/:id', handler);
  router.add('DELETE', '/api/posts/:id', handler);
});

console.log('=== Done ===');
