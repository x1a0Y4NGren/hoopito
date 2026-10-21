import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { mkdir, readFile, readdir, writeFile } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const sha256 = (value) => createHash('sha256').update(value).digest('hex');
const validSha256 = (value) => /^[a-f0-9]{64}$/.test(value);

function checkSourceSha(sourceSha) {
  if (!/^[a-f0-9]{40}$/.test(sourceSha ?? '')) {
    throw new Error('A complete 40-character source SHA is required');
  }
}

function checkPath(path) {
  if (
    typeof path !== 'string' ||
    path.includes('\\') ||
    path.includes(':') ||
    path.split('/').some((part) => !part || part === '.' || part === '..')
  ) {
    throw new Error(`Invalid manifest path: ${String(path)}`);
  }
}

async function collectFiles(dist, prefix = '') {
  const files = [];
  for (const entry of await readdir(dist, { withFileTypes: true })) {
    const path = prefix ? `${prefix}/${entry.name}` : entry.name;
    checkPath(path);
    if (entry.isDirectory()) {
      files.push(...(await collectFiles(join(dist, entry.name), path)));
    } else if (entry.isFile()) {
      const contents = await readFile(join(dist, entry.name));
      files.push({ path, bytes: contents.length, sha256: sha256(contents) });
    } else {
      throw new Error(`Build output contains a non-regular file: ${path}`);
    }
  }
  return files.sort((left, right) =>
    left.path < right.path ? -1 : left.path > right.path ? 1 : 0,
  );
}

function fileDigest(files) {
  return sha256(JSON.stringify(files));
}

function summary(manifest) {
  return {
    sourceSha: manifest.sourceSha,
    distSha256: manifest.distSha256,
    fileCount: manifest.files.length,
    bytes: manifest.files.reduce((total, file) => total + file.bytes, 0),
  };
}

export async function createBuildArtifact({ dist, manifestPath, sourceSha }) {
  checkSourceSha(sourceSha);
  const files = await collectFiles(dist);
  if (files.length === 0) throw new Error('Cannot bind an empty build output');
  const manifest = {
    schema: 1,
    sourceSha,
    distSha256: fileDigest(files),
    files,
  };
  await mkdir(dirname(manifestPath), { recursive: true });
  await writeFile(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
  return summary(manifest);
}

export async function verifyBuildArtifact({ dist, manifestPath, sourceSha }) {
  checkSourceSha(sourceSha);
  const manifest = JSON.parse(await readFile(manifestPath, 'utf8'));
  if (manifest.schema !== 1 || !Array.isArray(manifest.files)) {
    throw new Error('Unsupported build artifact manifest');
  }
  if (manifest.sourceSha !== sourceSha) {
    throw new Error(`Build source SHA mismatch: expected ${sourceSha}`);
  }
  for (const file of manifest.files) {
    checkPath(file.path);
    if (!validSha256(file.sha256) || !Number.isSafeInteger(file.bytes)) {
      throw new Error(`Invalid manifest file metadata: ${file.path}`);
    }
  }
  if (
    !validSha256(manifest.distSha256) ||
    fileDigest(manifest.files) !== manifest.distSha256
  ) {
    throw new Error('Build manifest digest mismatch');
  }
  const actual = await collectFiles(dist);
  if (
    !actual.length ||
    JSON.stringify(actual.map((file) => file.path)) !==
      JSON.stringify(manifest.files.map((file) => file.path))
  ) {
    throw new Error('Build artifact file set mismatch');
  }
  for (let index = 0; index < actual.length; index += 1) {
    if (
      actual[index].sha256 !== manifest.files[index].sha256 ||
      actual[index].bytes !== manifest.files[index].bytes
    ) {
      throw new Error(`Build content mismatch: ${actual[index].path}`);
    }
  }
  return summary(manifest);
}

if (
  process.argv[1] &&
  fileURLToPath(import.meta.url) === resolve(process.argv[1])
) {
  try {
    const [mode, ...args] = process.argv.slice(2);
    const options = {};
    for (let index = 0; index < args.length; index += 2) {
      if (!['--source-sha', '--dist', '--manifest'].includes(args[index])) {
        throw new Error(`Unsupported argument: ${args[index]}`);
      }
      if (!args[index + 1]) throw new Error(`Missing ${args[index]} value`);
      options[args[index]] = args[index + 1];
    }
    const sourceSha = options['--source-sha'] ?? process.env.GITHUB_SHA;
    checkSourceSha(sourceSha);
    const checkedOutSha = execFileSync('git', ['rev-parse', 'HEAD'], {
      encoding: 'utf8',
    }).trim();
    if (sourceSha !== checkedOutSha) {
      throw new Error(
        'Requested source SHA does not match the checked-out source',
      );
    }
    const operation =
      mode === 'create'
        ? createBuildArtifact
        : mode === 'verify'
          ? verifyBuildArtifact
          : null;
    if (!operation) throw new Error('Expected create or verify');
    const result = await operation({
      sourceSha,
      dist: resolve(options['--dist'] ?? 'dist'),
      manifestPath: resolve(options['--manifest'] ?? 'build-artifact.json'),
    });
    process.stdout.write(
      `${JSON.stringify({ status: 'pass', ...result }, null, 2)}\n`,
    );
  } catch (error) {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  }
}
