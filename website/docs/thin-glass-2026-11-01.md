# 薄玻璃维护说明 · 2026-11-01

本轮把保留的玻璃面调整为薄液态玻璃，并移除计分横屏、赛果和历史三个 App 截图的外框与光学登记。
七个停留页、球馆模型与镜头、1.2秒真实滚动切章，以及既有事实文案继续使用原有契约。
本文说明实现和证据的维护方式，不替代实际浏览器、原速录屏或 GPU 验收记录。

## 材质入口

[`src/data/glass-material.ts`](../src/data/glass-material.ts) 是 CSS 与 HDR 光学参数的共同来源。
[`Layout.astro`](../src/components/Layout.astro) 在构建时输出 CSS 变量，
[`immersive-glass.css`](../src/styles/immersive-glass.css) 消费基础面，
[`liquid-glass-pass.ts`](../src/scripts/liquid-glass-pass.ts) 消费光学参数。
调整材质时从这个数据源修改，避免页面样式和着色器各自出现一组漂移的常量。

| 路径                  | 参数与用途                                                                                   |
| --------------------- | -------------------------------------------------------------------------------------------- |
| 普通 CSS 降级／移动端 | sRGB `#151b1e`，基础不透明度0.54；12px背景模糊、0.9饱和度；单层细边、轻阴影                  |
| 完整画质 WebGL        | 相同着色、不透明度和0.9饱和度，在线性 HDR 中计算；5px边缘带、最高2.5px折射，中心位移0、色散0 |
| `density` CSS 降级    | 同色不透明度0.9，背景模糊0；保留细边与轻阴影                                                 |
| 减少透明度            | 普通 CSS 路径采用0.97不透明度并关闭背景滤镜                                                  |

两条路径共享设计参数，不保证逐像素相等。HDR 路径使用独立的1.4px扩散采样核，
饱和度按线性场景的亮度计算；它与 CSS 的12px模糊不是等效半径，修改时分别观察实际结果。
光学 pass 继续位于 Bloom 之后、OutputPass 之前，只采样当前球场的线性 HDR 输出。
`CourtScene`、`StoryFrame`、`GlassSurface` 接口及同帧组件更新→轮廓读取→场景提交顺序继续保留。
WebGL可用且实际启用完整光学 pass 时才设置 `data-glass="webgl"`，此时 CSS 边框保留占位但透明，
由着色器绘制唯一可见边缘。CSS 降级保留标准 `backdrop-filter` 在厂商前缀之后。
文字保护只在文字区域保留一层可控遮光，避免整面二次染灰或加厚边框。

## 截图与交互

计分章仅操作区、复盘章仅分析区登记为光学表面。三张 App 截图继续保留原有 `data-story-*`
运动标记、双语图注、点击大图和键盘入口；大图继续使用完整分辨率的干净展示副本。
不改变截图像素、比分、比例和拍摄来源，不增加设备边框或遮住 App 自身内容。
其他保留表面仍受每章最多三个、相邻转场最多六个的统一登记上限约束。
修改截图或视图结构后同时检查两种语言、横竖布局、大图打开／关闭与焦点恢复。

## 外部参考与许可身份

2026-11-01 经 GitHub 连接器核对默认分支与以下固定提交，随后在固定提交中读取文件。
链接中的提交 SHA 与下表的 Git blob SHA 是两种身份；blob 标识被审阅文件的实际内容，不能替作提交 SHA。

- [shuding/liquid-glass](https://github.com/shuding/liquid-glass/tree/a2d2e847f793430e3409a52927af815a23f4d372)：
  `main` 当时为 `a2d2e847f793430e3409a52927af815a23f4d372`。
- [rdev/liquid-glass-react](https://github.com/rdev/liquid-glass-react/tree/ac48eab18d1f7f444ae30002d240cae29c863a21)：
  `master` 当时为 `ac48eab18d1f7f444ae30002d240cae29c863a21`。

| 项目                    | 审阅文件                                                                                                                 | Git blob SHA                               |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------ |
| shuding/liquid-glass    | [README.md](https://github.com/shuding/liquid-glass/blob/a2d2e847f793430e3409a52927af815a23f4d372/README.md)             | `8edf26581a7cb7cf9f6fc2b2509b8e560b46370b` |
| shuding/liquid-glass    | [liquid-glass.js](https://github.com/shuding/liquid-glass/blob/a2d2e847f793430e3409a52927af815a23f4d372/liquid-glass.js) | `876fd61e0ecb4ee812776da66bd3099646ac1e64` |
| shuding/liquid-glass    | [LICENSE](https://github.com/shuding/liquid-glass/blob/a2d2e847f793430e3409a52927af815a23f4d372/LICENSE)                 | `0a5528e9a24a7fe18fd8bcd620d1ffb546943114` |
| rdev/liquid-glass-react | [README.md](https://github.com/rdev/liquid-glass-react/blob/ac48eab18d1f7f444ae30002d240cae29c863a21/README.md)          | `e8371e32f3266e99fc09c0650f0247c5e344606b` |
| rdev/liquid-glass-react | [src/index.tsx](https://github.com/rdev/liquid-glass-react/blob/ac48eab18d1f7f444ae30002d240cae29c863a21/src/index.tsx)  | `a0e6b7242d2c66c598eecdfbe33815d996621571` |
| rdev/liquid-glass-react | [LICENSE](https://github.com/rdev/liquid-glass-react/blob/ac48eab18d1f7f444ae30002d240cae29c863a21/LICENSE)              | `4088348a7ff1e19436f9c43c31f7cdcc1bf8fc7c` |
| rdev/liquid-glass-react | [package.json](https://github.com/rdev/liquid-glass-react/blob/ac48eab18d1f7f444ae30002d240cae29c863a21/package.json)    | `4161f036d2f09e7dc1356b9393859045010f4e91` |

这两个项目用于观察边缘折射、克制高光与清晰内容的关系。网站沿用自己的圆角距离着色器，
没有复制第三方实现，也没有引入 React、SVG位移库、新上下文或网络请求。
两份 MIT 许可的版权归属与后续采用代码时须保留的声明见
[`THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md#continuous-court-and-glass)。
上游 React 组件依赖 React／React DOM >=18；其 README 对 Safari／Firefox 的位移支持限制
属于上游实现说明，不能当作本网站已通过或失败的兼容性结果。

## 验证口径

本轮证据目录为仓库外 `D:/temp/hoopito-liquid-glass-20261101/`。原始前后截图、原速滚动录屏、
性能原始记录及失败样本分别保存；每项按实际源码／工作区摘要、构建、浏览器、渲染器和视口绑定。
必须分别核对 `full` WebGL、普通 CSS 降级与 `density` CSS 降级的实际运行状态。
仅有 `data-scene="3d"` 不能证明完整玻璃已启用，还需读取实际画质和 `data-glass`；
通过 CSS 隐藏场景或只切换属性得到的截图不能冒称完整 WebGL 实拍。

截图可证明构图、边缘和可读性；原速录屏与真实呈现／GPU数据分别证明各自范围。
过往 Firefox／WebKit 时序失败、Windows WebKit 原生滚轮限制及 AMD／NVIDIA GPU 失败
继续绑定原始样本，不因本轮改动或新的静态截图改记为通过。没有新的实际结果时不宣称性能改善、
全平台通过或 Safari 已验收。最终实际验证结果由本轮证据记录说明。
