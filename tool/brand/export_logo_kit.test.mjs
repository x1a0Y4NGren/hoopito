import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import {
  cp,
  mkdir,
  mkdtemp,
  readFile,
  readdir,
  rm,
  symlink,
  writeFile,
} from "node:fs/promises";
import { after, before, test } from "node:test";
import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repo = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const scratch = join(repo, "website/output");
const script = "tool/brand/export_logo_kit.mjs";
const kit = "assets/brand/hoopito-logo-kit";
const hash = (bytes) => createHash("sha256").update(bytes).digest("hex");
const inputs = [
  script,
  "website/package.json",
  "website/package-lock.json",
  "assets/icons/hoopito-app-icon-foreground.png",
  "assets/icons/hoopito-app-icon.png",
  "assets/icons/hoopito-app-icon-monochrome.png",
  "docs/design/brand/source.json",
  "assets/fonts/BarlowCondensed-Bold.ttf",
  "assets/fonts/NotoSansSC-Regular.otf",
  "LICENSE",
  "assets/fonts/OFL.txt",
  "assets/fonts/OFL-NotoSansSC.txt",
];
const textSources = [
  ["docs/design/brand/source.json", "00-masters/approval-record.json"],
  ["LICENSE", "04-licenses/LICENSE-Artwork.txt"],
  ["assets/fonts/OFL.txt", "04-licenses/OFL-Barlow.txt"],
  ["assets/fonts/OFL-NotoSansSC.txt", "04-licenses/OFL-NotoSansSC.txt"],
];
let workspace;
let lf;
let crlf;

async function fixture(name, eol) {
  const root = join(workspace, name);
  for (const path of inputs) {
    const destination = join(root, path);
    await mkdir(dirname(destination), { recursive: true });
    if (
      textSources.some(([source]) => source === path) ||
      path === "website/package-lock.json"
    ) {
      const text = (await readFile(join(repo, path), "utf8")).replace(
        /\r\n/g,
        "\n",
      );
      await writeFile(destination, text.replace(/\n/g, eol));
    } else {
      await cp(join(repo, path), destination);
    }
  }
  await symlink(
    join(repo, "website/node_modules"),
    join(root, "website/node_modules"),
    process.platform === "win32" ? "junction" : "dir",
  );
  return root;
}

function run(root) {
  return execFileSync(process.execPath, [join(root, script)], {
    cwd: root,
    encoding: "utf8",
    timeout: 120_000,
    stdio: ["ignore", "pipe", "pipe"],
  });
}

before(async () => {
  await mkdir(scratch, { recursive: true });
  workspace = await mkdtemp(join(scratch, "logo-export-test-"));
  lf = await fixture("lf", "\n");
  crlf = await fixture("crlf", "\r\n");
  run(lf);
  run(crlf);
});

after(async () => {
  // Only remove this test's unique scratch directory; never follow the dependency link.
  if (
    workspace &&
    relative(scratch, workspace).startsWith("logo-export-test-") &&
    dirname(workspace) === scratch
  ) {
    await rm(workspace, { recursive: true, force: true });
  }
});

test("LF and CRLF source checkouts export identical files and provenance", async () => {
  const manifest = JSON.parse(await readFile(join(lf, kit, "manifest.json")));
  for (const path of [
    "manifest.json",
    ...manifest.outputs.map((record) => record.path),
  ]) {
    assert.deepEqual(
      await readFile(join(crlf, kit, path)),
      await readFile(join(lf, kit, path)),
      `${path} depends on checkout line endings`,
    );
  }
});

test("English, Chinese and bilingual lockups retain visible outlines and finite layout", async () => {
  const widths = new Map();
  for (const locale of ["en", "zh", "bilingual"]) {
    for (const theme of ["on-light", "on-dark"]) {
      const path = `03-lockups/hoopito-${locale}-${theme}.svg`;
      const svg = await readFile(join(lf, kit, path), "utf8");
      assert.doesNotMatch(svg, /<text\b/i, `${path} must embed font outlines`);
      const dimensions = svg.match(
        /<svg\b[^>]*\bwidth="([\d.]+)" height="([\d.]+)"/,
      );
      assert.ok(dimensions, `${path} must declare its dimensions`);
      const width = Number(dimensions[1]);
      assert.ok(Number.isFinite(width) && width > 178, path);
      assert.equal(Number(dimensions[2]), 240, path);
      widths.set(`${locale}-${theme}`, width);

      const outlines = [...svg.matchAll(/<path\b[^>]*\bd="([^"]*)"/g)];
      const expectedGlyphs = { en: 8, zh: 2, bilingual: 10 }[locale];
      assert.equal(outlines.length, expectedGlyphs, `${path} lost lettering`);
      for (const [, outline] of outlines) {
        assert.doesNotMatch(outline, /\b(?:NaN|Infinity|undefined)\b/, path);
        assert.match(outline, /[MLCQ]/i, `${path} has an empty glyph`);
      }
      const transforms = [...svg.matchAll(/\btransform="([^"]+)"/g)];
      assert.ok(transforms.length >= expectedGlyphs, path);
      for (const [, transform] of transforms) {
        assert.doesNotMatch(transform, /\b(?:NaN|Infinity|undefined)\b/, path);
        const values = transform.match(
          /[-+]?(?:\d*\.\d+|\d+\.?\d*)(?:e[-+]?\d+)?/gi,
        );
        assert.ok(values?.length, `${path}: ${transform}`);
        assert.ok(
          values.every((value) => Number.isFinite(Number(value))),
          path,
        );
      }
      const raster = await readFile(
        join(lf, kit, `03-lockups/hoopito-${locale}-${theme}@2x.png`),
      );
      assert.deepEqual(
        raster.subarray(0, 8),
        Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
        `${path} must have a PNG counterpart`,
      );
      assert.equal(raster.readUInt32BE(16), width * 2, path);
      assert.equal(raster.readUInt32BE(20), 480, path);
    }
  }
  for (const theme of ["on-light", "on-dark"]) {
    assert.ok(widths.get(`bilingual-${theme}`) > widths.get(`en-${theme}`));
    assert.ok(widths.get(`bilingual-${theme}`) > widths.get(`zh-${theme}`));
  }
});

test("approval and licenses preserve their text with an explicit LF representation", async () => {
  const manifest = JSON.parse(await readFile(join(crlf, kit, "manifest.json")));
  for (const [source, output] of textSources) {
    const expected = Buffer.from(
      (await readFile(join(repo, source), "utf8")).replace(/\r\n/g, "\n"),
    );
    assert.deepEqual(await readFile(join(crlf, kit, output)), expected, output);
    const record = manifest.sources.find((item) => item.path === source);
    assert.ok(record, `${source} is missing from source provenance`);
    assert.equal(record.normalization, "utf8-lf");
    assert.equal(record.sha256, hash(expected));
  }
});

test("the dependency lock is bound by its LF digest in both checkouts", async () => {
  const expected = hash(
    Buffer.from(
      (await readFile(join(repo, "website/package-lock.json"), "utf8")).replace(
        /\r\n/g,
        "\n",
      ),
    ),
  );
  for (const root of [lf, crlf]) {
    const manifest = JSON.parse(
      await readFile(join(root, kit, "manifest.json")),
    );
    const record = manifest.sources.find(
      (source) => source.path === "website/package-lock.json",
    );
    assert.ok(
      record,
      "The exported provenance must include the dependency lock",
    );
    assert.equal(record.normalization, "utf8-lf");
    assert.equal(record.sha256, expected);
  }
});

test("every exported file is covered by a correct hash and original masters remain exact", async () => {
  const manifest = JSON.parse(await readFile(join(lf, kit, "manifest.json")));
  for (const record of manifest.outputs) {
    const bytes = await readFile(join(lf, kit, record.path));
    assert.equal(bytes.length, record.bytes, record.path);
    assert.equal(hash(bytes), record.sha256, record.path);
  }
  for (const [source, output] of [
    [
      "assets/icons/hoopito-app-icon-foreground.png",
      "00-masters/hoopito-symbol-transparent-1024.png",
    ],
    [
      "assets/icons/hoopito-app-icon.png",
      "00-masters/hoopito-app-icon-1024.png",
    ],
    [
      "assets/icons/hoopito-app-icon-monochrome.png",
      "00-masters/hoopito-symbol-monochrome-1024.png",
    ],
  ]) {
    assert.deepEqual(
      await readFile(join(lf, kit, output)),
      await readFile(join(repo, source)),
      output,
    );
  }
});

test("a changed production foreground is rejected before writing any kit output", async () => {
  const root = await fixture("unapproved", "\n");
  await writeFile(
    join(root, "assets/icons/hoopito-app-icon-foreground.png"),
    "unapproved image",
  );
  assert.throws(() => run(root), /AssertionError/);
  await assert.rejects(readdir(join(root, kit)), { code: "ENOENT" });
});
