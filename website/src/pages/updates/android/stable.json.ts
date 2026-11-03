import { serializeAndroidUpdate } from '../../../data/android-update.ts';
import { release } from '../../../data/release.ts';

export function GET(): Response {
  return new Response(serializeAndroidUpdate(release), {
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'public, max-age=0, must-revalidate',
    },
  });
}
