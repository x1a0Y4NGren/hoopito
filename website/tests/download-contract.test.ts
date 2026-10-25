import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import { release } from '../src/data/release.ts';

const apkUrl = '/downloads/v2.0.1/Hoopito-v2.0.1-android.apk';
const apkFilename = 'Hoopito-v2.0.1-android.apk';

test('the domestic channel uses the maintainer Lanzou share and public password without a Baidu placeholder', () => {
  assert.equal(release.lanzouUrl, 'https://wwbdc.lanzoub.com/ixNAU4d7x6kj');
  assert.equal(release.lanzouPassword, 'gkyz');
  assert.equal('baiduPanUrl' in release, false);
});

test('the website serves the unchanged signed release from a versioned same-origin URL', () => {
  assert.equal(release.apkUrl, apkUrl);
  assert.equal(release.apkFilename, apkFilename);
  assert.equal(
    release.upstreamApkUrl,
    'https://github.com/x1a0Y4NGren/hoopito/releases/download/v2.0.1/Hoopito-v2.0.1-android.apk',
  );
  assert.equal(release.apkBytes, 76441047);
  assert.equal(
    release.sha256,
    'c42a9a71836f47c70bd1cafb08ae1232083909970afdc7d9e150ce9cc68b87b9',
  );
  assert.equal(release.downloadPageUrl, 'https://hoopito.com/#download');
});

test('Vercel delivers the APK as a named attachment with immutable version caching', async () => {
  const config = JSON.parse(
    await readFile(new URL('../vercel.json', import.meta.url), 'utf8'),
  );
  const rule = config.headers.find(
    (entry: { source: string }) => entry.source === apkUrl,
  );
  assert.ok(rule, 'the APK needs its own response headers');
  const headers = Object.fromEntries(
    rule.headers.map((header: { key: string; value: string }) => [
      header.key.toLowerCase(),
      header.value,
    ]),
  );
  assert.equal(
    headers['content-disposition'],
    `attachment; filename="${apkFilename}"`,
  );
  assert.equal(
    headers['content-type'],
    'application/vnd.android.package-archive',
  );
  assert.equal(headers['cache-control'], 'public, max-age=31536000, immutable');
});

test('the shared build prepares the verified APK before budget and artifact checks', async () => {
  const { scripts } = JSON.parse(
    await readFile(new URL('../package.json', import.meta.url), 'utf8'),
  );
  assert.equal(
    scripts.build,
    'astro build && node scripts/prepare-download.mjs && node scripts/check-budget.mjs',
  );
});
