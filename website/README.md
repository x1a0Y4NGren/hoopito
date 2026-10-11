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
历史验收记录见 [VERIFICATION.md](VERIFICATION.md)。新增球场材质验证保存在
`output/playwright/court-materials/`；远端构建与浏览器验证保存在 `output/vercel/`，
以各次记录的源码哈希核对实际被测版本。

## 场景与交互

正文、截图和下载入口先由 HTML 呈现；使用浏览器原生滚动。只有视口至少
1024px、精细指针且支持 WebGL2 时，才动态加载 3D 球场。网站使用一套界面，
不提供动效模式开关或另一张替代球场图。3D 准备期间显示同一夜场暖光背景，
就绪后淡入。手机和其他不满足条件的设备保留相同排版和二维投篮演示。

3D 初始化超过 8 秒、初始化失败或 WebGL 上下文丢失时回到二维；持续卡顿
先降低画质，再降级。标签页隐藏时暂停场景，页面默认静音。系统减少动态效果
设置仅停止镜头飞行、持续动画和投篮飞行，保留同一 3D 场景；镜头按章节直接
定位，场景只在滚动、尺寸或演示状态变化时重绘。恢复系统动效后直接恢复动画，
不销毁或重新创建渲染器。正文与演示结果始终保持可用。
JavaScript 未运行时，介绍、截图和下载链接仍可访问。

球场标线由解析距离着色器生成，按 5cm 宽度和屏幕像素覆盖率平滑边缘，
不依赖低分辨率线条贴图。普通屏使用最多 4× MSAA，2 倍像素密度使用最多
2× MSAA；采样数按实际 HDR／深度格式的共同支持选择，不支持时在色调映射
之后使用 FXAA。仅场景几何进入多重采样缓冲区，辉光与输出使用单采样 HDR
缓冲区，避免每个后期步骤重复解析。木纹使用最多 8× 各向异性过滤。

画布按设备像素密度渲染，最高 2 倍；额外像素分配限制在约 600 万像素，
超大视口至少保留 1 倍原生密度。降画质先关闭反射、辉光和阴影，保留画布
密度与标线平滑。辉光缓冲区宽度最高 1280px，柔和反射不另开 MSAA；
静态球馆阴影只在投篮球位置、重置或动效状态变化时重绘。修改球场硬件或
灯光的运行时位置时，也必须设置 `renderer.shadowMap.needsUpdate = true`。
`canvas.dataset` 的 `pixelRatio`、`antialias`、`quality` 与 `renderer` 可用于
核对实际运行配置；高清屏的实际帧率仍受设备 GPU 性能影响。

球场木面使用生成的枫木贴图，金属构件使用石墨色微纹理，玻璃与 LED 扩散罩
使用低对比度细节贴图；标线仍由着色器独立绘制。灯具包含锥形灯杆、固定件、
双灯头、扩散罩和散热片，篮架包含护垫、玻璃边缘、夹具与篮圈挂钩。
篮网为有厚度的菱形绳网，绳结和网底收口合并为一个网格；球穿过时顶端保持
固定，下端扩张和轻摆，完成、重置或系统动效变化后恢复。硬件按材质合并，
减少绘制调用；篮网关闭投影。

三张材质仅在桌面 3D 场景内请求，图片解码与渲染器共用取消和释放生命周期。
资源失败或超时仍保留介绍、下载与二维演示；移动页面不请求这些贴图。
`src/data/court-materials.ts` 同时供场景和体积检查使用，桌面预算包含贴图。

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

新增球场材质使用内置 ImageGen 生成，原始 PNG 保存在
[`assets/materials/source/`](assets/materials/source/)；每张图的完整提示词与生成方式
保存在 [`assets/materials/generation.json`](assets/materials/generation.json)。
原图只包含表面细节，场景灯光、反射、标线和三维结构在运行时渲染。
`npm run assets` 从这些原图生成 `public/textures/` 中的 WebP，并把原图、生成记录
与输出的 SHA-256 写入来源清单。调整编码尺寸或质量时修改生成器并重新验证
实际画面与桌面预算；普通构建无需重新生成图片或调用 ImageGen。

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

Vercel 预览工作已恢复，项目为 `hooptrace-website`，所属空间为
`xyr175-9459s-projects`。当前预览地址：
[HoopTrace Preview](https://hooptrace-website-5idw8c439-xyr175-9459s-projects.vercel.app/)。
项目保留 Vercel Authentication；账号登录后可访问，也可通过 Deployment 页面
的 Share 功能创建有期限的分享链接。分享凭据不写入源码或验证报告。
部署通过上传当前工作区的网站文件构建；`output/vercel/` 中的来源清单记录
基线提交、未提交状态、完整文件 SHA-256 和部署文件集合。后续提交不能替代
已经部署的工作区哈希。没有部署正式域名，也没有推送仓库。

本机 CLI 已完成登录；认证配置独立保存在忽略的 `.vercel/cli-state/`。
在使用 CLI 时显式指定 `--global-config` 指向该目录、
`--scope xyr175-9459s-projects` 和预期项目或部署 ID；不要把认证目录作为证据打包。
首次部署应显式指定 Preview；REST API 对应 `target: "staging"`，省略环境可能把
新项目首次部署归为 Production。生产构建的 `SITE_URL` 门禁继续保留。

预览与本地页面设置 `noindex,nofollow`，不输出正式 canonical。
`robots.txt` 同时禁止抓取，预览 `sitemap.xml` 为空；Vercel 的预览地址用于分享图和语言链接。

正式上线前，在 Vercel Production 环境设置 `SITE_URL` 为确认的公开 HTTPS
origin，不含页面路径。`VERCEL_ENV=production` 且缺少 `SITE_URL` 时构建直接失败；
正式配置用于 canonical、语言替代链接及分享图地址。域名和生产发布另按上线
安排确认，保留 Preview 的禁止收录设置。
