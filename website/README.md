# HoopTrace 介绍与下载网站

网站与 Flutter App 位于同一仓库，独立构建。Astro 输出静态 HTML，TypeScript
管理交互，GSAP 驱动页面动效，Three.js 按条件加载连续球场场景。

中文首页 `/`、英文首页 `/en/`；网站隐私说明分别为 `/privacy/` 和 `/en/privacy/`。
两种语言共享组件，文案集中在 `src/data/content.ts`；语言切换保留当前章节锚点。
真实计分与复盘截图随语言切换，网站文案独立于 Flutter ARB。

## 本地开发与验证

使用 Node.js **24.x** 和 npm，在仓库根目录执行：

```powershell
Set-Location website
npm ci
npm run dev
```

开发地址为 [http://127.0.0.1:4321](http://127.0.0.1:4321)。其余命令均在 `website/` 执行：

| 命令                   | 用途                                                                                                 |
| ---------------------- | ---------------------------------------------------------------------------------------------------- |
| `npm run check`        | Astro 与 TypeScript 检查                                                                             |
| `npm run format:check` | 检查网站源码与文档格式                                                                               |
| `npm test`             | 演示比分、位置和重置状态测试                                                                         |
| `npm run build`        | 生成 `dist/` 并检查页面实际资源图的压缩体积预算                                                      |
| `npm run preview`      | 本地查看生产构建                                                                                     |
| `npm run test:e2e`     | 在 Chromium、Firefox、WebKit 执行浏览器场景                                                          |
| `npm run assets`       | 从仓库原始素材重新生成网页图片、字体、二维码和来源清单                                               |
| `npm run measure:perf` | 用本机已安装的 Chrome 测量固定移动环境和实际 GPU 的帧间隔；结果写入 `output/playwright/performance/` |

首次运行浏览器测试时安装对应浏览器，然后先构建：

```powershell
npx playwright install --no-shell chromium firefox webkit
npm run check
npm test
npm run build
npm run test:e2e
```

Playwright 自动启动本地 `preview` 服务；失败时保留 trace 与截图，报告位于
`output/playwright/`。Linux CI 使用
`npx playwright install --with-deps --no-shell chromium firefox webkit` 安装运行时依赖。
构建预算以逐文件 gzip 计算：移动首屏每种语言不超过 500 KiB，桌面 3D
增量不超过 800 KiB。体积检查、模拟设备检查和真实 GPU 帧率各自保留证据。
本轮实际运行结果、性能环境及剩余阻碍统一见 [VERIFICATION.md](VERIFICATION.md)。

## 场景与交互

正文、截图和下载入口先由 HTML 呈现；使用浏览器原生滚动。只有视口至少
1024px、精细指针、未启用精简动效且支持 WebGL2 时，才动态加载 3D 球场。
手机和其他不满足条件的设备使用二维版本。

3D 初始化超过 8 秒、初始化失败或 WebGL 上下文丢失时回到二维；持续卡顿
先降低画质，再降级。标签页隐藏时暂停场景。页面默认静音；“精简动效”
开关与系统减少动态效果设置均会关闭 3D 和持续动画，正文与演示结果保持可用。
JavaScript 未运行时，介绍、截图和下载链接仍可访问。

投篮演示使用标明为示例的数据，只在当前页面内存中运行：选择位置后记两分，
比分由 6:6 变为 8:6，并记录一处命中落点。预设位置可用键盘操作；重置会取消
未完成的动画与旧回调。网站不读写 App 数据库，也不把演示结果保存为真实比赛。

页面不接入广告、用户分析或遥测 SDK，不设置追踪 Cookie。字体、截图和场景
资源从同一网站加载；Vercel 托管访问日志、GitHub 下载及外链访问分别受服务方
隐私政策约束。网站隐私页同时链接 App 隐私说明，区分网站访问与 App 离线使用。

## 素材与来源维护

`public/` 内网页素材进入版本管理，普通构建直接使用这些文件。原始 Logo、
字体与八张截图保留在仓库原位置；生成器只写网站资源与来源清单。它会核对
已批准的 C Logo 哈希、截图拍摄记录和合成数据声明，再生成无损 WebP。
竖版截图为 1080×1920，横屏计分图为 1920×1080，原图系统栏与像素内容保留。

完成文案、页面或交互源码修改后运行 `npm run assets`，再重新构建与检查。
生成器扫描 `src/` 的 Astro、TypeScript、JavaScript 和 JSON，形成中文字体
WOFF2 子集；Barlow 保留原有字形集。它同时更新二维码和
[ASSET_SOURCES.json](ASSET_SOURCES.json)，记录源文件与输出哈希、尺寸、字体字符、
转换方式和拍摄来源。生成命令需要仓库中的原始素材，不适用于只复制 `website/`
且没有父目录原始文件的环境。

截图拍摄记录来自 [v2.0.0 截图来源](../docs/release/v2.0.0-screenshots.json)，
包含其真实 Debug 构建来源，不能据此更改正式 APK 的来源。
字体 OFL 与第三方许可随资源保留，详见
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。GSAP 使用其标准许可。

## 发行信息维护

`src/data/release.ts` 集中维护版本、最低 Android 版本、APK 地址、文件大小、
SHA-256、发行页与项目链接。发布新 App 后先核对官方 Release 的真实附件，
再更新此配置、双语相关文案并运行 `npm run assets`，让二维码和页面保持一致。
APK 直接从 GitHub Release 下载，不复制进网站目录。

首版对应正式 v2.0.0，支持 Android 7.0／API 24 及以上。
旧 v1 到 v2 使用不同签名，不能覆盖安装；须先把完整 JSON 保存到 App 外，
确认文件已保存，再卸载旧版、安装并恢复。CSV 和图片不能完整恢复。
该提示与当前 [发行记录](../docs/release/v2.0.0-release-record.md) 保持一致。

## Vercel 预览与正式域名

Vercel 项目 Root Directory 设置为 `website`，Node.js 为 24.x，安装命令
`npm ci`，构建命令 `npm run build`，输出目录 `dist`。这是纯静态 Astro 项目，
不需要 Vercel 服务端适配器。`vercel.json` 保存构建设置与基础响应头。
`dist/`、`.vercel/`、浏览器报告和本地环境变量文件不提交。

维护者已暂停 Vercel 相关工作，需明确恢复后才继续连接与部署。
本轮交付本地可运行版本和验收记录，见 [VERIFICATION.md](VERIFICATION.md)；尚无远端预览地址。
预览与本地页面设置 `noindex,nofollow`，不输出正式 canonical。
`robots.txt` 同时禁止抓取，预览 `sitemap.xml` 为空；Vercel 的预览地址用于分享图和语言链接。

正式上线前，在 Vercel Production 环境设置 `SITE_URL` 为确认的公开 HTTPS
origin，不含页面路径。`VERCEL_ENV=production` 且缺少 `SITE_URL` 时构建直接失败；
正式配置用于 canonical、语言替代链接及分享图地址。域名和生产发布另按上线
安排确认，保留 Preview 的禁止收录设置。
