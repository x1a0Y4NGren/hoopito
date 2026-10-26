# Hoopito · 球豆 介绍与下载网站

**官网：[简体中文](https://hoopito.com/) · [English](https://hoopito.com/en/)**

网站与 Flutter App 位于同一仓库，独立构建。Astro 输出静态 HTML，TypeScript
管理交互，GSAP 驱动页面动效，Three.js 按条件加载连续球场场景。

中文首页 `/`、英文首页 `/en/`；网站隐私说明分别为 `/privacy/` 和 `/en/privacy/`。
两种语言共享组件，文案集中在 `src/data/content.ts`；语言切换保留当前章节锚点。
真实计分与复盘截图随语言切换，网站文案独立于 Flutter ARB。

导航按实际固定栏高度加 20px 对齐各章节的标题行，不把章节间的外层留白当作入口。
体验对齐球场输入舞台，复盘直达卡牌转正与终场比分的阅读状态；刷新、语言切换、
浏览器前后退和尺寸重算使用同一定位方法，保留原生平滑滚动与 URL 锚点。
导航橙色细线按实际阅读章节切换，并通过 `aria-current="location"` 标注当前入口；
首屏和现场计分没有对应导航项，因此不亮线。手动滚动后不沿用旧 URL 锚点判断。
语言切换同样跟随实际阅读章节；“跳到正文”将键盘焦点交给正文，下一次 Tab 进入内容入口。

桌面投篮球场加载时显示由实际场景导出的 `scene-poster-demo-{compact,standard,wide}.webp` 俯视画面，
当前章节和宿主尺寸的首帧绘制完成后才显露 WebGL，避免先显示另一套二维球场。
该海报仅由桌面媒体条件请求，手机仍使用 SVG；WebGL 不可用、初始化超时或失败时
保留 SVG 操作降级。海报与既有开场占位一起导出、记录来源和校验，纳入桌面预算。

复盘在桌面以赛果为主体、历史为辅助，滚动末段转正以便阅读；手机依次展示
介绍、赛果、价值说明和历史。真实截图的 8:11 与网页演示 6:6 → 8:6 分别标注。

桌面复盘舞台进入半屏后开始落位，沿用 75% 视口高度的滚动区间；固定外层容器，
子舞台以渐慢曲线靠近导航下方的 88px 阅读位置。`replay-cards.ts` 与页面落位共用
同一条时间线和跟随进度，卡牌、比分仍按滚动距离推进。向下手动滚动到末段后停手，
在 240–420ms 内轻轻吸附至终点，此时两张卡牌正面与终场 8:11 同时到位。
反向滚动、锚点导航、大图打开和后台不会主动吸附；锚点直达完整阅读状态。
高度不足、手机或减少动态效果时不固定，较矮桌面在普通滚动到阅读位置时完成翻转。
两张卡牌带真实正面与品牌卡背，从远处侧立开始，主轴连续翻转 540°，
同时展开俯仰角并靠近页面，最终完全转正。卡牌飞行只动画变换与透明度，
投影采用静态渐变而非模糊过滤；说明文字保持独立排版，不改动截图像素。
反向滚动沿同一时间线返回，手机、无 JavaScript 与系统减少动态效果时使用正常排版。
透视与错峰的设计参考 Codrops 的
[3DStackMotion](https://github.com/codrops/3DStackMotion) 和
[RotatingOnScrollAnimations](https://github.com/codrops/RotatingOnScrollAnimations)，
本项目自行编写路径与落定节奏，未引入参考项目代码、图片或滚动库。

图表数据来自 `src/data/replay-example.ts`，是独立编排的虚构比赛：
`0:0 → 2:0 → 2:2 → 4:2 → 6:2 → 6:4 → 6:6 → 6:7 → 8:7 → 8:9 → 8:11`。
用领先、追平、反超和终场说明复盘价值；与真实截图的终比分相同，但不声称
重建了截图比赛的真实逐球记录，也不延续上一章的 `6:6 → 8:6` 交互演示。
完整 SVG 阶梯路径由共享序列生成，运行时只推进裁剪窗口、游标与比分，不反复
测量路径长度或绘制全新的路径。手机、无 JavaScript 与减少动态效果时显示完整走势。

当前品牌中文为「球豆」、英文为「Hoopito」，共享名称为「Hoopito · 球豆」，
大写字标为 `HOOPITO`；npm 包名为 `hoopito-website`。已批准的 C 独眼球怪
保持原图与几何。官网下载入口提供蓝奏云与 GitHub 两种渠道，使用已公开发行的
`Hoopito-v2.0.1-android.apk`，安装名称为 Hoopito／球豆。GitHub 仓库已更名为
`x1a0Y4NGren/hoopito`，原仓库地址保留跳转。
当前八张双语截图来自同一正式签名包。网站与 GitHub README 使用裁掉系统状态栏、
导航栏和横屏系统留白的展示副本，保留 App 内容的真实像素与比例；原图及旧截图
保持拍摄来源并按版本留存。原始 ImageGen 提示词、来源图与历史验收记录保留当时名称。

## 本地开发与验证

使用 Node.js **24.x** 和 npm，在仓库根目录执行：

```powershell
Set-Location website
npm ci
npm run dev
```

开发地址为 [http://127.0.0.1:4321](http://127.0.0.1:4321)。其余命令均在 `website/` 执行：

| 命令                                       | 用途                                                           |
| ------------------------------------------ | -------------------------------------------------------------- |
| `npm run check`                            | Astro 与 TypeScript 检查                                       |
| `npm run format:check`                     | 检查网站源码与文档格式                                         |
| `npm test`                                 | 演示、镜头衔接、画质滞回与响应式资源选择测试                   |
| `npm run build`                            | 生成 `dist/` 并检查页面实际资源图的压缩体积预算                |
| `npm run preview`                          | 本地查看生产构建                                               |
| `npm run test:e2e`                         | 在 Chromium、Firefox、WebKit 执行浏览器场景                    |
| `npm run assets`                           | 从仓库原始素材重新生成网页图片、字体、二维码和来源清单         |
| `npm run measure:perf`                     | 固定移动实验环境，冷缓存三次测量中英文 LCP、CLS 与真实请求预算 |
| `node scripts/measure-gpu.mjs`             | 独立有窗口 Chrome，分别记录环境、渲染提交与呈现证据状态        |
| `node scripts/check-journey.mjs --desktop` | 同一桌面会话检查中英文完整路径，保存截图、录像与 trace         |
| `node scripts/check-journey.mjs --android` | 在已有 Android AVD 的 Chrome 中检查中英文真实触摸路径          |
| `node scripts/export-scene-poster.mjs`     | 从当前生产构建导出桌面首屏占位，随后运行 `npm run assets`      |

首次运行浏览器测试时安装对应浏览器，然后先构建：

```powershell
npx playwright install --no-shell chromium firefox webkit
npm run check
npm test
npm run build
npm run test:e2e
```

Playwright 自动启动本地 `preview` 服务；失败时保留 trace 与截图，报告位于
`output/playwright/`。Linux CI 为每个任务仅安装所需浏览器及运行时依赖。
构建预算以逐文件 gzip 计算：移动首屏每种语言不超过 500 KiB，桌面 3D
增量不超过 800 KiB。体积检查、模拟设备检查和真实 GPU 帧率各自保留证据。
CI 先执行 15 分钟有界的 `validate`，只构建一次；生成包含源码提交 SHA、逐文件
SHA-256、字节数和总摘要的 `build-artifact.json`，连同 `dist/` 上传当前运行的构建产物。
三个普通 UI 任务（Chromium／Firefox／WebKit，各 15 分钟、2 workers）与 Chromium
软件 WebGL 的两个分片（各20分钟、1 worker）只依赖 `validate`，使用独立 runner；
任一浏览器或分片失败不取消其余任务。普通 UI 关闭 WebGL，标记 `@webgl` 的检查按
[Playwright sharding](https://playwright.dev/docs/test-sharding)分到两个独立任务，分片内部串行运行。
两个分片的用例并集必须等于完整 WebGL 清单，均完成且零失败／flaky才算该组通过。
这是为软件渲染与依赖安装留出总时限余量，不增加单项／任务时限或减少采样与断言。
WebGL 任务使用 `playwright.webgl.config.ts`，保留完整 Chromium；CI 按
[Chromium 的软件 WebGL 模式](https://github.com/chromium/chromium/blob/156.0.8078.4/docs/gpu/swiftshader.md)
采用软件合成器，仅将 WebGL 绘制交给 SwiftShader，避免把它同时用作整个浏览器的 GL 驱动。
该配置继承原有用例、超时、画质与失败证据设置；本地仍使用现有真实 GPU 启动参数。
软件渲染检查只证明场景与交互生命周期，不代表真实 GPU 的显示帧率。
CI 的 WebGL 检查以有窗口模式运行，由
[Xvfb 虚拟显示](https://playwright.dev/docs/ci#running-headed)提供 1920×1080 屏幕，
避免依赖无头软件合成器的帧调度；普通 UI 和本地启动方式不变。日志保存实际浏览器
启动参数，WebGL 报告附上现有画布、渲染器、可见性及运行环境信息。
WebGL 任务还以两秒间隔保存 `runtime.jsonl`，记录主机 CPU／内存、可用的 cgroup
资源限制与本任务 Chromium 子进程的原始计数，供失败时区分资源争用和进程积累。
采样不保存原始环境变量或命令行，不改变测试结果、时限、画质及绘制流程。
测试任务只下载当前工作流运行中按完整提交 SHA 命名的构建，校验本地源码身份、文件集合
及每个文件的 SHA-256 后才启动 preview，不重新构建或引用其他提交的“最新产物”。
失败允许一次诊断重试，但 `--fail-on-flaky-tests` 会将重试后通过也判为不稳定失败。
各任务无论成功与否均保存独立 HTML／JSON 结果、执行状态、日志、trace 和失败截图，
按浏览器、WebGL分片及工作流运行次数区分，保留14天；构建身份摘要也随报告保存。
网站的 8 秒初始化回退期限与现有单测、断言超时保持原值。
密集俯视采样按有重叠边界的区间拆分，每种视口仍覆盖全部 63 个位置及相邻边的
双向检查，保留 2px／0.5° 精度。开场使用加载前安装的受控时钟和逐帧 `runFor()`
检查真实开场进度、中间／最终投影有效性与停绘；稳定阅读、下载和恢复交互使用真实时钟。
这些软件 WebGL 功能检查不代表真实 GPU 帧率或开场墙钟耗时。
浏览器安装通过 `scripts/install-ci-browser.sh` 在一次性 Linux runner 上执行：
安装期间将 Azure HTTP 镜像入口替换为 Ubuntu 官方 HTTPS archive，并按
[APT 配置](https://manpages.ubuntu.com/manpages/jammy/man5/apt.conf.5.html)
限制连接／数据停滞为30秒、失败重试2次。安装结束恢复原镜像和临时配置；
不禁用包签名验证、不重试测试，不延长15／20分钟任务时限。
本机 `npm run test:e2e` 仍运行完整组合。可在 `website/` 手动校验构建：

```powershell
$sourceSha = git rev-parse HEAD
node scripts/build-artifact.mjs create --source-sha $sourceSha --manifest output/build-artifact.json
node scripts/build-artifact.mjs verify --source-sha $sourceSha --manifest output/build-artifact.json
```

此命令中的源码身份是当前 `HEAD`。本地存在未提交改动时，还须单独记录工作区差异摘要；
不能用该提交 SHA 冒称未提交源码的完整身份。CI 校验的是当前运行检出的提交。

历史验收记录见 [VERIFICATION.md](VERIFICATION.md)。新增球场材质验证保存在
`output/playwright/court-materials/`；远端构建与浏览器验证保存在 `output/vercel/`，
以各次记录的源码哈希核对实际被测版本。

### 本地 GPU 与完整路径复验

使用当前 `dist/`，同一时刻只运行一组 GPU 测量、浏览器测试或 Android 模拟器验证。
GPU 测量期间保持 Chrome 窗口真实可见且拥有焦点，桌面路径退出后再运行 Android。
这些工具只需本地构建和浏览器／设备，不依赖部署或远端预览。

```powershell
node scripts/measure-gpu.mjs
# 完成后，在另一个终端保持 npm run preview 运行，再依次执行：
$env:HOOPITO_HEADED = '1'
node scripts/check-journey.mjs --desktop
node scripts/check-journey.mjs --android
```

GPU 脚本自行在本地随机端口提供 `dist/`，Windows 下默认测 AMD／NVIDIA × 1440×900／1920×1080
× DPR 1／2。每次配置使用独立 Chrome 进程和临时 profile：`cold` 是首个文档；
`warmed` 是同一 context 完成首轮工作负载后的第二个文档，保留进程／着色器缓存，
服务器仍使用 `no-store`。冷、热样本分别记录；独立进程的 trace 只用于诊断。

| GPU 环境变量                                       | 用途                                                                 |
| -------------------------------------------------- | -------------------------------------------------------------------- |
| `HOOPITO_GPU`                                      | 逗号分隔的适配器，默认 `amd,nvidia`；每次只读枚举实际 LUID           |
| `HOOPITO_GPU_VIEWPORTS`                            | JSON 数组，例如 `[{"width":1440,"height":900,"dpr":1}]`              |
| `HOOPITO_GPU_PHASES`                               | 从 `intro,experience-entry,replay-entry,reverse-story,shot` 选择阶段 |
| `HOOPITO_GPU_RUNS`                                 | 每配置固定运行 1–3 次；未设置时沿用脚本的有限重测策略                |
| `HOOPITO_GPU_OUTPUT`                               | 本次证据目录，必须为空或不存在；默认创建带时间戳的目录               |
| `HOOPITO_CHROME_PATH`                              | 覆盖 Windows 已安装 Chrome 的可执行文件路径                          |
| `HOOPITO_GPU_TRACES=0`／`HOOPITO_GPU_TRACE_ONLY=1` | 关闭诊断 trace／只补采诊断，不替代无追踪门槛测量                     |
| `HOOPITO_GPU_HEADLESS=1`                           | 仅辅助诊断；不满足有窗口环境验收                                     |

查看 `measurements.json` 的 `environmental`、`submissionGate`、`presentationGate`，
分别判断环境资格、活跃渲染提交节奏和可归属于网站新内容的呈现证据。
平均 ≥58 次/秒、p95 ≤20ms 只用于提交节奏；缺少帧／surface 身份链时，
呈现状态保持 `unavailable`，总体不能标为通过。合成器诊断回调、事件数量或时间邻近
都不能证明网站新帧已经呈现，更不能作为物理屏幕 60FPS 的证明。

完整路径脚本要求 `HOOPITO_LOCAL_ORIGIN` 指向当前生产构建的本地 preview，默认
`http://127.0.0.1:4321`；它核对已服务 HTML 与 `dist/` 的摘要。
`HOOPITO_JOURNEY_OUTPUT` 设置证据父目录，每次创建独立时间戳子目录。
每个模式在同一会话检查中英文的真实正反滚动、计分按钮、大图缩放／拖动／关闭恢复、
选点投篮与中途重置、复盘终态、下载、隐私往返和语言保留章节；保存源码／构建摘要、
错误、请求及手势记录、页面截图和 trace，桌面另存录像。失败与能力不可用分别报告。

Android 使用已运行的 `Pixel_API_36`，按 AVD 名动态查找 serial；
`HOOPITO_ANDROID_AVD`、`HOOPITO_ADB_PATH` 可覆盖名称和 ADB 路径。
脚本使用已安装 Chrome，以实际页面 CSS 坐标发送 CDP 单指滑动，避开浏览器工具栏和网页固定
导航；双指／拖动也使用 CDP 触摸事件，不直接改写页面滚动位置。每次手势记录实际方式和坐标。
这些是设备浏览器的触摸输入验证，不冒称操作系统硬件输入证据；ADB 用于原生界面和临时设置。
不会启动模拟器或安装 App。Chrome 首次启动的通知介绍仅在原生界面标题、包名及“No thanks”
按钮匹配时拒绝；临时 UI 层级文件精确删除，读取失败有界重试，无法确认时报告失败。
临时旋转与端口 reverse 映射在结束／中断时恢复；截图仅取浏览器页面，不含系统栏。
`HOOPITO_APK_PATH` 可指定已获取的官方 APK，否则只检查已知本地发行目录，
按当前 `src/data/release.ts` 核对字节数和 SHA-256。报告区分链接检查、本地产物校验与
远程获取，脚本不重复下载 APK。CLI 说明见 `node scripts/check-journey.mjs --help`。

## 场景与交互

大图查看有加载、失败与重试状态，失败或加载时暂停缩放；迟到的图片请求不会覆盖随后打开的图片。
窗口变化保留当前倍率，适应窗口按钮恢复 100%；支持拖拽、双指与 `+`／`−`、`0`、方向键操作。
短横屏优先保留图片和操作栏，完整操作提示仍由对话框的无障碍说明提供。
辅助说明使用至少 12px，安装与备份说明为 14px；触控入口至少 48px。
文字放大时比分节点和演示按钮自然换行，已播放的聚光浮层不继续占据过期尺寸。

正文、截图和下载入口先由 HTML 呈现，保留浏览器原生滚动。视口至少 1024px、
精细指针且支持 WebGL2 时，才加载单一室内球馆场景。桌面以篮球近景开场，
首屏和复盘各增加 75% 视口高度的固定舞台；投篮演示增加 32%；计分章节自然滚动。页面内容高于
可用视口时自然流动。手机采用独立的球馆氛围、透明篮球和 SVG 编排，不请求
Three.js 或桌面材质。桌面加载占位来自同一场景的实际导出，避免切换构图。

`main.ts` 的 `gsap.matchMedia()` 管理响应式时间线和撤销。DOM 与场景共享
`StoryFrame { chapter, progress, active }`；`story-pose.ts` 让相邻章节复用端点，
同时插值镜头位置、朝向、视角和灯光。调整几何、灯光、材质或镜头后，先构建、
导出占位，再生成素材并重新构建；`assets/art/scene-poster.json` 绑定实际源码哈希。

固定舞台用滚动时间线驱动镜头；取消固定后，镜头跨度改按章节选择的实际边界
计算，避免放大文字时提前切入下一段。手机用 420ms、12px 的短转场与有限视差，
按钮和导航反馈为 200ms。响应式时间线退出时恢复样式，不截获滚轮或强制跳章。

计分设备直接以正面展示，三项功能仅通过点击或 Enter／Space 切换。编号、当前功能、
截图标注和按钮选中状态同步；滚动离开再进入、调整窗口或切换系统动效设置均保留
所选功能。此章节不固定、不增加滚动距离，也不自动切换说明。

初始不选中任何功能，截图保持无标注。第一个按钮进入可视范围时播放一次1.45秒的
聚光与弧线箭头提示，箭头随线条绘制前进，轻点一次后淡出；提示仅用于说明按钮可以点击。
点击任意功能立即取消提示，再选中并播放
对应操作。离开返回不会重复提示。减少动态效果时保留中性初始状态和文字提示。

点击功能后，`scoring-feedback.ts` 播放约1.94秒的操作示意：区域外短暂压暗、描边展开，
指针和点按波纹依次演示记分，短轨迹提示落点，回转箭头提示撤回。截图下方明确标注
操作示意与当前说明；不修改真实截图或其中的比分。再次点击重播，快速切换取消上一段。
后台和大图分别记录暂停原因；系统减少动态效果时直接保留选中标注和说明。
入场、落点与撤回共享 `arrow-drawing.ts`：按路径弧长采样，同步绘制线条、前端位置与切线方向，
避免箭头头部晚跳出、错向或与线条分离。落点先指向示例位置，再出现点按反馈；撤回采用开放回转弧线。
几何表达参考 [Perfect Arrows](https://github.com/steveruizok/perfect-arrows) 的曲线与方向分离设计；
当前实现使用浏览器 SVG 几何接口与既有 GSAP，无额外运行时依赖。

投篮演示复用同一个 Canvas 与渲染器：画布始终留在固定背景的右侧 48vw 区域，
不移动 DOM、不切换画幅。场边镜头在体验舞台进入 85% 视口后连续升至俯视，
抵达 88px 停留线时完成转向；离开后连续接回复盘镜头。高文字缩放下取消固定，
按实际导航栏和透明布局区计算构图。球场鼠标选点走真实相机射线，三个位置按钮
保留键盘操作。手机、WebGL 失败及超时继续使用配色更深的 SVG 球场，比分与结果共享状态。
只有桌面且舞台完整放得下（含导航空间）时短暂固定；减少动态效果与窄屏取消固定。
媒体设置变化时保存演示舞台的屏幕位置，复用现有状态与 WebGL 上下文。

俯视构图使用建筑剖切：镜头高度从 8m 升到 18m 时，外围墙板、场外引导灯、
收起的座椅和篮架后支撑逐渐淡出，篮板、篮圈、篮网及场地保持完整。反向滚动
按同一高度曲线恢复，不改变光源、相机或输入坐标。硬件材质按用途隔离，
透明变换不影响前框和篮圈；篮架阴影在剖切边界刷新。

复盘的背景阅读遮罩跟随既有卡牌／比分 playhead：18%–78% 之间平滑加强，
卡牌转正时场线退到背景，反向滚动恢复；手机和减少动效使用稳定阅读状态。
这条表现曲线不改变卡牌的 540° 翻转或相机端点，也不新增持续动画循环。

`CourtScene.setCameraPlacement()` 接收视口 CSS 像素区域、过渡比例与输入资格；
`pointFromClient()` 按真实画布边界和最终相机矩阵检测地板，`projectPoint()` 将场地点
投影回页面。透明交互层只在俯视到位时接收选点，拖动超过 6px 后不再视作点击。
投影往返与布局测试覆盖偏移画布、1×／2× 密度、窗口变化及 200% 字号，误差不超过 2 CSS px。

`demo-invitation.ts` 只负责一次性聚光与箭头：球场、位置按钮达到55%可见时提示，
球场使用真实地板投影位置的柔和局部聚光，无整块发光框；
首次真实选点后再提示已启用的记分按钮。提示不自动选点或记分；记分、重置与减少动态效果
取消旧动画和待播放提示；后台与大图通过共同暂停原因控制，尺寸变化只重新对齐装饰层。

3D 初始化超过 8 秒、素材失败或 WebGL 上下文丢失时保留主视觉与二维演示。
页面默认静音。系统减少动态效果时保留相同排版与视觉，取消固定舞台和投篮飞行；
镜头保持固定。画布只在镜头、投篮或状态变化时绘制，阅读停留后休眠，隐藏
页面暂停，下载章节停止绘制。恢复系统动效时复用渲染器。正文与演示结果始终可用。
JavaScript 未运行时，介绍、截图和下载链接仍可访问。

球场标线由解析距离着色器生成，按 5cm 宽度和屏幕像素覆盖率平滑边缘，
不依赖低分辨率线条贴图。普通屏使用最多 4× MSAA，2 倍像素密度使用最多
2× MSAA；采样数按实际 HDR／深度格式的共同支持选择，不支持时在色调映射
之后使用 FXAA。仅场景几何进入多重采样缓冲区，辉光与输出使用单采样 HDR
缓冲区，避免每个后期步骤重复解析。木纹使用最多 8× 各向异性过滤。

画布按实际右侧 48vw 展示区域分配缓冲区，位于导航以下，最高 2 倍密度，预算约 500 万像素。
自动画质依次为 `full`、`effects`、`density`：先减少辉光与拖尾，再降低密度；
高分屏至少 1.5 倍，普通屏至少 1 倍。仅连续活跃帧参与采样，并使用滞回与
冷却时间排除空闲、后台和短暂加载；短暂阅读保留活跃帧证据，后台、下载和视口变化清空。
初始化可用 GPU 计时扩展时，分别测开场、计分、投篮和俯视镜头的三次已编译绘制中位成本，
按各镜头中的最高成本依次检查各档，预留页面合成成本，
再播放开场；扩展不可用时使用运行中采样。该测量不把资源加载或编译时间计为性能不足。
自动恢复不会超过本次初始化中 GPU 预计算已验证的最高档，避免低档运行较快就误升到
已经超预算的高档；持续活跃平均低于 58 次/秒或 p95 超过 20ms 时按滞回策略降档。
较低档在原生 MSAA 可用时直接绘制到 RGBA8 画布，省去 HDR 解析与后处理；不可用时
保留 HDR／FXAA 路径。较低档同时取消导航背景模糊与细微全屏颗粒。环境反射预计算，无全场 Reflector 副相机。
辉光缓冲区宽度最高 720px；静态阴影只在投篮球位置或重置等必要状态变化时重绘。修改硬件或
灯光的运行时位置时，也必须设置 `renderer.shadowMap.needsUpdate = true`。
`canvas.dataset` 的 `pixelRatio`、`antialias`、`quality` 与 `renderer` 可用于
核对实际运行配置；`renderCount`、`rendering`、`frameP95` 和整帧绘制计数用于诊断。
高清屏的实际帧率仍受设备 GPU 性能影响。

球场木面使用生成的枫木贴图，金属构件使用石墨色微纹理，玻璃与 LED 扩散罩
使用低对比度细节贴图；标线由着色器独立绘制。室内吊灯、钢桁架与吸音墙建立
真实尺度，俯视镜头让天花构件淡出。篮架包含护垫、玻璃边缘、夹具与挂钩，
篮球使用皮革色彩、线性微表面和贴合球面的解析橡胶槽。
静态球馆照明预计算到地板顶点，木面使用两道随视角变化的轻量清漆高光；篮架底部
与篮球使用缓存柔影。暗部墙面和远处桁架使用固定环境色，避免对不可见高光反复计算。
篮网为有厚度的菱形绳网，绳结和网底收口合并为一个网格；球穿过时顶端保持
固定，下端扩张和轻摆，完成、重置或系统动效变化后恢复。硬件按材质合并，
减少绘制调用；篮网关闭投影。

五张材质仅在桌面 3D 场景内请求，图片解码与渲染器共用取消和释放生命周期。
资源失败或超时仍保留介绍、下载与二维演示；移动页面不请求这些贴图。
`src/data/court-materials.ts` 同时供场景和体积检查使用，桌面预算包含贴图。

投篮演示使用标明为示例的数据，只在当前页面内存中运行：选择位置后记两分，
比分由 6:6 变为 8:6，并记录一处命中落点。预设位置可用键盘操作；重置会取消
未完成的动画与旧回调。网站不读写 App 数据库，也不把演示结果保存为真实比赛。

`shot-feedback.ts` 用单一可暂停时间线协调二维篮球、拖尾、篮网与命中回调，
`shot-timing.ts` 与三维表现共享飞行 1.20 秒、穿网 0.35 秒、回弹 0.58 秒。
记分立即更新，1.55 秒出现命中标记；篮网上沿固定，下部继续回弹到 2.13 秒。
后台、大图和页面缓存分别记录暂停原因，全部解除后才继续；重置取消旧回调并恢复网形。
二维木面使用既有 ImageGen 原图的独立 384px 副本，接近演示章节时才请求，
不加载桌面材质。系统减少动态效果时直接显示结果。

页面不接入广告、用户分析或遥测 SDK，不设置追踪 Cookie。字体、截图和场景
资源从同一网站加载；Vercel 托管访问日志，以及用户选择的蓝奏云、GitHub 下载和
外链访问分别受服务方隐私政策约束。打开渠道选择弹窗本身不会发起下载或加载网盘。
网站隐私页同时链接这些服务的隐私政策与 App 隐私说明，区分网站访问与 App 离线使用。

## 素材与来源维护

计分章节的三项说明对应展示截图中的实际控件，只通过点击演示，滚动不切换所选功能。计分、赛果和历史可通过“查看大图”打开干净的完整分辨率展示副本；支持 1–4 倍缩放、拖动、双指操作和 Esc 关闭，关闭后恢复焦点及滚动位置。大图与后台分别管理场景暂停，无 JavaScript 时图片链接仍可直接打开。

`public/` 内网页素材进入版本管理，普通构建直接使用这些文件。原始 Logo、
字体与八张截图保留在仓库原位置；生成器只写网站资源与来源清单。它会核对
已批准的 C Logo 哈希、截图拍摄记录和合成数据声明，再生成无损 WebP。
原图竖版为 1080×1920、横屏为 1920×1080，系统栏与像素内容保持原样。展示裁剪
由 [截图展示配置](../docs/design/screenshot-presentation.json) 校准：当前竖版副本为
1080×1783，横屏副本为 1818×954。裁掉系统区域后不缩放、不重绘 App 内容，
页面使用输出尺寸保持比例；网站和 README 共用 `public/screenshots/` 中的展示副本。
新设备／截图批次须重新检查系统边界并校准配置，未知尺寸会停止生成，不能沿用
固定像素值猜裁。`ASSET_SOURCES.json` 保存原图摘要、裁剪矩形、输出尺寸和摘要；
像素回归验证每张副本与原图对应区域完全一致。后续对外商店素材遵守同一规范，
不直接使用保留系统栏的原始证据文件。

完成文案、页面或交互源码修改后运行 `npm run assets`，再重新构建与检查。
生成器扫描 `src/` 的 Astro、TypeScript、JavaScript 和 JSON，形成中文字体
WOFF2 子集；Barlow 保留原有字形集。它同时更新二维码和
[ASSET_SOURCES.json](ASSET_SOURCES.json)，记录源文件与输出哈希、尺寸、字体字符、
转换方式和拍摄来源。生成命令需要仓库中的原始素材，不适用于只复制 `website/`
且没有父目录原始文件的环境。

更新传递依赖时，按安全公告定向更新锁文件并检查实际安装版本、父依赖范围和 `npm audit`。
`package-lock.json` 也是场景占位与 Logo 套件的来源输入；即使页面源码没有变化，也要完成
Astro 引导构建、启动本地 preview、`node scripts/export-scene-poster.mjs`、`npm run assets`
和最终 `npm run build`，保留新捕获原图及来源记录。随后在仓库根目录运行
`node tool/brand/export_logo_kit.mjs` 和对应测试，同步 Logo 清单的锁文件摘要。
历史验证记录继续绑定原测量版本；新来源不能只手改摘要或冒称旧捕获。

网站 CI 会实际运行素材生成器与 Logo 导出测试，并检查生成后的字体字形、许可和社区二维码像素；CI 使用已记录的真实场景捕获，不重新拍摄或代写来源摘要。

新增球场材质使用内置 ImageGen 生成，原始 PNG 保存在
[`assets/materials/source/`](assets/materials/source/)；每张图的完整提示词与生成方式
保存在 [`assets/materials/generation.json`](assets/materials/generation.json)。
原图只包含表面细节，场景灯光、反射、标线和三维结构在运行时渲染。
`npm run assets` 从这些原图生成 `public/textures/` 中的 WebP，并把原图、生成记录
与输出的 SHA-256 写入来源清单。调整编码尺寸或质量时修改生成器并重新验证
实际画面与桌面预算；普通构建无需重新生成图片或调用 ImageGen。

夜场横／竖版氛围与透明篮球保存在 `assets/art/source/`，完整 ImageGen 提示词
见 `assets/art/generation.json`。运行图片提供 AVIF／WebP 与响应式尺寸；手机
篮球最高使用 768px 副本，使高像素密度手机也保持图层预算。来源清单同时保留
原图、完整生成记录、转换方式和 SHA-256。

性能脚本默认写入带时间戳的 `output/cinematic/performance/`，保留失败样本。
工具环境变量使用 `HOOPITO_PERF_OUTPUT`、`HOOPITO_GPU_OUTPUT`、`HOOPITO_GPU`、
`HOOPITO_GPU_HEADLESS`、`HOOPITO_GPU_VIEWPORTS`、`HOOPITO_CHROME_PATH` 和
`HOOPITO_LOCAL_ORIGIN`；按需指定输出目录、GPU、浏览器或本地预览 origin。
移动实验使用 390×844、DPR 1、4× CPU、150ms 延迟与 1.6Mbit/s 下行，三次中位
LCP 目标 ≤2.5 秒，CLS ≤0.1。GPU 脚本在 Windows 只读枚举 DXGI，逐次选择
实际 AMD Radeon 与 RTX 4070 适配器，不修改系统偏好；记录浏览器、渲染器、
缓冲区、活跃渲染提交与独立 compositor trace。目标平均 ≥58 次/秒、p95 ≤20ms。
每种缓冲区配置使用独立的有窗口浏览器进程并激活窗口；测试异常保存页面状态与截图，
先前复用窗口的测量出现整秒 RAF 停顿，这些失败样本与新测量分别留存，不计为通过。
测量器关闭 Playwright 的焦点模拟，实际焦点未确认时保留异常，不用模拟的焦点证明前台。
全部门槛测量完成后，才在独立浏览器进程中采集合成器诊断，避免追踪影响下一组测量。
诊断先滚动预热章节图片和布局，再记录稳定滚动；冷启动与投篮门槛样本仍独立保存。
设置 `HOOPITO_GPU_TRACE_ONLY=1` 可仅补采 1440px／1× 和 1920px／2× 的双 GPU 诊断，
不会重复门槛矩阵；此模式的成功只表示追踪采集完成，不表示物理屏幕 FPS 验收通过。
渲染提交节奏是渲染函数返回后的主线程观测；GPU 绘制耗时与合成器呈现回调分别记录。
DPR 2 是浏览器设备缩放仿真与真实扩大的画布。有窗口测量与 headless 辅助数据分开，
均不冒称物理屏幕扫描或光学测量。

Android 实机验收需由使用者打开预览，记录型号、浏览器和结果：首次加载与刷新、
正反向和快速滚动、横竖屏、语言切换、选择位置记分及动画中重置、下载入口。
自动测试不能替代这项实际体验；未收到实机报告时保持待验。
若维护者明确允许以本地模拟器替代该轮手机验收，记录 Android 版本、模拟设备、浏览器、
视口与执行结果，并明确这是模拟器证据。本轮 #7–#10 已获得该授权，实际检查见
[VERIFICATION.md](VERIFICATION.md)，不再要求手机分享链接或真机反馈。

当前截图来自 [v2.0.1 截图来源](../docs/release/v2.0.1-screenshots.json)，
绑定正式 APK 的源码 `4ecd960`、摘要、设备、合成数据和拍摄时间。
[v2.0.0 历史截图](../docs/release/v2.0.0-screenshots.json)保留真实 Debug 来源，
后续网站提交不改变任何 APK 的构建来源。
字体 OFL 与第三方许可随资源保留，详见
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。GSAP 使用其标准许可。

## 发行信息维护

`src/data/release.ts` 集中维护版本、最低 Android 版本、官网 APK 相对路径、
文件名、GitHub 原始附件地址、蓝奏云分享链接与密码、文件大小、SHA-256、下载页与发行说明地址。
首屏和下载卡的主按钮打开原生渠道选择弹窗，上方为「蓝奏云下载渠道（国内）」，
通过 `lanzouUrl` 打开分享页；下方为「GitHub下载渠道（国外）」，使用 `upstreamApkUrl`
指向固定版本的正式 APK 附件，由浏览器处理下载。蓝奏云按钮下方以清晰小字显示
`lanzouPassword`，供用户在分享页输入。关闭弹窗恢复原按钮的焦点和阅读位置，
Esc、键盘与触摸均可操作。
没有 JavaScript 时主按钮直接打开 GitHub 正式附件，下载入口仍可用。
发行说明保留单独入口；二维码继续打开 `https://hoopito.com/#download`，扫描后由用户选择渠道。

配置蓝奏云时，将维护者提供的 HTTPS 分享 URL 填入 `lanzouUrl`，将对应分享密码填入
`lanzouPassword`。该密码为公开下载信息，直接显示在前端，不属于账号登录凭据。
网站不拼接未经平台确认的自动填码参数，不嵌入网盘、不抓取临时直链，也不通过 Vercel
代理安装包。分享页的密码校验与下载由蓝奏云处理，网站不宣称已完成下载，也不保证各渠道速度。
发布或更换分享前，应实际下载蓝奏云中的 APK，核对其大小和 SHA-256 与同版本正式发行包
一致；只凭文件名、上传成功提示或页面标注大小不能替代完整性验证。当前只提供上述两个渠道。

既有官网静态路径 `/downloads/v2.0.1/Hoopito-v2.0.1-android.apk` 和构建时校验流程继续保留，
可用于直接访问和完整性验证，但不再作为主按钮或渠道选项的默认下载路线。

`npm run build` 依次执行 Astro 构建、APK 准备与校验、资源预算检查。
准备工具优先使用 `HOOPITO_APK_PATH` 指定的本地正式包或 `.cache/downloads/`
中的 SHA-256 缓存，每次复用都重新检查字节数与摘要；没有可复用文件时，从
配置中固定版本的 GitHub Release 下载。每次下载限时 120 秒，网络失败最多重试
一次；HTTP 错误、内容类型错误、长度或摘要不符会终止构建。只有验证成功的文件
才进入 `dist/downloads/`，不会重新签名或重建 App，APK 和缓存均不提交。
CI 的逐文件构建摘要包含 APK，网页首屏不会请求或预加载它。

渠道弹窗可使用 `npm run dev` 本地审阅；验证官网保留的静态安装包请先构建，再使用
`npm run preview`，Astro 开发服务器不提供仅存在于 `dist/` 的安装包。
Vercel 的附件响应头、文件类型与版本缓存规则在
`vercel.json` 中配置，本地 Astro preview 不模拟这些平台响应头；部署后须复核
真实响应头、分段请求及下载完整性。只有直接访问官网静态安装包才使用 Vercel 的下载流量额度；
用户选择蓝奏云或 GitHub 后，文件传输由所选服务处理。

发布新 App 后先核对官方 Release 的真实附件，再同步上述配置、Vercel 中精确的
APK 路径与附件文件名、蓝奏云分享及密码、双语相关文案，并运行 `npm run assets`，让二维码和页面
保持一致。页面组件或文案变更涉及场景占位来源绑定时，按上面的素材流程重新导出。

当前下载为正式 v2.0.1，支持 Android 7.0／API 24 及以上，同证覆盖升级 v2.0.0。
旧 v1 到 v2 使用不同签名，不能覆盖安装；须先把完整 JSON 保存到 App 外，
确认文件已保存，再卸载旧版、安装并恢复。CSV 和图片不能完整恢复。
新 App 可导入旧 HoopTrace 与新 Hoopito JSON；旧 App 不能导入新名称备份。
这些提示与当前 [发行记录](../docs/release/v2.0.1-release-record.md) 保持一致。

## Vercel 预览与正式域名

Vercel 项目 Root Directory 设置为 `website`，Node.js 为 24.x，安装命令
`npm ci`，构建命令 `npm run build`，输出目录 `dist`。这是纯静态 Astro 项目，
不需要 Vercel 服务端适配器。`vercel.json` 保存构建设置与基础响应头。
`dist/`、`.vercel/`、浏览器报告和本地环境变量文件不提交。

既有 Vercel 项目已更名为 `hoopito-website`，项目身份保持不变，所属空间为
`xyr175-9459s-projects`。当前网站（含 #7–#10 精修）已合入 `main`，正式官网为
[https://hoopito.com](https://hoopito.com/)，英文首页为
[https://hoopito.com/en/](https://hoopito.com/en/)。`www.hoopito.com` 通过 HTTPS 308
跳转至主域名。首次正式部署为 `dpl_FnxezeHNKKawui9NGstwDh8LQSLf`，当时的网站构建源码为
`64944b7e59ffb9fca9b8307ab238789bb6b3f125`。

预览分支 `preview/website` 的受保护
[分支预览](https://hoopito-website-git-preview-website-xyr175-9459s-projects.vercel.app)
随该分支成功部署更新。各阶段的源码、验证结果与不可变预览地址见
[VERIFICATION.md](VERIFICATION.md)；品牌同步基线的实际源码与预览记录保留在
[v2.0.1 发行记录](../docs/release/v2.0.1-release-record.md)。
旧品牌预览仅属于历史部署，来源保留在 [VERIFICATION.md](VERIFICATION.md)。
2026-10-25 的分支命名迁移保留旧预览网站内容，仅将 CI 分支触发名更新为
`preview/website`；源码为 `f83a26892b9c9dfd21f1043858cc72b60ee3c528`，
[网站 CI](https://github.com/x1a0Y4NGren/hoopito/actions/runs/40202329365) 与
[不可变 Preview](https://hoopito-website-mol58jum6-xyr175-9459s-projects.vercel.app)
分别绑定该源码，部署身份为 `dpl_J258RCMpQk4R9Yb1xG9rmcR1k3Yq`。
分支入口已从 Vercel 回读并验证中英文页面与匿名认证跳转；该预览不替代当前生产版本。
Preview 继续保留 Vercel Authentication；账号登录后可访问，也可通过 Deployment 页面
的 Share 功能创建有期限的分享链接。分享凭据不写入源码或验证报告。
分支地址随该分支成功部署更新；每次部署的不可变地址与实际 Git 提交可在
Vercel Deployment 详情和构建日志中核对。`output/vercel/` 保存已验收部署的
来源清单、构建日志与浏览器证据。此前工作区上传、已提交文件上传和 Git
自动预览的来源记录分别保留，不能用后续提交或正式部署替代。

项目已连接 `x1a0Y4NGren/hoopito`，非生产分支允许生成 Preview。
早期曾通过 Vercel API 的 `gitSource` 指定仓库与提交创建预览，那些记录保持原有来源。
`main` 仍是 Production 分支，`vercel.json` 的 `git.deploymentEnabled.main=false`
继续阻止自动生产部署；当前正式版本由手动 Production 部署发布。后续推送 `main`
不会自动更新官网，正式发布仍按该次明确授权手动执行并核对部署来源。

重新连接已有项目时，先在 GitHub 的 Settings → Applications →
Installed GitHub Apps → Vercel → Configure 中确认仓库访问权，再使用
`vercel git connect https://github.com/x1a0Y4NGren/hoopito.git`。

本机 CLI 已完成登录；认证配置独立保存在忽略的 `.vercel/cli-state/`。
在使用 CLI 时显式指定 `--global-config` 指向该目录、
`--scope xyr175-9459s-projects` 和预期项目或部署 ID；不要把认证目录作为证据打包。
日常调试部署选择 Preview；REST `/v13/deployments` 的 Preview 请求省略
`target`，并核对返回部署环境及 Git 来源。`target: "staging"` 是独立的 Staging
环境，不能作为 Preview；正式发布使用 `target: "production"`。
生产构建的 `SITE_URL` 门禁继续保留。

预览与本地页面设置 `noindex,nofollow`，不输出正式 canonical。
`robots.txt` 同时禁止抓取，预览 `sitemap.xml` 为空；Vercel 的预览地址用于分享图和语言链接。

Vercel Production 环境已设置 `SITE_URL=https://hoopito.com`，用于 canonical、
语言替代链接及分享图地址。正式页面使用 `index,follow`，`robots.txt` 允许抓取，
`sitemap.xml` 包含 `/`、`/en/`、`/privacy/` 和 `/en/privacy/` 四页。
`SITE_URL` 必须保持为不含页面路径的公开 HTTPS origin；`VERCEL_ENV=production`
且缺少 `SITE_URL` 时构建直接失败。Preview 的认证与禁止收录设置继续保留。
官网主下载先选择蓝奏云或 GitHub 渠道；GitHub Releases 仍为正式发行来源。
构建时校验的同域静态安装包路径继续保留，网站部署不改变正式 APK 的内容、签名及应用源码来源。

官网 `#community` 与仓库 README 展示 QQ 球友交流群 **1129560287**。配置在
`src/data/community.ts`，双语文案与 QQ 隐私说明在 `src/data/content.ts`。
邀请卡使用 ImageGen 夜场背景和原始群码，来源、提示词与更新方法见
[`assets/community/README.md`](assets/community/README.md)。`npm run assets` 同时生成邀请卡、
延迟加载的预览和可保存的完整 PNG；不加载 QQ 脚本或自动访问第三方服务。
更换群码后必须核对群名／群号并使用 QQ 实扫，通用 QR 解码器不支持该圆形定位码。
