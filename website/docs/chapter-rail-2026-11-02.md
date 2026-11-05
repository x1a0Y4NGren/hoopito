# 球豆水滴章节轨道

桌面右侧以七个节点和球豆游标替代原生滚动条。首页、计分、体验、复盘、下载、社区和结尾共用已有阅读位置，结尾保留独立的 `closing` 身份。

轨道只在宽度至少1024px、精细指针且导航下方有400px轨道空间时启用。初始化完成后才隐藏原生滚动条，手机、粗指针、强制颜色、短屏、无JavaScript及运行失败使用原生路径。隐私页没有轨道。

2026-11-03比例精修后，轨道容器按导航下方视口高度的75%计算，最低400px，并限制在扣除32px页号和上下各24px留白后的空间内。取消480px上限；真正线段比容器短48px。底轨与橙色进度线共用28px中心轴、2px线宽和1px端部圆角，节点可见直径7px、点击区域仍为48px，球豆主体保持32px。容器与页号作为整体在导航下方居中，该次比例修改保留原有映射、逆映射与拖动刷新。

随后同日的液滴重构以多液团融合替代原先的尖滴轮廓和手画连接线，并按用户选择取消Logo滚转。以下描述当前液滴实现，早期截图和验证记录仍保留其原始表现。

## 位置与任务所有权

`chapter-rail-math.ts` 把真实页面位置映射到轨道，并提供对应逆映射。章节中心间距至少48px，剩余距离按实际页面长度分配，最后一章阅读尾段也保留行程。当前页号在相邻阅读区间之间的中点变化，长内容阅读中保持章节身份。

轨道在已有 `updateStory()` 中更新，不创建动画时钟、持续RAF、物理模拟或光学玻璃表面。主滴、接触滴和游标位置由同一真实滚动位置计算，Logo独立保持正向清晰。

`createChapterScroll` 内部新增 `navigateTo`、`beginDrag`、`dragTo`、`endDrag`、`isDragging` 和 `getMotion`，与滚轮共用一个tween、取消代次和刷新续播机制。`canNavigate` 允许减少动态效果时仍可即时导航，原有 `enabled` 继续控制滚轮吸附。

相邻点击1.2秒，跨章每多一章增加0.12秒，上限1.8秒。跨章经过中间内容而不额外停留。当前章点击保留阅读位置。拖动超过4px后直接写入真实滚动；松手保持已在阅读区间中的位置，其余以420ms吸附最近阅读边界，同距按最后拖动方向决定。

布局刷新保留已提交的目标和曲线阶段。拖动中缓存最新指针映射，在控制器完成重测后应用，避免要求额外鼠标移动。弹窗、后台、键盘与外部导航接管旧任务，释放指针捕获。减少动态效果时显示圆形球豆，关闭液滴融合，自动位移即时完成。

节点是真实锚点，保留历史和语言切换。可用Tab和Enter访问节点；游标提供垂直scrollbar语义、当前值、章节名称与落位播报。方向键及Page键先阅读本章长内容，到达边界后以新按键切章；Home/End到首尾，Escape结束拖动并收起提示。

## 品牌与运动来源

沿用 `/brand/mark.webp` 原始像素，不新增或重绘图案。512px画布的透明主体边界为 `[99,100,413,411]`，通过CSS裁去外围透明留白，以32px主体呈现，外层40px安全框保留空白。Logo始终正向，不拉伸或模糊；橙色液态层位于其下方。

液态层最多同时包含半径18px的主滴，以及固定在相邻节点附近的两个接触滴。接触范围为节点两侧48 CSS px，接触滴半径最大7px，先在主滴内部长出，再形成细颈、断开并平滑缩回节点。接近另一节点时由同一位置函数反向融合。不按滚动方向镜像整个图案，也不以“最近节点”硬切连接对象；同一轨道位置对应相同液团数据，反向、轻滚、重排和中途改目标都不需要重新启动播放。

局部SVG中的液团共享Gaussian blur与Alpha阈值滤镜，细颈由重叠的Alpha场形成，不再单独绘制连接线。基线参数为3 CSS px模糊、Alpha斜率19与偏移−9，最终使用统一材质配置校准主体尺度、轮廓清晰度和分离距离。滤镜采用明确的局部坐标，为液团位置和模糊边界留出空间，不沿用旧96px高度限制。轨道、7px节点、Logo与提示文字均不进入滤镜。

完整阅读落位和减少动态效果时显示清晰圆形主体。滤镜不可用时使用圆形球豆回退，导航、拖动、焦点与页号仍可用。SVG融合路径和圆形回退需要分别验证；不能仅凭节点或Logo仍可见，就认定实际液滴渲染通过。

当前实现是本站原创的确定性液团数据、SVG结构及接入代码，采用通用的模糊与Alpha阈值技术。以下项目作为设计与技术参考，不安装其React组件、弹簧或其他运行依赖，也未移植实质源代码。

- [Liquid Orb Navigation](https://github.com/Anima529/liquid-orb-navigation/blob/44b0b1e7691cede2d347cfa1b88b51b76919f213/index.html)，固定提交 `44b0b1e7691cede2d347cfa1b88b51b76919f213`。参考液滴黏连与独立清晰标签，[MIT许可](https://github.com/Anima529/liquid-orb-navigation/blob/44b0b1e7691cede2d347cfa1b88b51b76919f213/LICENSE)，Copyright 2026 Anima529
- [liquid-taffy 的goo校准](https://github.com/arknow91/liquid-taffy/blob/4bcf4005f857c371bf53d60b2cee14abcecedf6a/src/components/liquid/goo.ts)，固定提交 `4bcf4005f857c371bf53d60b2cee14abcecedf6a`。参考模糊与Alpha阈值成对校准、清晰内容独立分层，[MIT许可](https://github.com/arknow91/liquid-taffy/blob/4bcf4005f857c371bf53d60b2cee14abcecedf6a/LICENSE)，Copyright 2026 arknow91

早期轨道还参考过 [Fancy GooeySvgFilter](https://github.com/danielpetho/fancy/blob/f9f62c61207b2dd3210476dd98af3c9a5be24094/src/fancy/components/filter/gooey-svg-filter.tsx)，固定提交 `f9f62c61207b2dd3210476dd98af3c9a5be24094`，[MIT许可](https://github.com/danielpetho/fancy/blob/f9f62c61207b2dd3210476dd98af3c9a5be24094/LICENSE)，Copyright 2024 Daniel Petho。其Safari限制描述上游实现，不作为本站兼容性结论。

若后续移植这些项目的实质源码，必须保留相应MIT版权和许可全文。

## 验证

运行 `npm test`、`npm run check`、`npm run format:check`、`npm run build`，以及 `npx playwright test tests/chapter-rail.spec.ts tests/chapter-liquid.spec.ts`。真实滚轮和刷新续播回归沿用已有 `chapter-snap` 测试。重点检查液团先相连后分离、细颈断开与残滴回收，不以尖尾或淡出代替分离；同时检查相同位置正反轮廓、实际SVG滤镜和圆形回退。

早期轨道的实际工作区来源、原始失败、静态前后对比与原速录屏保存在 `D:/temp/hoopito-chapter-rail-20261102/`；比例精修在 `D:/temp/hoopito-rail-proportion-20261103/`，本次液滴重构使用 `D:/temp/hoopito-liquid-split-20261103/`。各阶段结果以各自实际报告为准，不将本文的设计约定视为测试已经通过。

背景的真实WebGL与CSS回退、轨道的SVG融合与圆形回退分别记录。自动化WebKit不等同于真实Safari，录屏帧率不替代GPU呈现验收。历史兼容性和GPU未通过记录不改标。

所有改动只保留本地，不提交、推送、部署或执行项目收尾。
