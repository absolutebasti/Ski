/**
 * KitzSki Tracker - Utility Functions
 */

const Utils = {
    /**
     * Calculate distance between two GPS coordinates using Haversine formula
     * @param {number} lat1 - Latitude of first point
     * @param {number} lon1 - Longitude of first point
     * @param {number} lat2 - Latitude of second point
     * @param {number} lon2 - Longitude of second point
     * @returns {number} Distance in meters
     */
    calculateDistance(lat1, lon1, lat2, lon2) {
        const R = 6371000; // Earth's radius in meters
        const φ1 = lat1 * Math.PI / 180;
        const φ2 = lat2 * Math.PI / 180;
        const Δφ = (lat2 - lat1) * Math.PI / 180;
        const Δλ = (lon2 - lon1) * Math.PI / 180;

        const a = Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
                  Math.cos(φ1) * Math.cos(φ2) *
                  Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
        
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

        return R * c;
    },

    /**
     * Convert meters per second to km/h
     * @param {number} mps - Speed in m/s
     * @returns {number} Speed in km/h
     */
    mpsToKmh(mps) {
        return mps * 3.6;
    },

    /**
     * Convert km/h to mph
     * @param {number} kmh - Speed in km/h
     * @returns {number} Speed in mph
     */
    kmhToMph(kmh) {
        return kmh * 0.621371;
    },

    /**
     * Convert kilometers to miles
     * @param {number} km - Distance in kilometers
     * @returns {number} Distance in miles
     */
    kmToMiles(km) {
        return km * 0.621371;
    },

    /**
     * Convert meters to feet
     * @param {number} m - Distance in meters
     * @returns {number} Distance in feet
     */
    metersToFeet(m) {
        return m * 3.28084;
    },

    /**
     * Format duration from milliseconds to MM:SS or HH:MM:SS
     * @param {number} ms - Duration in milliseconds
     * @returns {string} Formatted duration string
     */
    formatDuration(ms) {
        const totalSeconds = Math.floor(ms / 1000);
        const hours = Math.floor(totalSeconds / 3600);
        const minutes = Math.floor((totalSeconds % 3600) / 60);
        const seconds = totalSeconds % 60;

        if (hours > 0) {
            return `${hours}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
        }
        return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
    },

    /**
     * Format a date for display
     * @param {Date} date - Date object
     * @returns {string} Formatted date string
     */
    formatDate(date) {
        const now = new Date();
        const yesterday = new Date(now);
        yesterday.setDate(yesterday.getDate() - 1);

        if (date.toDateString() === now.toDateString()) {
            return 'Today';
        } else if (date.toDateString() === yesterday.toDateString()) {
            return 'Yesterday';
        } else {
            return date.toLocaleDateString('en-US', {
                month: 'short',
                day: 'numeric',
                year: date.getFullYear() !== now.getFullYear() ? 'numeric' : undefined
            });
        }
    },

    /**
     * Format time from Date object
     * @param {Date} date - Date object
     * @returns {string} Formatted time string
     */
    formatTime(date) {
        return date.toLocaleTimeString('en-US', {
            hour: '2-digit',
            minute: '2-digit',
            hour12: false
        });
    },

    /**
     * Generate a unique ID
     * @returns {string} Unique ID string
     */
    generateId() {
        return Date.now().toString(36) + Math.random().toString(36).substr(2);
    },

    /**
     * Debounce function
     * @param {Function} func - Function to debounce
     * @param {number} wait - Wait time in ms
     * @returns {Function} Debounced function
     */
    debounce(func, wait) {
        let timeout;
        return function executedFunction(...args) {
            const later = () => {
                clearTimeout(timeout);
                func(...args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
        };
    },

    /**
     * Throttle function
     * @param {Function} func - Function to throttle
     * @param {number} limit - Time limit in ms
     * @returns {Function} Throttled function
     */
    throttle(func, limit) {
        let inThrottle;
        return function executedFunction(...args) {
            if (!inThrottle) {
                func(...args);
                inThrottle = true;
                setTimeout(() => inThrottle = false, limit);
            }
        };
    },

    /**
     * Smooth value animation for display
     * @param {number} current - Current value
     * @param {number} target - Target value
     * @param {number} factor - Smoothing factor (0-1)
     * @returns {number} Smoothed value
     */
    smoothValue(current, target, factor = 0.3) {
        return current + (target - factor) * factor;
    },

    /**
     * Get speed category for color coding
     * @param {number} speed - Speed in km/h
     * @returns {string} Speed category
     */
    getSpeedCategory(speed) {
        if (speed < 20) return 'slow';
        if (speed < 40) return 'medium';
        if (speed < 60) return 'fast';
        return 'extreme';
    },

    /**
     * Check if the device is online
     * @returns {boolean} Online status
     */
    isOnline() {
        return navigator.onLine;
    },

    /**
     * Check if running as installed PWA
     * @returns {boolean} PWA status
     */
    isPWA() {
        return window.matchMedia('(display-mode: standalone)').matches ||
               window.navigator.standalone === true;
    },

    /**
     * Vibrate device if supported
     * @param {number|number[]} pattern - Vibration pattern
     */
    vibrate(pattern = 50) {
        if ('vibrate' in navigator) {
            navigator.vibrate(pattern);
        }
    },

    /**
     * Prevent screen from sleeping (if supported)
     * @returns {Promise} Wake lock promise
     */
    async requestWakeLock() {
        if ('wakeLock' in navigator) {
            try {
                return await navigator.wakeLock.request('screen');
            } catch (err) {
                console.log('Wake Lock error:', err);
            }
        }
        return null;
    },

    /**
     * Calculate average of an array
     * @param {number[]} arr - Array of numbers
     * @returns {number} Average value
     */
    average(arr) {
        if (arr.length === 0) return 0;
        return arr.reduce((a, b) => a + b, 0) / arr.length;
    },

    /**
     * Clamp a value between min and max
     * @param {number} value - Value to clamp
     * @param {number} min - Minimum value
     * @param {number} max - Maximum value
     * @returns {number} Clamped value
     */
    clamp(value, min, max) {
        return Math.min(Math.max(value, min), max);
    }
};

// Make Utils available globally
window.Utils = Utils;

