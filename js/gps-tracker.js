/**
 * KitzSki Tracker - GPS Tracking Engine
 */

const GPSTracker = {
    watchId: null,
    isTracking: false,
    isPaused: false,
    
    // Current position data
    currentPosition: null,
    previousPosition: null,
    
    // Tracking data
    trackingData: {
        positions: [],
        startTime: null,
        pauseTime: null,
        totalPausedTime: 0
    },
    
    // Callbacks
    onPositionUpdate: null,
    onError: null,
    
    // Settings
    options: {
        enableHighAccuracy: true,
        maximumAge: 1000,
        timeout: 10000
    },
    
    // Filtering settings
    minAccuracy: 30, // meters - reject readings with worse accuracy
    minDistance: 2, // meters - minimum distance to register movement
    speedSmoothingFactor: 0.4,
    
    // Speed calculation
    lastSpeeds: [],
    maxSpeedSamples: 5,

    /**
     * Check if GPS is available
     * @returns {boolean} GPS availability
     */
    isAvailable() {
        return 'geolocation' in navigator;
    },

    /**
     * Request GPS permission
     * @returns {Promise} Permission result
     */
    async requestPermission() {
        if (!this.isAvailable()) {
            throw new Error('Geolocation is not supported');
        }

        return new Promise((resolve, reject) => {
            navigator.geolocation.getCurrentPosition(
                (position) => {
                    this.currentPosition = this.processPosition(position);
                    resolve(this.currentPosition);
                },
                (error) => {
                    reject(this.handleError(error));
                },
                { enableHighAccuracy: true, timeout: 10000 }
            );
        });
    },

    /**
     * Start GPS tracking
     * @param {Function} onUpdate - Position update callback
     * @param {Function} onError - Error callback
     */
    startTracking(onUpdate, onError) {
        if (!this.isAvailable()) {
            onError(new Error('Geolocation is not supported'));
            return;
        }

        this.onPositionUpdate = onUpdate;
        this.onError = onError;
        this.isTracking = true;
        this.isPaused = false;
        
        // Reset tracking data
        this.trackingData = {
            positions: [],
            startTime: Date.now(),
            pauseTime: null,
            totalPausedTime: 0
        };
        
        this.lastSpeeds = [];
        this.previousPosition = null;

        // Start watching position
        this.watchId = navigator.geolocation.watchPosition(
            (position) => this.handlePosition(position),
            (error) => this.handleError(error),
            this.options
        );

        console.log('GPS tracking started');
    },

    /**
     * Pause tracking
     */
    pause() {
        if (this.isTracking && !this.isPaused) {
            this.isPaused = true;
            this.trackingData.pauseTime = Date.now();
            console.log('GPS tracking paused');
        }
    },

    /**
     * Resume tracking
     */
    resume() {
        if (this.isTracking && this.isPaused) {
            this.isPaused = false;
            if (this.trackingData.pauseTime) {
                this.trackingData.totalPausedTime += Date.now() - this.trackingData.pauseTime;
                this.trackingData.pauseTime = null;
            }
            console.log('GPS tracking resumed');
        }
    },

    /**
     * Stop GPS tracking
     * @returns {Object} Final tracking data
     */
    stopTracking() {
        if (this.watchId !== null) {
            navigator.geolocation.clearWatch(this.watchId);
            this.watchId = null;
        }

        this.isTracking = false;
        this.isPaused = false;
        
        const finalData = this.getTrackingData();
        console.log('GPS tracking stopped', finalData);
        
        return finalData;
    },

    /**
     * Handle incoming position data
     * @param {GeolocationPosition} position - Raw position from GPS
     */
    handlePosition(position) {
        if (this.isPaused) return;

        const processed = this.processPosition(position);
        
        // Filter out inaccurate readings
        if (processed.accuracy > this.minAccuracy) {
            console.log('Rejecting inaccurate reading:', processed.accuracy);
            return;
        }

        // Store previous position
        this.previousPosition = this.currentPosition;
        this.currentPosition = processed;

        // Add to track
        this.trackingData.positions.push({
            lat: processed.latitude,
            lon: processed.longitude,
            alt: processed.altitude,
            speed: processed.speed,
            timestamp: processed.timestamp
        });

        // Calculate distance from previous position
        if (this.previousPosition) {
            const distance = Utils.calculateDistance(
                this.previousPosition.latitude,
                this.previousPosition.longitude,
                processed.latitude,
                processed.longitude
            );
            processed.distanceFromPrevious = distance;
        }

        // Smooth speed using moving average
        processed.smoothedSpeed = this.getSmoothedSpeed(processed.speed);

        // Notify callback
        if (this.onPositionUpdate) {
            this.onPositionUpdate(processed);
        }
    },

    /**
     * Process raw GPS position into usable format
     * @param {GeolocationPosition} position - Raw position
     * @returns {Object} Processed position data
     */
    processPosition(position) {
        const { coords, timestamp } = position;
        
        // Convert speed from m/s to km/h
        let speedKmh = 0;
        if (coords.speed !== null && coords.speed >= 0) {
            speedKmh = Utils.mpsToKmh(coords.speed);
        }

        return {
            latitude: coords.latitude,
            longitude: coords.longitude,
            altitude: coords.altitude,
            accuracy: coords.accuracy,
            altitudeAccuracy: coords.altitudeAccuracy,
            heading: coords.heading,
            speed: speedKmh, // km/h
            speedRaw: coords.speed, // m/s (original)
            timestamp: timestamp
        };
    },

    /**
     * Get smoothed speed using moving average
     * @param {number} speed - Current speed
     * @returns {number} Smoothed speed
     */
    getSmoothedSpeed(speed) {
        // Add to samples
        this.lastSpeeds.push(speed);
        
        // Keep only recent samples
        if (this.lastSpeeds.length > this.maxSpeedSamples) {
            this.lastSpeeds.shift();
        }
        
        // Calculate weighted average (more weight to recent)
        let weightedSum = 0;
        let weightSum = 0;
        
        this.lastSpeeds.forEach((s, i) => {
            const weight = i + 1; // Increasing weight for newer samples
            weightedSum += s * weight;
            weightSum += weight;
        });
        
        return weightSum > 0 ? weightedSum / weightSum : speed;
    },

    /**
     * Handle GPS errors
     * @param {GeolocationPositionError} error - GPS error
     */
    handleError(error) {
        let message;
        
        switch (error.code) {
            case error.PERMISSION_DENIED:
                message = 'Location permission denied. Please enable location access.';
                break;
            case error.POSITION_UNAVAILABLE:
                message = 'Location unavailable. Make sure GPS is enabled.';
                break;
            case error.TIMEOUT:
                message = 'Location request timed out. Trying again...';
                break;
            default:
                message = 'An unknown GPS error occurred.';
        }
        
        console.error('GPS Error:', message, error);
        
        if (this.onError) {
            this.onError({ code: error.code, message });
        }
        
        return { code: error.code, message };
    },

    /**
     * Get current tracking data summary
     * @returns {Object} Tracking data summary
     */
    getTrackingData() {
        const positions = this.trackingData.positions;
        
        // Calculate total distance
        let totalDistance = 0;
        for (let i = 1; i < positions.length; i++) {
            totalDistance += Utils.calculateDistance(
                positions[i - 1].lat,
                positions[i - 1].lon,
                positions[i].lat,
                positions[i].lon
            );
        }

        // Calculate max speed
        const maxSpeed = positions.reduce((max, p) => Math.max(max, p.speed || 0), 0);
        
        // Calculate average speed (excluding zeros)
        const nonZeroSpeeds = positions.filter(p => p.speed > 1).map(p => p.speed);
        const avgSpeed = Utils.average(nonZeroSpeeds);

        // Calculate vertical drop
        const altitudes = positions.filter(p => p.alt !== null).map(p => p.alt);
        let verticalDrop = 0;
        let totalAscent = 0;
        
        if (altitudes.length > 1) {
            for (let i = 1; i < altitudes.length; i++) {
                const diff = altitudes[i - 1] - altitudes[i];
                if (diff > 0) {
                    verticalDrop += diff;
                } else {
                    totalAscent += Math.abs(diff);
                }
            }
        }

        // Calculate duration
        const endTime = this.isPaused ? this.trackingData.pauseTime : Date.now();
        const activeDuration = endTime - this.trackingData.startTime - this.trackingData.totalPausedTime;

        return {
            positions,
            distance: totalDistance / 1000, // km
            maxSpeed,
            avgSpeed,
            verticalDrop: Math.round(verticalDrop),
            totalAscent: Math.round(totalAscent),
            duration: activeDuration,
            startTime: this.trackingData.startTime,
            endTime: endTime,
            startAltitude: altitudes[0] || null,
            endAltitude: altitudes[altitudes.length - 1] || null
        };
    },

    /**
     * Get GPS accuracy description
     * @param {number} accuracy - Accuracy in meters
     * @returns {string} Accuracy level
     */
    getAccuracyLevel(accuracy) {
        if (accuracy <= 5) return 'excellent';
        if (accuracy <= 10) return 'good';
        if (accuracy <= 20) return 'fair';
        return 'poor';
    },

    /**
     * Update tracking options
     * @param {Object} options - New options
     */
    updateOptions(options) {
        this.options = { ...this.options, ...options };
        
        // Restart tracking with new options if currently tracking
        if (this.isTracking) {
            if (this.watchId !== null) {
                navigator.geolocation.clearWatch(this.watchId);
            }
            
            this.watchId = navigator.geolocation.watchPosition(
                (position) => this.handlePosition(position),
                (error) => this.handleError(error),
                this.options
            );
        }
    },

    /**
     * Get current position (one-time)
     * @returns {Promise} Current position
     */
    async getCurrentPosition() {
        return new Promise((resolve, reject) => {
            navigator.geolocation.getCurrentPosition(
                (position) => {
                    resolve(this.processPosition(position));
                },
                (error) => {
                    reject(this.handleError(error));
                },
                this.options
            );
        });
    }
};

// Make GPSTracker available globally
window.GPSTracker = GPSTracker;

