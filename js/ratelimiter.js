/**
 * Rate Limiting Module
 * HIGH-009: Implement Rate Limiting for API Calls
 * 
 * Prevents API abuse and protects Supabase free tier limits
 * Features: Client-side rate limiting, caching, exponential backoff
 */

const RateLimiter = {
    // Rate limit configuration
    limits: {
        default: { maxCalls: 100, windowMs: 60000 }, // 100 calls per minute
        supabase: { maxCalls: 60, windowMs: 60000 },  // 60 calls per minute
        mapbox: { maxCalls: 50, windowMs: 60000 },    // Mapbox API limit
        scraper: { maxCalls: 10, windowMs: 60000 },   // Slope status scraper
        geocoding: { maxCalls: 20, windowMs: 60000 }, // Geocoding requests
    },
    
    // Call tracking
    calls: {},
    
    // Cache storage
    cache: new Map(),
    
    // Retry configuration
    retryConfig: {
        maxRetries: 3,
        baseDelay: 1000,
        maxDelay: 30000,
        jitter: true
    },
    
    // Circuit breaker states
    circuits: {},
    
    /**
     * Initialize rate limiter
     */
    init() {
        // Load from localStorage if available
        const saved = localStorage.getItem('rateLimiterState');
        if (saved) {
            try {
                const state = JSON.parse(saved);
                this.calls = state.calls || {};
                this.circuits = state.circuits || {};
            } catch (e) {
                console.error('[RateLimiter] Failed to load state:', e);
            }
        }
        
        // Clean up old calls periodically
        setInterval(() => this.cleanup(), 60000);
        
        console.log('[RateLimiter] Initialized');
    },
    
    /**
     * Check if request is allowed
     */
    checkLimit(key, limitName = 'default') {
        const limit = this.limits[limitName] || this.limits.default;
        const now = Date.now();
        const windowStart = now - limit.windowMs;
        
        if (!this.calls[key]) {
            this.calls[key] = [];
        }
        
        // Remove old calls outside window
        this.calls[key] = this.calls[key].filter(t => t > windowStart);
        
        // Check circuit breaker
        if (this.isCircuitOpen(key)) {
            return { allowed: false, reason: 'circuit_open', retryAfter: this.getCircuitRetryTime(key) };
        }
        
        // Check rate limit
        if (this.calls[key].length >= limit.maxCalls) {
            const oldestCall = this.calls[key][0];
            const retryAfter = oldestCall + limit.windowMs - now;
            return { allowed: false, reason: 'rate_limit', retryAfter };
        }
        
        return { allowed: true };
    },
    
    /**
     * Record a call
     */
    recordCall(key) {
        if (!this.calls[key]) {
            this.calls[key] = [];
        }
        this.calls[key].push(Date.now());
        this.saveState();
    },
    
    /**
     * Make rate-limited request
     */
    async request(key, requestFn, options = {}) {
        const limitName = options.limit || 'default';
        const cacheKey = options.cache ? `${key}:${JSON.stringify(options.cacheParams || {})}` : null;
        const cacheTTL = options.cacheTTL || 300000; // 5 minutes default
        
        // Check cache first
        if (cacheKey) {
            const cached = this.getCache(cacheKey);
            if (cached && !options.skipCache) {
                console.log(`[RateLimiter] Cache hit for ${key}`);
                return cached;
            }
        }
        
        // Check rate limit
        const limitCheck = this.checkLimit(key, limitName);
        if (!limitCheck.allowed) {
            if (limitCheck.reason === 'circuit_open') {
                throw new Error(`Circuit breaker open for ${key}. Retry after ${limitCheck.retryAfter}ms`);
            }
            
            if (options.waitForLimit) {
                console.log(`[RateLimiter] Waiting ${limitCheck.retryAfter}ms for rate limit reset`);
                await this.sleep(limitCheck.retryAfter);
            } else {
                throw new Error(`Rate limit exceeded for ${key}. Retry after ${limitCheck.retryAfter}ms`);
            }
        }
        
        // Execute request with retry logic
        const result = await this.executeWithRetry(key, requestFn, options);
        
        // Record the call
        this.recordCall(key);
        
        // Cache result
        if (cacheKey && result !== undefined) {
            this.setCache(cacheKey, result, cacheTTL);
        }
        
        return result;
    },
    
    /**
     * Execute request with retry logic
     */
    async executeWithRetry(key, requestFn, options = {}) {
        const maxRetries = options.maxRetries ?? this.retryConfig.maxRetries;
        const baseDelay = options.baseDelay ?? this.retryConfig.baseDelay;
        
        let lastError;
        
        for (let attempt = 0; attempt <= maxRetries; attempt++) {
            try {
                const result = await requestFn();
                this.recordSuccess(key);
                return result;
            } catch (error) {
                lastError = error;
                
                // Don't retry on certain errors
                if (error.status === 400 || error.status === 401 || error.status === 403) {
                    throw error;
                }
                
                if (attempt < maxRetries) {
                    const delay = this.calculateBackoff(attempt, baseDelay);
                    console.log(`[RateLimiter] Retry ${attempt + 1}/${maxRetries} for ${key} after ${delay}ms`);
                    await this.sleep(delay);
                }
            }
        }
        
        this.recordFailure(key);
        throw lastError;
    },
    
    /**
     * Calculate exponential backoff with jitter
     */
    calculateBackoff(attempt, baseDelay) {
        const exponential = Math.min(
            baseDelay * Math.pow(2, attempt),
            this.retryConfig.maxDelay
        );
        
        if (this.retryConfig.jitter) {
            // Add random jitter (±25%)
            const jitter = exponential * 0.25;
            return exponential + (Math.random() * jitter * 2 - jitter);
        }
        
        return exponential;
    },
    
    /**
     * Check if circuit breaker is open
     */
    isCircuitOpen(key) {
        const circuit = this.circuits[key];
        if (!circuit) return false;
        
        if (circuit.state === 'open') {
            // Check if it's time to try again
            if (Date.now() > circuit.retryAfter) {
                circuit.state = 'half-open';
                return false;
            }
            return true;
        }
        
        return false;
    },
    
    /**
     * Get circuit retry time
     */
    getCircuitRetryTime(key) {
        const circuit = this.circuits[key];
        return circuit ? Math.max(0, circuit.retryAfter - Date.now()) : 0;
    },
    
    /**
     * Record successful request
     */
    recordSuccess(key) {
        if (!this.circuits[key]) {
            this.circuits[key] = { failures: 0, state: 'closed' };
        } else {
            this.circuits[key].failures = 0;
            this.circuits[key].state = 'closed';
        }
    },
    
    /**
     * Record failed request
     */
    recordFailure(key) {
        if (!this.circuits[key]) {
            this.circuits[key] = { failures: 1, state: 'closed' };
        } else {
            this.circuits[key].failures++;
            
            // Open circuit after 5 failures
            if (this.circuits[key].failures >= 5) {
                this.circuits[key].state = 'open';
                this.circuits[key].retryAfter = Date.now() + 60000; // 1 minute cooldown
                console.warn(`[RateLimiter] Circuit opened for ${key}`);
            }
        }
        this.saveState();
    },
    
    /**
     * Get cached value
     */
    getCache(key) {
        const item = this.cache.get(key);
        if (!item) return null;
        
        if (Date.now() > item.expires) {
            this.cache.delete(key);
            return null;
        }
        
        return item.value;
    },
    
    /**
     * Set cached value
     */
    setCache(key, value, ttl) {
        this.cache.set(key, {
            value,
            expires: Date.now() + ttl
        });
    },
    
    /**
     * Clear cache
     */
    clearCache(pattern = null) {
        if (pattern) {
            for (const key of this.cache.keys()) {
                if (key.includes(pattern)) {
                    this.cache.delete(key);
                }
            }
        } else {
            this.cache.clear();
        }
    },
    
    /**
     * Cleanup old calls
     */
    cleanup() {
        const now = Date.now();
        const maxAge = 600000; // 10 minutes
        
        Object.keys(this.calls).forEach(key => {
            this.calls[key] = this.calls[key].filter(t => now - t < maxAge);
            if (this.calls[key].length === 0) {
                delete this.calls[key];
            }
        });
        
        // Clean expired cache entries
        for (const [key, item] of this.cache.entries()) {
            if (now > item.expires) {
                this.cache.delete(key);
            }
        }
        
        this.saveState();
    },
    
    /**
     * Save state to localStorage
     */
    saveState() {
        try {
            localStorage.setItem('rateLimiterState', JSON.stringify({
                calls: this.calls,
                circuits: this.circuits
            }));
        } catch (e) {
            // localStorage might be full
        }
    },
    
    /**
     * Sleep utility
     */
    sleep(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    },
    
    /**
     * Get current stats
     */
    getStats() {
        const stats = {
            totalCalls: 0,
            activeCircuits: 0,
            cacheSize: this.cache.size,
            limits: {}
        };
        
        Object.keys(this.calls).forEach(key => {
            stats.totalCalls += this.calls[key].length;
        });
        
        Object.keys(this.circuits).forEach(key => {
            if (this.circuits[key].state === 'open') {
                stats.activeCircuits++;
            }
        });
        
        Object.keys(this.limits).forEach(key => {
            const limit = this.limits[key];
            const calls = this.calls[key] || [];
            const windowStart = Date.now() - limit.windowMs;
            const callsInWindow = calls.filter(t => t > windowStart).length;
            
            stats.limits[key] = {
                used: callsInWindow,
                limit: limit.maxCalls,
                remaining: Math.max(0, limit.maxCalls - callsInWindow)
            };
        });
        
        return stats;
    },
    
    /**
     * Fetch wrapper with rate limiting
     */
    async fetch(url, options = {}) {
        const key = options.rateLimitKey || new URL(url).hostname;
        const limitName = options.limitName || 'default';
        
        return this.request(key, async () => {
            const response = await fetch(url, options);
            if (!response.ok) {
                const error = new Error(`HTTP ${response.status}: ${response.statusText}`);
                error.status = response.status;
                throw error;
            }
            return response;
        }, {
            limit: limitName,
            cache: options.cache,
            cacheTTL: options.cacheTTL,
            maxRetries: options.maxRetries
        });
    }
};

// Initialize
RateLimiter.init();
