import * as THREE from 'three';
import { courtTextures } from '../data/court-materials';

type Owner = <T extends { dispose(): void }>(resource: T) => T;

/** Fetches abort with scene eligibility; decoded bitmaps share the scene's lifetime. */
export async function loadCourtTextures(signal: AbortSignal, own: Owner) {
  const entries = await Promise.all(
    Object.entries(courtTextures).map(async ([name, url]) => {
      const response = await fetch(url, { signal });
      if (!response.ok)
        throw new Error(`Court material could not load: ${name}`);
      const bitmap = await createImageBitmap(await response.blob(), {
        imageOrientation: 'flipY',
        colorSpaceConversion: 'none',
      });
      if (signal.aborted) {
        bitmap.close();
        throw new DOMException('Scene aborted', 'AbortError');
      }
      own({ dispose: () => bitmap.close() });
      const texture = own(new THREE.Texture(bitmap));
      texture.flipY = false;
      texture.colorSpace =
        name === 'glass' ? THREE.NoColorSpace : THREE.SRGBColorSpace;
      texture.wrapS = texture.wrapT = THREE.RepeatWrapping;
      texture.needsUpdate = true;
      return [name, texture] as const;
    }),
  );
  return Object.fromEntries(entries) as Record<
    keyof typeof courtTextures,
    THREE.Texture
  >;
}
