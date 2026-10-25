import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import {
  access,
  mkdtemp,
  mkdir,
  readFile,
  readdir,
  rm,
  symlink,
  writeFile,
} from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';

const apk = Buffer.from('PK\x03\x04a signed APK fixture');
const release = {
  apkUrl: '/downloads/v2.0.1/Hoopito-v2.0.1-android.apk',
  apkFilename: 'Hoopito-v2.0.1-android.apk',
  upstreamApkUrl:
    'https://github.com/example/hoopito/releases/download/v2.0.1/Hoopito-v2.0.1-android.apk',
  apkBytes: apk.length,
  sha256: createHash('sha256').update(apk).digest('hex'),
};

async function fixture(t: { after: (fn: () => Promise<void>) => void }) {
  const directory = await mkdtemp(join(tmpdir(), 'hoopito-apk-'));
  t.after(() => rm(directory, { recursive: true, force: true }));
  const dist = join(directory, 'dist');
  const cache = join(directory, 'cache');
  const localFile = join(directory, 'release.apk');
  const destination = join(dist, 'downloads/v2.0.1', release.apkFilename);
  let prepareDownload;
  try {
    ({ prepareDownload } = await import('../scripts/prepare-download.mjs'));
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== 'ERR_MODULE_NOT_FOUND')
      throw error;
    assert.fail('The bounded APK preparation script has not been implemented');
  }
  return { directory, dist, cache, localFile, destination, prepareDownload };
}

test('a verified local APK is copied into the versioned website download path', async (t) => {
  const { dist, cache, localFile, destination, prepareDownload } =
    await fixture(t);
  await writeFile(localFile, apk);
  await prepareDownload({
    release,
    dist,
    cache,
    localFile,
    fetch: () => assert.fail('A verified local APK must not use the network'),
  });
  assert.deepEqual(await readFile(destination), apk);
  assert.deepEqual(await readFile(localFile), apk);
});

for (const source of ['local', 'cache'] as const) {
  for (const damage of ['truncated', 'same-size tampering'] as const) {
    test(`a ${source} APK with ${damage} fails before it can become a public download`, async (t) => {
      const { dist, cache, localFile, destination, prepareDownload } =
        await fixture(t);
      await mkdir(cache, { recursive: true });
      const sourcePath =
        source === 'local' ? localFile : join(cache, `${release.sha256}.apk`);
      await writeFile(
        sourcePath,
        damage === 'truncated' ? apk.subarray(0, -1) : Buffer.alloc(apk.length),
      );
      await assert.rejects(
        prepareDownload({
          release,
          dist,
          cache,
          ...(source === 'local' ? { localFile } : {}),
          fetch: () => assert.fail('A corrupt artifact must fail closed'),
        }),
        damage === 'truncated' ? /size|bytes/i : /sha-?256|hash/i,
      );
      await assert.rejects(access(destination), { code: 'ENOENT' });
    });
  }
}

test('a SHA-keyed cache is verified and reused without a network request', async (t) => {
  const { dist, cache, destination, prepareDownload } = await fixture(t);
  await mkdir(cache, { recursive: true });
  await writeFile(join(cache, `${release.sha256}.apk`), apk);
  await prepareDownload({
    release,
    dist,
    cache,
    fetch: () => assert.fail('A valid cache must not use the network'),
  });
  assert.deepEqual(await readFile(destination), apk);
});

function response(body: BodyInit = apk, headers: HeadersInit = {}) {
  return new Response(body, {
    headers: { 'content-type': 'application/octet-stream', ...headers },
  });
}

test('a streamed download uses the pinned URL and populates verified output and cache', async (t) => {
  const { dist, cache, destination, prepareDownload } = await fixture(t);
  const urls: string[] = [];
  await prepareDownload({
    release,
    dist,
    cache,
    fetch: async (url, options) => {
      urls.push(String(url));
      assert.ok(options?.signal instanceof AbortSignal);
      return response();
    },
  });
  assert.deepEqual(urls, [release.upstreamApkUrl]);
  assert.deepEqual(await readFile(destination), apk);
  assert.deepEqual(await readFile(join(cache, `${release.sha256}.apk`)), apk);
  assert.deepEqual(await readdir(cache), [`${release.sha256}.apk`]);
});

test('one network failure may recover on the second attempt', async (t) => {
  const { dist, cache, destination, prepareDownload } = await fixture(t);
  let attempts = 0;
  await prepareDownload({
    release,
    dist,
    cache,
    fetch: async () => {
      if (++attempts === 1)
        throw new TypeError('fetch failed: connection reset');
      return response();
    },
  });
  assert.equal(attempts, 2);
  assert.deepEqual(await readFile(destination), apk);
});

test('persistent network failure stops at two attempts and leaves no partial artifact', async (t) => {
  const { dist, cache, destination, prepareDownload } = await fixture(t);
  let attempts = 0;
  await assert.rejects(
    prepareDownload({
      release,
      dist,
      cache,
      fetch: async () => {
        attempts++;
        throw new TypeError('fetch failed: offline');
      },
    }),
    /offline|network|fetch failed/i,
  );
  assert.equal(attempts, 2);
  assert.deepEqual(await readdir(cache), []);
  await assert.rejects(access(destination), { code: 'ENOENT' });
});

for (const stalledPart of ['headers', 'body'] as const) {
  test(`the attempt deadline includes stalled ${stalledPart} and remains bounded`, async (t) => {
    const { dist, cache, destination, prepareDownload } = await fixture(t);
    let attempts = 0;
    const started = performance.now();
    await assert.rejects(
      prepareDownload({
        release,
        dist,
        cache,
        timeoutMs: 15,
        fetch: async () => {
          attempts++;
          if (stalledPart === 'headers') return new Promise(() => {});
          return response(new ReadableStream({ start() {} }));
        },
      }),
      /timeout|timed out|deadline/i,
    );
    assert.equal(attempts, 2);
    assert.ok(performance.now() - started < 1_000);
    assert.deepEqual(await readdir(cache), []);
    await assert.rejects(access(destination), { code: 'ENOENT' });
  });
}

const invalidDownloads = [
  {
    name: 'HTTP errors',
    result: () => new Response('unavailable', { status: 503 }),
    message: /HTTP.*503/i,
  },
  {
    name: 'HTML responses',
    result: () =>
      response('<html>error</html>', { 'content-type': 'text/html' }),
    message: /content.type|HTML/i,
  },
  {
    name: 'truncated bodies',
    result: () => response(apk.subarray(0, -1)),
    message: /size|bytes/i,
  },
  {
    name: 'oversize bodies',
    result: () => response(Buffer.concat([apk, Buffer.from('extra')])),
    message: /size|bytes/i,
  },
  {
    name: 'incorrect SHA-256',
    result: () => response(Buffer.alloc(apk.length)),
    message: /sha-?256|hash/i,
  },
  {
    name: 'incorrect declared length',
    result: () => response(apk, { 'content-length': '2' }),
    message: /size|length|bytes/i,
  },
];

for (const { name, result, message } of invalidDownloads) {
  test(`${name} fail immediately without retries or partial files`, async (t) => {
    const { dist, cache, destination, prepareDownload } = await fixture(t);
    let attempts = 0;
    await assert.rejects(
      prepareDownload({
        release,
        dist,
        cache,
        fetch: async () => {
          attempts++;
          return result();
        },
      }),
      message,
    );
    assert.equal(attempts, 1);
    assert.deepEqual(await readdir(cache), []);
    await assert.rejects(access(destination), { code: 'ENOENT' });
  });
}

test('a body connection failure discards the partial file before retrying', async (t) => {
  const { dist, cache, destination, prepareDownload } = await fixture(t);
  let attempts = 0;
  await prepareDownload({
    release,
    dist,
    cache,
    fetch: async () => {
      if (++attempts === 2) return response();
      let sent = false;
      return response(
        new ReadableStream({
          pull(controller) {
            if (sent) controller.error(new TypeError('connection reset'));
            else {
              sent = true;
              controller.enqueue(apk.subarray(0, 4));
            }
          },
        }),
      );
    },
  });
  assert.equal(attempts, 2);
  assert.deepEqual(await readFile(destination), apk);
  assert.deepEqual(await readdir(cache), [`${release.sha256}.apk`]);
});

for (const apkUrl of [
  '/../outside.apk',
  '/downloads/../../outside.apk',
  '//downloads/v2.0.1/Hoopito-v2.0.1-android.apk',
  '/downloads/%2e%2e/Hoopito-v2.0.1-android.apk',
  '/downloads/v2.0.1\\Hoopito-v2.0.1-android.apk',
  `${release.apkUrl}?source=other`,
  'https://example.com/downloads/Hoopito-v2.0.1-android.apk',
]) {
  test(`unsafe output path ${apkUrl} is rejected before filesystem or network access`, async (t) => {
    const { directory, dist, cache, localFile, prepareDownload } =
      await fixture(t);
    await writeFile(localFile, apk);
    await assert.rejects(
      prepareDownload({
        release: { ...release, apkUrl },
        dist,
        cache,
        localFile,
      }),
      /path|URL|filename/i,
    );
    assert.deepEqual(await readdir(directory), ['release.apk']);
  });
}

test('a mismatched download filename is rejected', async (t) => {
  const { dist, cache, localFile, prepareDownload } = await fixture(t);
  await writeFile(localFile, apk);
  await assert.rejects(
    prepareDownload({
      release: { ...release, apkFilename: '../outside.apk' },
      dist,
      cache,
      localFile,
    }),
    /path|filename/i,
  );
});

test('an output directory junction cannot redirect the download outside dist', async (t) => {
  const { directory, dist, cache, localFile, prepareDownload } =
    await fixture(t);
  const outside = join(directory, 'outside');
  await mkdir(dist);
  await mkdir(outside);
  await symlink(outside, join(dist, 'downloads'), 'junction');
  await writeFile(localFile, apk);
  await assert.rejects(
    prepareDownload({ release, dist, cache, localFile }),
    /symlink|symbolic|junction|path/i,
  );
  assert.deepEqual(await readdir(outside), []);
});

test('failure preserves an existing public artifact without temporary siblings', async (t) => {
  const { dist, cache, localFile, destination, prepareDownload } =
    await fixture(t);
  await mkdir(join(dist, 'downloads/v2.0.1'), { recursive: true });
  await writeFile(destination, apk);
  await writeFile(localFile, Buffer.alloc(apk.length));
  await assert.rejects(
    prepareDownload({ release, dist, cache, localFile }),
    /sha-?256|hash/i,
  );
  assert.deepEqual(await readFile(destination), apk);
  assert.deepEqual(await readdir(join(dist, 'downloads/v2.0.1')), [
    release.apkFilename,
  ]);
});
