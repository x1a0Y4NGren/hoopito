import { createHash, randomUUID } from 'node:crypto';
import { createReadStream, createWriteStream } from 'node:fs';
import { lstat, mkdir, rename, rm } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { Readable, Transform } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import { fileURLToPath, pathToFileURL } from 'node:url';

const website = fileURLToPath(new URL('../', import.meta.url));

class ArtifactError extends Error {}
class NetworkError extends Error {}

function validateRelease(release) {
  const parts = release.apkUrl?.split('/');
  if (
    !parts ||
    parts.length !== 4 ||
    parts[0] !== '' ||
    parts[1] !== 'downloads' ||
    !parts
      .slice(2)
      .every((part) => /^[a-zA-Z0-9][a-zA-Z0-9._-]*$/.test(part)) ||
    parts[3] !== release.apkFilename ||
    !release.apkFilename.endsWith('.apk')
  ) {
    throw new ArtifactError('Unsafe APK download path or filename');
  }
  if (!Number.isSafeInteger(release.apkBytes) || release.apkBytes < 1)
    throw new ArtifactError('Invalid pinned APK byte size');
  if (!/^[a-f0-9]{64}$/.test(release.sha256))
    throw new ArtifactError('Invalid pinned APK SHA-256');
  const upstream = new URL(release.upstreamApkUrl);
  if (
    upstream.protocol !== 'https:' ||
    upstream.hostname !== 'github.com' ||
    upstream.port ||
    upstream.username ||
    upstream.password ||
    upstream.search ||
    upstream.hash ||
    !/^\/[^/]+\/[^/]+\/releases\/download\/[^/]+\/[^/]+\.apk$/.test(
      upstream.pathname,
    ) ||
    upstream.pathname.split('/').at(-1) !== release.apkFilename
  ) {
    throw new ArtifactError(
      'APK upstream must be a pinned GitHub release asset URL',
    );
  }
  return parts.slice(1);
}

async function outputDirectory(dist, parts) {
  let directory = resolve(dist);
  await mkdir(directory, { recursive: true });
  for (const part of parts) {
    directory = join(directory, part);
    try {
      await mkdir(directory);
    } catch (error) {
      if (error.code !== 'EEXIST') throw error;
    }
    const info = await lstat(directory);
    if (!info.isDirectory() || info.isSymbolicLink())
      throw new ArtifactError(
        'APK output path contains a symbolic link or junction',
      );
  }
  return directory;
}

function verifier(release) {
  let bytes = 0;
  const hash = createHash('sha256');
  return new Transform({
    transform(chunk, _encoding, done) {
      bytes += chunk.length;
      if (bytes > release.apkBytes) {
        done(
          new ArtifactError(
            `APK exceeds pinned size (${release.apkBytes} bytes)`,
          ),
        );
        return;
      }
      hash.update(chunk);
      done(null, chunk);
    },
    flush(done) {
      if (bytes !== release.apkBytes) {
        done(
          new ArtifactError(
            `APK size mismatch: expected ${release.apkBytes} bytes, got ${bytes}`,
          ),
        );
      } else if (hash.digest('hex') !== release.sha256) {
        done(new ArtifactError('APK SHA-256 mismatch'));
      } else done();
    },
  });
}

function temporary(file) {
  return `${file}.${randomUUID()}.tmp`;
}

async function copyVerified(source, destination, release) {
  const temp = temporary(destination);
  try {
    await pipeline(
      createReadStream(source),
      verifier(release),
      createWriteStream(temp, { flags: 'wx' }),
    );
    await rename(temp, destination);
  } finally {
    await rm(temp, { force: true });
  }
}

function isNetworkFailure(error) {
  if (error instanceof ArtifactError) return false;
  if (error instanceof NetworkError || error instanceof TypeError) return true;
  return /^(?:ECONNRESET|ECONNREFUSED|ENOTFOUND|EAI_AGAIN|ETIMEDOUT|EPIPE|UND_ERR_)/.test(
    error.code ?? error.cause?.code ?? '',
  );
}

async function downloadAttempt({ release, destination, fetch, timeoutMs }) {
  const temp = temporary(destination);
  const controller = new AbortController();
  let transfer;
  let timer;
  const deadline = new Promise((_, reject) => {
    timer = setTimeout(() => {
      const error = new NetworkError(
        `APK download timed out after ${timeoutMs}ms`,
      );
      controller.abort(error);
      reject(error);
    }, timeoutMs);
  });
  const download = async () => {
    const response = await fetch(release.upstreamApkUrl, {
      signal: controller.signal,
      redirect: 'follow',
    });
    if (controller.signal.aborted) {
      await response.body?.cancel();
      throw controller.signal.reason;
    }
    try {
      if (response.status !== 200)
        throw new ArtifactError(
          `APK download returned HTTP ${response.status}`,
        );
      const contentType = response.headers
        .get('content-type')
        ?.split(';')[0]
        .trim()
        .toLowerCase();
      if (
        contentType &&
        ![
          'application/octet-stream',
          'binary/octet-stream',
          'application/vnd.android.package-archive',
          'application/zip',
        ].includes(contentType)
      ) {
        throw new ArtifactError(`Unexpected APK content-type: ${contentType}`);
      }
      const contentLength = response.headers.get('content-length');
      if (
        contentLength !== null &&
        (!/^\d+$/.test(contentLength) ||
          Number(contentLength) !== release.apkBytes)
      )
        throw new ArtifactError(
          'APK Content-Length differs from pinned byte size',
        );
      if (!response.body) throw new ArtifactError('APK response has no body');
    } catch (error) {
      void response.body?.cancel().catch(() => {});
      throw error;
    }
    transfer = pipeline(
      Readable.fromWeb(response.body),
      verifier(release),
      createWriteStream(temp, { flags: 'wx' }),
      { signal: controller.signal },
    );
    await transfer;
    if (controller.signal.aborted) throw controller.signal.reason;
  };
  try {
    await Promise.race([download(), deadline]);
    await rename(temp, destination);
  } catch (error) {
    if (controller.signal.aborted) throw controller.signal.reason;
    throw error;
  } finally {
    clearTimeout(timer);
    controller.abort();
    if (transfer) await transfer.catch(() => {});
    await rm(temp, { force: true });
  }
}

// Build-time artifact preparation; this export exists only for filesystem tests.
export async function prepareDownload({
  release,
  dist = join(website, 'dist'),
  cache = join(website, '.cache/downloads'),
  localFile = '',
  fetch = globalThis.fetch,
  timeoutMs = 120_000,
}) {
  const parts = validateRelease(release);
  if (!Number.isSafeInteger(timeoutMs) || timeoutMs < 1)
    throw new ArtifactError(
      'APK timeout must be a positive number of milliseconds',
    );
  const directory = await outputDirectory(dist, parts.slice(0, -1));
  const destination = join(directory, release.apkFilename);
  await mkdir(cache, { recursive: true });
  const cached = join(cache, `${release.sha256}.apk`);
  if (localFile) {
    await copyVerified(localFile, cached, release);
  } else {
    let exists = true;
    try {
      await lstat(cached);
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
      exists = false;
    }
    if (!exists) {
      for (let attempt = 1; attempt <= 2; attempt++) {
        try {
          await downloadAttempt({
            release,
            destination: cached,
            fetch,
            timeoutMs,
          });
          break;
        } catch (error) {
          if (attempt === 2 || !isNetworkFailure(error)) throw error;
        }
      }
    }
  }
  // Recheck the bytes during every copy, including cache hits, before publishing.
  await copyVerified(cached, destination, release);
  return destination;
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(resolve(process.argv[1])).href
) {
  try {
    const { release } = await import('../src/data/release.ts');
    const destination = await prepareDownload({
      release,
      localFile: process.env.HOOPITO_APK_PATH,
    });
    console.log(
      `Prepared verified APK: ${destination} (${release.apkBytes} bytes)`,
    );
  } catch (error) {
    console.error(`APK preparation failed: ${error.message}`);
    process.exitCode = 1;
  }
}
