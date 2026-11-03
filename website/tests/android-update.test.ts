import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { release } from '../src/data/release.ts';
import { serializeAndroidUpdate } from '../src/data/android-update.ts';
import { GET } from '../src/pages/updates/android/stable.json.ts';
import { exportAndroidUpdate } from '../scripts/export-android-update.mjs';

test('stable metadata describes the published APK independently of development app version', async () => {
  const metadata = JSON.parse(serializeAndroidUpdate(release));
  assert.deepEqual(metadata, {
    schemaVersion: 1,
    applicationId: 'io.github.x1a0y4ngren.hooptrace',
    versionName: '2.1.0',
    versionCode: 6,
    minimumApi: 24,
    releaseNotes: release.releaseNotes,
    apk: {
      bytes: 77976935,
      sha256:
        'c408707fbb1298f845e059c1a7eeada7d5474ca987ba04e46dfd9d2dbee7fb1a',
      url: 'https://hoopito.com/downloads/v2.1.0/Hoopito-v2.1.0-android.apk',
      fallbackUrl:
        'https://github.com/x1a0Y4NGren/hoopito/releases/download/v2.1.0/Hoopito-v2.1.0-android.apk',
    },
  });
  assert.ok(metadata.releaseNotes.zh.trim());
  assert.ok(metadata.releaseNotes.en.trim());
  const response = GET();
  assert.equal(
    response.headers.get('content-type'),
    'application/json; charset=utf-8',
  );
  assert.equal(await response.text(), serializeAndroidUpdate(release));
});

test('rejects inconsistent versions, invalid types and unofficial APK URLs', () => {
  for (const invalid of [
    { versionCode: 7 },
    { versionCode: '6' },
    { version: '2.1.1' },
    { appVersion: '2.1.0+06' },
    { minimumApi: 0 },
    { apkBytes: 1.5 },
    { sha256: 'not-a-hash' },
    { releaseNotes: { zh: '', en: 'Notes' } },
    { releaseNotes: { zh: 'Notes', en: false } },
    { releaseNotes: { zh: 'x'.repeat(65536), en: 'Notes' } },
    { apkUrl: '//evil.example/update.apk' },
    { apkUrl: '/downloads/v2.1.1/Hoopito-v2.1.0-android.apk' },
    {
      upstreamApkUrl: release.upstreamApkUrl.replace(
        'github.com',
        'evil.example',
      ),
    },
    {
      upstreamApkUrl: release.upstreamApkUrl.replace(
        'x1a0Y4NGren',
        'another-owner',
      ),
    },
    { upstreamApkUrl: release.upstreamApkUrl + '?redirect=bad' },
    { upstreamApkUrl: release.upstreamApkUrl.replace('https:', 'http:') },
  ]) {
    assert.throws(
      () => serializeAndroidUpdate({ ...release, ...invalid } as never),
      JSON.stringify(invalid),
    );
  }
});

test('export bytes match the website and optional APK validation fails before writing', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'hoopito-update-'));
  try {
    const output = join(directory, 'android-update.json');
    await exportAndroidUpdate({ release, output });
    assert.equal(await readFile(output, 'utf8'), await GET().text());
    const apkPath = join(directory, 'candidate.apk');
    await writeFile(apkPath, 'wrong APK');
    await assert.rejects(
      exportAndroidUpdate({ release, output, apkPath }),
      /size mismatch|exceeds pinned size/,
    );
    assert.equal(
      await readFile(output, 'utf8'),
      serializeAndroidUpdate(release),
    );
    const bytes = Buffer.from('verified test APK');
    await writeFile(apkPath, bytes);
    const fixture = {
      ...release,
      apkBytes: bytes.length,
      sha256: createHash('sha256').update(bytes).digest('hex'),
    };
    await exportAndroidUpdate({ release: fixture, output, apkPath });
    assert.equal(
      await readFile(output, 'utf8'),
      serializeAndroidUpdate(fixture),
    );
    await writeFile(apkPath, Buffer.alloc(bytes.length, 0));
    await assert.rejects(
      exportAndroidUpdate({ release: fixture, output, apkPath }),
      /SHA-256 mismatch/,
    );
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

test('stable feed revalidates while the versioned APK remains immutable', async () => {
  const config = JSON.parse(
    await readFile(new URL('../vercel.json', import.meta.url), 'utf8'),
  );
  const headersFor = (path: string) =>
    config.headers.find((rule: { source: string }) => rule.source === path)
      ?.headers;
  assert.ok(
    headersFor('/updates/android/stable.json')?.some(
      (header: { key: string; value: string }) =>
        header.key === 'Cache-Control' &&
        header.value.includes('must-revalidate') &&
        !header.value.includes('immutable'),
    ),
  );
  assert.ok(
    headersFor(release.apkUrl)?.some(
      (header: { key: string; value: string }) =>
        header.key === 'Cache-Control' && header.value.includes('immutable'),
    ),
  );
});
