/**
 * KitzSki Tracker - Slope Angle Calculation
 * MEDIUM-003: Slope Angle Calculation
 * 
 * Calculates slope steepness from GPS data:
 * - Max slope angle per run
 * - Color-coded track by steepness
 * - Avalanche risk warnings for steep slopes
 */

const SlopeCalculator = {
    // Earth radius in meters
    EARTH_RADIUS: 6371000,
    
    /**
     * Calculate slope angle between two positions
     * @param {Object} pos1 - First position {lat, lon, alt}
     * @param {Object} pos2 - Second position {lat, lon, alt}
 * @returns {number} Slope angle in degrees
     */
    calculateSlopeAngle(pos1, pos2) {
        if (!pos1 || !pos2) return 0;
        if (pos1.alt === null || pos2.alt === null) return 0;
        
        // Calculate horizontal distance
        const horizontalDist = this.calculateHorizontalDistance(
            pos1.lat, pos1.lon,
            pos2.lat, pos2.lon
        );
        
        // Calculate vertical distance
        const verticalDist = pos2.alt - pos1.alt;
        
        // Avoid division by zero
        if (horizontalDist < 0.1) return 0;
        
        // Calculate slope angle using arctan
        const angleRad = Math.atan2(Math.abs(verticalDist), horizontalDist);
        const angleDeg = angleRad * (180 / Math.PI);
        
        // Return signed angle (negative for ascent, positive for descent)
        return verticalDist < 0 ? -angleDeg : angleDeg;
    },
    
    /**
     * Calculate horizontal distance using Haversine formula
     * @param {number} lat1 - First latitude
     * @param {number} lon1 - First longitude
     * @param {number} lat2 - Second latitude
     * @param {number} lon2 - Second longitude
     * @returns {number} Distance in meters
     */
    calculateHorizontalDistance(lat1, lon1, lat2, lon2) {
        const φ1 = lat1 * Math.PI / 180;
        const φ2 = lat2 * Math.PI / 180;
        const Δφ = (lat2 - lat1) * Math.PI / 180;
        const Δλ = (lon2 - lon1) * Math.PI / 180;
        
        const a = Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
                  Math.cos(φ1) * Math.cos(φ2) *
                  Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        
        return this.EARTH_RADIUS * c;
    },
    
    /**
     * Analyze an entire run for slope angles
     * @param {Array} positions - Array of positions
     * @returns {Object} Slope analysis
     */
    analyzeRun(positions) {
        if (!positions || positions.length < 2) {
            return {
                maxSlope: 0,
                avgSlope: 0,
                slopeProfile: [],
                steepSections: [],
                riskAssessment: 'unknown'
            };
        }
        
        const slopes = [];
        const steepSections = [];
        let currentSteepSection = null;
        
        for (let i = 1; i < positions.length; i++) {
            const pos1 = positions[i - 1];
            const pos2 = positions[i];
            
            // Only calculate if we have altitude data
            if (pos1.alt !== null && pos2.alt !== null) {
                const slope = this.calculateSlopeAngle(
                    { lat: pos1.lat, lon: pos1.lon, alt: pos1.alt },
                    { lat: pos2.lat, lon: pos2.lon, alt: pos2.alt }
                );
                
                slopes.push({
                    index: i,
                    slope: slope,
                    lat: (pos1.lat + pos2.lat) / 2,
                    lon: (pos1.lon + pos2.lon) / 2
                });
                
                // Track steep sections (>30 degrees)
                if (Math.abs(slope) > 30) {
                    if (!currentSteepSection) {
                        currentSteepSection = {
                            startIndex: i - 1,
                            maxSlope: Math.abs(slope),
                            slopes: [slope]
                        };
                    } else {
                        currentSteepSection.slopes.push(slope);
                        if (Math.abs(slope) > currentSteepSection.maxSlope) {
                            currentSteepSection.maxSlope = Math.abs(slope);
                        }
                    }
                } else {
                    if (currentSteepSection) {
                        currentSteepSection.endIndex = i - 1;
                        steepSections.push(currentSteepSection);
                        currentSteepSection = null;
                    }
                }
            }
        }
        
        // Close last steep section if exists
        if (currentSteepSection) {
            currentSteepSection.endIndex = positions.length - 1;
            steepSections.push(currentSteepSection);
        }
        
        // Calculate statistics
        const slopeValues = slopes.map(s => Math.abs(s.slope));
        const maxSlope = slopeValues.length > 0 ? Math.max(...slopeValues) : 0;
        const avgSlope = slopeValues.length > 0 ? 
            slopeValues.reduce((a, b) => a + b, 0) / slopeValues.length : 0;
        
        // Determine risk level
        const riskAssessment = this.assessAvalancheRisk(maxSlope, steepSections);
        
        return {
            maxSlope: Math.round(maxSlope * 10) / 10,
            avgSlope: Math.round(avgSlope * 10) / 10,
            slopeProfile: slopes,
            steepSections: steepSections.map(s => ({
                ...s,
                avgSlope: Math.abs(s.slopes.reduce((a, b) => a + b, 0) / s.slopes.length)
            })),
            riskAssessment
        };
    },
    
    /**
     * Assess avalanche risk based on slope angles
     * @param {number} maxSlope - Maximum slope angle
     * @param {Array} steepSections - Array of steep sections
     * @returns {Object} Risk assessment
     */
    assessAvalancheRisk(maxSlope, steepSections) {
        // Avalanche risk zones:
        // <30°: Generally safe
        // 30-35°: Moderate risk (most avalanches occur here)
        // 35-45°: High risk
        // >45°: Very high risk (but less frequent due to sluffing)
        
        let level = 'low';
        let warnings = [];
        
        if (maxSlope > 45) {
            level = 'extreme';
            warnings.push('Extremely steep terrain - high avalanche risk');
        } else if (maxSlope > 35) {
            level = 'high';
            warnings.push('Steep terrain (35°+) - significant avalanche risk');
        } else if (maxSlope > 30) {
            level = 'moderate';
            warnings.push('Moderate slope (30°+) - avalanche possible');
        }
        
        // Additional warnings based on steep section duration
        const longSteepSections = steepSections.filter(s => 
            s.slopes && s.slopes.length > 10
        );
        
        if (longSteepSections.length > 0) {
            warnings.push(`Sustained steep sections detected`);
        }
        
        return {
            level,
            maxSlope,
            steepSectionCount: steepSections.length,
            warnings,
            description: this.getRiskDescription(level)
        };
    },
    
    /**
     * Get risk level description
     * @param {string} level - Risk level
     * @returns {string} Description
     */
    getRiskDescription(level) {
        const descriptions = {
            low: 'Generally safe - normal precautions',
            moderate: 'Avalanche possible - check conditions',
            high: 'Significant risk - expert only with proper gear',
            extreme: 'Extreme risk - avoid if possible'
        };
        return descriptions[level] || descriptions.low;
    },
    
    /**
     * Get color for slope angle (for map visualization)
     * @param {number} angle - Slope angle in degrees
     * @returns {string} Hex color code
     */
    getSlopeColor(angle) {
        const absAngle = Math.abs(angle);
        
        if (absAngle < 15) return '#00ff00';      // Green - gentle
        if (absAngle < 25) return '#7fff00';      // Yellow-green - moderate
        if (absAngle < 30) return '#ffff00';      // Yellow - intermediate
        if (absAngle < 35) return '#ffbf00';      // Orange - steep
        if (absAngle < 40) return '#ff7f00';      // Dark orange - very steep
        if (absAngle < 45) return '#ff0000';      // Red - extreme
        return '#8b0000';                          // Dark red - very extreme
    },
    
    /**
     * Get difficulty rating based on slope angle
     * @param {number} angle - Slope angle in degrees
     * @returns {string} Difficulty rating
     */
    getDifficultyRating(angle) {
        const absAngle = Math.abs(angle);
        
        if (absAngle < 15) return 'Easy (Blue)';
        if (absAngle < 25) return 'Intermediate (Red)';
        if (absAngle < 35) return 'Advanced (Black)';
        return 'Expert (Double Black)';
    },
    
    /**
     * Format slope angle for display
     * @param {number} angle - Slope angle
     * @returns {string} Formatted string
     */
    formatSlope(angle) {
        const prefix = angle < 0 ? '↑' : '↓';
        return `${prefix} ${Math.abs(angle).toFixed(1)}°`;
    },
    
    /**
     * Calculate slope statistics for a segment
     * @param {Array} positions - Position array
     * @param {number} startIndex - Start index
     * @param {number} endIndex - End index
     * @returns {Object} Segment statistics
     */
    calculateSegmentStats(positions, startIndex, endIndex) {
        if (!positions || startIndex >= endIndex) return null;
        
        const segmentPositions = positions.slice(startIndex, endIndex + 1);
        const analysis = this.analyzeRun(segmentPositions);
        
        return {
            startIndex,
            endIndex,
            distance: this.calculateSegmentDistance(positions, startIndex, endIndex),
            ...analysis
        };
    },
    
    /**
     * Calculate distance of a segment
     * @param {Array} positions - Position array
     * @param {number} startIndex - Start index
     * @param {number} endIndex - End index
     * @returns {number} Distance in meters
     */
    calculateSegmentDistance(positions, startIndex, endIndex) {
        let distance = 0;
        
        for (let i = startIndex + 1; i <= endIndex && i < positions.length; i++) {
            distance += this.calculateHorizontalDistance(
                positions[i - 1].lat, positions[i - 1].lon,
                positions[i].lat, positions[i].lon
            );
        }
        
        return distance;
    }
};

// Make available globally
window.SlopeCalculator = SlopeCalculator;
