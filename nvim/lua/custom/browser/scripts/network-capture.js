#!/usr/bin/env node

const CDP = require('chrome-remote-interface');
const fs = require('fs');

const LOG_PATH = '/tmp/network-capture.json';
const METADATA_PATH = '/tmp/network-metadata.json';
const PORT = process.env.CDP_PORT || 9222;

const targetId = process.argv[2];

if (!targetId) {
  console.error('Usage: network-capture.js <targetId>');
  process.exit(1);
}

let rawEntries = [];
let metadataEntries = [];
let pendingRequests = new Map(); // Track requests awaiting response/finish
let writeTimeout;

function debouncedWrite() {
  clearTimeout(writeTimeout);
  writeTimeout = setTimeout(() => {
    fs.writeFileSync(LOG_PATH, JSON.stringify(rawEntries, null, 2));
    fs.writeFileSync(METADATA_PATH, JSON.stringify(metadataEntries, null, 2));
  }, 100);
}

function clearLog() {
  rawEntries = [];
  metadataEntries = [];
  pendingRequests.clear();
  fs.writeFileSync(LOG_PATH, '[]');
  fs.writeFileSync(METADATA_PATH, '[]');
}

// Convert CDP timing to HAR-style timing breakdown (all in ms)
function computeTimings(timing) {
  if (!timing) return null;

  const toMs = (start, end) => {
    if (start < 0 || end < 0) return -1;
    return Math.round((end - start) * 1000) / 1000;
  };

  // requestTime is the base timestamp in seconds
  const blocked = timing.dnsStart > 0 ? toMs(0, timing.dnsStart) : -1;
  const dns = toMs(timing.dnsStart, timing.dnsEnd);
  const connect = toMs(timing.connectStart, timing.connectEnd);
  const ssl = toMs(timing.sslStart, timing.sslEnd);
  const send = toMs(timing.sendStart, timing.sendEnd);
  const wait = toMs(timing.sendEnd, timing.receiveHeadersEnd);
  // receive is calculated when loadingFinished fires

  return { blocked, dns, connect, ssl, send, wait, receive: -1 };
}

// Extract cache-related headers
function extractCacheHeaders(headers) {
  if (!headers) return {};

  const result = {};
  const keysOfInterest = ['cache-control', 'etag', 'age', 'cf-cache-status'];

  for (const [key, value] of Object.entries(headers)) {
    const lowerKey = key.toLowerCase();
    if (keysOfInterest.includes(lowerKey)) {
      result[lowerKey] = value;
    }
  }

  return result;
}

async function capture() {
  const client = await CDP({ target: targetId, port: PORT });
  const { Network, Page } = client;

  clearLog();
  console.log(`Capturing network traffic`);
  console.log(`  Raw log: ${LOG_PATH}`);
  console.log(`  Metadata: ${METADATA_PATH}`);
  console.log(`  Target: ${targetId}`);
  console.log('Press Ctrl+C to stop\n');

  // Track page load start for relative timing
  let pageStartTime = null;

  Page.frameNavigated(() => {
    clearLog();
    pageStartTime = null; // Reset on navigation
    console.log('Page refreshed, cleared log');
  });

  // Request started
  Network.requestWillBeSent(({ requestId, request, timestamp, type, initiator }) => {
    if (!pageStartTime) pageStartTime = timestamp;

    const entry = {
      requestId,
      url: request.url,
      method: request.method,
      type,
      startTime: timestamp,
      relativeStart: Math.round((timestamp - pageStartTime) * 1000 * 100) / 100, // ms from page start
      initiator: initiator ? {
        type: initiator.type, // parser, script, preflight, other
        url: initiator.url || null,
      } : null,
    };

    rawEntries.push({
      time: Date.now(),
      requestId,
      method: request.method,
      url: request.url,
      type,
      relativeStart: entry.relativeStart,
    });

    pendingRequests.set(requestId, entry);
    debouncedWrite();
  });

  // Response received - contains most metadata
  Network.responseReceived(({ requestId, response, timestamp }) => {
    const pending = pendingRequests.get(requestId);
    if (!pending) return;

    // Update raw entry
    const rawEntry = rawEntries.find(e => e.requestId === requestId);
    if (rawEntry) {
      rawEntry.status = response.status;
      rawEntry.mimeType = response.mimeType;
    }

    // Build metadata entry
    pending.status = response.status;
    pending.mimeType = response.mimeType;
    pending.httpVersion = response.protocol || 'unknown';
    pending.headers = extractCacheHeaders(response.headers);
    pending.timings = computeTimings(response.timing);
    pending.responseTime = timestamp;

    // Sizes from response (may be updated in loadingFinished)
    pending.contentSize = response.encodedDataLength || 0;

    debouncedWrite();
  });

  // Loading finished - final sizes and timing
  Network.loadingFinished(({ requestId, encodedDataLength, timestamp }) => {
    const pending = pendingRequests.get(requestId);
    if (!pending) return;

    pending.transferSize = encodedDataLength || 0;

    // Calculate receive time if we have timing info
    if (pending.timings && pending.responseTime && pending.startTime) {
      const totalTime = (timestamp - pending.startTime) * 1000;
      const receiveStart = pending.responseTime - pending.startTime;
      pending.timings.receive = Math.round((timestamp - pending.responseTime) * 1000 * 1000) / 1000;
      pending.time = Math.round(totalTime * 1000) / 1000; // Total duration in ms
    }

    // Determine if cached
    pending.cached = pending.transferSize === 0 || pending.status === 304;

    // Calculate end time relative to page start
    const relativeEnd = Math.round((timestamp - pageStartTime) * 1000 * 100) / 100;

    // Create clean metadata entry
    const metadata = {
      url: pending.url,
      method: pending.method,
      type: pending.type,
      status: pending.status,
      time: pending.time || 0,
      transferSize: pending.transferSize || 0,
      contentSize: pending.contentSize || 0,
      mimeType: pending.mimeType,
      httpVersion: pending.httpVersion,
      timings: pending.timings,
      headers: pending.headers,
      cached: pending.cached,
      // Waterfall analysis fields
      relativeStart: pending.relativeStart, // ms from page start
      relativeEnd: relativeEnd,             // ms from page start
      initiator: pending.initiator,         // what triggered this request
      timestamp: Date.now(),
    };

    metadataEntries.push(metadata);
    pendingRequests.delete(requestId);
    debouncedWrite();
  });

  // Request failed
  Network.loadingFailed(({ requestId, errorText }) => {
    const pending = pendingRequests.get(requestId);
    if (!pending) return;

    const metadata = {
      url: pending.url,
      method: pending.method,
      type: pending.type,
      status: 0,
      error: errorText,
      time: 0,
      transferSize: 0,
      contentSize: 0,
      mimeType: null,
      httpVersion: null,
      timings: null,
      headers: {},
      cached: false,
      timestamp: Date.now(),
    };

    metadataEntries.push(metadata);
    pendingRequests.delete(requestId);
    debouncedWrite();
  });

  await Network.enable();
  await Page.enable();

  // Keep process alive
  process.on('SIGINT', () => {
    console.log('\nStopping capture...');
    client.close();
    process.exit(0);
  });

  process.on('SIGTERM', () => {
    client.close();
    process.exit(0);
  });
}

capture().catch(err => {
  console.error('Error:', err.message);
  process.exit(1);
});
