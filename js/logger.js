/**
 * KitzSki Tracker - Production Logger
 * CRITICAL-009: Fix Console.log Statements in Production
 * 
 * Replaces console.log with a logger that can be disabled in production
 * while preserving error logging for debugging.
 */

const Logger = {
    // Enable/disable logging based on environment
    enabled: (typeof process !== 'undefined' && process.env && process.env.NODE_ENV !== 'production') || 
             (typeof window !== 'undefined' && window.location && window.location.hostname === 'localhost') ||
             (typeof window !== 'undefined' && window.location && window.location.hostname === '127.0.0.1'),
    
    // Minimum level to log (debug, info, warn, error)
    minLevel: 'debug',
    
    // Log level priorities
    levels: {
        debug: 0,
        info: 1,
        warn: 2,
        error: 3
    },

    /**
     * Debug level logging (development only)
     * @param {...any} args - Arguments to log
     */
    debug(...args) {
        if (this.enabled && this.levels[this.minLevel] <= this.levels.debug) {
            console.debug('[DEBUG]', ...args);
        }
    },

    /**
     * Info level logging
     * @param {...any} args - Arguments to log
     */
    log(...args) {
        if (this.enabled && this.levels[this.minLevel] <= this.levels.info) {
            console.log(...args);
        }
    },

    /**
     * Info level logging with prefix
     * @param {...any} args - Arguments to log
     */
    info(...args) {
        if (this.enabled && this.levels[this.minLevel] <= this.levels.info) {
            console.info('[INFO]', ...args);
        }
    },

    /**
     * Warning level logging (always enabled in development, sampled in production)
     * @param {...any} args - Arguments to log
     */
    warn(...args) {
        // Always log warnings, but in production use console.warn directly
        console.warn('[WARN]', ...args);
    },

    /**
     * Error level logging (always enabled)
     * Sends to error tracking service in production
     * @param {...any} args - Arguments to log
     */
    error(...args) {
        // Always log errors
        console.error('[ERROR]', ...args);
        
        // Send to error tracking if available
        if (typeof window !== 'undefined' && window.ErrorTracker && typeof window.ErrorTracker.handleError === 'function') {
            const error = args.find(arg => arg instanceof Error) || new Error(args.join(' '));
            window.ErrorTracker.handleError(error, { context: 'Logger.error', args });
        }
    },

    /**
     * Group related logs (development only)
     * @param {string} label - Group label
     */
    group(label) {
        if (this.enabled) {
            console.group(label);
        }
    },

    /**
     * End group (development only)
     */
    groupEnd() {
        if (this.enabled) {
            console.groupEnd();
        }
    },

    /**
     * Time a function (development only)
     * @param {string} label - Timer label
     */
    time(label) {
        if (this.enabled) {
            console.time(label);
        }
    },

    /**
     * End timer (development only)
     * @param {string} label - Timer label
     */
    timeEnd(label) {
        if (this.enabled) {
            console.timeEnd(label);
        }
    },

    /**
     * Set logging enabled/disabled
     * @param {boolean} enabled - Whether logging is enabled
     */
    setEnabled(enabled) {
        this.enabled = enabled;
    },

    /**
     * Set minimum log level
     * @param {string} level - Minimum level (debug, info, warn, error)
     */
    setMinLevel(level) {
        if (this.levels[level] !== undefined) {
            this.minLevel = level;
        }
    }
};

// Make available globally
window.Logger = Logger;
