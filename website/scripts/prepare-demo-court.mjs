import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import sharp from 'sharp';

export const demoCourtRecord =
  'website/assets/materials/demo-court-generation-v2.json';
const digest = (bytes) => createHash('sha256').update(bytes).digest('hex');

/**
 * @typedef {{cx:number,cy:number,rx:number,ry:number}} RimAnchor
 * @typedef {{left:number,top:number,width:number,height:number}} Crop
 * @typedef {{dimensions_px:number[],source_dimensions_px:number[],crop_px?:Crop,
 * transformation:string,rim_anchor_px_source?:RimAnchor,
 * rim_anchor_px_production?:RimAnchor,
 * placement_svg?:{x:number,y:number,width:number,height:number},
 * alpha_pixels?:{transparent:number,solid:number,total:number}}} DemoArtProvenance
 */

/** Convert the generated color art without painting, stretching or dropping alpha. */
export async function encodeDemoCourtAsset(source, asset) {
  const sourceMetadata = await sharp(source).metadata();
  if (digest(source) !== asset.source_sha256)
    throw new Error(`Demo court source changed: ${asset.id}`);
  if (
    sourceMetadata.width !== asset.source_dimensions_px[0] ||
    sourceMetadata.height !== asset.source_dimensions_px[1]
  )
    throw new Error(`Demo court source dimensions changed: ${asset.id}`);
  if (!['maple', 'hoop'].includes(asset.id))
    throw new Error(`Unknown demo court art: ${asset.id}`);
  const floor = asset.id === 'maple';
  const crop = asset.crop_px;
  const sourceWidth = crop?.width ?? sourceMetadata.width;
  const sourceHeight = crop?.height ?? sourceMetadata.height;
  if (floor && sourceWidth !== sourceHeight)
    throw new Error(
      'Demo maple source must be square before proportional export',
    );
  if (!floor && !sourceMetadata.hasAlpha)
    throw new Error('Demo hoop source must have a real transparent background');
  let pipeline = sharp(source);
  if (crop) pipeline = pipeline.extract(crop);
  pipeline = floor
    ? pipeline.resize(384, 384)
    : pipeline.resize(512, 512, { fit: 'inside', withoutEnlargement: true });
  const quality = floor ? 64 : 82;
  const bytes = await pipeline
    .webp({ quality, alphaQuality: 100, effort: 6 })
    .toBuffer();
  if (bytes.length > (floor ? 12 : 24) * 1024)
    throw new Error(
      `Demo ${asset.id} exceeds its ${floor ? 12 : 24}KiB budget`,
    );
  const metadata = await sharp(bytes).metadata();
  /** @type {DemoArtProvenance} */
  const provenance = {
    dimensions_px: [metadata.width, metadata.height],
    source_dimensions_px: [sourceMetadata.width, sourceMetadata.height],
    ...(crop ? { crop_px: crop } : {}),
    transformation: floor
      ? `Independent uniformly lit generated maple color tile; proportional384px square WebP quality${quality}, maximum12KiB; no court markings, lighting or UI painted into the export`
      : `Generated backboard and rim only; ${crop ? 'recorded transparent crop and ' : ''}proportional resize up to512px, WebP quality${quality}, alphaQuality100, maximum24KiB; original alpha retained; no net, ball, text or court added`,
  };
  if (!floor) {
    const { data, info } = await sharp(bytes).ensureAlpha().raw().toBuffer({
      resolveWithObject: true,
    });
    let transparent = 0;
    let opaque = 0;
    for (let i = info.channels - 1; i < data.length; i += info.channels) {
      if (data[i] === 0) transparent++;
      if (data[i] >= 250) opaque++;
    }
    if (!metadata.hasAlpha || !transparent || !opaque)
      throw new Error(
        'Demo hoop must retain actual transparent and solid pixels',
      );
    const anchor = asset.rim_anchor_px;
    if (
      !anchor ||
      ![anchor.cx, anchor.cy, anchor.rx, anchor.ry].every(Number.isFinite) ||
      anchor.rx <= 0 ||
      anchor.ry <= 0
    )
      throw new Error('Demo hoop needs its measured source rim anchor');
    const scale = metadata.width / sourceWidth;
    const outputAnchor = {
      cx: (anchor.cx - (crop?.left ?? 0)) * scale,
      cy: (anchor.cy - (crop?.top ?? 0)) * scale,
      rx: anchor.rx * scale,
      ry: anchor.ry * scale,
    };
    if (
      outputAnchor.cx - outputAnchor.rx < 0 ||
      outputAnchor.cx + outputAnchor.rx > metadata.width ||
      outputAnchor.cy - outputAnchor.ry < 0 ||
      outputAnchor.cy + outputAnchor.ry > metadata.height
    )
      throw new Error('Measured demo rim is outside its exported image');
    const svgScale = 20 / outputAnchor.rx;
    Object.assign(provenance, {
      rim_anchor_px_source: anchor,
      rim_anchor_px_production: outputAnchor,
      placement_svg: {
        x: 300 - outputAnchor.cx * svgScale,
        y: 82 - outputAnchor.cy * svgScale,
        width: metadata.width * svgScale,
        height: metadata.height * svgScale,
      },
      alpha_pixels: {
        transparent,
        solid: opaque,
        total: info.width * info.height,
      },
    });
  }
  return { bytes, provenance };
}

export async function prepareDemoCourtAssets({ repositoryRoot, output }) {
  const recordBytes = await readFile(join(repositoryRoot, demoCourtRecord));
  const record = JSON.parse(recordBytes.toString('utf8'));
  if (record.tool !== 'image_gen.imagegen' || record.mode !== 'built-in')
    throw new Error(
      'Interactive court art must retain its built-in imagegen provenance',
    );
  if (
    record.assets.length !== 2 ||
    new Set(record.assets.map((asset) => asset.id)).size !== 2
  )
    throw new Error(
      'Interactive court art requires one independent floor and one hoop',
    );
  for (const asset of record.assets) {
    if (
      asset.id === 'hoop' &&
      (asset.rim_shape !== 'circle' ||
        asset.rim_anchor_px?.rx !== asset.rim_anchor_px?.ry)
    )
      throw new Error(
        'The true-overhead demo rim must retain a circular anchor',
      );
    const sourcePath = `website/assets/materials/${asset.source}`;
    const source = await readFile(join(repositoryRoot, sourcePath));
    const { bytes, provenance } = await encodeDemoCourtAsset(source, asset);
    await output(
      asset.id === 'maple' ? 'art/demo-maple-v2.webp' : 'art/demo-hoop-v2.webp',
      bytes,
      {
        source: sourcePath,
        source_sha256: digest(source),
        generation_record: demoCourtRecord,
        generation_record_sha256: digest(recordBytes),
        generated_with: record.tool,
        generation_mode: record.mode,
        ...provenance,
      },
    );
  }
}
