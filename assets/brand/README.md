# Hoopito · 球豆品牌素材

[Logo 整理套件](hoopito-logo-kit/README.md)保留现有批准图形，包含源图副本、多尺寸图、明暗底图和双语组合字标。[Issue #16](https://github.com/x1a0Y4NGren/hoopito/issues/16) 的导出修正及逐项检查已完成，并于 2026-10-25 通过维护者审阅；原图历史批准与这次套件验证分别记录。

已检查 10 个来源、34 个输出与清单、三个 master 的生产源字节一致性、尺寸、透明属性及紧裁像素；独立干净 Git checkout 的复现方式和逐项视觉结果见[验证记录](VALIDATION.md)。所有 PNG、WebP 和 SVG 均与此前整理稿逐字节相同，没有重新设计 Logo。

套件生成字节由 `.gitattributes` 的 `-text` 保护，导出脚本固定 LF。历史批准记录、许可及锁文件按 UTF-8／LF 计算来源摘要，导出的批准／许可副本也统一 LF，除换行外保留原文；历史文件自身不修改。清单中这些来源明确标记 `normalization: utf8-lf`，不能拿当前 checkout 的 CRLF 字节直接比较该摘要。

导出命令为 `node tool/brand/export_logo_kit.mjs`，需先在 `website/` 运行 `npm ci` 安装锁定依赖。回归命令为 `node --test tool/brand/export_logo_kit.test.mjs`。生成器只维护套件目录；本文件和验证记录位于其输出之外，重导出不会覆盖。

小尺寸请遵守套件说明：保留原安全边距的 32px 图中，主体实际约 20px，细节会软化；小型导航优先选紧裁版并额外留白。组合字标上下留白较大，建议显示画布高度至少 96px，不把画布高度当作字高。

App、网站和平台图标继续使用已有生产入口。套件 SVG 内嵌位图图标，不能当作纯矢量原稿；用途、留白及许可见套件说明。
