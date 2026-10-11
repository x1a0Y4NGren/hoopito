import type { APIRoute } from 'astro';

export const GET: APIRoute = ({ site }) => {
  const publicBuild =
    process.env.VERCEL_ENV === 'production' && !!process.env.SITE_URL;
  const urls =
    publicBuild && site ? ['/', '/en/', '/privacy/', '/en/privacy/'] : [];
  const xml = `<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">${urls.map((path) => `<url><loc>${new URL(path, site)}</loc></url>`).join('')}</urlset>`;
  return new Response(xml, {
    headers: { 'Content-Type': 'application/xml; charset=utf-8' },
  });
};
