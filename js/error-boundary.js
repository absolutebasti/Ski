/**
 * KitzSki Tracker - Error Boundaries and Global Error Handling
 * CRITICAL-007: Implement Proper Error Boundaries
 */

const ErrorTracker = {
    errors: [],
    maxErrors: 50,
    isTracking: false,
    
    /**
     * Initialize error tracking
     */
    init() {
        this.setupGlobalHandlers();
        this.setupPromiseRejectionHandler();
        console.log('[ErrorTracker] Initialized');
    },

    /**
     * Setup global error handlers
     */
    setupGlobalHandlers() {
        window.addEventListener('error', (event) => {
            this.handleError(event.error || event.message, {
                filename: event.filename,
                lineno: event.lineno,
                colno: event.colno,
                type: 'global'
            });
            
            // Prevent default handling if we're in tracking mode
            if (this.isTracking) {
                event.preventDefault();
            }
        });

        // Handle console errors that might not trigger window.onerror
        const originalConsoleError = console.error;
        console.error = (...args) => {
            // Check if this is a real error object
            const errorArg = args.find(arg => arg instanceof Error);
            if (errorArg) {
                this.handleError(errorArg, { type: 'console' });
            }
            originalConsoleError.apply(console, args);
        };
    },

    /**
     * Setup unhandled promise rejection handler
     */
    setupPromiseRejectionHandler() {
        window.addEventListener('unhandledrejection', (event) => {
            this.handleError(event.reason, {
                type: 'unhandledrejection',
                stack: event.reason?.stack
            });
            
            // Log to console but don't prevent default - let app handle it
            console.error('[Unhandled Promise Rejection]', event.reason);
            
            if (this.isTracking) {
                event.preventDefault();
            }
        });
    },

    /**
     * Handle an error
     * @param {Error|string} error - The error object or message
     * @param {Object} context - Additional context
     */
    handleError(error, context = {}) {
        const errorInfo = {
            message: error?.message || String(error),
            stack: error?.stack,
            timestamp: Date.now(),
            type: context.type || 'unknown',
            context: { ...context },
            userAgent: navigator.userAgent,
            url: window.location.href
        };

        // Add to error log
        this.errors.push(errorInfo);
        
        // Keep only recent errors
        if (this.errors.length > this.maxErrors) {
            this.errors.shift();
        }

        // Log for debugging
        console.error('[ErrorTracker]', errorInfo);

        // If tracking is active, trigger emergency save
        if (this.isTracking && window.App && typeof window.App.emergencySave === 'function') {
            try {
                window.App.emergencySave();
            } catch (e) {
                console.error('[ErrorTracker] Emergency save failed:', e);
            }
        }

        // Show user-friendly error if critical
        if (this.isCriticalError(errorInfo)) {
            this.showErrorToUser(errorInfo);
        }

        // Send to analytics if available (non-blocking)
        this.reportToAnalytics(errorInfo).catch(() => {});

        return errorInfo;
    },

    /**
     * Check if error is critical
     * @param {Object} errorInfo - Error information
     * @returns {boolean} True if critical
     */
    isCriticalError(errorInfo) {
        const criticalPatterns = [
            /out of memory/i,
            /quota exceeded/i,
            /security error/i,
            /blocked a frame/i,
            /evaluating.*module/i
        ];
        
        return criticalPatterns.some(pattern => pattern.test(errorInfo.message));
    },

    /**
     * Show error to user
     * @param {Object} errorInfo - Error information
     */
    showErrorToUser(errorInfo) {
        // Create error toast if not exists
        let toast = document.getElementById('error-toast');
        if (!toast) {
            toast = document.createElement('div');
            toast.id = 'error-toast';
            toast.style.cssText = `
                position: fixed;
                bottom: 20px;
                left: 50%;
                transform: translateX(-50%);
                background: rgba(255, 59, 48, 0.95);
                color: white;
                padding: 12px 24px;
                border-radius: 8px;
                z-index: 10000;
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                font-size: 14px;
                max-width: 90%;
                text-align: center;
                box-shadow: 0 4px 12px rgba(0,0,0,0.3);
                animation: slideUp 0.3s ease-out;
            `;
            document.body.appendChild(toast);
        }

        let message = 'An error occurred';
        if (this.isTracking) {
            message = 'An error occurred. Your progress has been saved.';
        } else if (errorInfo.type === 'unhandledrejection') {
            message = 'A background task failed. Please try again.';
        }

        toast.textContent = message;
        toast.style.display = 'block';

        // Auto-hide after 5 seconds
        setTimeout(() => {
            if (toast) {
                toast.style.display = 'none';
            }
        }, 5000);
    },

    /**
     * Report error to analytics (privacy-preserving)
     * @param {Object} errorInfo - Error information
     */
    async reportToAnalytics(errorInfo) {
        // Only report if analytics is available
        if (window.Analytics && typeof window.Analytics.track === 'function') {
            try {
                await window.Analytics.track('error', {
                    message: errorInfo.message,
                    type: errorInfo.type,
                    timestamp: errorInfo.timestamp
                });
            } catch (e) {
                // Silent fail - don't cause more errors
            }
        }
    },

    /**
     * Set tracking state
     * @param {boolean} isTracking - Whether GPS tracking is active
     */
    setTrackingState(isTracking) {
        this.isTracking = isTracking;
    },

    /**
     * Get error log
     * @returns {Array} Error history
     */
    getErrors() {
        return [...this.errors];
    },

    /**
     * Clear error log
     */
    clearErrors() {
        this.errors = [];
    },

    /**
     * Create a wrapped function that catches errors
     * @param {Function} fn - Function to wrap
     * @param {string} context - Context name
     * @returns {Function} Wrapped function
     */
    wrap(fn, context = 'unknown') {
        return (...args) => {
            try {
                return fn(...args);
            } catch (error) {
                this.handleError(error, { context, type: 'wrapped' });
                throw error; // Re-throw to maintain expected behavior
            }
        };
    },

    /**
     * Create async wrapped function
     * @param {Function} fn - Async function to wrap
     * @param {string} context - Context name
     * @returns {Function} Wrapped async function
     */
    wrapAsync(fn, context = 'unknown') {
        return async (...args) => {
            try {
                return await fn(...args);
            } catch (error) {
                this.handleError(error, { context, type: 'wrapped-async' });
                throw error;
            }
        };
    }
};

// Initialize on load
document.addEventListener('DOMContentLoaded', () => {
    ErrorTracker.init();
});

// Make available globally
window.ErrorTracker = ErrorTracker;
