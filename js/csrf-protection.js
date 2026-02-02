/**
 * KitzSki Tracker - CSRF Protection
 * CRITICAL-008: Implement CSRF Protection for Supabase Requests
 * 
 * Adds CSRF tokens to state-changing requests to prevent cross-site
 * request forgery attacks.
 */

const CSRFProtection = {
    token: null,
    tokenExpiry: null,
    TOKEN_LIFETIME: 3600000, // 1 hour in milliseconds
    
    /**
     * Initialize CSRF protection
     */
    init() {
        this.token = this.generateToken();
        this.tokenExpiry = Date.now() + this.TOKEN_LIFETIME;
        console.log('[CSRF] Protection initialized');
    },
    
    /**
     * Generate a cryptographically secure random token
     * @returns {string} Base64 encoded token
     */
    generateToken() {
        const array = new Uint8Array(32);
        if (window.crypto && window.crypto.getRandomValues) {
            window.crypto.getRandomValues(array);
        } else {
            // Fallback for older browsers (less secure)
            for (let i = 0; i < array.length; i++) {
                array[i] = Math.floor(Math.random() * 256);
            }
        }
        return btoa(String.fromCharCode.apply(null, array));
    },
    
    /**
     * Get current CSRF token, regenerating if expired
     * @returns {string} Valid CSRF token
     */
    getToken() {
        if (!this.token || Date.now() > this.tokenExpiry) {
            this.init();
        }
        return this.token;
    },
    
    /**
     * Validate a token against the current token
     * @param {string} token - Token to validate
     * @returns {boolean} True if valid
     */
    validateToken(token) {
        return token === this.getToken();
    },
    
    /**
     * Rotate the CSRF token (call periodically or after sensitive operations)
     */
    rotateToken() {
        this.init();
    },
    
    /**
     * Add CSRF headers to fetch options
     * @param {Object} options - Fetch options object
     * @returns {Object} Options with CSRF headers added
     */
    addCSRFHeader(options = {}) {
        const headers = new Headers(options.headers || {});
        headers.set('X-CSRF-Token', this.getToken());
        headers.set('X-Requested-With', 'XMLHttpRequest');
        
        return {
            ...options,
            headers
        };
    },
    
    /**
     * Create a fetch wrapper that includes CSRF protection
     * @param {string} url - URL to fetch
     * @param {Object} options - Fetch options
     * @returns {Promise} Fetch promise
     */
    async fetch(url, options = {}) {
        // Only add CSRF token to state-changing methods
        const stateChangingMethods = ['POST', 'PUT', 'PATCH', 'DELETE'];
        const method = (options.method || 'GET').toUpperCase();
        
        if (stateChangingMethods.includes(method)) {
            options = this.addCSRFHeader(options);
        }
        
        return fetch(url, options);
    },
    
    /**
     * Add CSRF token to form data
     * @param {FormData} formData - Form data object
     * @returns {FormData} Form data with token added
     */
    addTokenToForm(formData) {
        formData.append('_csrf_token', this.getToken());
        return formData;
    }
};

// Initialize on load
document.addEventListener('DOMContentLoaded', () => {
    CSRFProtection.init();
});

// Make available globally
window.CSRFProtection = CSRFProtection;
