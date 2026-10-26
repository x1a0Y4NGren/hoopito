import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../../', import.meta.url));
const record = JSON.parse(
  await readFile(
    new URL('../assets/art/scene-poster.json', import.meta.url),
    'utf8',
  ),
);

test('scene capture inputs match the canonical source bytes used by clean checkouts', () => {
  for (const input of record.source_inputs) {
    const path = input.path.startsWith('../')
      ? input.path.slice(3)
      : `website/${input.path}`;
    const bytes = execFileSync('git', ['show', `HEAD:${path}`], {
      cwd: root,
      maxBuffer: 4 * 1024 * 1024,
    });
    assert.equal(
      createHash('sha256').update(bytes).digest('hex'),
      input.sha256,
      `${path}: capture provenance must work in a clean checkout on every OS`,
    );
  }
});
