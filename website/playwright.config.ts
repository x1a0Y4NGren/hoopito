import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  testMatch: [
    '**/site.spec.ts',
    '**/loading-navigation.spec.ts',
    '**/site-audit.spec.ts',
    '**/viewer-resilience.spec.ts',
    '**/court-continuity.spec.ts',
    '**/chapter-polish.spec.ts',
  ],
  fullyParallel: true,
  forbidOnly: Boolean(process.env.CI),
  retries: process.env.CI ? 1 : 0,
  workers: process.env.CI ? 2 : 3,
  // Software WebGL on shared CI runners needs bounded extra test time. The
  // website's eight-second initialization deadline is unchanged and still tested.
  timeout: process.env.CI ? 90_000 : 30_000,
  expect: { timeout: process.env.CI ? 20_000 : 10_000 },
  outputDir: './output/playwright/results',
  reporter: [
    ['list'],
    ['html', { outputFolder: './output/playwright/report', open: 'never' }],
  ],
  use: {
    baseURL: 'http://127.0.0.1:4321',
    viewport: { width: 1440, height: 900 },
    reducedMotion: 'no-preference',
    trace: 'retain-on-failure',
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
          args: process.env.CI
            ? ['--use-angle=swiftshader', '--enable-unsafe-swiftshader']
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
