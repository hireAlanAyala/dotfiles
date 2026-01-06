#!/usr/bin/env node

const CDP = require('chrome-remote-interface');

const PORT = process.env.CDP_PORT || 9222;

async function getOrderedTabs() {
  const browser = await CDP({ port: PORT });
  const { Target } = browser;

  const { targetInfos } = await Target.getTargets();
  const pages = targetInfos.filter(t => t.type === 'page');

  const tabsWithWindows = await Promise.all(
    pages.map(async (target) => {
      try {
        const client = await CDP({ target: target.targetId, port: PORT });
        const { windowId } = await client.Browser.getWindowForTarget();
        await client.close();
        return { ...target, windowId };
      } catch {
        return { ...target, windowId: 0 };
      }
    })
  );

  await browser.close();

  return tabsWithWindows.sort((a, b) => {
    if (a.windowId !== b.windowId) return a.windowId - b.windowId;
    return a.targetId.localeCompare(b.targetId);
  });
}

async function main() {
  try {
    const tabs = await getOrderedTabs();
    console.log(JSON.stringify(tabs));
  } catch (err) {
    console.error(JSON.stringify({ error: err.message }));
    process.exit(1);
  }
}

main();
