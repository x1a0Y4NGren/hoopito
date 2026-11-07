# 快速上手练习的维护约定

练习复用正式赛前、计分和结果页面，通过可选的 `PracticePresentation` 提供提示、高亮和操作限制。入口是 `/practice`；设置页可随时重新进入。旧计分说明保留为手动帮助，不再承担首次自动教学。

## 入口与偏好

[`PracticeHost`](../../lib/app/practice_host.dart) 等待本地初始化完成、启动画面交接、App 回到前台、首页成为最上层页面且没有活动比赛或弹窗后，再展示首次邀请。邀请加载不参与启动就绪条件；偏好读取最多等待两秒，失败时本进程跳过邀请，正常导航和更新提示继续工作。

邀请的优先级高于自动更新提示。[更新宿主](../../lib/app/app_update_host.dart) 在邀请待处理、练习入口确认或练习页面可见时延后弹窗；后台更新检查仍可运行。导航检查使用最上层路由，不能仅依赖弹窗观察器。

[`PracticePreferences`](../../lib/core/settings/practice_preferences.dart) 在正式数据库的 `appSettings` 中使用独立键 `onboarding.practice.v1`，分别保存：

- `invitationHandled`：已处理邀请，或已手动进入练习；跳过、返回和退出不代表完成。
- `practiceCompleted`：练习结束命令成功后才置为真。

读改写在数据库事务中合并，只会将字段置为真。旧键 `scoring.guide.seen.v2` 不作为练习完成依据。内存中的邀请标记防止偏好写入失败造成同一进程反复邀请；该失败不阻止使用 App。

## 数据与推进条件

[`PracticeSession`](../../lib/features/practice/practice_session.dart) 每次创建独立的 `AppDatabase.inMemory()`、正式 `MatchCommandService`、`MatchRepository` 和命令驱动的 `ScoringController`。不得覆盖全局数据库 Provider，或连接正式比赛的保存、分享、球员归档和自动备份回调。练习命令、回执和审计仅存在于内存库，不进入正式历史、统计、导出或比赛自动备份。正式库仍可保存邀请/完成偏好，以及用户明确确认的原比赛暂停。

练习强制自由计分、无计时、临时双方和新的比赛 ID；不继承正式比赛 ID、球员档案或预设。使用详细记录模式来演示落点，但不据此推断记录完整度。

| 当前提示 | 推进依据 |
| --- | --- |
| 赛前设置 | 开始命令成功，创建隔离比赛 |
| 蓝方 +2 | 已提交投影为蓝方 2、红方 0，存在蓝方命中事件 |
| 撤销 | 该蓝方事件已撤回，比分回到 0:0 |
| 选择落点 | 控制器生成有效的本地球场草稿；此步不写比赛事件 |
| 红方 +2 | 红方命中事件已提交，比分为红方 2、蓝方 0，且该事件有确认落点 |
| 蓝方未命中 | 已提交蓝方运动战未中，比分仍为红方 2、蓝方 0 |
| 结束 | 用户确认比分和记录范围，`FinishMatchCommand` 成功 |

页面按步骤限制操作，并在写入中及同一步已消费时拦截重复操作。成功按钮点击本身不是推进依据；失败保留步骤，重试沿用命令语义。结束重试保留同一个结束命令，维持回执幂等性。蓝方首个得分后的可选限时补点窗口不与撤销教学竞争；练习必须完成红方确认落点后才进入未中步骤。

## 覆盖式指引与页面几何

赛前、计分和结果页分别用 [`PracticeCoachHost`](../../lib/features/practice/practice_coach.dart) 包住原页面。气泡位于页面上方的覆盖层，不占正文高度，也不预留顶部横幅空间；短横屏仍保留页面原有标题栏。`PracticePresentation.showCoach` 只控制指引可见性，不改变练习步骤、操作限制或数据隔离。在相同视口、字体、键盘状态和滚动位置下，开关指引应保持原控件尺寸与位置一致。目标不在可见范围时可以先滚动显示，不能将这种滚动与页面重新布局混为一谈。

`PracticeTarget` 通过独立锚点注册表登记实际控件的矩形，使用 `PracticeTargetId` 区分开始、双方得分、撤销、球场、未中、结束及结果比分等目标。`PracticeAvoid` 登记需要避让的区域，包括赛前名字输入框、计分比分、结果操作和确认弹窗控件。两类包装不增加约束或内边距；局部目标使用 `rectBuilder` 从子控件尺寸计算矩形。新增步骤或调整页面结构时，应注册实际交互区域，避免将整段滚动内容作为一个避让矩形。

指引以静态浅遮罩、高亮和箭头指向当前目标，按可见目标、避让区、安全区域和键盘计算气泡位置，并随布局及滚动重新测量。优先完整展示正文：先尝试常规宽度，再检查宽而浅的空位、可换行的窄栏，按实际字号测量文字，不以固定最小宽度直接判定空间不足。常规气泡将标题和步骤合在一行，退出按钮与正文并排，减少空白。确实放不下时才折叠成紧凑气泡，用户可展开或收起提示，退出入口保持至少 48dp。不要用指引挤压球场或缩小按钮，也不要用持续闪烁或移动箭头吸引注意。没有“下一步”按钮；只有前表列出的真实操作与成功投影推进练习。

计分操作弹窗与结束确认各自使用弹窗路由内的 Host；弹窗打开时，底层页面的指引隐藏。共享的[记录范围确认组件](../../lib/app/design_system/recording_confirmation.dart) 通过通用装饰回调包装弹窗、范围选项及确认／取消按钮，不依赖练习模块。弹窗内退出只关闭该练习持有的确切路由，先使未完成操作的续接失效，待路由结束后再退出练习；不能通过连续 `pop` 或返回首页等方式误关其他页面。

双语提示保持短句，每步只说明当前动作。记录范围的解释放在结束确认处，保持该处的比分核对、范围选择和说明可访问；不要把整段范围说明塞入每一步气泡。正式页面不传练习展示对象时，保留原有操作和布局。

## 原比赛、结束与释放

[`PracticeEntry`](../../lib/app/practice_entry.dart) 每次进入时重新查询正式活动比赛。需要暂停时先要求用户明确选择“暂停并练习”，再通过正式暂停命令停止原比赛；恢复或到期投影仍需持久化时也不能绕过该确认。已有稳定暂停/终止决策不重复暂停。退出或结果页返回原比赛都不自动恢复计时，继续由用户操作。

[`PracticeFlowPage`](../../lib/features/practice/practice_flow_page.dart) 仅在结束命令返回成功的 finished 投影后展示结果并调用完成偏好回调。偏好保存失败不阻塞结果或退出。结果页提供再练一次；存在原比赛时提供返回原比赛，否则提供开始正式比赛。分享、导出、修正完整度和保存球员等外部操作不出现在练习结果页。

退出、路由销毁和重练先阻止后续通知，等待开始/结束及控制器排队写入完成，再释放控制器并关闭内存库。重练创建全新会话，进程死亡不恢复练习。计分阶段使用计分页的横屏方向约束，离开该阶段恢复自由方向；平板规则沿用 `OrientationShell`。

## 验证入口

按[贡献指南](../../CONTRIBUTING.md#测试要求)选择验证范围。以下命令从仓库根目录运行；Windows 上串行运行 Flutter/Gradle，避免原生构建钩子碰撞。

```powershell
flutter test test/features/practice test/core/settings/practice_preferences_test.dart test/app/practice_entry_test.dart test/app/practice_host_test.dart test/app/practice_route_test.dart test/app/practice_update_priority_test.dart test/app/practice_journey_test.dart
flutter test test/features/practice/practice_coach_overlay_test.dart test/features/practice/practice_overlay_geometry_test.dart test/features/practice/practice_overlay_pages_test.dart test/features/practice/practice_overlay_scoring_test.dart
flutter test test/app/practice_goldens_test.dart test/app/practice_dialog_goldens_test.dart
flutter test integration_test/practice_onboarding_test.dart -d <android-device-id> --device-user <isolated-user-id>
```

会话测试覆盖事务失败、结束重试与带写入退出；页面测试覆盖错误动作、重复操作、键盘、窄屏及大字体。完整旅程以临时文件数据库承载正式侧，验证练习后没有正式比赛记录；设备入口复用同一旅程。

覆盖层定点测试分工：`practice_coach_overlay_test.dart` 检查引擎的锚点、避让、指针、紧凑状态与无障碍行为；`practice_overlay_geometry_test.dart` 检查计分内容不因指引占用高度；`practice_overlay_pages_test.dart` 比较赛前／结果页在竖屏、短横屏及 100%／200% 字体下的同滚动位置几何，并点击实际操作；`practice_overlay_scoring_test.dart` 检查计分、弹窗及退出交互。维护时同时检查实际目标、退出入口和弹窗中的范围选项，不能仅凭找到 Widget 就判定可点击。

Golden 覆盖中英文、深浅主题，以及赛前、计分、球场、结束、结果和大字体场景。确有预期视觉变化时才用 `--update-goldens` 更新，并人工检查图片；Linux 使用带 `_linux` 后缀的独立基线。

Android 集成测试只在专用设备或隔离用户运行。集成测试可能覆盖 `app-debug.apk`；后续安装验收前运行 `flutter build apk --debug` 重建普通入口。恢复本次测试改变的设备设置；保留来源与实际测试结果，不把本文作为验证通过记录。
