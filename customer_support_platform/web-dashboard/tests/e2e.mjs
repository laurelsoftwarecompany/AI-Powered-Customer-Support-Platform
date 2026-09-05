import { chromium } from "playwright-core";
import { spawn } from "child_process";
import http from "http";
import path from "path";
import fs from "fs";

const PORT = 3009;
const BASE_URL = `http://localhost:${PORT}`;

// Locate installed Chromium from Playwright cache
const localAppData = process.env.LOCALAPPDATA || "";
const chromePath = path.join(localAppData, "ms-playwright", "chromium-1243", "chrome-win64", "chrome.exe");

async function waitForServer(url, timeoutMs = 30000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    try {
      await new Promise((resolve, reject) => {
        const req = http.get(url, (res) => {
          if (res.statusCode < 500) resolve(true);
          else reject(new Error(`Status ${res.statusCode}`));
        });
        req.on("error", reject);
        req.end();
      });
      return true;
    } catch {
      await new Promise((r) => setTimeout(r, 500));
    }
  }
  throw new Error(`Server at ${url} did not respond within ${timeoutMs}ms`);
}

async function run() {
  console.log("=== STARTING WEB DASHBOARD E2E PLAYWRIGHT TESTS ===");

  console.log(`Starting Next.js production server on port ${PORT}...`);
  const server = spawn("npx", ["next", "start", "-p", String(PORT)], {
    stdio: "pipe",
    shell: true,
    env: { ...process.env, PORT: String(PORT) },
  });

  server.stdout.on("data", (d) => {
    const text = d.toString();
    if (text.includes("Ready") || text.includes("started")) {
      console.log(`[Next.js Server] ${text.trim()}`);
    }
  });

  server.stderr.on("data", (d) => {
    // console.error(`[Server Err] ${d}`);
  });

  let browser;
  try {
    await waitForServer(BASE_URL);
    console.log(`✓ Next.js server is online at ${BASE_URL}`);

    console.log(`Launching Chromium from: ${chromePath}`);
    browser = await chromium.launch({
      executablePath: chromePath,
      headless: true,
      args: ["--no-sandbox", "--disable-setuid-sandbox"],
    });

    const context = await browser.newContext({
      viewport: { width: 1280, height: 800 },
    });
    const page = await context.newPage();

    // 1. Visit Login Page
    console.log("TEST 1: Verify Login Screen Rendering & Structure...");
    const response = await page.goto(`${BASE_URL}/login`, { waitUntil: "domcontentloaded" });
    if (response.status() !== 200) {
      throw new Error(`Expected 200 from /login, got ${response.status()}`);
    }

    const title = await page.title();
    console.log(`✓ Page Title: ${title}`);

    // Check for email and password inputs
    const emailInput = page.locator('input[type="email"]');
    const passwordInput = page.locator('input[type="password"]');
    const submitBtn = page.locator('button[type="submit"]');

    await emailInput.waitFor({ state: "visible", timeout: 5000 });
    await passwordInput.waitFor({ state: "visible", timeout: 5000 });
    await submitBtn.waitFor({ state: "visible", timeout: 5000 });
    console.log("✓ Login form elements (email, password, submit) are visible");

    // 2. Test Invalid Form Submission
    console.log("TEST 2: Attempt Login with Invalid Credentials...");
    await emailInput.fill("invalid_user@test.com");
    await passwordInput.fill("WrongPassword123!");
    await submitBtn.click();

    // Should stay on login page and not throw crash
    await page.waitForTimeout(1000);
    const currentUrl = page.url();
    if (!currentUrl.includes("/login")) {
      throw new Error(`Expected to remain on /login, navigated to: ${currentUrl}`);
    }
    console.log("✓ Invalid login was safely rejected without unhandled crash");

    // 3. Test Responsive Viewports
    console.log("TEST 3: Test Responsive Layout on Mobile Viewport (375x667)...");
    await page.setViewportSize({ width: 375, height: 667 });
    await page.waitForTimeout(500);
    const mobileFormVisible = await emailInput.isVisible();
    if (!mobileFormVisible) {
      throw new Error("Login form not visible on mobile viewport");
    }
    console.log("✓ Mobile viewport rendered form correctly");

    console.log("\n==================================================");
    console.log("ALL WEB DASHBOARD E2E PLAYWRIGHT TESTS PASSED!");
    console.log("==================================================");
  } finally {
    if (browser) await browser.close();
    server.kill("SIGTERM");
    try {
      spawn("taskkill", ["/pid", String(server.pid), "/f", "/t"]);
    } catch {}
  }
  process.exit(0);
}

run().catch((err) => {
  console.error("E2E Test Failure:", err);
  process.exit(1);
});
