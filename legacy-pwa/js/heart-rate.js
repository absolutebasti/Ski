/**
 * Heart Rate Monitor Module
 * HIGH-007: Add Heart Rate Monitoring (Apple Watch/Bluetooth)
 * 
 * Integrates with Bluetooth heart rate monitors for fitness tracking
 * Uses Web Bluetooth API for device connectivity
 */

const HeartRateMonitor = {
    // Device connection
    device: null,
    server: null,
    characteristic: null,
    
    // State
    isConnected: false,
    isConnecting: false,
    currentHeartRate: null,
    heartRateHistory: [],
    
    // Configuration
    config: {
        serviceUuid: 'heart_rate', // 0x180d
        characteristicUuid: 'heart_rate_measurement', // 0x2a37
        maxHistoryLength: 3600, // Keep 1 hour of data (1 reading per second)
        reconnectAttempts: 3
    },
    
    // Event callbacks
    callbacks: {
        onConnect: null,
        onDisconnect: null,
        onHeartRate: null,
        onError: null
    },
    
    /**
     * Initialize the heart rate monitor
     */
    init() {
        // Check for Web Bluetooth support
        if (!navigator.bluetooth) {
            console.log('[HRM] Web Bluetooth not supported');
            return false;
        }
        
        console.log('[HRM] Initialized');
        return true;
    },
    
    /**
     * Check if Web Bluetooth is available
     */
    isSupported() {
        return !!navigator.bluetooth;
    },
    
    /**
     * Request permission and connect to a heart rate device
     */
    async connect() {
        if (!this.isSupported()) {
            throw new Error('Web Bluetooth not supported');
        }
        
        if (this.isConnected) {
            console.log('[HRM] Already connected');
            return true;
        }
        
        if (this.isConnecting) {
            console.log('[HRM] Connection in progress');
            return false;
        }
        
        this.isConnecting = true;
        
        try {
            console.log('[HRM] Requesting device...');
            
            // Request device with heart rate service
            this.device = await navigator.bluetooth.requestDevice({
                filters: [
                    { services: ['heart_rate'] },
                    { namePrefix: 'Polar' },
                    { namePrefix: 'Wahoo' },
                    { namePrefix: 'Garmin' },
                    { namePrefix: 'WHOOP' },
                    { namePrefix: 'Apple Watch' }
                ],
                optionalServices: ['battery_service', 'device_information']
            });
            
            console.log(`[HRM] Selected device: ${this.device.name}`);
            
            // Listen for disconnect
            this.device.addEventListener('gattserverdisconnected', () => {
                this.handleDisconnect();
            });
            
            // Connect to GATT server
            console.log('[HRM] Connecting to GATT server...');
            this.server = await this.device.gatt.connect();
            
            // Get heart rate service
            console.log('[HRM] Getting heart rate service...');
            const service = await this.server.getPrimaryService('heart_rate');
            
            // Get heart rate measurement characteristic
            console.log('[HRM] Getting measurement characteristic...');
            this.characteristic = await service.getCharacteristic('heart_rate_measurement');
            
            // Start notifications
            console.log('[HRM] Starting notifications...');
            await this.characteristic.startNotifications();
            
            this.characteristic.addEventListener('characteristicvaluechanged', (event) => {
                this.handleHeartRateData(event);
            });
            
            this.isConnected = true;
            this.isConnecting = false;
            
            if (this.callbacks.onConnect) {
                this.callbacks.onConnect(this.device.name);
            }
            
            console.log('[HRM] Connected successfully');
            return true;
            
        } catch (error) {
            this.isConnecting = false;
            console.error('[HRM] Connection failed:', error);
            
            if (this.callbacks.onError) {
                this.callbacks.onError(error);
            }
            
            throw error;
        }
    },
    
    /**
     * Disconnect from device
     */
    async disconnect() {
        if (this.characteristic) {
            try {
                await this.characteristic.stopNotifications();
            } catch (e) {
                console.warn('[HRM] Error stopping notifications:', e);
            }
        }
        
        if (this.server && this.server.connected) {
            this.server.disconnect();
        }
        
        this.handleDisconnect();
    },
    
    /**
     * Handle disconnection
     */
    handleDisconnect() {
        console.log('[HRM] Disconnected');
        this.isConnected = false;
        this.isConnecting = false;
        this.device = null;
        this.server = null;
        this.characteristic = null;
        
        if (this.callbacks.onDisconnect) {
            this.callbacks.onDisconnect();
        }
    },
    
    /**
     * Parse and handle heart rate data
     */
    handleHeartRateData(event) {
        const value = event.target.value;
        
        // Parse heart rate measurement
        // First byte: flags
        const flags = value.getUint8(0);
        const is16Bit = flags & 0x1;
        const sensorContactDetected = flags & 0x2;
        const sensorContactSupported = flags & 0x4;
        const energyExpendedPresent = flags & 0x8;
        const rrIntervalPresent = flags & 0x10;
        
        // Second byte(s): heart rate
        let heartRate;
        let offset = 1;
        
        if (is16Bit) {
            heartRate = value.getUint16(offset, true);
            offset += 2;
        } else {
            heartRate = value.getUint8(offset);
            offset += 1;
        }
        
        // Energy expended (optional)
        let energyExpended = null;
        if (energyExpendedPresent) {
            energyExpended = value.getUint16(offset, true);
            offset += 2;
        }
        
        // RR intervals (optional)
        const rrIntervals = [];
        if (rrIntervalPresent) {
            while (offset < value.byteLength) {
                rrIntervals.push(value.getUint16(offset, true));
                offset += 2;
            }
        }
        
        const reading = {
            heartRate,
            timestamp: Date.now(),
            sensorContact: sensorContactSupported ? !!sensorContactDetected : null,
            energyExpended,
            rrIntervals
        };
        
        this.currentHeartRate = heartRate;
        this.heartRateHistory.push(reading);
        
        // Trim history to max length
        if (this.heartRateHistory.length > this.config.maxHistoryLength) {
            this.heartRateHistory = this.heartRateHistory.slice(-this.config.maxHistoryLength);
        }
        
        if (this.callbacks.onHeartRate) {
            this.callbacks.onHeartRate(reading);
        }
        
        console.log(`[HRM] Heart rate: ${heartRate} bpm`);
    },
    
    /**
     * Get current heart rate
     */
    getCurrentHeartRate() {
        return this.currentHeartRate;
    },
    
    /**
     * Get heart rate history
     */
    getHeartRateHistory(duration = null) {
        if (!duration) {
            return [...this.heartRateHistory];
        }
        
        const cutoff = Date.now() - duration;
        return this.heartRateHistory.filter(h => h.timestamp > cutoff);
    },
    
    /**
     * Calculate heart rate statistics
     */
    calculateStats(duration = 60000) {
        const history = this.getHeartRateHistory(duration);
        
        if (history.length === 0) {
            return null;
        }
        
        const rates = history.map(h => h.heartRate);
        const sum = rates.reduce((a, b) => a + b, 0);
        
        return {
            current: this.currentHeartRate,
            average: Math.round(sum / rates.length),
            min: Math.min(...rates),
            max: Math.max(...rates),
            readings: rates.length,
            duration: duration
        };
    },
    
    /**
     * Calculate heart rate zones
     */
    calculateZones(maxHr = 190) {
        return {
            zone1: { min: 0.5 * maxHr, max: 0.6 * maxHr, name: 'Recovery', color: '#4CAF50' },
            zone2: { min: 0.6 * maxHr, max: 0.7 * maxHr, name: 'Aerobic', color: '#8BC34A' },
            zone3: { min: 0.7 * maxHr, max: 0.8 * maxHr, name: 'Tempo', color: '#FFC107' },
            zone4: { min: 0.8 * maxHr, max: 0.9 * maxHr, name: 'Threshold', color: '#FF9800' },
            zone5: { min: 0.9 * maxHr, max: 1.0 * maxHr, name: 'Max', color: '#F44336' }
        };
    },
    
    /**
     * Get current zone
     */
    getCurrentZone(maxHr = 190) {
        if (!this.currentHeartRate) return null;
        
        const zones = this.calculateZones(maxHr);
        const pct = this.currentHeartRate / maxHr;
        
        if (pct < 0.6) return zones.zone1;
        if (pct < 0.7) return zones.zone2;
        if (pct < 0.8) return zones.zone3;
        if (pct < 0.9) return zones.zone4;
        return zones.zone5;
    },
    
    /**
     * Get connection status
     */
    getStatus() {
        return {
            isSupported: this.isSupported(),
            isConnected: this.isConnected,
            isConnecting: this.isConnecting,
            deviceName: this.device?.name || null,
            currentHeartRate: this.currentHeartRate,
            historyLength: this.heartRateHistory.length
        };
    },
    
    /**
     * Set event callback
     */
    onConnect(callback) {
        this.callbacks.onConnect = callback;
    },
    
    onDisconnect(callback) {
        this.callbacks.onDisconnect = callback;
    },
    
    onHeartRate(callback) {
        this.callbacks.onHeartRate = callback;
    },
    
    onError(callback) {
        this.callbacks.onError = callback;
    },
    
    /**
     * Clear history
     */
    clearHistory() {
        this.heartRateHistory = [];
    },
    
    /**
     * Render HR display for UI
     */
    renderHRDisplay(container) {
        const stats = this.calculateStats();
        const zone = this.getCurrentZone();
        
        container.innerHTML = `
            <div class="hr-display ${this.isConnected ? 'connected' : 'disconnected'}">
                <div class="hr-value">
                    ${this.currentHeartRate ? `
                        <span class="bpm">${this.currentHeartRate}</span>
                        <span class="unit">bpm</span>
                    ` : '--'}
                </div>
                ${zone ? `
                    <div class="hr-zone" style="background: ${zone.color}">
                        ${zone.name}
                    </div>
                ` : ''}
                ${stats ? `
                    <div class="hr-stats">
                        <span>Min: ${stats.min}</span>
                        <span>Avg: ${stats.average}</span>
                        <span>Max: ${stats.max}</span>
                    </div>
                ` : ''}
                <button class="btn-hr-connect" onclick="HeartRateMonitor.toggleConnection()">
                    ${this.isConnected ? 'Disconnect' : 'Connect HRM'}
                </button>
            </div>
        `;
    },
    
    /**
     * Toggle connection state
     */
    async toggleConnection() {
        if (this.isConnected) {
            await this.disconnect();
        } else {
            await this.connect();
        }
    },
    
    /**
     * Get HR data for export (e.g., with run data)
     */
    getExportData() {
        return {
            isConnected: this.isConnected,
            deviceName: this.device?.name,
            averageHeartRate: this.calculateStats()?.average,
            maxHeartRate: this.calculateStats()?.max,
            history: this.heartRateHistory.map(h => ({
                timestamp: h.timestamp,
                heartRate: h.heartRate
            }))
        };
    }
};

// Initialize
HeartRateMonitor.init();
