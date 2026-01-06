#!/usr/bin/env node

const fs = require('fs');

const METADATA_PATH = process.argv[2] || '/tmp/network-metadata.json';

// Thresholds for flagging issues
const THRESHOLDS = {
  slowRequest: 1000,      // ms
  slowTTFB: 500,          // ms
  slowDNS: 100,           // ms
  slowSSL: 200,           // ms
  highBlocked: 100,       // ms
  largePayload: 500000,   // bytes (500KB)
  largeImage: 200000,     // bytes (200KB)
  lateDiscovery: 2000,    // ms from page start
  duplicateThreshold: 2,  // same URL fetched N+ times
};

// ANSI colors
const c = {
  reset: '\x1b[0m',
  bold: '\x1b[1m',
  dim: '\x1b[2m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m',
  white: '\x1b[37m',
};

function loadData() {
  try {
    const content = fs.readFileSync(METADATA_PATH, 'utf-8');
    return JSON.parse(content);
  } catch (err) {
    console.error(`${c.red}Error loading ${METADATA_PATH}: ${err.message}${c.reset}`);
    process.exit(1);
  }
}

function formatBytes(bytes) {
  if (bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
}

function formatMs(ms) {
  if (ms < 0) return '-';
  if (ms < 1000) return `${Math.round(ms)}ms`;
  return `${(ms / 1000).toFixed(2)}s`;
}

function truncateUrl(url, maxLen = 60) {
  if (url.length <= maxLen) return url;
  return url.slice(0, maxLen - 3) + '...';
}

function printHeader(title) {
  console.log(`\n${c.bold}${c.cyan}═══ ${title} ${'═'.repeat(Math.max(0, 60 - title.length))}${c.reset}\n`);
}

function printSubHeader(title) {
  console.log(`${c.bold}${c.white}── ${title}${c.reset}`);
}

// ============================================================================
// Analysis Functions
// ============================================================================

function analyzeSummary(entries) {
  printHeader('SUMMARY');

  const totalRequests = entries.length;
  const totalTransfer = entries.reduce((sum, e) => sum + (e.transferSize || 0), 0);
  const totalContent = entries.reduce((sum, e) => sum + (e.contentSize || 0), 0);
  const cachedCount = entries.filter(e => e.cached).length;
  const errorCount = entries.filter(e => e.status >= 400 || e.error).length;
  const failedCount = entries.filter(e => e.error).length;

  const times = entries.map(e => e.relativeEnd || 0).filter(t => t > 0);
  const pageLoadTime = times.length > 0 ? Math.max(...times) : 0;

  const avgTime = entries.reduce((sum, e) => sum + (e.time || 0), 0) / totalRequests;

  // Group by type
  const byType = {};
  entries.forEach(e => {
    const type = e.type || 'Other';
    byType[type] = (byType[type] || 0) + 1;
  });

  console.log(`  Total Requests:    ${c.bold}${totalRequests}${c.reset}`);
  console.log(`  Total Transfer:    ${c.bold}${formatBytes(totalTransfer)}${c.reset} (${formatBytes(totalContent)} uncompressed)`);
  console.log(`  Page Load Time:    ${c.bold}${formatMs(pageLoadTime)}${c.reset}`);
  console.log(`  Avg Request Time:  ${formatMs(avgTime)}`);
  console.log(`  Cache Hit Rate:    ${cachedCount}/${totalRequests} (${Math.round(cachedCount/totalRequests*100)}%)`);

  if (errorCount > 0) {
    console.log(`  ${c.red}Errors:            ${errorCount} (${failedCount} failed)${c.reset}`);
  }

  console.log(`\n  ${c.dim}By Type:${c.reset}`);
  Object.entries(byType)
    .sort((a, b) => b[1] - a[1])
    .forEach(([type, count]) => {
      console.log(`    ${type}: ${count}`);
    });
}

function analyzePerformance(entries) {
  printHeader('PERFORMANCE ISSUES');

  // Slow requests
  const slowRequests = entries
    .filter(e => e.time > THRESHOLDS.slowRequest)
    .sort((a, b) => b.time - a.time)
    .slice(0, 10);

  if (slowRequests.length > 0) {
    printSubHeader(`Slow Requests (>${formatMs(THRESHOLDS.slowRequest)})`);
    slowRequests.forEach(e => {
      console.log(`  ${c.yellow}${formatMs(e.time).padStart(8)}${c.reset}  ${e.status || '---'}  ${truncateUrl(e.url)}`);
    });
    console.log();
  }

  // Slow TTFB
  const slowTTFB = entries
    .filter(e => e.timings?.wait > THRESHOLDS.slowTTFB)
    .sort((a, b) => (b.timings?.wait || 0) - (a.timings?.wait || 0))
    .slice(0, 5);

  if (slowTTFB.length > 0) {
    printSubHeader(`Slow TTFB (>${formatMs(THRESHOLDS.slowTTFB)})`);
    slowTTFB.forEach(e => {
      console.log(`  ${c.yellow}${formatMs(e.timings.wait).padStart(8)}${c.reset}  ${truncateUrl(e.url)}`);
    });
    console.log();
  }

  // Slow DNS
  const slowDNS = entries
    .filter(e => e.timings?.dns > THRESHOLDS.slowDNS)
    .sort((a, b) => (b.timings?.dns || 0) - (a.timings?.dns || 0))
    .slice(0, 5);

  if (slowDNS.length > 0) {
    printSubHeader(`Slow DNS (>${formatMs(THRESHOLDS.slowDNS)})`);
    slowDNS.forEach(e => {
      const host = new URL(e.url).hostname;
      console.log(`  ${c.yellow}${formatMs(e.timings.dns).padStart(8)}${c.reset}  ${host}`);
    });
    console.log();
  }

  // Large payloads
  const largePayloads = entries
    .filter(e => e.transferSize > THRESHOLDS.largePayload)
    .sort((a, b) => b.transferSize - a.transferSize)
    .slice(0, 10);

  if (largePayloads.length > 0) {
    printSubHeader(`Large Payloads (>${formatBytes(THRESHOLDS.largePayload)})`);
    largePayloads.forEach(e => {
      const ratio = e.contentSize > 0 ? (e.transferSize / e.contentSize).toFixed(2) : '-';
      console.log(`  ${c.yellow}${formatBytes(e.transferSize).padStart(10)}${c.reset}  ${e.mimeType?.split('/')[1] || '?'}  ${truncateUrl(e.url)}`);
    });
    console.log();
  }

  // Large images specifically
  const largeImages = entries
    .filter(e => e.mimeType?.startsWith('image/') && e.transferSize > THRESHOLDS.largeImage)
    .sort((a, b) => b.transferSize - a.transferSize)
    .slice(0, 5);

  if (largeImages.length > 0) {
    printSubHeader(`Large Images (>${formatBytes(THRESHOLDS.largeImage)})`);
    largeImages.forEach(e => {
      console.log(`  ${c.yellow}${formatBytes(e.transferSize).padStart(10)}${c.reset}  ${truncateUrl(e.url)}`);
    });
    console.log();
  }

  if (slowRequests.length === 0 && slowTTFB.length === 0 && largePayloads.length === 0) {
    console.log(`  ${c.green}No major performance issues detected${c.reset}`);
  }
}

function analyzeCaching(entries) {
  printHeader('CACHING ANALYSIS');

  // Missing cache headers on static assets
  const staticTypes = ['Script', 'Stylesheet', 'Image', 'Font'];
  const missingCacheHeaders = entries.filter(e => {
    if (!staticTypes.includes(e.type)) return false;
    if (e.cached) return false;
    const cc = e.headers?.['cache-control'];
    return !cc || cc.includes('no-cache') || cc.includes('no-store');
  });

  if (missingCacheHeaders.length > 0) {
    printSubHeader('Missing/Bad Cache Headers on Static Assets');
    missingCacheHeaders.slice(0, 10).forEach(e => {
      const cc = e.headers?.['cache-control'] || 'none';
      console.log(`  ${c.yellow}${cc.padEnd(20).slice(0, 20)}${c.reset}  ${truncateUrl(e.url)}`);
    });
    if (missingCacheHeaders.length > 10) {
      console.log(`  ${c.dim}... and ${missingCacheHeaders.length - 10} more${c.reset}`);
    }
    console.log();
  }

  // CDN cache analysis
  const cdnEntries = entries.filter(e => e.headers?.['cf-cache-status']);
  if (cdnEntries.length > 0) {
    printSubHeader('CDN Cache Status (Cloudflare)');
    const byStatus = {};
    cdnEntries.forEach(e => {
      const status = e.headers['cf-cache-status'];
      byStatus[status] = (byStatus[status] || 0) + 1;
    });
    Object.entries(byStatus)
      .sort((a, b) => b[1] - a[1])
      .forEach(([status, count]) => {
        const color = status === 'HIT' ? c.green : status === 'MISS' ? c.yellow : c.white;
        console.log(`  ${color}${status.padEnd(10)}${c.reset} ${count}`);
      });
    console.log();
  }

  // Duplicate requests
  const urlCounts = {};
  entries.forEach(e => {
    // Normalize URL (remove query params for comparison)
    const url = e.url.split('?')[0];
    urlCounts[url] = (urlCounts[url] || 0) + 1;
  });

  const duplicates = Object.entries(urlCounts)
    .filter(([, count]) => count >= THRESHOLDS.duplicateThreshold)
    .sort((a, b) => b[1] - a[1]);

  if (duplicates.length > 0) {
    printSubHeader('Duplicate Requests');
    duplicates.slice(0, 10).forEach(([url, count]) => {
      console.log(`  ${c.yellow}${count}x${c.reset}  ${truncateUrl(url)}`);
    });
    console.log();
  }

  if (missingCacheHeaders.length === 0 && duplicates.length === 0) {
    console.log(`  ${c.green}Caching looks healthy${c.reset}`);
  }
}

function analyzeErrors(entries) {
  const errors = entries.filter(e => e.status >= 400 || e.error);

  if (errors.length === 0) return;

  printHeader('ERRORS');

  errors.forEach(e => {
    const status = e.error ? `${c.red}FAIL${c.reset}` :
                   e.status >= 500 ? `${c.red}${e.status}${c.reset}` :
                   `${c.yellow}${e.status}${c.reset}`;
    const msg = e.error || '';
    console.log(`  ${status.padEnd(14)}  ${truncateUrl(e.url)} ${c.dim}${msg}${c.reset}`);
  });
}

function analyzeWaterfall(entries) {
  printHeader('WATERFALL ANALYSIS');

  // Sort by start time
  const sorted = [...entries]
    .filter(e => e.relativeStart !== undefined)
    .sort((a, b) => a.relativeStart - b.relativeStart);

  if (sorted.length === 0) {
    console.log(`  ${c.dim}No timing data available${c.reset}`);
    return;
  }

  // Calculate parallelization score
  // For each point in time, count concurrent requests
  const events = [];
  sorted.forEach(e => {
    events.push({ time: e.relativeStart, delta: 1 });
    events.push({ time: e.relativeEnd || e.relativeStart + (e.time || 0), delta: -1 });
  });
  events.sort((a, b) => a.time - b.time);

  let concurrent = 0;
  let maxConcurrent = 0;
  let totalConcurrentTime = 0;
  let lastTime = 0;

  events.forEach(ev => {
    if (concurrent > 1) {
      totalConcurrentTime += ev.time - lastTime;
    }
    concurrent += ev.delta;
    maxConcurrent = Math.max(maxConcurrent, concurrent);
    lastTime = ev.time;
  });

  const totalTime = sorted.length > 0 ?
    Math.max(...sorted.map(e => e.relativeEnd || 0)) - sorted[0].relativeStart : 0;
  const parallelizationScore = totalTime > 0 ?
    Math.round(totalConcurrentTime / totalTime * 100) : 0;

  console.log(`  Max Concurrent:       ${c.bold}${maxConcurrent}${c.reset} requests`);
  console.log(`  Parallelization:      ${c.bold}${parallelizationScore}%${c.reset} of time with concurrent requests`);
  console.log();

  // Late discoveries
  const lateDiscoveries = sorted
    .filter(e => e.relativeStart > THRESHOLDS.lateDiscovery)
    .slice(0, 10);

  if (lateDiscoveries.length > 0) {
    printSubHeader(`Late Discoveries (>${formatMs(THRESHOLDS.lateDiscovery)} after page start)`);
    lateDiscoveries.forEach(e => {
      const initiator = e.initiator?.type || '?';
      console.log(`  ${c.yellow}${formatMs(e.relativeStart).padStart(8)}${c.reset}  [${initiator}]  ${truncateUrl(e.url)}`);
    });
    console.log();
  }

  // High blocked time (queuing)
  const queued = sorted
    .filter(e => e.timings?.blocked > THRESHOLDS.highBlocked)
    .sort((a, b) => (b.timings?.blocked || 0) - (a.timings?.blocked || 0))
    .slice(0, 5);

  if (queued.length > 0) {
    printSubHeader(`Connection Queuing (>${formatMs(THRESHOLDS.highBlocked)} blocked)`);
    queued.forEach(e => {
      console.log(`  ${c.yellow}${formatMs(e.timings.blocked).padStart(8)}${c.reset}  ${e.httpVersion || '?'}  ${truncateUrl(e.url)}`);
    });
    console.log();
  }

  // Dependency chains (find requests triggered by scripts)
  const scriptInitiated = sorted.filter(e => e.initiator?.type === 'script');
  if (scriptInitiated.length > 0) {
    printSubHeader('Script-Initiated Requests');
    const byInitiator = {};
    scriptInitiated.forEach(e => {
      const init = e.initiator?.url || 'unknown';
      if (!byInitiator[init]) byInitiator[init] = [];
      byInitiator[init].push(e);
    });

    Object.entries(byInitiator)
      .sort((a, b) => b[1].length - a[1].length)
      .slice(0, 5)
      .forEach(([initiator, reqs]) => {
        console.log(`  ${c.dim}${truncateUrl(initiator, 50)}${c.reset}`);
        console.log(`    → ${reqs.length} requests (avg start: ${formatMs(reqs.reduce((s, r) => s + r.relativeStart, 0) / reqs.length)})`);
      });
    console.log();
  }

  // HTTP/1.1 usage
  const http1 = sorted.filter(e => e.httpVersion === 'http/1.1' || e.httpVersion === 'HTTP/1.1');
  if (http1.length > 0) {
    printSubHeader('HTTP/1.1 Requests (may cause queuing)');
    const hosts = [...new Set(http1.map(e => new URL(e.url).hostname))];
    hosts.slice(0, 5).forEach(host => {
      const count = http1.filter(e => e.url.includes(host)).length;
      console.log(`  ${c.yellow}${count}${c.reset} requests to ${host}`);
    });
    console.log();
  }
}

function printRecommendations(entries) {
  printHeader('RECOMMENDATIONS');

  const recommendations = [];

  // Check for issues and add recommendations
  const slowRequests = entries.filter(e => e.time > THRESHOLDS.slowRequest);
  if (slowRequests.length > 3) {
    recommendations.push('Consider optimizing slow endpoints or adding caching');
  }

  const slowTTFB = entries.filter(e => e.timings?.wait > THRESHOLDS.slowTTFB);
  if (slowTTFB.length > 0) {
    recommendations.push('High TTFB detected - check server response times, consider edge caching');
  }

  const largeImages = entries.filter(e =>
    e.mimeType?.startsWith('image/') && e.transferSize > THRESHOLDS.largeImage
  );
  if (largeImages.length > 0) {
    recommendations.push('Compress/resize large images, consider WebP/AVIF format');
  }

  const missingCache = entries.filter(e => {
    const staticTypes = ['Script', 'Stylesheet', 'Image', 'Font'];
    if (!staticTypes.includes(e.type)) return false;
    const cc = e.headers?.['cache-control'];
    return !cc || cc.includes('no-cache');
  });
  if (missingCache.length > 5) {
    recommendations.push('Add Cache-Control headers to static assets');
  }

  const duplicates = {};
  entries.forEach(e => {
    const url = e.url.split('?')[0];
    duplicates[url] = (duplicates[url] || 0) + 1;
  });
  if (Object.values(duplicates).some(c => c >= 3)) {
    recommendations.push('Eliminate duplicate requests - check for redundant fetches');
  }

  const http1 = entries.filter(e => e.httpVersion === 'http/1.1');
  if (http1.length > entries.length * 0.3) {
    recommendations.push('Upgrade to HTTP/2 to improve parallelization');
  }

  const lateDiscoveries = entries.filter(e => e.relativeStart > THRESHOLDS.lateDiscovery);
  if (lateDiscoveries.length > 5) {
    recommendations.push('Preload critical resources, reduce dependency chains');
  }

  const highBlocked = entries.filter(e => e.timings?.blocked > THRESHOLDS.highBlocked);
  if (highBlocked.length > 3) {
    recommendations.push('Reduce request queuing - fewer requests or HTTP/2');
  }

  if (recommendations.length === 0) {
    console.log(`  ${c.green}✓ No critical issues found${c.reset}`);
  } else {
    recommendations.forEach((rec, i) => {
      console.log(`  ${c.yellow}${i + 1}.${c.reset} ${rec}`);
    });
  }

  console.log();
}

// ============================================================================
// Main
// ============================================================================

function main() {
  const entries = loadData();

  if (entries.length === 0) {
    console.log(`${c.yellow}No network data found in ${METADATA_PATH}${c.reset}`);
    console.log('Start a capture with <leader>bdn first');
    process.exit(0);
  }

  console.log(`${c.bold}${c.cyan}`);
  console.log('╔══════════════════════════════════════════════════════════════════╗');
  console.log('║                    NETWORK DIAGNOSIS REPORT                      ║');
  console.log('╚══════════════════════════════════════════════════════════════════╝');
  console.log(c.reset);

  analyzeSummary(entries);
  analyzePerformance(entries);
  analyzeCaching(entries);
  analyzeErrors(entries);
  analyzeWaterfall(entries);
  printRecommendations(entries);
}

main();
