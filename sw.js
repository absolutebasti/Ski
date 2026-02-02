/**
 * KitzSki Tracker - Service Worker
 * Provides offline support, caching, and background sync
 */

const CACHE_NAME = 'kitzski-v2';
const STATIC_CACHE = 'kitzski-static-v2';
const TILE_CACHE = 'kitzski-tiles-v2';
const OFFLINE_PAGE = '/offline.html';

// Cache expiration times
const TILE_MAX_AGE = 30 * 24 * 60 * 60 * 1000; // 30 days in milliseconds
const STATIC_MAX_AGE = 7 * 24 * 60 * 60 * 1000; // 7 days

// Static assets to precache
const STATIC_ASSETS = [
    '/',
    '/index.html',
    '/offline.html',
    '/manifest.json',
    '/css/styles.css',
    '/js/config.js',
    '/js/app.js',
    '/js/resorts.js',
    '/js/achievements.js',
    '/js/gps-tracker.js',
    '/js/map.js',
    '/js/stats.js',
    '/js/storage.js',
    '/js/utils.js',
    '/js/supabase.js',
    '/assets/trails/kitzbuehel.geojson',
    '/assets/trails/kitzbuehel-details.json',
    '/assets/icons/icon-192.svg',
    '/assets/icons/icon-512.svg',
    // External CDN resources
    'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2'
];

// Install event - cache static assets
self.addEventListener('install', (event) => {
    console.log('[SW] Installing...');
    
    event.waitUntil(
        caches.open(STATIC_CACHE)
            .then((cache) => {
                console.log('[SW] Caching static assets');
                return cache.addAll(STATIC_ASSETS);
            })
            .then(() => {
                console.log('[SW] Static assets cached');
                return self.skipWaiting();
            })
            .catch((error) => {
                console.error('[SW] Failed to cache static assets:', error);
            })
    );
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
    console.log('[SW] Activating...');
    
    event.waitUntil(
        caches.keys()
            .then((cacheNames) => {
                return Promise.all(
                    cacheNames
                        .filter((name) => {
                            return name.startsWith('kitzski-') && 
                                   name !== STATIC_CACHE && 
                                   name !== TILE_CACHE;
                        })
                        .map((name) => {
                            console.log('[SW] Deleting old cache:', name);
                            return caches.delete(name);
                        })
                );
            })
            .then(() => {
                console.log('[SW] Claiming clients');
                return self.clients.claim();
            })
    );
});

// Fetch event - serve from cache, fallback to network
self.addEventListener('fetch', (event) => {
    const { request } = event;
    const url = new URL(request.url);

    // Skip non-GET requests
    if (request.method !== 'GET') {
        return;
    }

    // Skip chrome-extension requests
    if (url.protocol === 'chrome-extension:') {
        return;
    }

    // Handle Mapbox tiles - cache with stale-while-revalidate
    if (url.hostname.includes('mapbox.com') || url.hostname.includes('tiles.mapbox.com')) {
        event.respondWith(handleMapboxTile(request));
        return;
    }

    // Handle static assets
    if (isStaticAsset(url)) {
        event.respondWith(handleStaticAsset(request));
        return;
    }

    // Handle API requests (including Supabase) - network first with offline queue
    if (url.pathname.includes('/rest/v1/') || url.hostname.includes('supabase.co')) {
        event.respondWith(handleAPIRequest(request));
        return;
    }

    // Default: Network first, cache fallback
    event.respondWith(handleDefaultFetch(request));
});

/**
 * Handle Mapbox tile requests with dedicated tile cache
 * CRITICAL-015: Implement proper offline tile caching with expiry
 */
async function handleMapboxTile(request) {
    const cache = await caches.open(TILE_CACHE);
    const cached = await cache.match(request);
    
    // Check if we have a valid cached tile
    if (cached) {
        const cachedDate = cached.headers.get('sw-cached-date');
        const isExpired = cachedDate && (Date.now() - parseInt(cachedDate)) > TILE_MAX_AGE;
        
        if (!isExpired) {
            // Return cached tile and refresh in background (stale-while-revalidate)
            fetch(request)
                .then((response) => {
                    if (response && response.status === 200) {
                        cache.put(request, addCacheTimestamp(response.clone()));
                    }
                })
                .catch(() => {});
            
            // Return cached response immediately
            return cached;
        }
        // If expired, continue to fetch fresh tile
    }
    
    try {
        const response = await fetch(request);
        if (response && response.status === 200) {
            // Add timestamp header and cache the response
            const responseWithTimestamp = addCacheTimestamp(response.clone());
            cache.put(request, responseWithTimestamp);
        }
        return response;
    } catch (error) {
        console.error('[SW] Failed to fetch tile:', error);
        
        // Return expired cached tile as fallback if available
        if (cached) {
            console.log('[SW] Serving expired tile as fallback');
            return cached;
        }
        
        // Return transparent 1x1 pixel as ultimate fallback
        return createTransparentTile();
    }
}

/**
 * Add cache timestamp header to response
 * @param {Response} response - Original response
 * @returns {Response} Response with timestamp header
 */
function addCacheTimestamp(response) {
    const headers = new Headers(response.headers);
    headers.set('sw-cached-date', Date.now().toString());
    
    return new Response(response.body, {
        status: response.status,
        statusText: response.statusText,
        headers: headers
    });
}

/**
 * Create a transparent 1x1 pixel PNG as fallback
 * @returns {Response} Transparent PNG response
 */
function createTransparentTile() {
    // 1x1 transparent PNG
    const transparentPng = new Uint8Array([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82
    ]);
    
    return new Response(transparentPng, {
        status: 200,
        headers: {
            'Content-Type': 'image/png',
            'Cache-Control': 'public, max-age=86400'
        }
    });
}

/**
 * Handle static assets - cache first
 */
async function handleStaticAsset(request) {
    const cache = await caches.open(STATIC_CACHE);
    const cached = await cache.match(request);
    
    if (cached) {
        return cached;
    }
    
    try {
        const response = await fetch(request);
        if (response && response.status === 200) {
            cache.put(request, response.clone());
        }
        return response;
    } catch (error) {
        // For HTML requests, return offline page
        if (request.headers.get('accept')?.includes('text/html')) {
            return cache.match(OFFLINE_PAGE) || cache.match('/index.html');
        }
        throw error;
    }
}

/**
 * Handle API requests - network first with offline queue
 */
async function handleAPIRequest(request) {
    try {
        const response = await fetch(request);
        return response;
    } catch (error) {
        console.log('[SW] API request failed, queuing for sync:', request.url);
        
        // Queue the request for background sync
        await queueRequestForSync(request);
        
        // Return a custom offline response
        return new Response(
            JSON.stringify({ 
                error: 'offline', 
                message: 'Request queued for sync when back online',
                offline: true 
            }),
            { 
                status: 503, 
                headers: { 'Content-Type': 'application/json' } 
            }
        );
    }
}

/**
 * Handle default fetch - network first, cache fallback
 */
async function handleDefaultFetch(request) {
    try {
        const response = await fetch(request);
        
        // Cache successful responses for static assets
        if (response && response.status === 200) {
            const url = new URL(request.url);
            if (isCacheableAsset(url)) {
                const cache = await caches.open(STATIC_CACHE);
                cache.put(request, response.clone());
            }
        }
        
        return response;
    } catch (error) {
        const cache = await caches.open(STATIC_CACHE);
        const cached = await cache.match(request);
        
        if (cached) {
            return cached;
        }
        
        // For HTML requests, return offline page
        if (request.headers.get('accept')?.includes('text/html')) {
            return cache.match(OFFLINE_PAGE) || cache.match('/index.html');
        }
        
        throw error;
    }
}

/**
 * Check if URL is a static asset
 */
function isStaticAsset(url) {
    const staticPaths = ['/', '/index.html', '/css/', '/js/', '/assets/', '/manifest.json'];
    return staticPaths.some(path => url.pathname.startsWith(path));
}

/**
 * Check if asset should be cached
 */
function isCacheableAsset(url) {
    const cacheableExtensions = ['.js', '.css', '.json', '.svg', '.png', '.jpg', '.woff2'];
    return cacheableExtensions.some(ext => url.pathname.endsWith(ext));
}

/**
 * Queue a failed request for background sync
 */
async function queueRequestForSync(request) {
    // Clone the request to store it
    const clonedRequest = request.clone();
    const body = await clonedRequest.text().catch(() => null);
    
    const requestData = {
        url: clonedRequest.url,
        method: clonedRequest.method,
        headers: Array.from(clonedRequest.headers.entries()),
        body: body,
        timestamp: Date.now()
    };
    
    // Store in IndexedDB via a message to the client
    const clients = await self.clients.matchAll();
    clients.forEach(client => {
        client.postMessage({
            type: 'QUEUE_REQUEST',
            request: requestData
        });
    });
}

// Background sync event
self.addEventListener('sync', (event) => {
    console.log('[SW] Background sync event:', event.tag);
    
    if (event.tag === 'sync-runs') {
        event.waitUntil(syncPendingRuns());
    } else if (event.tag === 'sync-api-requests') {
        event.waitUntil(syncPendingAPIRequests());
    }
});

/**
 * Sync pending runs to Supabase
 */
async function syncPendingRuns() {
    console.log('[SW] Syncing pending runs...');
    
    // Notify clients to check for unsynced runs
    const clients = await self.clients.matchAll();
    clients.forEach(client => {
        client.postMessage({
            type: 'SYNC_RUNS'
        });
    });
}

/**
 * Sync pending API requests
 */
async function syncPendingAPIRequests() {
    console.log('[SW] Syncing pending API requests...');
    
    // Notify clients to retry failed API calls
    const clients = await self.clients.matchAll();
    clients.forEach(client => {
        client.postMessage({
            type: 'SYNC_API_REQUESTS'
        });
    });
}

// Push event - for future push notifications
self.addEventListener('push', (event) => {
    console.log('[SW] Push event received');
    
    const data = event.data?.json() || {};
    const title = data.title || 'KitzSki Tracker';
    const options = {
        body: data.body || 'You have a new notification',
        icon: '/assets/icons/icon-192.svg',
        badge: '/assets/icons/icon-192.svg',
        data: data.data || {},
        actions: data.actions || []
    };
    
    event.waitUntil(
        self.registration.showNotification(title, options)
    );
});

// Notification click event
self.addEventListener('notificationclick', (event) => {
    console.log('[SW] Notification clicked');
    event.notification.close();
    
    event.waitUntil(
        self.clients.openWindow('/')
    );
});

// Message event - handle messages from the main app
self.addEventListener('message', (event) => {
    console.log('[SW] Message received:', event.data);
    
    if (event.data === 'skipWaiting') {
        self.skipWaiting();
    } else if (event.data?.type === 'CLEAR_CACHES') {
        event.waitUntil(clearAllCaches());
    }
});

/**
 * Clear all caches
 */
async function clearAllCaches() {
    const cacheNames = await caches.keys();
    return Promise.all(
        cacheNames
            .filter(name => name.startsWith('kitzski-'))
            .map(name => caches.delete(name))
    );
}
