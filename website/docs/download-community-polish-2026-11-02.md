# 下载与社区双页精修

本轮保留第五、六页的左右构图、球馆模型与镜头、薄玻璃和1.2秒真实滚动切章。
下载和社区各保留一个光学表面，不新增依赖、独立章节时钟或复制群号功能，FAQ与页脚不改。

## 组件与阅读

下载标题、社区标题和社区整段内容移除大范围遮光，阅读保护落在实际文字区域。
下载左侧重复的小Logo与HOOPITO品牌行删除，导航与下载卡品牌保留；“球场见”的字号与橙色短条不变。
卡内品牌和版本靠近、基线对齐，二维码仍为原112px与白边，不改内容或编码。
安装说明依次呈现当前下载版本、系统来源安装授权、从2.0.0覆盖升级与保留数据，使用自然换行。

校验和旧版升级正文仅增加160ms的透明度显露，不动画化高度；减少动态效果时不播放。
折叠区域继续使用原生details，重排沿用已有章节与玻璃轮廓刷新流程。
旧v1签名限制、App之外的完整JSON备份、卸载与恢复顺序、CSV和图片不能完整恢复等事实保留。

社区次标题普通桌面32–42px、手机32–44px，中英文独立校准。群号保持原数据、字号范围与可选择文本。
加入方法之后紧接保存邀请卡，外部群与离线说明放到按钮下方。
`.community-actions`只负责静态布局；保存按钮与说明分别登记动效，不在动效项里嵌套另一动效项。
保存按钮仍在同一元素上登记光学和运动标记，避免轮廓不同步。

海报及预览原图不变。图注明确增加“查看完整邀请卡”，与图片本身指向相同的完整PNG，
保留原生新标签页查看与文件下载语义，不引入新的大图弹窗。
入口至少48px，具有键盘焦点；海报与玻璃不作悬停位移或缩放，复用轻微内部反馈。

## 双语文案与事实核对

| 位置         | 中文                                                                                                             | English                                                                                                                                                                     |
| ------------ | ---------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 下载说明     | 永久免费 开源 核心功能离线可用／下一场单挑 带上球豆                                                              | Free forever and open source. Core features work offline. / Bring Hoopito to your next 1v1.                                                                                 |
| 安装说明     | 当前下载为 Hoopito · 球豆 v2.0.1／下载后 在系统提示中允许此来源安装／已安装 v2.0.0 可直接覆盖升级 保留数据和设置 | The current download is Hoopito v2.0.1. / Download the APK and allow installation from this source when Android asks. / Install over v2.0.0 to keep your data and settings. |
| 社区说明     | 分享球场故事 聊聊使用球豆的感受／也欢迎交流设计和开发的想法                                                      | Share a court story or tell us how Hoopito works for you. / Design and development ideas are welcome too.                                                                   |
| 加入方法     | 用 QQ 扫码 或搜索群号申请加入／同一部手机上浏览时 先保存邀请卡 再到 QQ 中识别图片                                | Scan with QQ or search the group number to request to join. / If you are browsing on the same phone, save the invitation and use QQ to recognize the QR code in the image.  |
| 次级说明     | 交流群是自愿参与的外部 QQ 群／不影响 App 的离线使用                                                              | Joining this external QQ group is optional. The app continues to work offline.                                                                                              |
| 完整图片入口 | 查看完整邀请卡                                                                                                   | View full invitation                                                                                                                                                        |

斜线表示段落或换行，不输出到页面。沿用humanizer通用模式轻度润色，中文用自然换行减少标点，
英文保留已有自然表达和必要断句。下载版本、群号、二维码、原海报与预览、渠道地址及升级事实不变。
内容字段仅新增内部的`community.openLabel`，不改变场景或下载的公共接口。

## 验证与来源

修改前基线、当前工作区和构建摘要、原始失败、双语实际截图、原速转场与检查结果保存在
`D:/temp/hoopito-download-community-polish-20261102/`，以该目录验证报告为准。
正常动态、静态full/WebGL和CSS降级分别记录；视频和提交统计不作为GPU呈现帧率验收。
历史兼容性、GPU及真实Safari／实体设备缺口独立保留。
本轮只在本地实现和验证，没有提交、推送、部署、长期预览更新或项目收尾。
