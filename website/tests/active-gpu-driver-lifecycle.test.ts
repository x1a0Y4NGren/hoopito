import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import ts from 'typescript';

// Execute the real development driver's phase loop with fake owned resources.
// The driver module itself is never imported, so this cannot launch Playwright,
// fetch a page, create its output directory or execute any GPU probe.
const path = new URL('../scripts/diagnose-active-gpu.mjs', import.meta.url);
const source = ts.createSourceFile(
  path.pathname,
  readFileSync(path, 'utf8'),
  ts.ScriptTarget.Latest,
  true,
  ts.ScriptKind.JS,
);
const loop = source.statements.find(
  (node) =>
    ts.isForOfStatement(node) && node.expression.getText(source) === 'phases',
);
assert.ok(loop, 'The actual diagnostic phase loop must be present.');
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;

type Failure = {
  launch?: boolean;
  context?: boolean;
  contextClose?: boolean;
  browserClose?: boolean;
};

async function exercise(failures: Failure[]) {
  const calls: string[] = [];
  const report = { phases: [] as any[] };
  const saved: any[][] = [];
  let launches = 0;
  const chromium = {
    async launch() {
      const index = launches++;
      const failure = failures[index];
      calls.push(`launch:${index}`);
      if (failure.launch) throw new Error('fixture launch failure');
      return {
        async newContext() {
          calls.push(`context:${index}`);
          if (failure.context)
            throw new Error('fixture context creation failure');
          return {
            async addInitScript() {
              // Stop the measurement body at its first operation. Lifecycle
              // behavior must still preserve this original phase failure.
              throw new Error('fixture phase body failure');
            },
            async close() {
              calls.push(`context.close:${index}`);
              if (failure.contextClose)
                throw new Error('fixture context close failure');
            },
          };
        },
        async close() {
          calls.push(`browser.close:${index}`);
          if (failure.browserClose)
            throw new Error('fixture browser close failure');
        },
      };
    },
  };
  const scope = {
    phases: failures.map((_, index) => `phase-${index}`),
    chromium,
    viewport: { width: 1920, height: 1080, dpr: 2 },
    adapter: { HighPart: 0, LowPart: 1 },
    process: { env: {} },
    report,
    save: async () => saved.push(JSON.parse(JSON.stringify(report.phases))),
    console: { log() {} },
    installActiveGpuProbe() {},
  };
  const run = new AsyncFunction(...Object.keys(scope), loop!.getText(source));
  let escaped: Error | undefined;
  try {
    await run(...Object.values(scope));
  } catch (error) {
    escaped = error as Error;
  }
  return { calls, report, saved, escaped };
}

test('GPU diagnostic launch failure still saves its phase and proceeds', async () => {
  const result = await exercise([{ launch: true }, {}]);
  assert.equal(result.report.phases.length, 2);
  assert.equal(result.saved.length, 2);
  assert.match(result.report.phases[0].error, /launch failure/);
  assert.equal(result.escaped, undefined);
});

test('GPU diagnostic context creation failure closes its browser and saves', async () => {
  const result = await exercise([{ context: true }]);
  assert.ok(result.calls.includes('browser.close:0'));
  assert.equal(result.saved.length, 1);
  assert.match(result.report.phases[0].error, /context creation failure/);
  assert.equal(result.escaped, undefined);
});

test('GPU diagnostic context close failure cannot skip browser close or evidence', async () => {
  const result = await exercise([{ contextClose: true }]);
  assert.ok(result.calls.includes('browser.close:0'));
  assert.equal(result.saved.length, 1);
  assert.match(result.report.phases[0].error, /phase body failure/);
  assert.match(
    JSON.stringify(result.report.phases[0].cleanupErrors),
    /context close failure/,
  );
  assert.equal(result.escaped, undefined);
});

test('GPU diagnostic browser close failure still saves stage evidence', async () => {
  const result = await exercise([{ browserClose: true }]);
  assert.equal(result.saved.length, 1);
  assert.match(result.report.phases[0].error, /phase body failure/);
  assert.match(
    JSON.stringify(result.report.phases[0].cleanupErrors),
    /browser close failure/,
  );
  assert.equal(result.escaped, undefined);
});

test('GPU diagnostic preserves both independent cleanup failures and next phase', async () => {
  const result = await exercise([
    { contextClose: true, browserClose: true },
    {},
  ]);
  assert.equal(result.report.phases.length, 2);
  assert.equal(result.saved.length, 2);
  assert.equal(result.report.phases[0].cleanupErrors.length, 2);
  assert.match(result.report.phases[0].error, /phase body failure/);
  assert.ok(result.calls.includes('context.close:1'));
  assert.ok(result.calls.includes('browser.close:1'));
  assert.equal(result.escaped, undefined);
});

test('GPU diagnostic ordinary phase failure keeps existing cleanup behavior', async () => {
  const result = await exercise([{}]);
  assert.deepEqual(result.calls, [
    'launch:0',
    'context:0',
    'context.close:0',
    'browser.close:0',
  ]);
  assert.equal(result.saved.length, 1);
  assert.match(result.report.phases[0].error, /phase body failure/);
  assert.equal(result.escaped, undefined);
});
