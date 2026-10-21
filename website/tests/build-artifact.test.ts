import assert from 'node:assert/strict';
import { mkdtemp, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';

const sourceSha = 'd2be9e046b5b1becb6432b683fdb97f56505ea18';

async function fixture(t: { after: (fn: () => Promise<void>) => void }) {
  const directory = await mkdtemp(join(tmpdir(), 'hoopito-build-artifact-'));
  t.after(() => rm(directory, { recursive: true, force: true }));
  const dist = join(directory, 'dist');
  const manifestPath = join(directory, 'build-artifact.json');
  await mkdir(join(dist, '_astro'), { recursive: true });
  await writeFile(join(dist, 'index.html'), '<h1>球豆</h1>\n');
  await writeFile(
    join(dist, '_astro', 'main.js'),
    'export const version = 1;\n',
  );
  const { createBuildArtifact, verifyBuildArtifact } =
    await import('../scripts/build-artifact.mjs');
  return { dist, manifestPath, createBuildArtifact, verifyBuildArtifact };
}

test('a build artifact binds portable file hashes and a digest to its source SHA', async (t) => {
  const fixtureData = await fixture(t);
  const { dist, manifestPath, createBuildArtifact, verifyBuildArtifact } =
    fixtureData;
  const created = await createBuildArtifact({ dist, manifestPath, sourceSha });
  const verified = await verifyBuildArtifact({ dist, manifestPath, sourceSha });
  assert.equal(verified.sourceSha, sourceSha);
  assert.equal(verified.distSha256, created.distSha256);
  assert.equal(verified.fileCount, 2);
  const manifest = JSON.parse(await readFile(manifestPath, 'utf8'));
  assert.deepEqual(
    manifest.files.map((file: { path: string }) => file.path),
    ['_astro/main.js', 'index.html'],
  );
  assert.match(manifest.distSha256, /^[a-f0-9]{64}$/);
  assert.equal(manifest.files[1].bytes, Buffer.byteLength('<h1>球豆</h1>\n'));
});

test('verification rejects a build from another source commit', async (t) => {
  const { dist, manifestPath, createBuildArtifact, verifyBuildArtifact } =
    await fixture(t);
  await createBuildArtifact({ dist, manifestPath, sourceSha });
  await assert.rejects(
    verifyBuildArtifact({
      dist,
      manifestPath,
      sourceSha: '1111111111111111111111111111111111111111',
    }),
    /source SHA/i,
  );
});

test('verification rejects same-size content tampering', async (t) => {
  const { dist, manifestPath, createBuildArtifact, verifyBuildArtifact } =
    await fixture(t);
  await createBuildArtifact({ dist, manifestPath, sourceSha });
  await writeFile(
    join(dist, '_astro', 'main.js'),
    'export const version = 2;\n',
  );
  await assert.rejects(
    verifyBuildArtifact({ dist, manifestPath, sourceSha }),
    /content mismatch.*_astro\/main\.js/i,
  );
});

for (const mutation of ['missing', 'extra'] as const) {
  test(`verification rejects ${mutation} output files`, async (t) => {
    const { dist, manifestPath, createBuildArtifact, verifyBuildArtifact } =
      await fixture(t);
    await createBuildArtifact({ dist, manifestPath, sourceSha });
    if (mutation === 'missing') await rm(join(dist, 'index.html'));
    else await writeFile(join(dist, 'stale.html'), 'an older build');
    await assert.rejects(
      verifyBuildArtifact({ dist, manifestPath, sourceSha }),
      /file set mismatch/i,
    );
  });
}

test('verification rejects a corrupted digest and unsafe manifest paths', async (t) => {
  const { dist, manifestPath, createBuildArtifact, verifyBuildArtifact } =
    await fixture(t);
  await createBuildArtifact({ dist, manifestPath, sourceSha });
  const original = JSON.parse(await readFile(manifestPath, 'utf8'));
  await writeFile(
    manifestPath,
    JSON.stringify({ ...original, distSha256: '0'.repeat(64) }),
  );
  await assert.rejects(
    verifyBuildArtifact({ dist, manifestPath, sourceSha }),
    /manifest digest/i,
  );
  for (const path of ['../outside.html', '/index.html', 'x\\index.html']) {
    const unsafe = structuredClone(original);
    unsafe.files[0].path = path;
    await writeFile(manifestPath, JSON.stringify(unsafe));
    await assert.rejects(
      verifyBuildArtifact({ dist, manifestPath, sourceSha }),
      /manifest path/i,
    );
  }
});

test('creation rejects empty output and invalid source identities', async (t) => {
  const { dist, manifestPath, createBuildArtifact } = await fixture(t);
  await assert.rejects(
    createBuildArtifact({ dist, manifestPath, sourceSha: 'latest' }),
    /source SHA/i,
  );
  await rm(dist, { recursive: true });
  await mkdir(dist);
  await assert.rejects(
    createBuildArtifact({ dist, manifestPath, sourceSha }),
    /empty/i,
  );
});
