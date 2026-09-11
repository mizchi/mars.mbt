import { execFileSync } from 'node:child_process';
import { cpSync, mkdtempSync, mkdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const cwd = dirname(fileURLToPath(import.meta.url));
const [revision = 'HEAD', ...args] = process.argv.slice(2);
const commit = execFileSync('git', ['rev-parse', '--verify', `${revision}^{commit}`], { cwd, encoding: 'utf8' }).trim();
const directory = mkdtempSync(join(tmpdir(), 'mars-benchmark-'));
try {
  // Export only library sources; the checkout and its build artifacts stay intact.
  const archive = execFileSync('git', ['archive', commit, 'src', 'moon.mod'], { cwd: dirname(cwd), maxBuffer: 16 * 1024 * 1024 });
  execFileSync('tar', ['-x', '-C', directory], { input: archive });
  const bench = join(directory, 'bench');
  mkdirSync(bench);
  for (const name of ['moon.work', 'moon.mod', 'bridge']) {
    cpSync(join(cwd, name), join(bench, name), { recursive: true });
  }
  execFileSync('moon', ['build', '--target', 'js', '--release'], { cwd: bench, stdio: 'inherit' });
  execFileSync(process.execPath, [
    '--expose-gc', join(cwd, 'bench.mjs'),
    '--baseline-module', join(bench, '_build/js/release/build/mizchi/mars_bench/mars_bench.js'),
    '--baseline-revision', commit,
    ...args,
  ], { cwd, stdio: 'inherit' });
} finally {
  rmSync(directory, { recursive: true, force: true });
}
