// Export the existing approved artwork; never redraw or recolor the mascot.
// Run from any directory after npm ci in website/.
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { createRequire } from "node:module";
import { readFile, writeFile, mkdir } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const repo = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const output = join(repo, "assets/brand/hoopito-logo-kit");
const requireWebsite = createRequire(join(repo, "website/package.json"));
const sharp = requireWebsite("sharp");
const requireFont = createRequire(requireWebsite.resolve("subset-font"));
const hb = await import(pathToFileURL(requireFont.resolve("harfbuzzjs")).href);
const hash = (bytes) => createHash("sha256").update(bytes).digest("hex");
const read = (path) => readFile(join(repo, path));
// Text provenance uses LF bytes, independent of core.autocrlf or the host OS.
// Do not rewrite historical sources; only normalize their exported representation.
const readText = async (path) =>
  Buffer.from(
    (await readFile(join(repo, path), "utf8")).replace(/\r\n/g, "\n"),
  );
const foreground = await read("assets/icons/hoopito-app-icon-foreground.png");
const appIcon = await read("assets/icons/hoopito-app-icon.png");
const monochrome = await read("assets/icons/hoopito-app-icon-monochrome.png");
const approvalBytes = await readText("docs/design/brand/source.json");
const approval = JSON.parse(approvalBytes);
assert.equal(hash(foreground), approval.normalizedForegroundSha256);
const bold = await read("assets/fonts/BarlowCondensed-Bold.ttf");
const noto = await read("assets/fonts/NotoSansSC-Regular.otf");
const records = [];

async function save(path, bytes, description) {
  const full = join(output, path);
  await mkdir(dirname(full), { recursive: true });
  await writeFile(full, bytes);
  const metadata = /\.(png|webp)$/.test(path)
    ? await sharp(bytes).metadata()
    : null;
  records.push({
    path,
    bytes: bytes.length,
    sha256: hash(bytes),
    description,
    ...(metadata
      ? {
          width: metadata.width,
          height: metadata.height,
          alpha: metadata.hasAlpha,
        }
      : {}),
  });
}

function glyphs(bytes, text, x, y, size, color, tracking = 0) {
  const blob = new hb.Blob(bytes),
    face = new hb.Face(blob, 0),
    font = new hb.Font(face);
  const buffer = new hb.Buffer();
  buffer.addText(text);
  buffer.guessSegmentProperties();
  hb.shape(font, buffer);
  const scale = size / face.upem;
  let advance = 0;
  const paths = buffer
    .getGlyphInfosAndPositions()
    .map((glyph) => {
      assert.ok(glyph.codepoint, `Missing glyph for ${text}`);
      const path = `<path d="${font.glyphToPath(glyph.codepoint)}" transform="translate(${advance + glyph.xOffset} ${glyph.yOffset})"/>`;
      advance += glyph.xAdvance + tracking / scale;
      return path;
    })
    .join("");
  return {
    width: advance * scale - tracking,
    svg: `<g fill="${color}" transform="translate(${x} ${y}) scale(${scale} ${-scale})">${paths}</g>`,
  };
}

function lockup(locale, ink, background = "") {
  let lettering = "",
    end = 178;
  if (locale !== "zh") {
    const en = glyphs(bold, "HOOPITO", 178, 172, 148, ink, -1.7);
    const dot = glyphs(bold, ".", 178 + en.width + 3, 172, 148, "#FF5A1F");
    lettering = en.svg + dot.svg;
    end = 178 + en.width + 3 + dot.width;
  }
  if (locale === "zh") {
    const zh = glyphs(noto, "球豆", 178, 166, 120, ink);
    lettering = zh.svg;
    end = 178 + zh.width;
  } else if (locale === "bilingual") {
    const zh = glyphs(noto, "球豆", end + 48, 166, 120, ink);
    lettering += zh.svg;
    end += 48 + zh.width;
  }
  const width = Math.ceil(end + 48);
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="240" viewBox="0 0 ${width} 240" role="img" aria-label="Hoopito · 球豆">
<title>Hoopito · 球豆</title>
${background ? `<rect width="${width}" height="240" fill="${background}"/>` : ""}
<image href="data:image/png;base64,${foreground.toString("base64")}" x="8" y="32" width="176" height="176"/>
${lettering}</svg>`;
}

await save(
  "00-masters/hoopito-symbol-transparent-1024.png",
  foreground,
  "Byte-identical approved production foreground; 1024 canvas with 620px mascot safe zone.",
);
await save(
  "00-masters/hoopito-app-icon-1024.png",
  appIcon,
  "Byte-identical approved opaque launcher master.",
);
await save(
  "00-masters/hoopito-symbol-monochrome-1024.png",
  monochrome,
  "Byte-identical warm-white monochrome master with negative-space facial details.",
);
await save(
  "00-masters/approval-record.json",
  approvalBytes,
  "Historical approval and ImageGen provenance, normalized to UTF-8/LF only; original text and source names retained.",
);

for (const size of [512, 256, 128, 64, 32]) {
  await save(
    `01-symbol/hoopito-symbol-transparent-${size}.png`,
    await sharp(foreground).resize(size, size).png().toBuffer(),
    "Proportional downsample of the approved transparent source; original safe padding retained.",
  );
}
await save(
  "01-symbol/hoopito-symbol-transparent-tight.png",
  await sharp(foreground)
    .extract({ left: 202, top: 204, width: 620, height: 614 })
    .png()
    .toBuffer(),
  "Lossless crop of fully transparent outer padding only; 620x614 native mascot pixels, add clear space when placing.",
);
await save(
  "01-symbol/hoopito-symbol-transparent-512.webp",
  await sharp(foreground).resize(512, 512).webp({ lossless: true }).toBuffer(),
  "Lossless WebP encoding after proportional downsampling.",
);
await save(
  "01-symbol/hoopito-symbol-monochrome-512.png",
  await sharp(monochrome).resize(512, 512).png().toBuffer(),
  "Warm-white single-color mark for dark backgrounds; existing negative-space geometry retained.",
);

for (const size of [512, 192]) {
  await save(
    `02-backgrounds/hoopito-app-icon-dark-${size}.png`,
    await sharp(appIcon).resize(size, size).png().toBuffer(),
    "Proportional downsample of the approved opaque app icon; not a platform resource replacement.",
  );
}
for (const [name, background] of [
  ["dark", "#101112"],
  ["light", "#F4F3EF"],
]) {
  await save(
    `02-backgrounds/hoopito-symbol-${name}-1024.png`,
    await sharp(foreground).flatten({ background }).png().toBuffer(),
    "Approved foreground composited on a solid brand background; shape and all opaque face details unchanged.",
  );
}

const previews = [];
for (const locale of ["en", "zh", "bilingual"]) {
  for (const [theme, ink, bg] of [
    ["on-light", "#101112", "#F4F3EF"],
    ["on-dark", "#F4F3EF", "#101112"],
  ]) {
    const svg = lockup(locale, ink);
    await save(
      `03-lockups/hoopito-${locale}-${theme}.svg`,
      Buffer.from(svg),
      "Portable hybrid SVG: approved bitmap icon embedded; Barlow/Noto lettering converted to vector paths. Not an all-vector mascot.",
    );
    await save(
      `03-lockups/hoopito-${locale}-${theme}@2x.png`,
      await sharp(Buffer.from(svg), { density: 144 }).png().toBuffer(),
      "2x PNG render of the hybrid lockup; transparent background, no newly generated mascot detail.",
    );
    previews.push({ locale, theme, svg: lockup(locale, ink, bg) });
  }
}

const panelWidth = 760,
  panelHeight = 230;
const layers = [];
for (let index = 0; index < previews.length; index++) {
  const preview = previews[index];
  const left = (index % 2) * panelWidth,
    top = Math.floor(index / 2) * panelHeight;
  const raster = await sharp(Buffer.from(preview.svg))
    .resize(680, 180, {
      fit: "contain",
      background: preview.theme === "on-light" ? "#F4F3EF" : "#101112",
    })
    .png()
    .toBuffer();
  layers.push({
    input: Buffer.from(
      `<svg width="760" height="230"><rect width="760" height="230" fill="${preview.theme === "on-light" ? "#F4F3EF" : "#101112"}"/></svg>`,
    ),
    left,
    top,
  });
  layers.push({ input: raster, left: left + 40, top: top + 25 });
}
await save(
  "PREVIEW.png",
  await sharp({
    create: {
      width: panelWidth * 2,
      height: panelHeight * 3,
      channels: 4,
      background: "#101112",
    },
  })
    .composite(layers)
    .png()
    .toBuffer(),
  "Contact sheet of English, Chinese and bilingual lockups on light and dark brand backgrounds.",
);
const licenseSources = [];
for (const [source, name] of [
  ["LICENSE", "LICENSE-Artwork.txt"],
  ["assets/fonts/OFL.txt", "OFL-Barlow.txt"],
  ["assets/fonts/OFL-NotoSansSC.txt", "OFL-NotoSansSC.txt"],
]) {
  const bytes = await readText(source);
  licenseSources.push({
    path: source,
    sha256: hash(bytes),
    normalization: "utf8-lf",
  });
  await save(
    `04-licenses/${name}`,
    bytes,
    "Repository artwork or bundled font license; text unchanged, UTF-8/LF representation.",
  );
}
await save(
  "palette.json",
  Buffer.from(
    JSON.stringify(
      {
        brand: "Hoopito · 球豆",
        colors: {
          arenaOrange: "#FF5A1F",
          nearBlack: "#101112",
          warmWhite: "#F4F3EF",
        },
        fonts: {
          latin: "Barlow Condensed Bold",
          chinese: "Noto Sans SC Regular",
        },
      },
      null,
      2,
    ) + "\n",
  ),
  "Existing approved brand colors and existing project typography.",
);

const readme = `# Hoopito · 球豆 Logo 套件

现有正式 C「独眼球怪」Logo 的整理导出。保留原图、配色、表情和篮球纹路，不是重新设计。

## 文件在哪里

- \`00-masters/\`：正式透明源图、深色 App 图标、暖白单色源图（均 1024×1024），以及原批准记录。
- \`01-symbol/\`：透明 PNG 512／256／128／64／32px、512px WebP、暖白单色版及去掉透明留白的紧裁版。
- \`02-backgrounds/\`：明暗背景展示图；原 App 图标的 512／192px 副本。
- \`03-lockups/\`：英文 HOOPITO.、中文 球豆、双语组合；每种均有浅底用深色字、深底用暖白字的透明 SVG 和 2 倍 PNG。
- \`PREVIEW.png\`：组合版本一览；\`palette.json\`：品牌色；\`04-licenses/\`：图形与字体许可；\`manifest.json\`：来源、处理方式和文件 SHA-256。

## 如何使用

普通网页、海报或介绍文档：优先选 \`03-lockups/\`；仅需角色图案时选 \`01-symbol/hoopito-symbol-transparent-tight.png\`，并在四周额外保留至少主体宽度 10% 的空白。应用图标与需要既有安全边距的场景使用 \`00-masters/\`。

\`on-light\` 表示适合浅色背景，\`on-dark\` 表示适合深色背景；两者文件本身均透明。暖白单色图案只适合有足够对比的深色背景，眼睛、笑和球纹为空白负空间。不要改变三色图案中的黑色眼瞳、笑和球纹，不拉伸、不旋转、不添加描边、阴影或渐变。

小尺寸使用：保留原安全边距的 32px 图中，角色实际约 20px，眼睛和轮廓可辨，笑和球纹会软化；64px 图保留更多细节。小型导航优先使用紧裁版，角色显示宽度至少 32px，另留 10% 空白。组合字标包含较大的上下留白，建议显示画布高度至少 96px（文字和图形实高约 43px）；不要把画布高度当作可见字高。

正式源画布为 1024×1024，但主体原始有效区域约 620×614px；扩大输出不代表增加原图细节。SVG 是“内嵌 PNG 图标＋已转路径文字”的混合文件，**不是纯矢量图标**。适合网页和常规排版；大型喷绘需要另行确认源图分辨率，不能把此文件当作无限精度矢量原稿。

品牌色：竞技橙 \`#FF5A1F\`、近黑 \`#101112\`、暖白 \`#F4F3EF\`。字标沿用项目的 Barlow Condensed／Noto Sans SC，字形已转路径，无需安装字体也能显示。

## 来源和复现

图形批准日期：2026-10-04。原始生成记录在项目 \`docs/design/brand/\`，保留历史名称；当前生产图形在 \`assets/icons/\`。本套件仅是整理的副本，没有修改 App、网站或平台图标入口。

在 \`website/\` 安装锁定依赖后，于仓库根目录运行：

\`\`\`powershell
node tool/brand/export_logo_kit.mjs
\`\`\`

该命令只更新本文件夹中由其生成的文件，不修改原始 Logo 或网站资源。历史批准记录及许可副本统一为 UTF-8／LF，除换行外保留原文；清单中 \`normalization: utf8-lf\` 的来源摘要也按该表示计算，不使用当前 checkout 的 CRLF 字节。图像和字体按原字节计算摘要，\`website/package-lock.json\` 记录依赖版本来源。

运行 \`node --test tool/brand/export_logo_kit.test.mjs\` 可在隔离输出中检查 LF／CRLF 一致性、来源与输出摘要，以及未批准图形的拒绝行为。图形沿用仓库 MIT 许可；字体及其转路径字形遵守附带 SIL OFL 1.1。没有另行加入第三方图片。
`;
await save(
  "README.md",
  Buffer.from(readme),
  "Usage, source identity, safe-space and mixed bitmap/vector limitations.",
);
const manifest = {
  brand: "Hoopito · 球豆",
  approvalDate: "2026-10-04",
  generatedBy: "node tool/brand/export_logo_kit.mjs",
  generatorSha256: hash(await readFile(fileURLToPath(import.meta.url))),
  sources: [
    {
      path: "assets/icons/hoopito-app-icon-foreground.png",
      sha256: hash(foreground),
    },
    { path: "assets/icons/hoopito-app-icon.png", sha256: hash(appIcon) },
    {
      path: "assets/icons/hoopito-app-icon-monochrome.png",
      sha256: hash(monochrome),
    },
    {
      path: "docs/design/brand/source.json",
      sha256: hash(approvalBytes),
      normalization: "utf8-lf",
    },
    { path: "assets/fonts/BarlowCondensed-Bold.ttf", sha256: hash(bold) },
    { path: "assets/fonts/NotoSansSC-Regular.otf", sha256: hash(noto) },
    ...licenseSources,
    {
      path: "website/package-lock.json",
      sha256: hash(await readText("website/package-lock.json")),
      normalization: "utf8-lf",
    },
  ],
  outputs: records,
};
await writeFile(
  join(output, "manifest.json"),
  JSON.stringify(manifest, null, 2) + "\n",
);
for (const record of records)
  assert.equal(hash(await readFile(join(output, record.path))), record.sha256);
console.log(
  JSON.stringify(
    {
      folder: output,
      files: records.length + 1,
      verified: true,
      foregroundSha256: hash(foreground),
    },
    null,
    2,
  ),
);
