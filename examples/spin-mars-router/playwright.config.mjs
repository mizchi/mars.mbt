import { defineConfig } from "@playwright/test";

const baseURL = "http://127.0.0.1:3101";

export default defineConfig({
  testDir: "./e2e",
  testMatch: "**/*.spec.ts",
  fullyParallel: false,
  workers: 1,
  timeout: 30_000,
  expect: {
    timeout: 10_000,
  },
  use: {
    baseURL,
  },
  webServer: {
    command:
      "sh -lc 'moon build --target wasm --release impl && moon-component componentize _build/wasm/release/build/impl/impl.wasm --wit-dir wit -o component.wasm && spin up --listen 127.0.0.1:3101'",
    url: `${baseURL}/health`,
    timeout: 180_000,
    reuseExistingServer: false,
  },
});
