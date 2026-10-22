import { defineConfig } from '@playwright/test';
import base from './playwright.config';

const chromium = base.projects!.find((project) => project.name === 'chromium');
if (!chromium) throw new Error('The WebGL suite requires the Chromium project');

export default defineConfig({
  ...base,
  grep: /@webgl/,
  workers: 1,
  projects: [
    {
      ...chromium,
      use: {
        ...chromium.use,
        launchOptions: {
          ...chromium.use?.launchOptions,
          // Keep full Chromium, but isolate SwiftShader to WebGL on CI. Using
          // it as the entire GL driver also routes browser compositing through
          // that driver, which is a different workload from scene lifecycle tests.
          args: process.env.CI
            ? [
                '--use-gl=angle',
                '--use-angle=swiftshader-webgl',
                '--enable-unsafe-swiftshader',
              ]
            : chromium.use?.launchOptions?.args,
        },
      },
    },
  ],
});
