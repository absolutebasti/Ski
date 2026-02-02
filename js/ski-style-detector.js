/**
 * KitzSki Tracker - Ski Style Detection (AI-powered)
 * HIGH-017: Implement Ski Style Detection
 * 
 * Automatically detects skiing style from GPS patterns:
 * - Carving: Consistent radius turns, smooth speed curves
 * - Moguls: High frequency direction changes, vertical oscillations
 * - Powder: Slower speeds, more irregular patterns
 * - Racing: High speeds, minimal turning
 */

const SkiStyleDetector = {
    // Style detection thresholds
    THRESHOLDS: {
        carving: {
            minTurnFrequency: 1.5,  // turns per minute
            maxTurnFrequency: 4,
            maxSpeedVariance: 15,    // km/h variance
            minConsistency: 0.7      // pattern consistency score
        },
        moguls: {
            minVerticalOscillation: 8,  // meters
            minTurnFrequency: 3,
            maxAvgSpeed: 35            // km/h
        },
        powder: {
            maxAvgSpeed: 30,
            minIrregularity: 0.4,      // pattern irregularity
            minSpeedVariance: 10
        },
        racing: {
            minAvgSpeed: 50,
            maxTurnFrequency: 0.8,
            minConsistency: 0.8
        }
    },

    /**
     * Analyze a run and detect skiing style
     * @param {Array} positions - Array of position data points
     * @returns {Object} Detected style with confidence score
     */
    analyzeRun(positions) {
        if (!positions || positions.length < 10) {
            return { style: 'unknown', confidence: 0, reason: 'insufficient_data' };
        }

        const features = this.extractFeatures(positions);
        
        // Calculate style scores
        const scores = {
            carving: this.calculateCarvingScore(features),
            moguls: this.calculateMogulsScore(features),
            powder: this.calculatePowderScore(features),
            racing: this.calculateRacingScore(features)
        };

        // Find best matching style
        let bestStyle = 'mixed';
        let bestScore = 0.5; // Minimum threshold

        for (const [style, score] of Object.entries(scores)) {
            if (score > bestScore) {
                bestScore = score;
                bestStyle = style;
            }
        }

        // Determine confidence level
        const confidence = Math.min(bestScore, 0.95);

        return {
            style: bestStyle,
            confidence: Math.round(confidence * 100) / 100,
            features,
            scores,
            description: this.getStyleDescription(bestStyle)
        };
    },

    /**
     * Extract features from position data
     * @param {Array} positions - Position array
     * @returns {Object} Extracted features
     */
    extractFeatures(positions) {
        // Calculate turn frequency
        const turnFrequency = this.calculateTurnFrequency(positions);
        
        // Calculate speed statistics
        const speeds = positions.map(p => p.speed || 0).filter(s => s > 0);
        const avgSpeed = speeds.length > 0 ? 
            speeds.reduce((a, b) => a + b, 0) / speeds.length : 0;
        const speedVariance = this.calculateVariance(speeds);
        
        // Calculate vertical oscillation (for mogul detection)
        const verticalOscillation = this.calculateVerticalOscillation(positions);
        
        // Calculate pattern consistency
        const consistency = this.calculateConsistency(positions);
        
        // Calculate pattern irregularity (for powder detection)
        const irregularity = 1 - consistency;

        return {
            turnFrequency,
            avgSpeed: Math.round(avgSpeed * 10) / 10,
            speedVariance: Math.round(speedVariance * 10) / 10,
            verticalOscillation: Math.round(verticalOscillation * 10) / 10,
            consistency: Math.round(consistency * 100) / 100,
            irregularity: Math.round(irregularity * 100) / 100,
            duration: positions.length > 0 ? 
                (positions[positions.length - 1].timestamp - positions[0].timestamp) / 1000 : 0
        };
    },

    /**
     * Calculate turn frequency (turns per minute)
     * @param {Array} positions - Position array
     * @returns {number} Turns per minute
     */
    calculateTurnFrequency(positions) {
        if (positions.length < 3) return 0;

        let turns = 0;
        let lastBearing = null;
        const bearings = [];

        for (let i = 1; i < positions.length; i++) {
            const bearing = this.calculateBearing(
                positions[i - 1].lat,
                positions[i - 1].lon,
                positions[i].lat,
                positions[i].lon
            );
            
            if (lastBearing !== null) {
                const diff = Math.abs(bearing - lastBearing);
                const normalizedDiff = diff > 180 ? 360 - diff : diff;
                
                // Significant direction change = potential turn
                if (normalizedDiff > 20 && normalizedDiff < 160) {
                    bearings.push(normalizedDiff);
                    
                    // Count as turn if direction keeps changing
                    if (bearings.length >= 2) {
                        const lastTwo = bearings.slice(-2);
                        if (Math.abs(lastTwo[0] - lastTwo[1]) > 10) {
                            turns++;
                        }
                    }
                }
            }
            
            lastBearing = bearing;
        }

        // Convert to turns per minute
        const durationMinutes = positions.length > 0 ? 
            ((positions[positions.length - 1].timestamp - positions[0].timestamp) / 1000) / 60 : 0;
        
        return durationMinutes > 0 ? turns / durationMinutes : 0;
    },

    /**
     * Calculate bearing between two points
     * @param {number} lat1 - Start latitude
     * @param {number} lon1 - Start longitude
     * @param {number} lat2 - End latitude
     * @param {number} lon2 - End longitude
     * @returns {number} Bearing in degrees
     */
    calculateBearing(lat1, lon1, lat2, lon2) {
        const φ1 = lat1 * Math.PI / 180;
        const φ2 = lat2 * Math.PI / 180;
        const Δλ = (lon2 - lon1) * Math.PI / 180;

        const y = Math.sin(Δλ) * Math.cos(φ2);
        const x = Math.cos(φ1) * Math.sin(φ2) -
                  Math.sin(φ1) * Math.cos(φ2) * Math.cos(Δλ);

        let bearing = Math.atan2(y, x) * 180 / Math.PI;
        return (bearing + 360) % 360;
    },

    /**
     * Calculate speed variance
     * @param {Array} speeds - Array of speeds
     * @returns {number} Variance
     */
    calculateVariance(speeds) {
        if (speeds.length < 2) return 0;
        
        const mean = speeds.reduce((a, b) => a + b, 0) / speeds.length;
        const squaredDiffs = speeds.map(s => Math.pow(s - mean, 2));
        return Math.sqrt(squaredDiffs.reduce((a, b) => a + b, 0) / speeds.length);
    },

    /**
     * Calculate vertical oscillation (for mogul detection)
     * @param {Array} positions - Position array
     * @returns {number} Average vertical oscillation in meters
     */
    calculateVerticalOscillation(positions) {
        if (positions.length < 3) return 0;

        let totalOscillation = 0;
        let oscillationCount = 0;

        for (let i = 2; i < positions.length; i++) {
            const alt1 = positions[i - 2].alt;
            const alt2 = positions[i - 1].alt;
            const alt3 = positions[i].alt;

            if (alt1 !== null && alt2 !== null && alt3 !== null) {
                // Check for up-down pattern (characteristic of moguls)
                const diff1 = alt2 - alt1;
                const diff2 = alt3 - alt2;

                if ((diff1 > 0 && diff2 < 0) || (diff1 < 0 && diff2 > 0)) {
                    totalOscillation += Math.abs(diff1) + Math.abs(diff2);
                    oscillationCount++;
                }
            }
        }

        return oscillationCount > 0 ? totalOscillation / oscillationCount : 0;
    },

    /**
     * Calculate pattern consistency (0-1)
     * @param {Array} positions - Position array
     * @returns {number} Consistency score
     */
    calculateConsistency(positions) {
        if (positions.length < 5) return 0.5;

        // Calculate acceleration consistency
        const accelerations = [];
        let lastSpeed = null;
        let lastTime = null;

        for (const pos of positions) {
            if (lastSpeed !== null && lastTime !== null) {
                const timeDiff = (pos.timestamp - lastTime) / 1000; // seconds
                if (timeDiff > 0) {
                    const speedDiff = (pos.speed || 0) - lastSpeed;
                    accelerations.push(speedDiff / timeDiff);
                }
            }
            lastSpeed = pos.speed || 0;
            lastTime = pos.timestamp;
        }

        if (accelerations.length < 2) return 0.5;

        // Calculate how consistent the accelerations are
        const variance = this.calculateVariance(accelerations);
        // Lower variance = higher consistency
        return Math.max(0, Math.min(1, 1 - (variance / 10)));
    },

    /**
     * Calculate carving style score
     * @param {Object} features - Extracted features
     * @returns {number} Score 0-1
     */
    calculateCarvingScore(features) {
        const { turnFrequency, speedVariance, consistency } = features;
        const t = this.THRESHOLDS.carving;

        let score = 0;

        // Check turn frequency is in range
        if (turnFrequency >= t.minTurnFrequency && turnFrequency <= t.maxTurnFrequency) {
            score += 0.4;
        }

        // Check speed variance is low
        if (speedVariance <= t.maxSpeedVariance) {
            score += 0.3;
        }

        // Check consistency is high
        if (consistency >= t.minConsistency) {
            score += 0.3;
        }

        return score;
    },

    /**
     * Calculate moguls style score
     * @param {Object} features - Extracted features
     * @returns {number} Score 0-1
     */
    calculateMogulsScore(features) {
        const { verticalOscillation, turnFrequency, avgSpeed } = features;
        const t = this.THRESHOLDS.moguls;

        let score = 0;

        // Check vertical oscillation
        if (verticalOscillation >= t.minVerticalOscillation) {
            score += 0.4;
        }

        // Check high turn frequency
        if (turnFrequency >= t.minTurnFrequency) {
            score += 0.35;
        }

        // Check lower speed
        if (avgSpeed <= t.maxAvgSpeed) {
            score += 0.25;
        }

        return score;
    },

    /**
     * Calculate powder style score
     * @param {Object} features - Extracted features
     * @returns {number} Score 0-1
     */
    calculatePowderScore(features) {
        const { avgSpeed, irregularity, speedVariance } = features;
        const t = this.THRESHOLDS.powder;

        let score = 0;

        // Check lower speed
        if (avgSpeed <= t.maxAvgSpeed) {
            score += 0.35;
        }

        // Check high irregularity
        if (irregularity >= t.minIrregularity) {
            score += 0.35;
        }

        // Check speed variance
        if (speedVariance >= t.minSpeedVariance) {
            score += 0.3;
        }

        return score;
    },

    /**
     * Calculate racing style score
     * @param {Object} features - Extracted features
     * @returns {number} Score 0-1
     */
    calculateRacingScore(features) {
        const { avgSpeed, turnFrequency, consistency } = features;
        const t = this.THRESHOLDS.racing;

        let score = 0;

        // Check high speed
        if (avgSpeed >= t.minAvgSpeed) {
            score += 0.5;
        }

        // Check low turn frequency
        if (turnFrequency <= t.maxTurnFrequency) {
            score += 0.25;
        }

        // Check high consistency
        if (consistency >= t.minConsistency) {
            score += 0.25;
        }

        return score;
    },

    /**
     * Get style description
     * @param {string} style - Style name
     * @returns {string} Human readable description
     */
    getStyleDescription(style) {
        const descriptions = {
            carving: 'Smooth carving with consistent turns',
            moguls: 'Mogul skiing with quick direction changes',
            powder: 'Powder skiing with variable conditions',
            racing: 'High-speed racing style',
            mixed: 'Mixed skiing style'
        };
        return descriptions[style] || descriptions.mixed;
    },

    /**
     * Get style badge CSS class
     * @param {string} style - Style name
     * @returns {string} CSS class name
     */
    getStyleBadgeClass(style) {
        const classes = {
            carving: 'style-carving',
            moguls: 'style-moguls',
            powder: 'style-powder',
            racing: 'style-racing',
            mixed: 'style-mixed'
        };
        return classes[style] || classes.mixed;
    },

    /**
     * Get style icon
     * @param {string} style - Style name
     * @returns {string} Emoji icon
     */
    getStyleIcon(style) {
        const icons = {
            carving: '🎿',
            moguls: '⛷️',
            powder: '❄️',
            racing: '⚡',
            mixed: '🏔️'
        };
        return icons[style] || icons.mixed;
    }
};

// Make available globally
window.SkiStyleDetector = SkiStyleDetector;
