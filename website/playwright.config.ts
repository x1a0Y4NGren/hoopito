import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  testMatch: [
    '**/site.spec.ts',
    '**/immersive-glass.spec.ts',
    '**/thin-glass.spec.ts',
    '**/scoring-polish.spec.ts',
    '**/experience-polish.spec.ts',
    '**/replay-polish.spec.ts',
    '**/download-community-polish.spec.ts',
    '**/chapter-rail.spec.ts',
    '**/chapter-rail-recovery.spec.ts',
    '**/chapter-liquid.spec.ts',
    '**/chapter-snap.spec.ts',
    '**/chapter-snap-recovery.spec.ts',
    '**/poster-story.spec.ts',
    '**/loading-navigation.spec.ts',
    '**/site-audit.spec.ts',
    '**/viewer-resilience.spec.ts',
    '**/court-continuity.spec.ts',
    '**/chapter-polish.spec.ts',
    '**/component-refinement.spec.ts',
    '**/visual-polish.spec.ts',
    '**/mobile-experience.spec.ts',
    '**/mobile-snap.spec.ts',
    '**/demo-court-art.spec.ts',
  ],
  fullyParallel: true,
  forbidOnly: Boolean(process.env.CI),
  retries: process.env.CI ? 1 : 0,
  workers: process.env.CI ? 1 : 3,
  // Software WebGL on shared CI runners needs bounded extra test time. The
  // website's eight-second initialization deadline is unchanged and still tested.
  timeout: process.env.CI ? 90_000 : 30_000,
  expect: { timeout: process.env.CI ? 20_000 : 10_000 },
  outputDir: process.env.PLAYWRIGHT_OUTPUT_DIR ?? './output/playwright/results',
  reporter: [
    ['list'],
    [
      'html',
      {
        outputFolder:
          process.env.PLAYWRIGHT_HTML_OUTPUT_DIR ??
          './output/playwright/report',
        open: 'never',
      },
    ],
    [
      'json',
      {
        outputFile:
          process.env.PLAYWRIGHT_JSON_OUTPUT_FILE ??
          './output/playwright/results.json',
      },
    ],
  ],
  use: {
    baseURL: 'http://127.0.0.1:4321',
    viewport: { width: 1440, height: 900 },
    reducedMotion: 'no-preference',
    // Continuous trace snapshots/screencasts add protocol and GPU readback
    // work during the very gestures and frames under measurement. Retain
    // action/source traces and the separate failure screenshot without that
    // capture workload changing native wheel delivery or render cadence.
    trace: {
      mode: 'retain-on-failure',
      screenshots: false,
      snapshots: false,
      sources: true,
    },
    screenshot: 'only-on-failure',
  },
  projects: [
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        // New headless uses the full Chrome rendering pipeline, including real GPU support locally.
        channel: 'chromium',
        viewport: { width: 1440, height: 900 },
        launchOptions: {
          // Only WebGL needs the software driver. Forcing browser compositing
          // through it also slows CSS glass/scroll tests which never draw 3D.
          args: process.env.CI
            ? [
                '--use-gl=angle',
                '--use-angle=swiftshader-webgl',
                '--enable-unsafe-swiftshader',
              ]
            : ['--enable-gpu'],
        },
      },
    },
    {
      name: 'firefox',
      use: {
        ...devices['Desktop Firefox'],
        viewport: { width: 1440, height: 900 },
      },
    },
    {
      name: 'webkit',
      use: {
        ...devices['Desktop Safari'],
        viewport: { width: 1440, height: 900 },
        // Match the other engines' baseline raster workload. Safari's device
        // preset silently defaults to 2x (four times the pixels); Retina/DPR
        // checks create explicit contexts independently of this baseline.
        deviceScaleFactor: 1,
      },
    },
  ],
  webServer: {
    command: 'npm run preview -- --port 4321',
    url: 'http://127.0.0.1:4321',
    reuseExistingServer: !process.env.CI,
    timeout: 60_000,
  },
});
