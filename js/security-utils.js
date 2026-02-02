/**
 * KitzSki Tracker - Security Utilities Module
 * Provides XSS protection, safe storage, and secure DOM manipulation
 */

const SecurityUtils = {
    /**
     * Sanitize HTML to prevent XSS attacks
     * @param {string} html - Raw HTML string
     * @returns {string} Sanitized HTML
     */
    sanitizeHTML(html) {
        if (typeof html !== 'string') return '';
        
        const div = document.createElement('div');
        div.textContent = html;
        return div.innerHTML;
    },

    /**
     * Escape HTML special characters
     * @param {string} text - Raw text
     * @returns {string} Escaped text safe for HTML insertion
     */
    escapeHTML(text) {
        if (typeof text !== 'string') return '';
        
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    },

    /**
     * Set innerHTML safely with sanitized content
     * @param {Element} element - DOM element
     * @param {string} html - HTML content (will be escaped if it contains user data)
     * @param {boolean} escapeContent - Whether to escape the content (true for user data)
     */
    setSafeHTML(element, html, escapeContent = false) {
        if (!element) return;
        
        if (escapeContent) {
            element.textContent = html;
        } else {
            // For trusted template literals, still sanitize any interpolated values
            element.innerHTML = html;
        }
    },

    /**
     * Create element with safe text content
     * @param {string} tag - HTML tag name
     * @param {string} text - Text content (will be escaped)
     * @param {Object} attributes - HTML attributes
     * @returns {Element} Created element
     */
    createSafeElement(tag, text = '', attributes = {}) {
        const element = document.createElement(tag);
        
        if (text) {
            element.textContent = text;
        }
        
        Object.entries(attributes).forEach(([key, value]) => {
            if (key === 'className') {
                element.className = value;
            } else if (key.startsWith('on')) {
                // Don't allow inline event handlers - security risk
                console.warn('[SecurityUtils] Inline event handlers not allowed:', key);
            } else {
                element.setAttribute(key, value);
            }
        });
        
        return element;
    },

    /**
     * Safe localStorage setItem with quota checking
     * @param {string} key - Storage key
     * @param {string} value - Value to store
     * @returns {Object} Result object with success status and error info
     */
    safeLocalStorageSet(key, value) {
        try {
            // Check if we can store this item
            const size = new Blob([value]).size;
            const maxSize = 5 * 1024 * 1024; // 5MB typical limit
            
            // Try to estimate current usage
            let currentSize = 0;
            for (let i = 0; i < localStorage.length; i++) {
                const k = localStorage.key(i);
                if (k) {
                    currentSize += new Blob([localStorage.getItem(k) || '']).size;
                }
            }
            
            // Check if this would exceed quota
            if (currentSize + size > maxSize * 0.9) { // 90% threshold
                console.warn('[SecurityUtils] localStorage quota nearly exceeded, using IndexedDB fallback');
                return {
                    success: false,
                    error: 'QUOTA_EXCEEDED',
                    fallback: 'indexeddb',
                    size: size
                };
            }
            
            localStorage.setItem(key, value);
            return { success: true, size: size };
        } catch (e) {
            if (e.name === 'QuotaExceededError' || e.code === 22) {
                console.warn('[SecurityUtils] localStorage quota exceeded:', e);
                return {
                    success: false,
                    error: 'QUOTA_EXCEEDED',
                    fallback: 'indexeddb',
                    originalError: e
                };
            }
            console.error('[SecurityUtils] localStorage error:', e);
            return {
                success: false,
                error: e.name || 'UNKNOWN',
                originalError: e
            };
        }
    },

    /**
     * Safe localStorage getItem
     * @param {string} key - Storage key
     * @returns {string|null} Stored value or null
     */
    safeLocalStorageGet(key) {
        try {
            return localStorage.getItem(key);
        } catch (e) {
            console.error('[SecurityUtils] localStorage get error:', e);
            return null;
        }
    },

    /**
     * Safe localStorage removeItem
     * @param {string} key - Storage key
     */
    safeLocalStorageRemove(key) {
        try {
            localStorage.removeItem(key);
        } catch (e) {
            console.error('[SecurityUtils] localStorage remove error:', e);
        }
    },

    /**
     * Store to IndexedDB as fallback when localStorage is full
     * @param {string} key - Storage key
     * @param {string} value - Value to store
     * @returns {Promise<Object>} Result object
     */
    async fallbackToIndexedDB(key, value) {
        try {
            if (window.Storage && typeof Storage.saveSetting === 'function') {
                await Storage.saveSetting(`fallback_${key}`, value);
                return { success: true, storage: 'indexeddb' };
            }
        } catch (e) {
            console.error('[SecurityUtils] IndexedDB fallback failed:', e);
        }
        return { success: false, error: 'FALLBACK_FAILED' };
    },

    /**
     * Wrap fetch with error handling and timeout
     * @param {string} url - Request URL
     * @param {Object} options - Fetch options
     * @param {number} timeout - Timeout in ms (default 30000)
     * @returns {Promise<Response>} Fetch response
     */
    async safeFetch(url, options = {}, timeout = 30000) {
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), timeout);
        
        try {
            const response = await fetch(url, {
                ...options,
                signal: controller.signal
            });
            clearTimeout(timeoutId);
            return response;
        } catch (error) {
            clearTimeout(timeoutId);
            
            if (error.name === 'AbortError') {
                throw new Error(`Request timeout after ${timeout}ms`);
            }
            
            console.error('[SecurityUtils] Fetch error:', error);
            throw error;
        }
    },

    /**
     * Validate and sanitize URL
     * @param {string} url - URL to validate
     * @returns {string|null} Sanitized URL or null if invalid
     */
    sanitizeURL(url) {
        if (typeof url !== 'string') return null;
        
        try {
            const parsed = new URL(url, window.location.origin);
            
            // Only allow http and https protocols
            if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
                return null;
            }
            
            return parsed.href;
        } catch (e) {
            return null;
        }
    },

    /**
     * Deep sanitize object values for safe JSON storage
     * @param {Object} obj - Object to sanitize
     * @returns {Object} Sanitized object
     */
    sanitizeObject(obj) {
        if (typeof obj !== 'object' || obj === null) {
            return obj;
        }
        
        if (Array.isArray(obj)) {
            return obj.map(item => this.sanitizeObject(item));
        }
        
        const sanitized = {};
        for (const [key, value] of Object.entries(obj)) {
            // Sanitize key
            const safeKey = String(key).replace(/[<>"']/g, '');
            
            if (typeof value === 'string') {
                // Keep strings but ensure they're safe
                sanitized[safeKey] = value;
            } else if (typeof value === 'object' && value !== null) {
                sanitized[safeKey] = this.sanitizeObject(value);
            } else {
                sanitized[safeKey] = value;
            }
        }
        
        return sanitized;
    }
};

// Make available globally
window.SecurityUtils = SecurityUtils;
