/**
 * KitzSki Tracker - Request Utilities
 * CRITICAL-013: Add Request Timeout Handling
 * 
 * Provides fetch with timeout, retry logic, and exponential backoff
 * for improved reliability in poor network conditions.
 */

const RequestUtils = {
    DEFAULT_TIMEOUT: 10000, // 10 seconds
    DEFAULT_RETRIES: 3,
    
    /**
     * Fetch with timeout support
     * @param {string} url - URL to fetch
     * @param {Object} options - Fetch options
     * @param {number} timeout - Timeout in milliseconds
     * @returns {Promise} Fetch promise
     */
    async fetchWithTimeout(url, options = {}, timeout = this.DEFAULT_TIMEOUT) {
        const controller = new AbortController();
        const id = setTimeout(() => controller.abort(), timeout);
        
        try {
            const response = await fetch(url, {
                ...options,
                signal: controller.signal
            });
            clearTimeout(id);
            return response;
        } catch (error) {
            clearTimeout(id);
            if (error.name === 'AbortError') {
                throw new Error(`Request timeout after ${timeout}ms: ${url}`);
            }
            throw error;
        }
    },
    
    /**
     * Fetch with retry logic and exponential backoff
     * @param {string} url - URL to fetch
     * @param {Object} options - Fetch options
     * @param {Object} retryOptions - Retry configuration
     * @returns {Promise} Fetch promise
     */
    async fetchWithRetry(url, options = {}, retryOptions = {}) {
        const {
            maxRetries = this.DEFAULT_RETRIES,
            initialDelay = 1000,
            maxDelay = 10000,
            timeout = this.DEFAULT_TIMEOUT
        } = retryOptions;
        
        let lastError;
        
        for (let attempt = 0; attempt <= maxRetries; attempt++) {
            try {
                return await this.fetchWithTimeout(url, options, timeout);
            } catch (error) {
                lastError = error;
                
                // Don't retry on client errors (4xx)
                if (error.status >= 400 && error.status < 500) {
                    throw error;
                }
                
                // Don't retry after last attempt
                if (attempt === maxRetries) {
                    break;
                }
                
                // Calculate delay with exponential backoff and jitter
                const delay = Math.min(
                    initialDelay * Math.pow(2, attempt),
                    maxDelay
                );
                const jitter = Math.random() * 1000; // Add up to 1s jitter
                
                console.warn(`[RequestUtils] Retry ${attempt + 1}/${maxRetries} for ${url} after ${delay + jitter}ms`);
                await this.sleep(delay + jitter);
            }
        }
        
        throw new Error(`Failed after ${maxRetries + 1} attempts: ${lastError.message}`);
    },
    
    /**
     * Sleep/delay helper
     * @param {number} ms - Milliseconds to sleep
     * @returns {Promise} Promise that resolves after delay
     */
    sleep(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    },
    
    /**
     * Create a circuit breaker for failing endpoints
     * @param {Object} options - Circuit breaker options
     * @returns {Object} Circuit breaker instance
     */
    createCircuitBreaker(options = {}) {
        const {
            failureThreshold = 5,
            resetTimeout = 30000,
            halfOpenMaxCalls = 3
        } = options;
        
        return {
            state: 'CLOSED', // CLOSED, OPEN, HALF_OPEN
            failures: 0,
            lastFailureTime: null,
            halfOpenCalls: 0,
            
            async execute(fn) {
                if (this.state === 'OPEN') {
                    if (Date.now() - this.lastFailureTime > resetTimeout) {
                        this.state = 'HALF_OPEN';
                        this.halfOpenCalls = 0;
                        console.log('[CircuitBreaker] Entering HALF_OPEN state');
                    } else {
                        throw new Error('Circuit breaker is OPEN');
                    }
                }
                
                try {
                    const result = await fn();
                    this.onSuccess();
                    return result;
                } catch (error) {
                    this.onFailure();
                    throw error;
                }
            },
            
            onSuccess() {
                if (this.state === 'HALF_OPEN') {
                    this.halfOpenCalls++;
                    if (this.halfOpenCalls >= halfOpenMaxCalls) {
                        this.state = 'CLOSED';
                        this.failures = 0;
                        console.log('[CircuitBreaker] Circuit CLOSED');
                    }
                } else {
                    this.failures = 0;
                }
            },
            
            onFailure() {
                this.failures++;
                this.lastFailureTime = Date.now();
                
                if (this.failures >= failureThreshold) {
                    this.state = 'OPEN';
                    console.warn('[CircuitBreaker] Circuit OPENED due to failures');
                }
            }
        };
    },
    
    /**
     * Wrapper for Supabase requests with timeout and retry
     * @param {Function} requestFn - Function that returns a promise
     * @param {Object} options - Request options
     * @returns {Promise} Request promise
     */
    async supabaseRequest(requestFn, options = {}) {
        const {
            timeout = 15000, // Supabase requests get longer timeout
            retries = 2,
            operation = 'unknown'
        } = options;
        
        let lastError;
        
        for (let attempt = 0; attempt <= retries; attempt++) {
            try {
                // Create a timeout promise
                const timeoutPromise = new Promise((_, reject) => {
                    setTimeout(() => reject(new Error(`Supabase ${operation} timeout`)), timeout);
                });
                
                // Race between request and timeout
                return await Promise.race([
                    requestFn(),
                    timeoutPromise
                ]);
            } catch (error) {
                lastError = error;
                
                if (attempt < retries) {
                    const delay = Math.pow(2, attempt) * 1000;
                    console.warn(`[Supabase] Retry ${attempt + 1}/${retries} for ${operation} after ${delay}ms`);
                    await this.sleep(delay);
                }
            }
        }
        
        throw lastError;
    }
};

// Make available globally
window.RequestUtils = RequestUtils;
