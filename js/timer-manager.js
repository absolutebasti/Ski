/**
 * KitzSki Tracker - Timer Manager
 * HIGH-006: Memory Leak - Uncleared Intervals/Timers
 * 
 * Centralized timer management to prevent memory leaks from uncleared
 * intervals and timeouts.
 */

const TimerManager = {
    // Store all active timers
    timers: new Map(),
    timerId: 0,
    
    /**
     * Set a timeout with automatic tracking
     * @param {Function} callback - Function to execute
     * @param {number} delay - Delay in milliseconds
     * @param {string} name - Timer name for debugging
     * @param {...any} args - Arguments to pass to callback
     * @returns {number} Timer ID
     */
    setTimeout(callback, delay, name = 'unnamed', ...args) {
        const id = ++this.timerId;
        const timeoutId = setTimeout((...callbackArgs) => {
            this.timers.delete(id);
            callback(...callbackArgs);
        }, delay, ...args);
        
        this.timers.set(id, {
            type: 'timeout',
            timeoutId,
            name,
            created: Date.now()
        });
        
        return id;
    },
    
    /**
     * Set an interval with automatic tracking
     * @param {Function} callback - Function to execute
     * @param {number} delay - Interval in milliseconds
     * @param {string} name - Timer name for debugging
     * @param {...any} args - Arguments to pass to callback
     * @returns {number} Timer ID
     */
    setInterval(callback, delay, name = 'unnamed', ...args) {
        const id = ++this.timerId;
        const intervalId = setInterval(callback, delay, ...args);
        
        this.timers.set(id, {
            type: 'interval',
            intervalId,
            name,
            created: Date.now()
        });
        
        return id;
    },
    
    /**
     * Clear a timeout by TimerManager ID
     * @param {number} id - Timer ID from setTimeout
     */
    clearTimeout(id) {
        if (!id) return;
        
        const timer = this.timers.get(id);
        if (timer && timer.type === 'timeout') {
            clearTimeout(timer.timeoutId);
            this.timers.delete(id);
        }
    },
    
    /**
     * Clear an interval by TimerManager ID
     * @param {number} id - Timer ID from setInterval
     */
    clearInterval(id) {
        if (!id) return;
        
        const timer = this.timers.get(id);
        if (timer && timer.type === 'interval') {
            clearInterval(timer.intervalId);
            this.timers.delete(id);
        }
    },
    
    /**
     * Clear all timers matching a name pattern
     * @param {string|RegExp} pattern - Name pattern to match
     */
    clearByName(pattern) {
        const regex = pattern instanceof RegExp ? pattern : new RegExp(pattern);
        
        for (const [id, timer] of this.timers.entries()) {
            if (regex.test(timer.name)) {
                if (timer.type === 'timeout') {
                    clearTimeout(timer.timeoutId);
                } else if (timer.type === 'interval') {
                    clearInterval(timer.intervalId);
                }
                this.timers.delete(id);
            }
        }
    },
    
    /**
     * Clear all active timers
     */
    clearAll() {
        for (const [id, timer] of this.timers.entries()) {
            if (timer.type === 'timeout') {
                clearTimeout(timer.timeoutId);
            } else if (timer.type === 'interval') {
                clearInterval(timer.intervalId);
            }
        }
        this.timers.clear();
    },
    
    /**
     * Get active timer count
     * @returns {number} Number of active timers
     */
    getActiveCount() {
        return this.timers.size;
    },
    
    /**
     * Get active timers info (for debugging)
     * @returns {Array} Array of timer info objects
     */
    getActiveTimers() {
        return Array.from(this.timers.entries()).map(([id, timer]) => ({
            id,
            type: timer.type,
            name: timer.name,
            age: Date.now() - timer.created
        }));
    },
    
    /**
     * Clean up old timers (defensive cleanup)
     * Removes timers older than maxAge
     * @param {number} maxAge - Maximum age in milliseconds
     */
    cleanup(maxAge = 300000) { // 5 minutes default
        const now = Date.now();
        let cleaned = 0;
        
        for (const [id, timer] of this.timers.entries()) {
            if (now - timer.created > maxAge) {
                if (timer.type === 'timeout') {
                    clearTimeout(timer.timeoutId);
                } else if (timer.type === 'interval') {
                    clearInterval(timer.intervalId);
                }
                this.timers.delete(id);
                cleaned++;
            }
        }
        
        if (cleaned > 0) {
            console.log(`[TimerManager] Cleaned up ${cleaned} old timers`);
        }
    }
};

// Cleanup on page unload
window.addEventListener('beforeunload', () => {
    TimerManager.clearAll();
});

// Periodic cleanup every 5 minutes
setInterval(() => {
    TimerManager.cleanup();
}, 300000);

// Make available globally
window.TimerManager = TimerManager;
