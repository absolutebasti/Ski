const CACHE_NAME = 'kitzski-v1';
const STATIC_ASSETS = [
    '/',
    '/index.html',
    '/manifest.json',
    '/css/styles.css',
    '/js/config.js',
    '/js/app.js',
    '/js/gps-tracker.js',
    '/js/map.js',
    '/js/stats.js',
    '/js/storage.js',
    '/js/utils.js',
    '/assets/kitzbuehel-trails.geojson'
];

// Install event - cache static assets
self.addEventListener('install', (event) => {
    event.waitUntil(
        caches.open(CACHE_NAME)
            .then((cache) => {
                console.log('Caching static assets');
                return cache.addAll(STATIC_ASSETS);
            })
            .then(() => self.skipWaiting())
    );
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
    event.waitUntil(
        caches.keys()
            .then((cacheNames) => {
                return Promise.all(
                    cacheNames
                        .filter((name) => name !== CACHE_NAME)
                        .map((name) => caches.delete(name))
                );
            })
            .then(() => self.clients.claim())
    );
});

// Fetch event - serve from cache, fallback to network
self.addEventListener('fetch', (event) => {
    const { request } = event;
    const url = new URL(request.url);

    // Skip non-GET requests
    if (request.method !== 'GET') return;

    // Skip external requests (except Mapbox tiles which we want to cache)
    if (!url.origin.includes(self.location.origin) && 
        !url.hostname.includes('mapbox.com')) {
        return;
    }

    event.respondWith(
        caches.match(request)
            .then((cachedResponse) => {
                if (cachedResponse) {
                    // Return cached version
                    return cachedResponse;
                }

                // Fetch from network
                return fetch(request)
                    .then((response) => {
                        // Don't cache non-successful responses
                        if (!response || response.status !== 200) {
                            return response;
                        }

                        // Clone the response
                        const responseToCache = response.clone();

                        // Cache map tiles and other resources
                        if (url.hostname.includes('mapbox.com') || 
                            url.pathname.includes('/assets/')) {
                            caches.open(CACHE_NAME)
                                .then((cache) => {
                                    cache.put(request, responseToCache);
                                });
                        }

                        return response;
                    })
                    .catch(() => {
                        // Offline fallback for HTML pages
                        if (request.headers.get('accept').includes('text/html')) {
                            return caches.match('/index.html');
                        }
                    });
            })
    );
});

// Background sync for saving runs when back online
self.addEventListener('sync', (event) => {
    if (event.tag === 'sync-runs') {
        event.waitUntil(syncRuns());
    }
});

async function syncRuns() {
    // Future: sync runs to a backend server
    console.log('Syncing runs...');
}
