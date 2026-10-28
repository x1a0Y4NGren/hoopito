// Public signed Release APK built from 4ecd960. Later website commits do not
// change the application source or the downloaded artifact.
export const release = {
  version: '2.0.1',
  appVersion: '2.0.1+5',
  versionCode: 5,
  releaseNotes: {
    zh: '正式更名为球豆（Hoopito），同步应用名称、图标资源、网站与宣传素材。保留 v2 正式签名、安装身份、比赛数据和设置，可覆盖升级 v2.0.0。新版本继续导入旧 HoopTrace JSON；新品牌导出的 JSON 不能导入旧 App。历史 v1 仍须先把完整 JSON 保存到 App 外，再卸载安装并恢复。',
    en: 'Renamed to Hoopito (球豆), with updated app labels, assets, website and screenshots. The v2 signing identity, match data and settings are preserved; v2.0.0 supports an in-place update. Legacy HoopTrace JSON remains importable. New Hoopito JSON cannot be imported by the old app. Historical v1 users must first save a complete JSON backup outside the app, then uninstall, install and restore.',
  },
  minimumAndroid: '7.0',
  minimumApi: 24,
  apkBytes: 76441047,
  apkFilename: 'Hoopito-v2.0.1-android.apk',
  apkUrl: '/downloads/v2.0.1/Hoopito-v2.0.1-android.apk',
  upstreamApkUrl:
    'https://github.com/x1a0Y4NGren/hoopito/releases/download/v2.0.1/Hoopito-v2.0.1-android.apk',
  lanzouUrl: 'https://wwbdc.lanzoub.com/ixNAU4d7x6kj',
  lanzouPassword: 'gkyz',
  downloadPageUrl: 'https://hoopito.com/#download',
  releaseUrl: 'https://github.com/x1a0Y4NGren/hoopito/releases/tag/v2.0.1',
  sha256: 'c42a9a71836f47c70bd1cafb08ae1232083909970afdc7d9e150ce9cc68b87b9',
  repositoryUrl: 'https://github.com/x1a0Y4NGren/hoopito',
  issuesUrl: 'https://github.com/x1a0Y4NGren/hoopito/issues/new/choose',
  privacyUrl: 'https://github.com/x1a0Y4NGren/hoopito/blob/main/PRIVACY.md',
  licenseUrl: 'https://github.com/x1a0Y4NGren/hoopito/blob/main/LICENSE',
  authorUrl: 'https://github.com/x1a0Y4NGren',
} as const;
