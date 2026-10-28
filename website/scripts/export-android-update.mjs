import { mkdir, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { serializeAndroidUpdate } from '../src/data/android-update.ts';
import { verifyApkFile } from './prepare-download.mjs';

export async function exportAndroidUpdate({ release, output, apkPath = '' }) {
  const json = serializeAndroidUpdate(release);
  if (apkPath) await verifyApkFile(apkPath, release);
  await mkdir(dirname(resolve(output)), { recursive: true });
  await writeFile(output, json, 'utf8');
  return resolve(output);
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(resolve(process.argv[1])).href
) {
  try {
    const args = process.argv.slice(2);
    if (args.includes('--help')) {
      console.log(
        'Usage: npm run export:android-update -- [--output <android-update.json>] [--apk <signed.apk>]',
      );
    } else {
      let output = fileURLToPath(
        new URL('../output/releases/android-update.json', import.meta.url),
      );
      let apkPath = '';
      while (args.length) {
        const flag = args.shift();
        const value = args.shift();
        if (
          !['--output', '--apk'].includes(flag) ||
          !value ||
          value.startsWith('--')
        ) {
          throw new Error(
            'Expected --output <path> or --apk <path>; see --help',
          );
        }
        if (flag === '--output') output = value;
        else apkPath = value;
      }
      const { release } = await import('../src/data/release.ts');
      const destination = await exportAndroidUpdate({
        release,
        output,
        apkPath,
      });
      console.log(
        `Exported Android update metadata: ${destination} (${apkPath ? 'APK verified' : 'metadata only; APK not verified'})`,
      );
    }
  } catch (error) {
    console.error(`Android update export failed: ${error.message}`);
    process.exitCode = 1;
  }
}
