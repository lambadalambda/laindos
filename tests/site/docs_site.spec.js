const { expect, test } = require("@playwright/test");

function watchErrors(page) {
  const errors = [];
  page.on("pageerror", error => errors.push(error.message));
  page.on("console", message => {
    const text = message.text();
    if (message.type() === "error" && !text.startsWith("Failed to load resource: net::ERR_")) errors.push(text);
  });
  return errors;
}

async function pageMetrics(page) {
  return page.evaluate(() => {
    const offenders = Array.from(document.querySelectorAll("body *"))
      .map(el => {
        const rect = el.getBoundingClientRect();
        return {
          tag: el.tagName,
          className: String(el.className || ""),
          text: String(el.textContent || "").replace(/\s+/g, " ").slice(0, 80),
          left: Math.round(rect.left),
          right: Math.round(rect.right),
          width: Math.round(rect.width),
          clientWidth: el.clientWidth,
          scrollWidth: el.scrollWidth,
        };
      })
      .filter(item => item.right > window.innerWidth + 1 || item.scrollWidth > item.clientWidth + 1)
      .slice(0, 12);
    return {
      bodyScrollWidth: document.body.scrollWidth,
      docScrollWidth: document.documentElement.scrollWidth,
      innerWidth: window.innerWidth,
      offenders,
    };
  });
}

async function expectNoHorizontalOverflow(page) {
  const metrics = await pageMetrics(page);
  expect(metrics.docScrollWidth, JSON.stringify(metrics.offenders, null, 2)).toBeLessThanOrEqual(metrics.innerWidth + 1);
  expect(metrics.bodyScrollWidth, JSON.stringify(metrics.offenders, null, 2)).toBeLessThanOrEqual(metrics.innerWidth + 1);
}

async function installV86Stub(page) {
  await page.route("**/build/libv86.js", route => route.fulfill({
    contentType: "text/javascript",
    body: `
      window.__v86Options = [];
      window.V86 = class {
        constructor(options) {
          this.listeners = new Map();
          window.__v86Options.push(options);
          const text = options.screen_container && options.screen_container.querySelector(':scope > div');
          const canvas = options.screen_container && options.screen_container.querySelector(':scope > canvas');
          if (canvas) canvas.style.display = 'none';
          if (text) {
            text.textContent = Array.from({ length: 25 }, (_, y) =>
              String(y + 1).padStart(2, '0') + ' LainDOS '.padEnd(78, '.')
            ).join('\\n');
          }
          setTimeout(() => this.emit('emulator-started'), 0);
        }
        add_listener(name, callback) {
          if (!this.listeners.has(name)) this.listeners.set(name, []);
          this.listeners.get(name).push(callback);
        }
        emit(name, value) {
          for (const callback of this.listeners.get(name) || []) callback(value);
        }
        destroy() {}
      };
    `,
  }));
}

test.describe("docs site static pages", () => {
  for (const [file, heading] of [
    ["dosapi.html", "The DOS API"],
    ["memory.html", "Memory"],
    ["programs.html", "Programs"],
  ]) {
    test(`${file} hydrates with content`, async ({ page }) => {
      const errors = watchErrors(page);
      await installV86Stub(page);
      await page.goto(`/${file}`, { waitUntil: "networkidle" });
      await expect(page.locator("h1")).toContainText(heading);
      await expect.poll(async () => (await page.locator("#root").innerText()).length).toBeGreaterThan(600);
      expect(errors).toEqual([]);
    });
  }
});

test.describe("docs site layout", () => {
  test("run.html fits a 1440px viewport", async ({ page }) => {
    const errors = watchErrors(page);
    await installV86Stub(page);
    await page.goto("/run.html", { waitUntil: "networkidle" });
    await expectNoHorizontalOverflow(page);
    expect(errors).toEqual([]);
  });

  test("tests.html fits a 1440px viewport", async ({ page }) => {
    const errors = watchErrors(page);
    await page.goto("/tests.html", { waitUntil: "networkidle" });
    await expectNoHorizontalOverflow(page);
    expect(errors).toEqual([]);
  });
});

test.describe("docs site emulator", () => {
  test("enables v86 sound and leaves text room vertically", async ({ page }) => {
    const errors = watchErrors(page);
    await installV86Stub(page);
    await page.goto("/run.html", { waitUntil: "networkidle" });
    await page.getByRole("button", { name: /power on/i }).click();
    await page.waitForFunction(() => window.__v86Options && window.__v86Options.length === 1);

    const emulator = await page.evaluate(() => {
      const text = document.querySelector(".v86-screen > div");
      const style = text && getComputedStyle(text);
      const options = window.__v86Options[0];
      return {
        disableSpeaker: options.disable_speaker,
        fontSize: style ? parseFloat(style.fontSize) : 0,
        lineHeight: style ? parseFloat(style.lineHeight) : 0,
      };
    });

    expect(emulator.disableSpeaker).toBe(false);
    expect(emulator.lineHeight).toBeGreaterThanOrEqual(emulator.fontSize * 1.15);
    expect(errors).toEqual([]);
  });
});
