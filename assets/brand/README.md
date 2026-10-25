# Hoopito · 球豆品牌素材

[Logo 整理套件](hoopito-logo-kit/README.md)保留现有批准图形，包含源图副本、多尺寸图、明暗底图和双语组合字标。当前以**待最终验收的整理稿**保存，剩余工作由 [Issue #16](https://github.com/x1a0Y4NGren/hoopito/issues/16) 跟踪。

已检查来源及输出摘要、生产源一致性、尺寸、透明属性和紧裁像素；独立导出复现及小尺寸／组合字标的逐项视觉确认仍待完成。套件中的历史批准日期只证明原图形获批，不代表这组新导出全部通过最终验收。

套件生成字节由 `.gitattributes` 的 `-text` 保护，导出脚本固定 LF，避免 Git 自动转换行尾使清单失效。历史来源 `docs/design/brand/source.json` 在当前 Windows 工作区与 Git blob 中的行尾不同；干净 checkout 的跨平台来源规范和重新导出核验仍由 #16 跟踪，当前摘要匹配不等同于跨平台复现通过。

导出命令为 `node tool/brand/export_logo_kit.mjs`，需先在 `website/` 安装锁定依赖。生成器只维护套件目录；本文件记录整理状态，避免重导出覆盖待办说明。

App、网站和平台图标继续使用已有生产入口。套件 SVG 内嵌位图图标，不能当作纯矢量原稿；用途、留白及许可见套件说明。
