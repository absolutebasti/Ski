/**
 * Barometric Altimeter Module
 * HIGH-012: Implement Barometric Altimeter Support
 * 
 * Uses device barometric pressure sensor for more accurate altitude
 * Falls back to GPS altitude when barometer unavailable
 */

const BarometricAltimeter = {
    // Sensor
    barometer: null,
    isAvailable: false,
    isActive: false,
    
    // Calibration
    calibration: {
        seaLevelPressure: 1013.25, // hPa
        gpsOffset: 0, // Difference between GPS and barometric altitude
        isCalibrated: false,
        calibrationTime: null
    },
    
    // Data
    readings: [],
    maxReadings: 100,
    
    // Pressure to altitude formula constants
    constants: {
        seaLevelPressure: 1013.25,
        lapseRate: 0.0065, // Temperature lapse rate (K/m)
        gasConstant: 287.05, // Specific gas constant for dry air (J/(kg·K))
        gravity: 9.80665, // Standard gravity (m/s²)
        temperature: 288.15 // Standard temperature at sea level (K)
    },
    
    // Event callbacks
    callbacks: {
        onReading: null,
        onError: null
    },
    
    /**
     * Initialize barometric altimeter
     */
    async init() {
        // Check for Barometer API (iOS 15+ Safari, Chrome Android)
        if ('Barometer' in window) {
            console.log('[Barometer] Barometer API available');
            this.isAvailable = true;
        } else if ('AmbientPressureSensor' in window) {
            console.log('[Barometer] AmbientPressureSensor API available');
            this.isAvailable = true;
        } else {
            console.log('[Barometer] Barometer not available, will use GPS altitude');
            this.isAvailable = false;
        }
        
        // Load calibration from storage
        await this.loadCalibration();
        
        return this.isAvailable;
    },
    
    /**
     * Check if barometer is available
     */
    checkAvailability() {
        return this.isAvailable;
    },
    
    /**
     * Start barometer readings
     */
    async start() {
        if (!this.isAvailable) {
            throw new Error('Barometer not available');
        }
        
        if (this.isActive) {
            return true;
        }
        
        try {
            // Try Barometer API first
            if ('Barometer' in window) {
                this.barometer = new window.Barometer({ frequency: 1 });
                
                this.barometer.addEventListener('reading', (e) => {
                    this.handleReading(e.target.pressure);
                });
                
                await this.barometer.start();
            }
            // Fallback to AmbientPressureSensor
            else if ('AmbientPressureSensor' in window) {
                this.barometer = new window.AmbientPressureSensor({ frequency: 1 });
                
                this.barometer.addEventListener('reading', (e) => {
                    this.handleReading(e.target.pressure);
                });
                
                this.barometer.addEventListener('error', (e) => {
                    this.handleError(e);
                });
                
                await this.barometer.start();
            }
            
            this.isActive = true;
            console.log('[Barometer] Started');
            return true;
            
        } catch (error) {
            console.error('[Barometer] Failed to start:', error);
            this.handleError(error);
            throw error;
        }
    },
    
    /**
     * Stop barometer readings
     */
    async stop() {
        if (this.barometer && this.isActive) {
            try {
                await this.barometer.stop();
            } catch (e) {
                console.warn('[Barometer] Error stopping:', e);
            }
        }
        
        this.isActive = false;
        console.log('[Barometer] Stopped');
    },
    
    /**
     * Handle pressure reading
     */
    handleReading(pressure) {
        const reading = {
            pressure, // hPa
            timestamp: Date.now(),
            altitude: this.pressureToAltitude(pressure)
        };
        
        this.readings.push(reading);
        
        // Keep only recent readings
        if (this.readings.length > this.maxReadings) {
            this.readings.shift();
        }
        
        if (this.callbacks.onReading) {
            this.callbacks.onReading(reading);
        }
    },
    
    /**
     * Handle errors
     */
    handleError(error) {
        console.error('[Barometer] Error:', error);
        
        if (this.callbacks.onError) {
            this.callbacks.onError(error);
        }
    },
    
    /**
     * Convert pressure to altitude using hypsometric formula
     */
    pressureToAltitude(pressure) {
        // Hypsometric formula
        // h = (T0 / L) * [1 - (P / P0)^(R*L/g)]
        const { seaLevelPressure, lapseRate, gasConstant, gravity, temperature } = this.constants;
        
        const exponent = (gasConstant * lapseRate) / gravity;
        const altitude = (temperature / lapseRate) * (1 - Math.pow(pressure / seaLevelPressure, exponent));
        
        return altitude;
    },
    
    /**
     * Convert altitude to pressure
     */
    altitudeToPressure(altitude) {
        const { seaLevelPressure, lapseRate, gasConstant, gravity, temperature } = this.constants;
        
        const exponent = (gasConstant * lapseRate) / gravity;
        const pressure = seaLevelPressure * Math.pow(
            1 - (lapseRate * altitude) / temperature,
            1 / exponent
        );
        
        return pressure;
    },
    
    /**
     * Calibrate using GPS altitude
     */
    calibrateWithGPS(gpsAltitude) {
        if (this.readings.length === 0) {
            console.warn('[Barometer] No barometric readings available for calibration');
            return false;
        }
        
        // Get average recent barometric altitude
        const recentReadings = this.readings.slice(-10);
        const avgPressure = recentReadings.reduce((sum, r) => sum + r.pressure, 0) / recentReadings.length;
        const baroAltitude = this.pressureToAltitude(avgPressure);
        
        // Calculate offset
        this.calibration.gpsOffset = gpsAltitude - baroAltitude;
        this.calibration.isCalibrated = true;
        this.calibration.calibrationTime = Date.now();
        
        // Recalculate sea level pressure based on GPS
        this.calibration.seaLevelPressure = this.calculateSeaLevelPressure(avgPressure, gpsAltitude);
        
        this.saveCalibration();
        
        console.log(`[Barometer] Calibrated with GPS: offset=${this.calibration.gpsOffset.toFixed(1)}m, seaLevel=${this.calibration.seaLevelPressure.toFixed(2)}hPa`);
        
        return true;
    },
    
    /**
     * Calculate sea level pressure from station pressure and altitude
     */
    calculateSeaLevelPressure(stationPressure, altitude) {
        // Simplified formula: P0 = P * (1 + (L*h)/(T0))^((g*M)/(R*L))
        // Using approximation for simplicity
        const { lapseRate, gravity, gasConstant, temperature } = this.constants;
        
        const exponent = gravity / (gasConstant * lapseRate);
        const seaLevelPressure = stationPressure * Math.pow(
            1 + (lapseRate * altitude) / temperature,
            exponent
        );
        
        return seaLevelPressure;
    },
    
    /**
     * Get current altitude
     */
    getAltitude() {
        if (!this.isActive || this.readings.length === 0) {
            return null;
        }
        
        const latest = this.readings[this.readings.length - 1];
        let altitude = latest.altitude;
        
        // Apply calibration offset
        if (this.calibration.isCalibrated) {
            altitude += this.calibration.gpsOffset;
        }
        
        return {
            altitude: Math.round(altitude),
            pressure: latest.pressure,
            timestamp: latest.timestamp,
            source: 'barometer',
            calibrated: this.calibration.isCalibrated
        };
    },
    
    /**
     * Get smoothed altitude (average of recent readings)
     */
    getSmoothedAltitude(samples = 5) {
        if (this.readings.length < samples) {
            return this.getAltitude();
        }
        
        const recent = this.readings.slice(-samples);
        const avgAltitude = recent.reduce((sum, r) => sum + r.altitude, 0) / recent.length;
        
        let altitude = avgAltitude;
        if (this.calibration.isCalibrated) {
            altitude += this.calibration.gpsOffset;
        }
        
        return {
            altitude: Math.round(altitude),
            pressure: recent[recent.length - 1].pressure,
            timestamp: Date.now(),
            source: 'barometer',
            calibrated: this.calibration.isCalibrated,
            samples
        };
    },
    
    /**
     * Calculate relative altitude change from a reference point
     */
    getRelativeAltitude(referenceReading = null) {
        const current = this.getAltitude();
        if (!current) return null;
        
        const ref = referenceReading || this.readings[0];
        if (!ref) return null;
        
        return {
            change: current.altitude - ref.altitude,
            current: current.altitude,
            reference: ref.altitude,
            timestamp: current.timestamp
        };
    },
    
    /**
     * Get altitude with fallback to GPS
     */
    getAltitudeWithFallback(gpsAltitude) {
        const baro = this.getAltitude();
        
        if (baro && this.calibration.isCalibrated) {
            return {
                ...baro,
                gpsAltitude,
                accuracy: 'high' // Barometer is ~1m vs GPS ~10-30m
            };
        }
        
        // Auto-calibrate if we have GPS and barometer but not calibrated
        if (baro && gpsAltitude && !this.calibration.isCalibrated) {
            this.calibrateWithGPS(gpsAltitude);
            return this.getAltitudeWithFallback(gpsAltitude);
        }
        
        // Fallback to GPS
        return {
            altitude: Math.round(gpsAltitude),
            source: 'gps',
            accuracy: 'medium'
        };
    },
    
    /**
     * Save calibration to storage
     */
    async saveCalibration() {
        try {
            const data = {
                seaLevelPressure: this.calibration.seaLevelPressure,
                gpsOffset: this.calibration.gpsOffset,
                isCalibrated: this.calibration.isCalibrated,
                calibrationTime: this.calibration.calibrationTime
            };
            
            if (typeof Storage !== 'undefined') {
                await Storage.set('barometerCalibration', data);
            } else {
                // SECURITY FIX: Use safe localStorage with quota checking
                const result = SecurityUtils.safeLocalStorageSet('barometerCalibration', JSON.stringify(data));
                if (!result.success && result.fallback === 'indexeddb') {
                    SecurityUtils.fallbackToIndexedDB('barometerCalibration', JSON.stringify(data)).catch(() => {});
                }
            }
        } catch (e) {
            console.error('[Barometer] Failed to save calibration:', e);
        }
    },
    
    /**
     * Load calibration from storage
     */
    async loadCalibration() {
        try {
            let data = null;
            
            if (typeof Storage !== 'undefined') {
                data = await Storage.get('barometerCalibration');
            } else {
                const saved = localStorage.getItem('barometerCalibration');
                if (saved) data = JSON.parse(saved);
            }
            
            if (data) {
                this.calibration = {
                    ...this.calibration,
                    ...data
                };
                console.log('[Barometer] Loaded calibration:', data);
            }
        } catch (e) {
            console.error('[Barometer] Failed to load calibration:', e);
        }
    },
    
    /**
     * Reset calibration
     */
    resetCalibration() {
        this.calibration = {
            seaLevelPressure: 1013.25,
            gpsOffset: 0,
            isCalibrated: false,
            calibrationTime: null
        };
        this.saveCalibration();
        console.log('[Barometer] Calibration reset');
    },
    
    /**
     * Get calibration status
     */
    getCalibrationStatus() {
        return {
            ...this.calibration,
            readingsCount: this.readings.length
        };
    },
    
    /**
     * Set event callbacks
     */
    onReading(callback) {
        this.callbacks.onReading = callback;
    },
    
    onError(callback) {
        this.callbacks.onError = callback;
    },
    
    /**
     * Get status summary
     */
    getStatus() {
        return {
            isAvailable: this.isAvailable,
            isActive: this.isActive,
            isCalibrated: this.calibration.isCalibrated,
            readingsCount: this.readings.length,
            currentAltitude: this.getAltitude()?.altitude || null
        };
    },
    
    /**
     * Render altitude display for UI
     */
    renderAltitudeDisplay(container) {
        const status = this.getStatus();
        const altitude = this.getSmoothedAltitude();
        
        container.innerHTML = `
            <div class="altimeter-display ${status.isActive ? 'active' : 'inactive'}">
                <div class="altitude-value">
                    ${altitude ? `
                        <span class="meters">${altitude.altitude}</span>
                        <span class="unit">m</span>
                    ` : '--'}
                </div>
                <div class="altitude-source">
                    ${status.isActive ? `
                        📊 Barometer
                        ${status.isCalibrated ? '✓ Calibrated' : '⚠ Uncalibrated'}
                    ` : '📡 GPS Only'}
                </div>
                ${altitude?.pressure ? `
                    <div class="pressure-value">
                        ${altitude.pressure.toFixed(1)} hPa
                    </div>
                ` : ''}
                <button class="btn-calibrate" onclick="BarometricAltimeter.calibrateWithGPS(prompt('Enter current GPS altitude:'))">
                    Calibrate
                </button>
            </div>
        `;
    }
};

// Initialize
BarometricAltimeter.init();
