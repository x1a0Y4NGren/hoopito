// Public signed Release APK built from 9bbd3b87e99d71f5d9117cd2c5a763a7f8b95d1f. Later website commits do not
// change the application source or the downloaded artifact.
export const release = {
  version: '2.1.0',
  appVersion: '2.1.0+6',
  versionCode: 6,
  releaseNotes: {
    zh: '新增连续对局：固定两人连打多场，汇总胜场并逐场复盘。改进自由／目标计分，支持应用内检查更新、下载和系统安装确认。沿用 v2 正式签名，可覆盖升级 v2.0.0／v2.0.1；升级前请保存完整 JSON 到 App 外。数据库升级至 schema 4，JSON 仍为格式 2；旧 App 无法恢复新版备份。v2.0.1 需先手动安装一次新版才能使用更新器。',
    en: 'Play a series with the same pair, track wins, and replay each game. Improved free/target scoring and added in-app update checks, downloads and system-confirmed installation. Retains the official v2 certificate for in-place upgrades from v2.0.0/v2.0.1. Save a full JSON backup outside the app first. Database schema is now 4; JSON format stays 2. Older apps cannot restore new backups. Install manually once from v2.0.1 to get the updater.',
  },
  minimumAndroid: '7.0',
  minimumApi: 24,
  apkBytes: 77976935,
  apkFilename: 'Hoopito-v2.1.0-android.apk',
  apkUrl: '/downloads/v2.1.0/Hoopito-v2.1.0-android.apk',
  upstreamApkUrl:
    'https://github.com/x1a0Y4NGren/hoopito/releases/download/v2.1.0/Hoopito-v2.1.0-android.apk',
  lanzouUrl: 'https://xiaoyangren.lanzoub.com/b01i5z85wb',
  lanzouPassword: 'ayj6',
  downloadPageUrl: 'https://hoopito.com/#download',
  releaseUrl: 'https://github.com/x1a0Y4NGren/hoopito/releases/tag/v2.1.0',
  sha256: 'c408707fbb1298f845e059c1a7eeada7d5474ca987ba04e46dfd9d2dbee7fb1a',
  repositoryUrl: 'https://github.com/x1a0Y4NGren/hoopito',
  issuesUrl: 'https://github.com/x1a0Y4NGren/hoopito/issues/new/choose',
  privacyUrl: 'https://github.com/x1a0Y4NGren/hoopito/blob/main/PRIVACY.md',
  licenseUrl: 'https://github.com/x1a0Y4NGren/hoopito/blob/main/LICENSE',
  authorUrl: 'https://github.com/x1a0Y4NGren',
} as const;
