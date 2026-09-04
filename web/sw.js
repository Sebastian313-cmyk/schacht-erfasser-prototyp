// ============================================================
// SERVICE WORKER - Auto-Update für Web-Version
// ============================================================

const CACHE_NAME = 'erfasser-app-v1';
const urlsToCache = [
  '/',
  '/index.html',
  '/main.dart.js',
  '/flutter.js',
  '/favicon.png',
  '/manifest.json',
];

// Installation
self.addEventListener('install', (event) => {
  console.log('[SW] Installing...');
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      console.log('[SW] Caching app shell');
      return cache.addAll(urlsToCache);
    })
  );
  // Sofort aktivieren (kein Warten auf alte Tabs)
  self.skipWaiting();
});

// Aktivierung
self.addEventListener('activate', (event) => {
  console.log('[SW] Activating...');
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== CACHE_NAME) {
            console.log('[SW] Deleting old cache:', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
  // Sofort alle Clients übernehmen
  return self.clients.claim();
});

// Fetch Strategy: Network First, dann Cache
self.addEventListener('fetch', (event) => {
  event.respondWith(
    fetch(event.request)
      .then((response) => {
        // Erfolgreiches Netzwerk → Cache aktualisieren
        if (response.status === 200) {
          const responseToCache = response.clone();
          caches.open(CACHE_NAME).then((cache) => {
            cache.put(event.request, responseToCache);
          });
        }
        return response;
      })
      .catch(() => {
        // Netzwerkfehler → Aus Cache laden
        return caches.match(event.request).then((response) => {
          if (response) {
            console.log('[SW] Serving from cache:', event.request.url);
            return response;
          }
          return new Response('Offline - Keine Verbindung', {
            status: 503,
            statusText: 'Service Unavailable',
          });
        });
      })
  );
});

// Update-Notification
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    console.log('[SW] Skipping waiting...');
    self.skipWaiting();
  }
});
