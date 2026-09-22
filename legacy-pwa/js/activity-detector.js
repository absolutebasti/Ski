/**
 * Activity Detection Module
 * HIGH-006: Implement Run Auto-Detection (Lift vs Ski)
 * 
 * Automatically detects when user is on a ski lift vs actively skiing
 * Splits tracking into separate runs automatically
 */

const ActivityDetector = {
    // Detection states
    states: {
        UNKNOWN: 'unknown',
        STOPPED: 'stopped',
        LIFT: 'lift',
        SKIING: 'skiing'
    },
    
    // Current state
    currentState: 'unknown',
    
    // State history
    stateHistory: [],
    
    // Configuration
    config: {
        // Speed thresholds (m/s)
        speedThresholds: {
            stopped: 1,      // < 1 m/s = stopped
            liftMin: 1,      // 1-8 m/s = could be lift
            liftMax: 8,      // 8-15 m/s = could be skiing
            skiingMin: 15    // > 15 m/s = definitely skiing
        },
        
        // Altitude change thresholds (meters per position)
        altitudeThresholds: {
            liftRising: 2,    // Rising 2m+ = likely lift
            skiDescending: -2 // Descending 2m+ = likely skiing
        },
        
        // Time thresholds (milliseconds)
        timeThresholds: {
            stateChangeDelay: 5000,     // Wait 5s before confirming state change
            minSkiDuration: 30000,      // Minimum 30s to count as a run
            minLiftDuration: 60000      // Minimum 60s to be considered a lift
        },
        
        // Pattern detection
        patterns: {
            liftStraightness: 0.9,      // Lifts tend to be straight lines
            skiVariation: 0.3           // Skiing has more direction variation
        }
    },
    
    // Current run tracking
    currentRun: null,
    runs: [],
    liftSegments: [],
    
    // Event callbacks
    callbacks: {
        onStateChange: null,
        onRunDetected: null,
        onLiftDetected: null,
        onSkiingStart: null,
        onSkiingEnd: null
    },
    
    /**
     * Initialize detector
     */
    init() {
        this.currentState = this.states.UNKNOWN;
        console.log('[ActivityDetector] Initialized');
    },
    
    /**
     * Process new position data
     */
    processPosition(position, previousPositions = []) {
        const state = this.detectState(position, previousPositions);
        
        // Add to history
        this.stateHistory.push({
            state,
            position,
            timestamp: Date.now()
        });
        
        // Keep only last 60 seconds of history
        const cutoff = Date.now() - 60000;
        this.stateHistory = this.stateHistory.filter(h => h.timestamp > cutoff);
        
        // Check for state change
        this.handleStateChange(state);
        
        return state;
    },
    
    /**
     * Detect current activity state
     */
    detectState(position, previousPositions) {
        const speed = position.speed || 0;
        const altitude = position.altitude || 0;
        
        // Get recent positions for context
        const recent = previousPositions.slice(-10);
        
        // Calculate altitude trend
        const altitudeChange = this.calculateAltitudeTrend(recent, position);
        
        // Calculate direction straightness
        const straightness = this.calculateStraightness(recent);
        
        // State detection logic
        if (speed < this.config.speedThresholds.stopped) {
            return this.states.STOPPED;
        }
        
        // Check for lift indicators
        if (this.isLiftIndicators(speed, altitudeChange, straightness)) {
            return this.states.LIFT;
        }
        
        // Check for skiing indicators
        if (this.isSkiingIndicators(speed, altitudeChange, straightness)) {
            return this.states.SKIING;
        }
        
        return this.states.UNKNOWN;
    },
    
    /**
     * Check if indicators suggest lift ride
     */
    isLiftIndicators(speed, altitudeChange, straightness) {
        // Lift: moderate speed, rising altitude, straight line
        const isLiftSpeed = speed >= this.config.speedThresholds.liftMin && 
                           speed <= this.config.speedThresholds.liftMax;
        const isRising = altitudeChange > this.config.altitudeThresholds.liftRising;
        const isStraight = straightness > this.config.patterns.liftStraightness;
        
        // Two of three indicators required
        return (isLiftSpeed && isRising) || 
               (isLiftSpeed && isStraight) || 
               (isRising && isStraight);
    },
    
    /**
     * Check if indicators suggest skiing
     */
    isSkiingIndicators(speed, altitudeChange, straightness) {
        // Skiing: higher speed, descending, varied direction
        const isSkiingSpeed = speed >= this.config.speedThresholds.skiingMin ||
                             (speed >= this.config.speedThresholds.liftMax && 
                              altitudeChange < this.config.altitudeThresholds.skiDesc);
        const isDescending = altitudeChange < this.config.altitudeThresholds.skiDescending;
        const isVaried = straightness < this.config.patterns.skiVariation;
        
        // Descending + speed is strong indicator
        return isDescending && speed > this.config.speedThresholds.liftMin;
    },
    
    /**
     * Calculate altitude trend from recent positions
     */
    calculateAltitudeTrend(recent, current) {
        if (recent.length < 2) return 0;
        
        const older = recent[Math.max(0, recent.length - 5)];
        if (!older || !older.altitude) return 0;
        
        return current.altitude - older.altitude;
    },
    
    /**
     * Calculate direction straightness (0-1)
     */
    calculateStraightness(positions) {
        if (positions.length < 3) return 1;
        
        // Calculate bearing changes
        let totalBearingChange = 0;
        
        for (let i = 2; i < positions.length; i++) {
            const bearing1 = this.calculateBearing(positions[i-2], positions[i-1]);
            const bearing2 = this.calculateBearing(positions[i-1], positions[i]);
            
            let change = Math.abs(bearing2 - bearing1);
            if (change > 180) change = 360 - change;
            
            totalBearingChange += change;
        }
        
        const avgChange = totalBearingChange / (positions.length - 2);
        
        // Convert to straightness (0 = very curvy, 1 = straight)
        return Math.max(0, 1 - (avgChange / 90));
    },
    
    /**
     * Calculate bearing between two positions
     */
    calculateBearing(pos1, pos2) {
        const lat1 = pos1.latitude * Math.PI / 180;
        const lat2 = pos2.latitude * Math.PI / 180;
        const lon1 = pos1.longitude * Math.PI / 180;
        const lon2 = pos2.longitude * Math.PI / 180;
        
        const y = Math.sin(lon2 - lon1) * Math.cos(lat2);
        const x = Math.cos(lat1) * Math.sin(lat2) -
                  Math.sin(lat1) * Math.cos(lat2) * Math.cos(lon2 - lon1);
        
        const bearing = Math.atan2(y, x) * 180 / Math.PI;
        return (bearing + 360) % 360;
    },
    
    /**
     * Handle state change with debouncing
     */
    handleStateChange(newState) {
        if (newState === this.currentState) return;
        
        // Check if state change is stable
        const stable = this.isStateChangeStable(newState);
        if (!stable) return;
        
        const previousState = this.currentState;
        this.currentState = newState;
        
        console.log(`[ActivityDetector] State: ${previousState} → ${newState}`);
        
        // Trigger callbacks
        if (this.callbacks.onStateChange) {
            this.callbacks.onStateChange(newState, previousState);
        }
        
        // Handle specific transitions
        if (newState === this.states.SKIING && previousState !== this.states.SKIING) {
            this.onSkiingStart();
        }
        
        if (previousState === this.states.SKIING && newState !== this.states.SKIING) {
            this.onSkiingEnd();
        }
        
        if (newState === this.states.LIFT) {
            this.onLiftStart();
        }
    },
    
    /**
     * Check if state change is stable (not momentary)
     */
    isStateChangeStable(newState) {
        const recentHistory = this.stateHistory.slice(-10);
        const newStateCount = recentHistory.filter(h => h.state === newState).length;
        
        // Require at least 7 of last 10 readings to be new state
        return newStateCount >= 7;
    },
    
    /**
     * Handle skiing start
     */
    onSkiingStart() {
        console.log('[ActivityDetector] Skiing started');
        
        this.currentRun = {
            id: Utils.generateId(),
            startTime: Date.now(),
            startPosition: this.stateHistory[this.stateHistory.length - 1]?.position,
            positions: []
        };
        
        if (this.callbacks.onSkiingStart) {
            this.callbacks.onSkiingStart(this.currentRun);
        }
        
        // Notify user
        this.notifyUser('🏔️ Run started!');
    },
    
    /**
     * Handle skiing end
     */
    onSkiingEnd() {
        console.log('[ActivityDetector] Skiing ended');
        
        if (!this.currentRun) return;
        
        this.currentRun.endTime = Date.now();
        this.currentRun.endPosition = this.stateHistory[this.stateHistory.length - 1]?.position;
        this.currentRun.duration = this.currentRun.endTime - this.currentRun.startTime;
        
        // Only save if run was long enough
        if (this.currentRun.duration >= this.config.timeThresholds.minSkiDuration) {
            this.runs.push(this.currentRun);
            
            if (this.callbacks.onRunDetected) {
                this.callbacks.onRunDetected(this.currentRun);
            }
            
            this.notifyUser(`✅ Run completed! (${Math.round(this.currentRun.duration / 1000)}s)`);
        } else {
            this.notifyUser('Run too short, discarded');
        }
        
        this.currentRun = null;
    },
    
    /**
     * Handle lift start
     */
    onLiftStart() {
        console.log('[ActivityDetector] Lift ride detected');
        
        if (this.callbacks.onLiftDetected) {
            this.callbacks.onLiftDetected();
        }
        
        this.notifyUser('🚡 Lift ride detected');
    },
    
    /**
     * Add position to current run
     */
    addPositionToRun(position) {
        if (this.currentRun) {
            this.currentRun.positions.push(position);
        }
    },
    
    /**
     * Get current run number
     */
    getCurrentRunNumber() {
        return this.runs.length + (this.currentRun ? 1 : 0);
    },
    
    /**
     * Get total runs detected
     */
    getTotalRuns() {
        return this.runs.length;
    },
    
    /**
     * Get all completed runs
     */
    getRuns() {
        return [...this.runs];
    },
    
    /**
     * Reset detector
     */
    reset() {
        this.currentState = this.states.UNKNOWN;
        this.stateHistory = [];
        this.currentRun = null;
        this.runs = [];
        this.liftSegments = [];
    },
    
    /**
     * Set callback for state changes
     */
    onStateChange(callback) {
        this.callbacks.onStateChange = callback;
    },
    
    /**
     * Set callback for run detection
     */
    onRunDetected(callback) {
        this.callbacks.onRunDetected = callback;
    },
    
    /**
     * Set callback for lift detection
     */
    onLiftDetected(callback) {
        this.callbacks.onLiftDetected = callback;
    },
    
    /**
     * Set callback for skiing start
     */
    onSkiingStart(callback) {
        this.callbacks.onSkiingStart = callback;
    },
    
    /**
     * Set callback for skiing end
     */
    onSkiingEnd(callback) {
        this.callbacks.onSkiingEnd = callback;
    },
    
    /**
     * Notify user (uses app's notification system or console)
     */
    notifyUser(message) {
        if (typeof Utils !== 'undefined' && Utils.showToast) {
            Utils.showToast(message);
        } else {
            console.log(`[ActivityDetector] ${message}`);
        }
        
        // Also use haptic feedback if available
        if (navigator.vibrate) {
            navigator.vibrate(50);
        }
    },
    
    /**
     * Get status for UI display
     */
    getStatus() {
        return {
            state: this.currentState,
            stateDisplay: this.getStateDisplay(this.currentState),
            currentRun: this.currentRun ? {
                number: this.getCurrentRunNumber(),
                duration: Date.now() - this.currentRun.startTime,
                positionCount: this.currentRun.positions.length
            } : null,
            totalRuns: this.runs.length,
            isOnLift: this.currentState === this.states.LIFT
        };
    },
    
    /**
     * Get display text for state
     */
    getStateDisplay(state) {
        const displays = {
            [this.states.UNKNOWN]: '⏳ Detecting...',
            [this.states.STOPPED]: '⏸️ Stopped',
            [this.states.LIFT]: '🚡 On Lift',
            [this.states.SKIING]: '⛷️ Skiing!'
        };
        return displays[state] || state;
    },
    
    /**
     * Render activity indicator for UI
     */
    renderIndicator(container) {
        const status = this.getStatus();
        
        container.innerHTML = `
            <div class="activity-indicator state-${status.state}">
                <div class="activity-state">${status.stateDisplay}</div>
                ${status.currentRun ? `
                    <div class="activity-run-info">
                        Run ${status.currentRun.number} • 
                        ${this.formatDuration(status.currentRun.duration)}
                    </div>
                ` : `
                    <div class="activity-run-info">
                        ${status.totalRuns} runs completed
                    </div>
                `}
            </div>
        `;
    },
    
    /**
     * Format duration for display
     */
    formatDuration(ms) {
        const seconds = Math.floor(ms / 1000);
        const minutes = Math.floor(seconds / 60);
        const secs = seconds % 60;
        return `${minutes}:${secs.toString().padStart(2, '0')}`;
    }
};

// Initialize
ActivityDetector.init();
