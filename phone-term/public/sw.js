// Minimal service worker — exists so the app is installable as a PWA.
// Network-first passthrough; no offline caching (the bridge needs the network anyway).
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));
self.addEventListener('fetch', () => {});
