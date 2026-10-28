// Published-release data only. The development app may already have a later version.
export interface PublishedAndroidRelease {
  version: string;
  appVersion: string;
  versionCode: number;
  minimumApi: number;
  releaseNotes: { zh: string; en: string };
  apkBytes: number;
  apkFilename: string;
  apkUrl: string;
  upstreamApkUrl: string;
  sha256: string;
}

function positiveInteger(value: number): boolean {
  return Number.isSafeInteger(value) && value > 0;
}

export function serializeAndroidUpdate(
  release: PublishedAndroidRelease,
): string {
  if (
    typeof release.version !== 'string' ||
    !/^\d+\.\d+\.\d+$/.test(release.version) ||
    !positiveInteger(release.versionCode) ||
    release.appVersion !== `${release.version}+${release.versionCode}` ||
    !positiveInteger(release.minimumApi) ||
    !positiveInteger(release.apkBytes) ||
    typeof release.sha256 !== 'string' ||
    !/^[a-f0-9]{64}$/.test(release.sha256) ||
    !['zh', 'en'].every((language) => {
      const note = release.releaseNotes?.[language as 'zh' | 'en'];
      return typeof note === 'string' && note.trim().length > 0;
    })
  ) {
    throw new Error('Invalid published Android release metadata or appVersion');
  }
  const filename = `Hoopito-v${release.version}-android.apk`;
  const apkPath = `/downloads/v${release.version}/${filename}`;
  const fallback = `https://github.com/x1a0Y4NGren/hoopito/releases/download/v${release.version}/${filename}`;
  if (
    release.apkFilename !== filename ||
    release.apkUrl !== apkPath ||
    release.upstreamApkUrl !== fallback
  ) {
    throw new Error('APK URLs must match the official pinned release paths');
  }
  const json = `${JSON.stringify(
    {
      schemaVersion: 1,
      applicationId: 'io.github.x1a0y4ngren.hooptrace',
      versionName: release.version,
      versionCode: release.versionCode,
      minimumApi: release.minimumApi,
      releaseNotes: {
        zh: release.releaseNotes.zh,
        en: release.releaseNotes.en,
      },
      apk: {
        bytes: release.apkBytes,
        sha256: release.sha256,
        url: `https://hoopito.com${apkPath}`,
        fallbackUrl: fallback,
      },
    },
    null,
    2,
  )}\n`;
  if (new TextEncoder().encode(json).length > 65536) {
    throw new Error('Android update metadata exceeds 64 KiB');
  }
  return json;
}
