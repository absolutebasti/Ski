/**
 * KitzSki Tracker - GPS Tracking Engine with Kalman Filtering
 * 
 * Implements Kalman filtering for improved GPS accuracy in alpine environments
 * where multipath errors (reflections from snow/mountains) are common.
 */

/**
 * 1D Kalman Filter for smoothing sensor data
 * Optimized for GPS measurements with adaptive noise filtering
 */
class KalmanFilter {
    constructor(options = {}) {
        // Process noise (how much the system can change between measurements)
        this.Q = options.processNoise || 0.01;
        
        // Measurement noise (how noisy the sensor is)
        this.R = options.measurementNoise || 1;
        
        // Estimation error covariance
        this.P = options.initialError || 1;
        
        // State estimate
        this.X = options.initialValue || 0;
        
        // Adaptive filtering: adjust noise based on measurement quality
        this.adaptive = options.adaptive !== false;
        this.minR = options.minMeasurementNoise || 0.1;
        this.maxR = options.maxMeasurementNoise || 10;
    }

    /**
     * Filter a measurement
     * @param {number} measurement - Raw measurement value
     * @param {number} accuracy - Optional accuracy indicator (lower is better)
     * @returns {number} Filtered value
     */
    filter(measurement, accuracy = null) {
        // Adaptive noise adjustment based on accuracy
        if (this.adaptive && accuracy !== null) {
            // Scale measurement noise based on accuracy
            // Higher accuracy value = more noise = less trust in measurement
            this.R = Math.max(this.minR, Math.min(this.maxR, accuracy / 10));
        }

        // Prediction step
        // X = X (state doesn't change in our model)
        this.P = this.P + this.Q;

        // Update step
        const K = this.P / (this.P + this.R); // Kalman gain
        this.X = this.X + K * (measurement - this.X);
        this.P = (1 - K) * this.P;

        return this.X;
    }

    /**
     * Reset the filter
     * @param {number} initialValue - New initial value
     */
    reset(initialValue = 0) {
        this.X = initialValue;
        this.P = 1;
    }

    /**
     * Get current filtered value without updating
     * @returns {number} Current estimate
     */
    getValue() {
        return this.X;
    }
}

/**
 * 2D Kalman Filter for position (latitude/longitude)
 * Tracks position with velocity for smoother predictions
 */
class KalmanFilter2D {
    constructor(options = {}) {
        // State: [x, y, vx, vy] - position and velocity
        this.state = new Float64Array([0, 0, 0, 0]);
        
        // State covariance matrix (4x4)
        this.P = new Float64Array([
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            0, 0, 0, 1
        ]);
        
        // Process noise
        const posNoise = options.positionNoise || 0.01;
        const velNoise = options.velocityNoise || 0.1;
        this.Q = new Float64Array([
            posNoise, 0, 0, 0,
            0, posNoise, 0, 0,
            0, 0, velNoise, 0,
            0, 0, 0, velNoise
        ]);
        
        // Measurement noise (varies with GPS accuracy)
        this.R_base = options.measurementNoise || 1;
        this.minAccuracy = options.minAccuracy || 5;
        this.maxAccuracy = options.maxAccuracy || 50;
        
        // Time step
        this.dt = options.dt || 1;
        this.lastTime = null;
    }

    /**
     * Predict step (using constant velocity model)
     * @param {number} dt - Time delta in seconds
     */
    predict(dt) {
        if (!dt || dt <= 0) dt = this.dt;
        
        // State transition matrix F
        // [1, 0, dt, 0]
        // [0, 1, 0, dt]
        // [0, 0, 1,  0]
        // [0, 0, 0,  1]
        
        // X = F * X (state prediction)
        const x = this.state[0];
        const y = this.state[1];
        const vx = this.state[2];
        const vy = this.state[3];
        
        this.state[0] = x + vx * dt;
        this.state[1] = y + vy * dt;
        // velocity remains the same
        
        // P = F * P * F' + Q (covariance prediction)
        // Simplified for constant velocity model
        this.P[0] += this.P[2] * dt + this.P[8] * dt + this.P[10] * dt * dt + this.Q[0];
        this.P[1] += this.P[3] * dt + this.P[9] * dt + this.P[11] * dt * dt;
        this.P[4] += this.P[6] * dt + this.P[12] * dt + this.P[14] * dt * dt;
        this.P[5] += this.P[7] * dt + this.P[13] * dt + this.P[15] * dt * dt + this.Q[5];
        this.P[2] += this.P[10] * dt;
        this.P[3] += this.P[11] * dt;
        this.P[6] += this.P[14] * dt;
        this.P[7] += this.P[15] * dt;
        this.P[8] += this.P[10] * dt;
        this.P[9] += this.P[11] * dt;
        this.P[12] += this.P[14] * dt;
        this.P[13] += this.P[15] * dt;
        this.P[10] += this.Q[10];
        this.P[15] += this.Q[15];
    }

    /**
     * Update step with new measurement
     * @param {number} x - Measured x position
     * @param {number} y - Measured y position
     * @param {number} accuracy - GPS accuracy in meters
     * @param {number} timestamp - Timestamp in ms
     */
    update(x, y, accuracy = 10, timestamp = null) {
        // Calculate dt
        let dt = this.dt;
        if (timestamp && this.lastTime) {
            dt = (timestamp - this.lastTime) / 1000;
            if (dt <= 0 || dt > 10) dt = this.dt; // Sanity check
        }
        this.lastTime = timestamp;
        
        // Predict step
        this.predict(dt);
        
        // Calculate measurement noise based on accuracy
        const R = this.R_base * Math.max(0.5, accuracy / this.minAccuracy);
        
        // Innovation (measurement - prediction)
        const ix = x - this.state[0];
        const iy = y - this.state[1];
        
        // Innovation covariance
        const Sx = this.P[0] + R;
        const Sy = this.P[5] + R;
        
        // Kalman gain
        const Kx = this.P[0] / Sx;
        const Ky = this.P[5] / Sy;
        const Kvx = this.P[2] / Sx;
        const Kvy = this.P[7] / Sy;
        
        // Update state
        this.state[0] += Kx * ix;
        this.state[1] += Ky * iy;
        this.state[2] += Kvx * ix;
        this.state[3] += Kvy * iy;
        
        // Update covariance
        this.P[0] = (1 - Kx) * this.P[0];
        this.P[5] = (1 - Ky) * this.P[5];
        this.P[2] = (1 - Kx) * this.P[2];
        this.P[7] = (1 - Ky) * this.P[7];
        
        return {
            x: this.state[0],
            y: this.state[1],
            vx: this.state[2],
            vy: this.state[3]
        };
    }

    /**
     * Get current filtered position
     * @returns {Object} {x, y, vx, vy}
     */
    getPosition() {
        return {
            x: this.state[0],
            y: this.state[1],
            vx: this.state[2],
            vy: this.state[3]
        };
    }

    /**
     * Get current speed from velocity components
     * @returns {number} Speed in m/s
     */
    getSpeed() {
        return Math.sqrt(this.state[2] * this.state[2] + this.state[3] * this.state[3]);
    }

    /**
     * Reset the filter
     */
    reset(x = 0, y = 0) {
        this.state[0] = x;
        this.state[1] = y;
        this.state[2] = 0;
        this.state[3] = 0;
        this.P.fill(0);
        this.P[0] = 1;
        this.P[5] = 1;
        this.P[10] = 1;
        this.P[15] = 1;
        this.lastTime = null;
    }
}

/**
 * GPS Tracker with Kalman Filtering
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
    
    // Memory management - CRITICAL FIX for memory leak
    POSITION_BUFFER_LIMIT: 5000,     // Max positions in memory
    POSITION_FLUSH_SIZE: 2500,       // Number to flush when limit reached
    flushedPositionCount: 0,         // Track total flushed positions
    runId: null,                     // Current run ID for storage
    
    // Callbacks
    onPositionUpdate: null,
    onError: null,
    
    // Settings
    options: {
        enableHighAccuracy: true,
        maximumAge: 1000,
        timeout: 10000
    },
    
    // Filtering settings - improved for alpine environments
    minAccuracy: 20, // meters - reduced from 50 for better filtering
    minDistance: 2, // meters - reduced for better precision
    minSpeedThreshold: 1, // km/h - reduced for better sensitivity
    
    // Kalman filters
    kalmanPosition: null,
    kalmanAltitude: null,
    kalmanSpeed: null,
    
    // Speed calculation (legacy fallback)
    lastSpeeds: [],
    maxSpeedSamples: 5,
    lastPositionTime: null,
    lastPosition: null,
    
    // Altitude history for smoothing
    altitudeHistory: [],
    maxAltitudeSamples: 10,

    /**
     * Check if GPS is available
     * @returns {boolean} GPS availability
     */
    isAvailable() {
        return 'geolocation' in navigator;
    },

    /**
     * Initialize Kalman filters
     */
    initKalmanFilters() {
        // Position filter with adaptive noise based on accuracy
        this.kalmanPosition = new KalmanFilter2D({
            positionNoise: 0.001,
            velocityNoise: 0.01,
            measurementNoise: 1,
            minAccuracy: 5,
            maxAccuracy: 50,
            dt: 1
        });
        
        // Altitude filter - GPS altitude is notoriously noisy
        this.kalmanAltitude = new KalmanFilter({
            processNoise: 0.005,
            measurementNoise: 5, // High noise for altitude
            minMeasurementNoise: 1,
            maxMeasurementNoise: 50,
            adaptive: true
        });
        
        // Speed filter for final smoothing
        this.kalmanSpeed = new KalmanFilter({
            processNoise: 0.01,
            measurementNoise: 2,
            minMeasurementNoise: 0.5,
            maxMeasurementNoise: 10,
            adaptive: true
        });
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
     * @param {string} runId - Optional run ID for storage
     */
    startTracking(onUpdate, onError, runId = null) {
        if (!this.isAvailable()) {
            onError(new Error('Geolocation is not supported'));
            return;
        }

        this.onPositionUpdate = onUpdate;
        this.onError = onError;
        this.isTracking = true;
        this.isPaused = false;
        this.runId = runId || `run-${Date.now()}`;
        this.flushedPositionCount = 0;
        
        // Reset tracking data
        this.trackingData = {
            positions: [],
            startTime: Date.now(),
            pauseTime: null,
            totalPausedTime: 0
        };
        
        this.lastSpeeds = [];
        this.altitudeHistory = [];
        this.previousPosition = null;
        
        // Initialize Kalman filters
        this.initKalmanFilters();

        // Start watching position
        this.watchId = navigator.geolocation.watchPosition(
            (position) => this.handlePosition(position),
            (error) => this.handleError(error),
            this.options
        );

        console.log('[GPS] Tracking started with Kalman filtering, runId:', this.runId);
    },

    /**
     * Flush positions to IndexedDB to prevent memory leak
     * CRITICAL FIX: Implements circular buffer pattern
     */
    async flushPositionsToStorage() {
        if (!this.runId || this.trackingData.positions.length === 0) {
            return;
        }

        try {
            // Save the oldest positions that will be removed from memory
            const positionsToFlush = this.trackingData.positions.slice(0, this.POSITION_FLUSH_SIZE);
            
            // Store in IndexedDB via Storage module (if available)
            if (window.Storage && typeof window.Storage.saveTrackingProgress === 'function') {
                await window.Storage.saveTrackingProgress(this.runId, positionsToFlush, this.flushedPositionCount);
            }
            
            // Remove flushed positions from memory
            this.trackingData.positions = this.trackingData.positions.slice(this.POSITION_FLUSH_SIZE);
            this.flushedPositionCount += positionsToFlush.length;
            
            console.log(`[GPS] Flushed ${positionsToFlush.length} positions to storage. In memory: ${this.trackingData.positions.length}, Total flushed: ${this.flushedPositionCount}`);
        } catch (error) {
            console.error('[GPS] Failed to flush positions:', error);
            // If flush fails, continue with positions in memory - don't lose data
        }
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
     * @returns {Promise<Object>} Final tracking data
     */
    async stopTracking() {
        if (this.watchId !== null) {
            navigator.geolocation.clearWatch(this.watchId);
            this.watchId = null;
        }

        this.isTracking = false;
        this.isPaused = false;
        
        const finalData = await this.getTrackingData();
        
        // Cleanup tracking progress from storage
        await this.cleanupTrackingProgress();
        
        console.log('[GPS] Tracking stopped', finalData);
        
        return finalData;
    },

    /**
     * Handle incoming position data
     * @param {GeolocationPosition} position - Raw position from GPS
     */
    async handlePosition(position) {
        if (this.isPaused) return;

        const processed = this.processPosition(position);
        
        // Filter out very inaccurate readings
        if (processed.accuracy > this.minAccuracy * 2) {
            console.log('[GPS] Rejecting very inaccurate reading:', processed.accuracy);
            return;
        }

        // Validate position data (CRITICAL-006: Input validation)
        if (!this.validatePosition(processed)) {
            console.warn('[GPS] Invalid position data rejected:', processed);
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
            timestamp: processed.timestamp,
            accuracy: processed.accuracy,
            filtered: true
        });

        // CRITICAL FIX: Check if we need to flush positions to prevent memory leak
        if (this.trackingData.positions.length >= this.POSITION_BUFFER_LIMIT) {
            await this.flushPositionsToStorage();
        }

        // Notify callback
        if (this.onPositionUpdate) {
            this.onPositionUpdate(processed);
        }
    },

    /**
     * Validate GPS position data
     * CRITICAL-006: Input validation for GPS Position Data
     * @param {Object} pos - Processed position object
     * @returns {boolean} True if valid
     */
    validatePosition(pos) {
        // Check coordinate bounds
        if (pos.latitude < -90 || pos.latitude > 90) {
            console.warn('[GPS] Invalid latitude:', pos.latitude);
            return false;
        }
        if (pos.longitude < -180 || pos.longitude > 180) {
            console.warn('[GPS] Invalid longitude:', pos.longitude);
            return false;
        }

        // Check altitude sanity (mountain range dependent, -500m to 5000m covers most ski areas)
        if (pos.altitude !== null && (pos.altitude < -500 || pos.altitude > 5000)) {
            console.warn('[GPS] Invalid altitude:', pos.altitude);
            return false;
        }

        // Check speed sanity (world record ~250 km/h, allow up to 252 km/h = 70 m/s)
        if (pos.speed > 252) {
            console.warn('[GPS] Impossible speed detected:', pos.speed);
            return false;
        }

        // Check accuracy threshold (positions >100m accuracy are too unreliable)
        if (pos.accuracy > 100) {
            console.warn('[GPS] Position accuracy too low:', pos.accuracy);
            return false;
        }

        return true;
    },

    /**
     * Process raw GPS position with Kalman filtering
     * @param {GeolocationPosition} position - Raw position
     * @returns {Object} Processed and filtered position data
     */
    processPosition(position) {
        const { coords, timestamp } = position;
        
        // Convert lat/lon to local meters for Kalman filter
        // Using approximate conversion: 1 degree lat ~ 111km, 1 degree lon varies
        if (!this.origin) {
            this.origin = { lat: coords.latitude, lon: coords.longitude };
        }
        
        const localX = (coords.longitude - this.origin.lon) * 111320 * Math.cos(this.origin.lat * Math.PI / 180);
        const localY = (coords.latitude - this.origin.lat) * 110540;
        
        // Update position Kalman filter
        const filteredPos = this.kalmanPosition.update(
            localX, localY, coords.accuracy, timestamp
        );
        
        // Convert back to lat/lon
        const filteredLat = this.origin.lat + filteredPos.y / 110540;
        const filteredLon = this.origin.lon + filteredPos.x / (111320 * Math.cos(this.origin.lat * Math.PI / 180));
        
        // Calculate speed from Kalman velocity (m/s)
        const kalmanSpeedMs = this.kalmanPosition.getSpeed();
        let speedKmh = Utils.mpsToKmh(kalmanSpeedMs);
        
        // Also try GPS-reported speed for comparison
        let gpsSpeedKmh = 0;
        if (coords.speed !== null && coords.speed >= 0) {
            gpsSpeedKmh = Utils.mpsToKmh(coords.speed);
        }
        
        // Fallback: Calculate speed from position change if both are unavailable
        if (speedKmh < 0.5 && gpsSpeedKmh === 0 && this.lastPosition && this.lastPositionTime) {
            const timeDiff = (timestamp - this.lastPositionTime) / 1000;
            if (timeDiff > 0 && timeDiff < 10) {
                const distance = Utils.calculateDistance(
                    this.lastPosition.latitude,
                    this.lastPosition.longitude,
                    coords.latitude,
                    coords.longitude
                );
                const calculatedSpeed = (distance / timeDiff) * 3.6;
                if (calculatedSpeed > 0.5 && calculatedSpeed < 200) {
                    speedKmh = calculatedSpeed;
                }
            }
        }
        
        // Fuse GPS speed with Kalman speed if GPS speed is available and reasonable
        if (gpsSpeedKmh > 1 && Math.abs(gpsSpeedKmh - speedKmh) < 30) {
            // Weight GPS speed based on accuracy
            const gpsWeight = Math.max(0, 1 - coords.accuracy / 50);
            speedKmh = gpsSpeedKmh * gpsWeight + speedKmh * (1 - gpsWeight);
        }
        
        // Apply speed Kalman filter for final smoothing
        speedKmh = this.kalmanSpeed.filter(speedKmh, coords.accuracy);
        
        // Apply minimum speed threshold (filter GPS noise when stationary)
        if (speedKmh < this.minSpeedThreshold) {
            speedKmh = 0;
        }
        
        // Filter altitude with Kalman filter
        let filteredAltitude = coords.altitude;
        if (coords.altitude !== null) {
            filteredAltitude = this.kalmanAltitude.filter(coords.altitude, coords.altitudeAccuracy || 20);
            
            // Additional smoothing with median filter for altitude
            this.altitudeHistory.push(filteredAltitude);
            if (this.altitudeHistory.length > this.maxAltitudeSamples) {
                this.altitudeHistory.shift();
            }
            
            // Use median of recent altitudes for stability
            if (this.altitudeHistory.length >= 3) {
                const sorted = [...this.altitudeHistory].sort((a, b) => a - b);
                filteredAltitude = sorted[Math.floor(sorted.length / 2)];
            }
        }
        
        // Store for next calculation
        this.lastPosition = { latitude: coords.latitude, longitude: coords.longitude };
        this.lastPositionTime = timestamp;

        return {
            latitude: filteredLat,
            longitude: filteredLon,
            rawLatitude: coords.latitude,
            rawLongitude: coords.longitude,
            altitude: filteredAltitude,
            rawAltitude: coords.altitude,
            accuracy: coords.accuracy,
            altitudeAccuracy: coords.altitudeAccuracy,
            heading: coords.heading,
            speed: speedKmh,
            speedRaw: coords.speed ? Utils.mpsToKmh(coords.speed) : 0,
            speedKalman: Utils.mpsToKmh(kalmanSpeedMs),
            timestamp: timestamp,
            filtered: true
        };
    },

    /**
     * Get smoothed speed using moving average (legacy method)
     * @param {number} speed - Current speed
     * @returns {number} Smoothed speed
     * @deprecated Use Kalman filter instead
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
            const weight = i + 1;
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
    async getTrackingData() {
        let positions = [...this.trackingData.positions];
        
        // CRITICAL FIX: Retrieve flushed positions from storage
        if (this.flushedPositionCount > 0 && this.runId) {
            try {
                const progress = await Storage.getTrackingProgress(this.runId);
                if (progress && progress.positions) {
                    // Combine flushed positions with in-memory positions
                    positions = [...progress.positions, ...positions];
                    console.log('[GPS] Retrieved', progress.positions.length, 'flushed positions from storage');
                }
            } catch (error) {
                console.error('[GPS] Failed to retrieve flushed positions:', error);
                // Continue with in-memory positions only
            }
        }
        
        // Calculate total distance using filtered positions
        let totalDistance = 0;
        for (let i = 1; i < positions.length; i++) {
            totalDistance += Utils.calculateDistance(
                positions[i - 1].lat,
                positions[i - 1].lon,
                positions[i].lat,
                positions[i].lon
            );
        }

        // Calculate max speed (use filtered values)
        const maxSpeed = positions.reduce((max, p) => Math.max(max, p.speed || 0), 0);
        
        // Calculate average speed (excluding zeros)
        const nonZeroSpeeds = positions.filter(p => p.speed > 1).map(p => p.speed);
        const avgSpeed = Utils.average(nonZeroSpeeds);

        // Calculate vertical drop using filtered altitudes
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
            endAltitude: altitudes[altitudes.length - 1] || null,
            flushedPositionCount: this.flushedPositionCount,
            totalPositionCount: positions.length,
            filterStats: {
                positionFilter: 'Kalman2D',
                altitudeFilter: 'Kalman+Median',
                speedFilter: 'Kalman'
            }
        };
    },

    /**
     * Cleanup tracking progress from storage after run is saved
     */
    async cleanupTrackingProgress() {
        if (this.runId) {
            try {
                await Storage.deleteTrackingProgress(this.runId);
                console.log('[GPS] Cleaned up tracking progress for run:', this.runId);
            } catch (error) {
                console.error('[GPS] Failed to cleanup tracking progress:', error);
            }
        }
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
