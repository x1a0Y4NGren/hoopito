import { defineConfig } from 'astro/config';

const publicOrigin = process.env.SITE_URL;
const site =
  publicOrigin ||
  (process.env.VERCEL_URL ? `https://${process.env.VERCEL_URL}` : undefined);
if (process.env.VERCEL_ENV === 'production' && !publicOrigin) {
  throw new Error(
    'Set SITE_URL to the verified public origin before a production build.',
  );
}

export default defineConfig({
  site: site || undefined,
  output: 'static',
  trailingSlash: 'always',
  i18n: {
    defaultLocale: 'zh',
    locales: ['zh', 'en'],
    routing: { prefixDefaultLocale: false },
  },
  vite: {
    build: {
      rollupOptions: {
        output: {
          manualChunks: (id) =>
            id.replaceAll('\\', '/').includes('/node_modules/three/')
              ? 'court-engine'
              : undefined,
        },
      },
    },
  },
});
