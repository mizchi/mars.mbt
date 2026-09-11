// Drain every response before closing connections. wrk aborts outstanding
// requests at shutdown, exposing Mars's existing partial-response fallback bug.
import http from 'node:http';
import { performance } from 'node:perf_hooks';

const [url, seconds, connections] = process.argv.slice(2);
const count = Number(connections);
const agent = new http.Agent({ keepAlive: true, maxSockets: count });
const started = performance.now();
const deadline = started + Number(seconds) * 1000;
const latencies = [];
let bytes = 0;

async function worker() {
  while (performance.now() < deadline) {
    const start = performance.now();
    await new Promise((resolve, reject) => {
      const request = http.get(url, { agent }, response => {
        if (response.statusCode !== 200) {
          response.resume();
          reject(new Error(`HTTP ${response.statusCode}`));
          return;
        }
        response.on('data', chunk => { bytes += chunk.length; });
        response.on('error', reject);
        response.on('end', resolve);
      });
      request.on('error', reject);
      request.setTimeout(5000, () => request.destroy(new Error('Request timed out')));
    });
    latencies.push(performance.now() - start);
  }
}

try {
  await Promise.all(Array.from({ length: count }, worker));
  const elapsed = (performance.now() - started) / 1000;
  latencies.sort((a, b) => a - b);
  console.log(JSON.stringify({
    requests: latencies.length,
    elapsed_seconds: elapsed,
    rps: latencies.length / elapsed,
    body_bytes: bytes,
    p50_ms: latencies[Math.floor(latencies.length * 0.5)],
    p99_ms: latencies[Math.floor(latencies.length * 0.99)],
  }));
} finally {
  agent.destroy();
}
