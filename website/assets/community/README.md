# 球豆球友群邀请卡

群号：**1129560287**。用户提供的 QQ 群二维码仅用于受邀加入交流群。

- `source/qq-group-original.jpg`：用户原图，1370×2435，原样保留。
- `source/arena-invitation-imagegen.png`：内置 ImageGen 生成的夜场背景；完整提示词、来源摘要与合成坐标在 `generation.json`。
- `../../scripts/prepare-community.mjs`：将原图的 928×928 码区原尺寸嵌入背景，外加 128px 纯白静区。字体沿用 Barlow／Noto Sans SC，标志沿用已批准原图。
- `../../public/community/hoopito-qq-group.png`、`.webp`：1536×1536 无损完整成品，供保存与大图查看。
- `../../public/community/hoopito-qq-group-preview.webp`：768×768 等比缩小的无损 WebP 预览，官网／README 使用此图并链接完整 PNG，减少下半页图片传输。预览经过缩放，不冒称与原码逐像素相同；完整 PNG／WebP 的原尺寸码区保持原像素。

在 `website/` 运行 `node scripts/prepare-community.mjs` 可单独重建。`npm run assets` 同样生成邀请卡，并把来源、处理方式及 SHA-256 记录到 `ASSET_SOURCES.json`。原码点、圆形定位图案与 QQ 中央标记不由 ImageGen 重绘，不改变颜色和比例；生成器与像素测试核对两种成品的码区逐像素等于原图裁剪。

QQ 使用的圆形定位码不能由现有通用 QR 解码器可靠解码。像素一致性已纳入验证，但不能替代 QQ 客户端实扫；上线前请用 QQ 确认群名／群号并检查入群流程。更换群码时保留旧来源，重新校准尺寸／裁剪、更新来源摘要并实扫；不可只替换文件继续沿用原坐标。

2026-10-25 用户已用 QQ 确认本轮完整 PNG 扫码成功，群号 **1129560287** 正确。该 PNG 的 SHA-256 为 `ffb7c3ac3655adf704d6910933342a4f95093ada56c5eeb26a21b72b38ddc740`；这项人工确认不等同于通用解码器自动验证。

图片可本地查看和保存，不自动连接 QQ、不嵌入第三方脚本。加入 QQ 后的资料与发言由用户主动提交，适用 QQ 平台规则；不改变离线 App 的数据行为。
