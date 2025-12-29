/**
 * KitzSki Tracker - Statistics Module
 */

const Stats = {
    // Current run statistics
    currentRun: {
        distance: 0,
        maxSpeed: 0,
        currentSpeed: 0,
        avgSpeed: 0,
        verticalDrop: 0,      // Cumulative descent (what skiers care about)
        totalAscent: 0,       // Cumulative ascent (lifts)
        currentAltitude: null,
        previousAltitude: null, // For tracking changes
        startAltitude: null,
        highestAltitude: null,
        lowestAltitude: null,
        duration: 0,
        startTime: null,
        positions: []
    },
    
    // Timer interval
    timerInterval: null,
    
    // UI element references
    elements: null,

    /**
     * Initialize stats module
     */
    init() {
        this.cacheElements();
        this.reset();
    },

    /**
     * Cache DOM elements for performance
     */
    cacheElements() {
        this.elements = {
            currentSpeed: document.getElementById('currentSpeed'),
            maxSpeed: document.getElementById('maxSpeed'),
            distance: document.getElementById('distance'),
            verticalDrop: document.getElementById('verticalDrop'),
            altitude: document.getElementById('altitude'),
            duration: document.getElementById('duration'),
            runs: document.getElementById('runs'),
            speedCard: document.querySelector('.stat-speed'),
            recordSpeed: document.getElementById('recordSpeed'),
            recordDistance: document.getElementById('recordDistance'),
            recordVertical: document.getElementById('recordVertical')
        };
    },

    /**
     * Reset all statistics
     */
    reset() {
        this.currentRun = {
            distance: 0,
            maxSpeed: 0,
            currentSpeed: 0,
            avgSpeed: 0,
            verticalDrop: 0,
            totalAscent: 0,
            currentAltitude: null,
            previousAltitude: null,
            startAltitude: null,
            highestAltitude: null,
            lowestAltitude: null,
            duration: 0,
            startTime: null,
            positions: [],
            speedReadings: []
        };
        
        this.updateUI();
    },

    /**
     * Start tracking timer
     */
    startTimer() {
        this.currentRun.startTime = Date.now();
        
        this.timerInterval = setInterval(() => {
            this.currentRun.duration = Date.now() - this.currentRun.startTime;
            this.updateDuration();
        }, 1000);
    },

    /**
     * Stop tracking timer
     */
    stopTimer() {
        if (this.timerInterval) {
            clearInterval(this.timerInterval);
            this.timerInterval = null;
        }
    },

    /**
     * Pause timer
     */
    pauseTimer() {
        this.stopTimer();
    },

    /**
     * Resume timer
     * @param {number} pausedDuration - Duration that was paused
     */
    resumeTimer(pausedDuration = 0) {
        // Adjust start time to account for pause
        this.currentRun.startTime += pausedDuration;
        
        this.timerInterval = setInterval(() => {
            this.currentRun.duration = Date.now() - this.currentRun.startTime;
            this.updateDuration();
        }, 1000);
    },

    /**
     * Update statistics with new GPS position
     * @param {Object} position - GPS position data
     */
    updateFromPosition(position) {
        const { speed, smoothedSpeed, altitude, latitude, longitude, distanceFromPrevious } = position;
        
        // Update current speed (use smoothed if available)
        this.currentRun.currentSpeed = smoothedSpeed || speed || 0;
        
        // Store speed reading for average calculation
        if (this.currentRun.currentSpeed > 1) {
            this.currentRun.speedReadings.push(this.currentRun.currentSpeed);
        }
        
        // Update max speed
        if (this.currentRun.currentSpeed > this.currentRun.maxSpeed) {
            this.currentRun.maxSpeed = this.currentRun.currentSpeed;
        }
        
        // Update distance (only if actually moving, not GPS noise)
        if (distanceFromPrevious && distanceFromPrevious > 3 && this.currentRun.currentSpeed > 0) {
            this.currentRun.distance += distanceFromPrevious / 1000; // Convert to km
        }
        
        // Update altitude stats
        if (altitude !== null && altitude !== undefined) {
            this.currentRun.currentAltitude = altitude;
            
            if (this.currentRun.startAltitude === null) {
                this.currentRun.startAltitude = altitude;
                this.currentRun.previousAltitude = altitude;
                this.currentRun.highestAltitude = altitude;
                this.currentRun.lowestAltitude = altitude;
            }
            
            // Track highest and lowest (for reference)
            if (altitude > this.currentRun.highestAltitude) {
                this.currentRun.highestAltitude = altitude;
            }
            if (altitude < this.currentRun.lowestAltitude) {
                this.currentRun.lowestAltitude = altitude;
            }
            
            // Calculate CUMULATIVE vertical (what skiers actually care about)
            // Only count if we have a previous reading and the change is significant
            // Using 5m threshold because GPS altitude accuracy is ~10-30m typically
            if (this.currentRun.previousAltitude !== null) {
                const altChange = this.currentRun.previousAltitude - altitude;
                
                if (altChange > 5) {
                    // Descended - add to vertical drop
                    this.currentRun.verticalDrop += altChange;
                } else if (altChange < -5) {
                    // Ascended (lift) - add to total ascent
                    this.currentRun.totalAscent += Math.abs(altChange);
                }
            }
            
            this.currentRun.previousAltitude = altitude;
        }
        
        // Store position
        this.currentRun.positions.push({
            lat: latitude,
            lon: longitude,
            alt: altitude,
            speed: this.currentRun.currentSpeed,
            timestamp: Date.now()
        });
        
        // Calculate average speed
        if (this.currentRun.speedReadings.length > 0) {
            this.currentRun.avgSpeed = Utils.average(this.currentRun.speedReadings);
        }
        
        // Update UI
        this.updateUI();
    },

    /**
     * Update all UI elements
     */
    updateUI() {
        if (!this.elements.currentSpeed) return;
        
        // Current speed
        const speedValue = Math.round(this.currentRun.currentSpeed);
        if (this.elements.currentSpeed.textContent !== speedValue.toString()) {
            this.elements.currentSpeed.textContent = speedValue;
            this.animateValue(this.elements.currentSpeed);
        }
        
        // Update speed color
        this.updateSpeedColor(this.currentRun.currentSpeed);
        
        // Max speed
        this.elements.maxSpeed.textContent = Math.round(this.currentRun.maxSpeed);
        
        // Distance
        this.elements.distance.textContent = this.currentRun.distance.toFixed(2);
        
        // Vertical drop
        this.elements.verticalDrop.textContent = Math.round(this.currentRun.verticalDrop);
        
        // Altitude
        if (this.currentRun.currentAltitude !== null) {
            this.elements.altitude.textContent = Math.round(this.currentRun.currentAltitude);
        }
    },

    /**
     * Update duration display
     */
    updateDuration() {
        if (this.elements.duration) {
            this.elements.duration.textContent = Utils.formatDuration(this.currentRun.duration);
        }
    },

    /**
     * Update speed color based on value
     * @param {number} speed - Current speed
     */
    updateSpeedColor(speed) {
        if (!this.elements.speedCard) return;
        
        // Remove all speed classes
        this.elements.speedCard.classList.remove('speed-slow', 'speed-medium', 'speed-fast', 'speed-extreme');
        
        // Add appropriate class
        const category = Utils.getSpeedCategory(speed);
        this.elements.speedCard.classList.add(`speed-${category}`);
    },

    /**
     * Animate value update
     * @param {HTMLElement} element - Element to animate
     */
    animateValue(element) {
        element.classList.add('updating');
        setTimeout(() => {
            element.classList.remove('updating');
        }, 300);
    },

    /**
     * Get final run data for saving
     * @returns {Object} Run data object
     */
    getRunData() {
        return {
            id: Utils.generateId(),
            startTime: this.currentRun.startTime,
            endTime: Date.now(),
            duration: this.currentRun.duration,
            distance: this.currentRun.distance,
            maxSpeed: this.currentRun.maxSpeed,
            avgSpeed: this.currentRun.avgSpeed,
            verticalDrop: this.currentRun.verticalDrop,
            startAltitude: this.currentRun.startAltitude,
            endAltitude: this.currentRun.currentAltitude,
            highestAltitude: this.currentRun.highestAltitude,
            lowestAltitude: this.currentRun.lowestAltitude,
            positions: this.currentRun.positions
        };
    },

    /**
     * Update run count display
     * @param {number} count - Number of runs
     */
    async updateRunCount() {
        if (this.elements.runs) {
            const count = await Storage.getRunCount();
            this.elements.runs.textContent = count;
        }
    },

    /**
     * Update records display
     * @param {Object} records - Records object
     */
    updateRecords(records) {
        if (records.speed && this.elements.recordSpeed) {
            this.elements.recordSpeed.textContent = `${Math.round(records.speed.value)} km/h`;
        }
        
        if (records.distance && this.elements.recordDistance) {
            this.elements.recordDistance.textContent = `${records.distance.value.toFixed(2)} km`;
        }
        
        if (records.vertical && this.elements.recordVertical) {
            this.elements.recordVertical.textContent = `${Math.round(records.vertical.value)} m`;
        }
    },

    /**
     * Calculate session statistics
     * @param {Array} runs - Array of run objects
     * @returns {Object} Session stats
     */
    calculateSessionStats(runs) {
        if (runs.length === 0) {
            return {
                totalRuns: 0,
                totalDistance: 0,
                totalVertical: 0,
                totalDuration: 0,
                avgSpeed: 0,
                topSpeed: 0
            };
        }

        const totalDistance = runs.reduce((sum, run) => sum + run.distance, 0);
        const totalVertical = runs.reduce((sum, run) => sum + run.verticalDrop, 0);
        const totalDuration = runs.reduce((sum, run) => sum + run.duration, 0);
        const topSpeed = Math.max(...runs.map(run => run.maxSpeed));
        const avgSpeed = Utils.average(runs.map(run => run.avgSpeed).filter(s => s > 0));

        return {
            totalRuns: runs.length,
            totalDistance,
            totalVertical,
            totalDuration,
            avgSpeed,
            topSpeed
        };
    }
};

// Make Stats available globally
window.Stats = Stats;

