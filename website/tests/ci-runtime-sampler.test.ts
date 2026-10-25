import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { EventEmitter } from 'node:events';
import { promisify } from 'node:util';
import { test } from 'node:test';

const execute = promisify(execFile);
const script = resolve('scripts/ci-runtime-sampler.mjs');
const sampler = () => import('../scripts/ci-runtime-sampler.mjs');
async function fixture(t: { after: (fn: () => Promise<void>) => void }) {
  const directory = await mkdtemp(join(tmpdir(), 'hoopito-ci-runtime-'));
  t.after(() => rm(directory, { recursive: true, force: true }));
  return { directory, output: join(directory, 'runtime.jsonl') };
}
const records = async (output: string) =>
  (await readFile(output, 'utf8'))
    .trim()
    .split('\n')
    .map((line) => JSON.parse(line));

test('proc stat parsing keeps offsets when comm contains spaces and parentheses', async () => {
  const { parseProcStat } = await sampler();
  const fields = Array.from({ length: 22 }, (_, index) => String(index + 3));
  fields[0] = 'S';
  fields[1] = '120';
  fields[9] = '73';
  fields[11] = '401';
  fields[12] = '207';
  fields[17] = '19';
  fields[21] = '256';
  assert.deepEqual(
    parseProcStat(`321 (chrome (worker) name) ${fields.join(' ')}`, 4096),
    {
      pid: 321,
      ppid: 120,
      comm: 'chrome (worker) name',
      majflt: 73,
      utime: 401,
      stime: 207,
      threads: 19,
      rssKiB: 1024,
    },
  );
  assert.equal(parseProcStat('not a process', 4096), null);
});

test('descendant discovery excludes unrelated browsers and tolerates a cycle', async () => {
  const { descendantPids } = await sampler();
  const graph = [
    { pid: 10, ppid: 1 },
    { pid: 11, ppid: 10 },
    { pid: 12, ppid: 11 },
    { pid: 13, ppid: 12 },
    { pid: 20, ppid: 1 },
    { pid: 21, ppid: 20 },
    { pid: 30, ppid: 31 },
    { pid: 31, ppid: 30 },
  ];
  assert.deepEqual(
    [...descendantPids(graph, 10)].sort((a, b) => a - b),
    [11, 12, 13],
  );
  assert.deepEqual([...descendantPids(graph, 30)], [31]);
});

test('Linux samples retain raw pressure and only owned Chrome metrics without command secrets', async () => {
  const { collectSample } = await sampler();
  const stat = (pid: number, parent: number) => {
    const fields = Array.from({ length: 22 }, () => '0');
    fields[0] = 'S';
    fields[1] = String(parent);
    fields[21] = '256';
    return `${pid} (chrome worker) ${fields.join(' ')}`;
  };
  const files = new Map([
    ['/proc/self/cgroup', '0::/test-cgroup\n'],
    ['/proc/10/stat', stat(10, 1)],
    ['/proc/11/stat', stat(11, 10)],
    ['/proc/12/stat', stat(12, 11)],
    ['/proc/20/stat', stat(20, 1)],
    [
      '/proc/11/cmdline',
      '/private/chrome\0--secret=password\0--type=renderer\0',
    ],
    ['/proc/12/cmdline', '/private/node\0--type=browser\0'],
    ['/proc/11/schedstat', '112 223 3\n'],
  ]);
  const value = await collectSample(
    10,
    { platform: 'linux', pageSize: 4096 },
    {
      readFile: async (path: string) => files.get(path) ?? 'raw-counters\n',
      readdir: async () => ['self', '10', '11', '12', '20'],
    },
  );
  assert.equal(value.raw['/proc/stat'], 'raw-counters\n');
  assert.equal(
    value.raw['/sys/fs/cgroup/test-cgroup/cpu.pressure'],
    'raw-counters\n',
  );
  assert.equal(value.processes.length, 1);
  assert.deepEqual(value.processes[0], {
    pid: 11,
    ppid: 10,
    majflt: 0,
    utime: 0,
    stime: 0,
    threads: 0,
    rssKiB: 1024,
    type: 'renderer',
    schedstat: '112 223 3',
  });
  assert.equal(JSON.stringify(value).includes('password'), false);
  assert.equal(JSON.stringify(value).includes('/private'), false);
});

test('CLI preserves nonzero exit, stdout and stderr and appends its final sample', async (t) => {
  const { output } = await fixture(t);
  await writeFile(output, '{"kind":"prior-run"}\n');
  let failure: { code?: number; stdout?: string; stderr?: string } = {};
  try {
    await execute(process.execPath, [
      script,
      '--output',
      output,
      '--',
      process.execPath,
      '-e',
      'process.stdout.write("child-out");process.stderr.write("child-err");process.exit(17)',
    ]);
    assert.fail('the child failure must propagate');
  } catch (error) {
    failure = error as typeof failure;
  }
  assert.equal(failure.code, 17);
  assert.match(failure.stdout!, /child-out/);
  assert.match(failure.stderr!, /child-err/);
  const saved = await records(output);
  assert.equal(saved[0].kind, 'prior-run');
  assert.equal(saved[1].kind, 'environment');
  assert.ok(saved[1].cpuModels.length > 0);
  assert.ok(saved[1].availableParallelism >= 1);
  assert.deepEqual(
    saved
      .filter((value) => value.kind === 'sample')
      .map((value) => value.phase),
    ['initial', 'final'],
  );
  assert.equal(saved.at(-1).child.code, 17);
  assert.equal(saved.at(-1).child.signal, null);
  assert.ok(saved.at(-1).collectionMs >= 0);
  assert.ok(saved.at(-1).monotonicMs >= saved[2].monotonicMs);
  assert.equal(
    saved.some(
      (value) => 'command' in value || 'args' in value || 'env' in value,
    ),
    false,
  );
});

test('sampling is serial, timers stop and signal listeners are removed on child exit', async (t) => {
  const { output } = await fixture(t);
  const { runSampler } = await sampler();
  const signals = new EventEmitter();
  let active = 0,
    peak = 0,
    calls = 0;
  const code = await runSampler({
    command: process.execPath,
    args: ['-e', 'setTimeout(() => process.exit(0), 160)'],
    output,
    intervalMs: 5,
    signals,
    collect: async () => {
      calls++;
      active++;
      peak = Math.max(peak, active);
      await new Promise((resolve) => setTimeout(resolve, 25));
      active--;
      return { probe: true };
    },
  });
  assert.equal(code, 0);
  assert.equal(peak, 1);
  assert.ok(calls >= 3);
  const done = calls;
  await new Promise((resolve) => setTimeout(resolve, 40));
  assert.equal(calls, done);
  assert.equal(
    signals.listenerCount('SIGINT') + signals.listenerCount('SIGTERM'),
    0,
  );
  assert.equal((await records(output)).at(-1).phase, 'final');
});

test('telemetry failures never change the supervised child failure', async (t) => {
  const { directory } = await fixture(t);
  const { runSampler } = await sampler();
  const code = await runSampler({
    command: process.execPath,
    args: ['-e', 'process.exit(23)'],
    output: directory,
    collect: async () => {
      throw new Error('diagnostic read failed');
    },
  });
  assert.equal(code, 23);
});

test('sampling cap reserves a final record and read failures remain diagnostic', async (t) => {
  const { output } = await fixture(t);
  const { runSampler, MAX_SAMPLES } = await sampler();
  assert.equal(MAX_SAMPLES, 602);
  const code = await runSampler({
    command: process.execPath,
    args: ['-e', 'setTimeout(() => process.exit(19), 120)'],
    output,
    intervalMs: 1,
    maxSamples: 4,
    collect: async () => {
      throw Object.assign(new Error('read failed'), { code: 'ENOENT' });
    },
  });
  assert.equal(code, 19);
  const samples = (await records(output)).filter(
    (value) => value.kind === 'sample',
  );
  assert.equal(samples.length, 4);
  assert.equal(samples.at(-1).phase, 'final');
  assert.equal(samples.at(-1).errors[0].code, 'ENOENT');
});

test('spawn failure is nonzero and retains a final diagnostic record', async (t) => {
  const { directory, output } = await fixture(t);
  const { runSampler } = await sampler();
  assert.equal(
    await runSampler({ command: join(directory, 'absent-executable'), output }),
    127,
  );
  assert.equal((await records(output)).at(-1).child.error, 'ENOENT');
});

test('a forwarded termination affects only the owned child and still writes final evidence', async (t) => {
  const { output } = await fixture(t);
  const { runSampler } = await sampler();
  const signals = new EventEmitter();
  let sent = false;
  const code = await runSampler({
    command: process.execPath,
    args: ['-e', 'setInterval(() => {}, 1000)'],
    output,
    signals,
    collect: async () => {
      if (!sent) {
        sent = true;
        signals.emit('SIGTERM');
      }
      return {};
    },
  });
  assert.equal(code, 143);
  assert.equal((await records(output)).at(-1).child.signal, 'SIGTERM');
  assert.equal(signals.listenerCount('SIGTERM'), 0);
});

test(
  'Linux termination reaches the owned child group including its grandchild',
  { skip: process.platform !== 'linux', timeout: 5000 },
  async (t) => {
    const { directory, output } = await fixture(t);
    const ready = join(directory, 'grandchild-ready');
    const closed = join(directory, 'grandchild-closed');
    const grandchild = `const fs=require('node:fs');process.on('SIGTERM',()=>{fs.writeFileSync(process.argv[2],'closed');process.exit(0)});fs.writeFileSync(process.argv[1],'ready');setInterval(()=>{},1000);setTimeout(()=>process.exit(42),2500);`;
    const parent = `require('node:child_process').spawn(process.execPath,['-e',${JSON.stringify(grandchild)},${JSON.stringify(ready)},${JSON.stringify(closed)}],{stdio:'inherit'});setInterval(()=>{},1000);setTimeout(()=>process.exit(42),2500);`;
    const signals = new EventEmitter();
    const { runSampler } = await sampler();
    const code = await runSampler({
      command: process.execPath,
      args: ['-e', parent],
      output,
      intervalMs: 10,
      signals,
      collect: async () => {
        try {
          await readFile(ready);
          signals.emit('SIGTERM');
        } catch {
          /* Wait for the handler to be installed. */
        }
        return {};
      },
    });
    assert.equal(code, 143);
    for (let attempt = 0; ; attempt++) {
      try {
        assert.equal(await readFile(closed, 'utf8'), 'closed');
        break;
      } catch (error) {
        if (
          attempt >= 100 ||
          (error as NodeJS.ErrnoException).code !== 'ENOENT'
        )
          throw error;
        await new Promise((resolve) => setTimeout(resolve, 10));
      }
    }
  },
);
