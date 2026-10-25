import type { APIRoute } from 'astro';

export const GET: APIRoute = ({ site }) => {
  const publicBuild =
    process.env.VERCEL_ENV === 'production' && !!process.env.SITE_URL;
  const body =
    publicBuild && site
      ? `User-agent: *\nAllow: /\nSitemap: ${new URL('/sitemap.xml', site)}\n`
      : 'User-agent: *\nDisallow: /\n';
  return new Response(body, {
    headers: { 'Content-Type': 'text/plain; charset=utf-8' },
  });
};
