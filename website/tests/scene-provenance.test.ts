import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
const record = JSON.parse(
  await readFile(
    new URL('../assets/art/scene-poster.json', import.meta.url),
    'utf8',
  ),
);

test('scene capture inputs use portable source bytes across clean checkouts', async () => {
  for (const input of record.source_inputs) {
    // Check current sources so a valid, uncommitted capture can be verified
    // before committing. The generator separately checks their actual bytes.
    const source = new URL(input.path, new URL('../', import.meta.url));
    const bytes = await readFile(source);
    const text = bytes.toString('utf8');
    assert.deepEqual(Buffer.from(text), bytes, `${input.path} must be UTF-8`);
    assert.equal(
      createHash('sha256').update(text.replace(/\r\n/g, '\n')).digest('hex'),
      input.sha256,
      `${input.path}: capture provenance must work in a clean checkout on every OS`,
    );
  }
});
