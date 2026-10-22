import { spawn, execFile } from 'node:child_process';
import { appendFile, mkdir, readFile, readdir } from 'node:fs/promises';
import {
  availableParallelism,
  constants,
  cpus,
  platform,
  release,
} from 'node:os';
import { basename, dirname, join, posix, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';

const execute = promisify(execFile);
const codeOf = (error) => error?.code ?? error?.name ?? 'diagnostic-error';
export const MAX_SAMPLES = 602;

export function parseProcStat(value, pageSize) {
  const match = /^(\d+) \((.*)\) (\S.*)$/.exec(value.trim());
  if (!match) return null;
  const fields = match[3].split(/\s+/);
  if (fields.length < 22) return null;
  const [ppid, majflt, utime, stime, threads, rss] = [1, 9, 11, 12, 17, 21].map(
    (index) => Number(fields[index]),
  );
  if (![ppid, majflt, utime, stime, threads, rss].every(Number.isFinite))
    return null;
  return {
    pid: Number(match[1]),
    ppid,
    comm: match[2],
    majflt,
    utime,
    stime,
    threads,
    rssKiB: pageSize ? (rss * pageSize) / 1024 : null,
  };
}

export function descendantPids(processes, root) {
  const owned = new Set([root]);
  for (let changed = true; changed;) {
    changed = false;
    for (const { pid, ppid } of processes) {
      if (owned.has(ppid) && !owned.has(pid)) {
        owned.add(pid);
        changed = true;
      }
    }
  }
  owned.delete(root);
  return owned;
}

async function environment() {
  const errors = [];
  const config = async (name) => {
    try {
      const { stdout } = await execute('getconf', [name], { timeout: 1000 });
      const value = Number(stdout.trim());
      if (!Number.isSafeInteger(value) || value <= 0)
        throw new Error('invalid-getconf');
      return value;
    } catch (error) {
      errors.push({ operation: name, code: codeOf(error) });
      return null;
    }
  };
  const linux = platform() === 'linux';
  return {
    kind: 'environment',
    platform: platform(),
    kernel: release(),
    cpuModels: [...new Set(cpus().map((cpu) => cpu.model))],
    cpuCount: cpus().length,
    availableParallelism: availableParallelism(),
    clockTicksPerSecond: linux ? await config('CLK_TCK') : null,
    pageSize: linux ? await config('PAGESIZE') : null,
    sourceSha: /^[a-f0-9]{40}$/i.test(process.env.GITHUB_SHA ?? '')
      ? process.env.GITHUB_SHA
      : null,
    errors,
  };
}

/**
 * @param {number} root
 * @param {{platform: string, pageSize?: number | null}} metadata
 * @param {{readFile: (path: string, encoding: 'utf8') => Promise<string>, readdir: (path: string) => Promise<string[]>}} io
 */
export async function collectSample(
  root,
  metadata,
  io = { readFile, readdir },
) {
  /** @type {Record<string, string | null>} */
  const raw = {};
  if (metadata.platform !== 'linux')
    return { scope: 'metadata-only', processes: [], raw };
  const errors = [];
  const read = async (path) => {
    try {
      return await io.readFile(path, 'utf8');
    } catch (error) {
      errors.push({ operation: path, code: codeOf(error) });
      return null;
    }
  };
  const files = [
    '/proc/stat',
    '/proc/meminfo',
    '/proc/pressure/cpu',
    '/proc/pressure/io',
    '/proc/pressure/memory',
  ];
  const cgroup = await read('/proc/self/cgroup');
  raw['/proc/self/cgroup'] = cgroup;
  // Read the supervisor's cgroup: its child inherits this resource boundary.
  const relative = cgroup
    ?.split('\n')
    .find((line) => line.startsWith('0::'))
    ?.slice(3);
  const cgroupRoot =
    relative && !relative.split('/').includes('..')
      ? posix.join('/sys/fs/cgroup', relative)
      : '/sys/fs/cgroup';
  for (const file of [
    'cpu.stat',
    'cpu.max',
    'memory.current',
    'memory.max',
    'memory.events',
    'cpu.pressure',
    'io.pressure',
    'memory.pressure',
  ])
    files.push(posix.join(cgroupRoot, file));
  for (const file of files) raw[file] = await read(file);
  const processes = [];
  for (const entry of await io.readdir('/proc')) {
    if (!/^\d+$/.test(entry)) continue;
    try {
      const parsed = parseProcStat(
        await io.readFile(`/proc/${entry}/stat`, 'utf8'),
        metadata.pageSize,
      );
      if (parsed) processes.push(parsed);
    } catch {
      /* Process exit during enumeration is normal. */
    }
  }
  const owned = descendantPids(processes, root);
  const chrome = [];
  for (const process of processes) {
    if (!owned.has(process.pid)) continue;
    try {
      const args = (
        await io.readFile(`/proc/${process.pid}/cmdline`, 'utf8')
      ).split('\0');
      if (
        !/^(?:chrome|chromium(?:-browser)?|headless_shell)$/.test(
          basename(args[0]),
        )
      )
        continue;
      const token = args.find((arg) => /^--type=[a-z0-9-]+$/.test(arg));
      const { comm, ...metrics } = process;
      chrome.push({
        ...metrics,
        type: token ? token.slice(7) : 'browser',
        schedstat:
          (await read(`/proc/${process.pid}/schedstat`))?.trim() ?? null,
      });
    } catch {
      /* Do not retain another process's command line or transient errors. */
    }
  }
  return { scope: 'owned-descendant-chrome', raw, processes: chrome, errors };
}

/**
 * @param {{command: string, args?: string[], output: string, intervalMs?: number, maxSamples?: number, signals?: import('node:events').EventEmitter, collect?: (root: number, metadata: {platform: string, pageSize?: number | null}) => Promise<object>}} options
 */
export async function runSampler({
  command,
  args = [],
  output,
  intervalMs = 2000,
  maxSamples = MAX_SAMPLES,
  signals = process,
  collect = collectSample,
}) {
  let warned = false;
  const warn = (error) => {
    if (warned) return;
    warned = true;
    console.error(
      `Runtime telemetry unavailable (${codeOf(error)}); child result is unchanged.`,
    );
  };
  const write = async (record) => {
    try {
      await mkdir(dirname(output), { recursive: true });
      await appendFile(output, `${JSON.stringify(record)}\n`);
    } catch (error) {
      warn(error);
    }
  };
  let metadata;
  try {
    metadata = await environment();
  } catch (error) {
    warn(error);
    metadata = {
      kind: 'environment',
      platform: platform(),
      errors: [codeOf(error)],
    };
  }
  const runId = `${Date.now()}-${process.pid}`;
  await write({ ...metadata, runId, timestamp: new Date().toISOString() });
  // npm.cmd requires a shell on Windows. Invoke its Node entry point instead;
  // arguments stay separate and are never interpolated into a command string.
  if (platform() === 'win32' && /^npm(?:\.cmd)?$/i.test(basename(command))) {
    args = [
      process.env.npm_execpath ??
        join(dirname(process.execPath), 'node_modules/npm/bin/npm-cli.js'),
      ...args,
    ];
    command = process.execPath;
  }
  const child = spawn(command, args, {
    stdio: 'inherit',
    shell: false,
    detached: platform() === 'linux',
  });
  let result;
  const ended = new Promise((resolve) => {
    child.once('error', (error) => {
      result = { code: 127, signal: null, error: codeOf(error) };
      resolve(result);
    });
    child.once('exit', (code, signal) => {
      result = { code, signal };
      resolve(result);
    });
  });
  const forward = (signal) => {
    if (result) return;
    try {
      // The Linux child created its own group; never signal the caller's group.
      if (platform() === 'linux' && child.pid > 0)
        process.kill(-child.pid, signal);
      else child.kill(signal);
    } catch (error) {
      if (error.code !== 'ESRCH') warn(error);
    }
  };
  const onInt = () => forward('SIGINT'),
    onTerm = () => forward('SIGTERM');
  signals.on('SIGINT', onInt);
  signals.on('SIGTERM', onTerm);
  let timer,
    pending = Promise.resolve(),
    sampleCount = 0;
  const sample = async (phase) => {
    sampleCount++;
    const started = performance.now();
    let data;
    try {
      data = await collect(child.pid, metadata);
    } catch (error) {
      data = { errors: [{ operation: 'sample', code: codeOf(error) }] };
    }
    await write({
      ...data,
      kind: 'sample',
      runId,
      phase,
      timestamp: new Date().toISOString(),
      monotonicMs: performance.now(),
      collectionMs: performance.now() - started,
      ...(phase === 'final' ? { child: result } : {}),
    });
  };
  const schedule = () => {
    if (result || sampleCount >= maxSamples - 1) return;
    timer = setTimeout(() => {
      pending = sample('interval').then(schedule);
    }, intervalMs);
  };
  try {
    await sample('initial');
    schedule();
    await ended;
    clearTimeout(timer);
    await pending;
    await sample('final');
  } finally {
    clearTimeout(timer);
    signals.removeListener('SIGINT', onInt);
    signals.removeListener('SIGTERM', onTerm);
  }
  return result.code ?? 128 + (constants.signals[result.signal] ?? 1);
}

if (
  process.argv[1] &&
  resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  const args = process.argv.slice(2);
  if (args[0] !== '--output' || !args[1] || args[2] !== '--' || !args[3]) {
    console.error(
      'Usage: node ci-runtime-sampler.mjs --output FILE -- COMMAND [ARGS]',
    );
    process.exitCode = 2;
  } else {
    process.exitCode = await runSampler({
      output: args[1],
      command: args[3],
      args: args.slice(4),
    });
  }
}
