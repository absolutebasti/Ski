/**
 * Segments & Leaderboards Module
 * HIGH-005: Run Segments & Leaderboards
 * 
 * Creates virtual segments on popular slopes for competitive racing
 * Similar to Strava segments for skiing
 */

const Segments = {
    // Predefined segments for Kitzbühel
    segments: [
        {
            id: 'streif-full',
            name: 'Streif - Full Descent',
            description: 'The legendary Hahnenkamm downhill course',
            difficulty: 'expert',
            start: { lat: 47.4568, lon: 12.3645, radius: 50 },
            end: { lat: 47.4491, lon: 12.3913, radius: 50 },
            distance: 3312, // meters
            vertical: 860, // meters
            avgSlope: 26, // degrees
            maxSlope: 85,
            category: 'downhill'
        },
        {
            id: 'streif-startshuss',
            name: 'Streif - Startschuss',
            description: 'The infamous starting jump',
            difficulty: 'expert',
            start: { lat: 47.4568, lon: 12.3645, radius: 30 },
            end: { lat: 47.4555, lon: 12.3655, radius: 30 },
            distance: 200,
            vertical: 80,
            avgSlope: 45,
            category: 'downhill'
        },
        {
            id: 'streif-mausefalle',
            name: 'Streif - Mausefalle',
            description: 'The legendary Mausefalle jump',
            difficulty: 'expert',
            start: { lat: 47.4555, lon: 12.3655, radius: 30 },
            end: { lat: 47.4540, lon: 12.3670, radius: 30 },
            distance: 300,
            vertical: 120,
            avgSlope: 50,
            category: 'downhill'
        },
        {
            id: 'streif-hausberg',
            name: 'Streif - Hausberg',
            description: 'The Hausbergkante technical section',
            difficulty: 'expert',
            start: { lat: 47.4530, lon: 12.3680, radius: 40 },
            end: { lat: 47.4520, lon: 12.3750, radius: 40 },
            distance: 800,
            vertical: 200,
            avgSlope: 35,
            category: 'downhill'
        },
        {
            id: 'ganslern',
            name: 'Ganslernhang',
            description: 'Classic slalom training slope',
            difficulty: 'medium',
            start: { lat: 47.4450, lon: 12.3920, radius: 40 },
            end: { lat: 47.4480, lon: 12.3880, radius: 40 },
            distance: 1200,
            vertical: 280,
            avgSlope: 18,
            category: 'slalom'
        },
        {
            id: 'ehrenbach',
            name: 'Ehrenbachhöhe',
            description: 'Beautiful red piste with great views',
            difficulty: 'medium',
            start: { lat: 47.4350, lon: 12.4050, radius: 50 },
            end: { lat: 47.4420, lon: 12.3950, radius: 50 },
            distance: 2500,
            vertical: 450,
            avgSlope: 12,
            category: 'piste'
        },
        {
            id: 'baumgarten',
            name: 'Baumgartenabfahrt',
            description: 'Wide cruising blue run',
            difficulty: 'easy',
            start: { lat: 47.4400, lon: 12.4000, radius: 50 },
            end: { lat: 47.4480, lon: 12.3900, radius: 50 },
            distance: 2800,
            vertical: 400,
            avgSlope: 10,
            category: 'piste'
        },
        {
            id: 'kogel',
            name: 'Kogelabfahrt',
            description: 'Fast red run from Kogel peak',
            difficulty: 'medium',
            start: { lat: 47.4300, lon: 12.4100, radius: 50 },
            end: { lat: 47.4400, lon: 12.3950, radius: 50 },
            distance: 3200,
            vertical: 600,
            avgSlope: 15,
            category: 'piste'
        },
        {
            id: 'pengelstein-nord',
            name: 'Pengelstein Nord',
            description: 'Challenging north face run',
            difficulty: 'hard',
            start: { lat: 47.4250, lon: 12.4200, radius: 50 },
            end: { lat: 47.4350, lon: 12.4050, radius: 50 },
            distance: 2000,
            vertical: 500,
            avgSlope: 20,
            category: 'piste'
        },
        {
            id: 'jochberg',
            name: 'Jochbergabfahrt',
            description: 'Long descent to Jochberg village',
            difficulty: 'medium',
            start: { lat: 47.4150, lon: 12.4300, radius: 60 },
            end: { lat: 47.4320, lon: 12.4150, radius: 60 },
            distance: 4500,
            vertical: 800,
            avgSlope: 12,
            category: 'piste'
        },
        {
            id: 'kirchberg-valley',
            name: 'Kirchberg Valley Run',
            description: 'Scenic valley descent',
            difficulty: 'easy',
            start: { lat: 47.4200, lon: 12.4250, radius: 60 },
            end: { lat: 47.4450, lon: 12.3950, radius: 60 },
            distance: 5000,
            vertical: 600,
            avgSlope: 8,
            category: 'piste'
        },
        {
            id: 'bichlalm',
            name: 'Bichlalm Trail',
            description: 'Beautiful tree run',
            difficulty: 'medium',
            start: { lat: 47.4380, lon: 12.3850, radius: 40 },
            end: { lat: 47.4450, lon: 12.3750, radius: 40 },
            distance: 1800,
            vertical: 350,
            avgSlope: 14,
            category: 'piste'
        }
    ],
    
    // Leaderboard data (would sync with Supabase in production)
    leaderboards: {},
    
    // User's personal bests
    personalBests: {},
    
    /**
     * Initialize segments module
     */
    async init() {
        // Load personal bests from storage
        await this.loadPersonalBests();
        
        // Load leaderboards (mock data for now)
        this.generateMockLeaderboards();
        
        console.log(`[Segments] Initialized with ${this.segments.length} segments`);
    },
    
    /**
     * Load personal bests from storage
     */
    async loadPersonalBests() {
        try {
            const saved = await Storage.get('personalBests');
            if (saved) {
                this.personalBests = saved;
            }
        } catch (e) {
            console.error('[Segments] Failed to load personal bests:', e);
        }
    },
    
    /**
     * Save personal bests
     */
    async savePersonalBests() {
        try {
            await Storage.set('personalBests', this.personalBests);
        } catch (e) {
            console.error('[Segments] Failed to save personal bests:', e);
        }
    },
    
    /**
     * Generate mock leaderboard data
     */
    generateMockLeaderboards() {
        this.segments.forEach(segment => {
            const times = [];
            
            // Generate 10 random times
            const baseTime = segment.distance / 15; // Assume 15 m/s average
            
            for (let i = 0; i < 10; i++) {
                const variance = (Math.random() - 0.5) * 0.3; // ±15% variance
                const time = baseTime * (1 + variance + (i * 0.05));
                
                times.push({
                    rank: i + 1,
                    time: Math.round(time),
                    speed: Math.round(segment.distance / time * 3.6 * 10) / 10,
                    userId: `user_${Math.random().toString(36).substr(2, 8)}`,
                    displayName: this.generateAnonymousName(),
                    date: new Date(Date.now() - Math.random() * 30 * 24 * 60 * 60 * 1000).toISOString()
                });
            }
            
            // Sort by time
            times.sort((a, b) => a.time - b.time);
            
            // Update ranks
            times.forEach((t, i) => t.rank = i + 1);
            
            this.leaderboards[segment.id] = times;
        });
    },
    
    /**
     * Generate anonymous name
     */
    generateAnonymousName() {
        const adjectives = ['Fast', 'Swift', 'Crazy', 'Brave', 'Wild', 'Sneaky', 'Happy', 'Snow', 'Ice', 'Alpine'];
        const nouns = ['Skier', 'Rider', 'Carver', 'Powder', 'Eagle', 'Wolf', 'Bear', 'Fox', 'Racer', 'Champ'];
        const adj = adjectives[Math.floor(Math.random() * adjectives.length)];
        const noun = nouns[Math.floor(Math.random() * nouns.length)];
        return `${adj} ${noun}`;
    },
    
    /**
     * Get all segments
     */
    getAllSegments() {
        return this.segments.map(s => ({
            ...s,
            personalBest: this.personalBests[s.id] || null,
            leaderboard: this.leaderboards[s.id]?.slice(0, 3) || []
        }));
    },
    
    /**
     * Get segment by ID
     */
    getSegment(id) {
        const segment = this.segments.find(s => s.id === id);
        if (!segment) return null;
        
        return {
            ...segment,
            personalBest: this.personalBests[id] || null,
            leaderboard: this.leaderboards[id] || []
        };
    },
    
    /**
     * Check if a position is within a segment's start zone
     */
    isAtSegmentStart(position, segment) {
        const dist = this.calculateDistance(
            position.latitude,
            position.longitude,
            segment.start.lat,
            segment.start.lon
        );
        return dist <= segment.start.radius;
    },
    
    /**
     * Check if a position is within a segment's end zone
     */
    isAtSegmentEnd(position, segment) {
        const dist = this.calculateDistance(
            position.latitude,
            position.longitude,
            segment.end.lat,
            segment.end.lon
        );
        return dist <= segment.end.radius;
    },
    
    /**
     * Calculate distance between two coordinates
     */
    calculateDistance(lat1, lon1, lat2, lon2) {
        const R = 6371e3; // Earth's radius in meters
        const φ1 = lat1 * Math.PI / 180;
        const φ2 = lat2 * Math.PI / 180;
        const Δφ = (lat2 - lat1) * Math.PI / 180;
        const Δλ = (lon2 - lon1) * Math.PI / 180;

        const a = Math.sin(Δφ/2) * Math.sin(Δφ/2) +
                  Math.cos(φ1) * Math.cos(φ2) *
                  Math.sin(Δλ/2) * Math.sin(Δλ/2);
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));

        return R * c;
    },
    
    /**
     * Detect segments during tracking
     * Call this with each GPS position update
     */
    detectSegments(positions) {
        if (positions.length < 2) return [];
        
        const currentPos = positions[positions.length - 1];
        const detected = [];
        
        this.segments.forEach(segment => {
            // Check if we just crossed the start
            if (this.isAtSegmentStart(currentPos, segment)) {
                const wasAtStart = positions.slice(-5, -1).some(p => 
                    this.isAtSegmentStart(p, segment)
                );
                
                if (!wasAtStart) {
                    detected.push({
                        type: 'segment_start',
                        segment: segment,
                        position: currentPos,
                        timestamp: currentPos.timestamp
                    });
                }
            }
            
            // Check if we just crossed the end
            if (this.isAtSegmentEnd(currentPos, segment)) {
                const wasAtEnd = positions.slice(-5, -1).some(p => 
                    this.isAtSegmentEnd(p, segment)
                );
                
                if (!wasAtEnd) {
                    detected.push({
                        type: 'segment_end',
                        segment: segment,
                        position: currentPos,
                        timestamp: currentPos.timestamp
                    });
                }
            }
        });
        
        return detected;
    },
    
    /**
     * Calculate segment time from run positions
     */
    calculateSegmentTime(positions, segment) {
        let startTime = null;
        let endTime = null;
        
        for (const pos of positions) {
            if (!startTime && this.isAtSegmentStart(pos, segment)) {
                startTime = pos.timestamp;
            }
            
            if (startTime && this.isAtSegmentEnd(pos, segment)) {
                endTime = pos.timestamp;
                break;
            }
        }
        
        if (startTime && endTime) {
            return {
                time: endTime - startTime,
                startTime,
                endTime,
                speed: segment.distance / ((endTime - startTime) / 1000) * 3.6 // km/h
            };
        }
        
        return null;
    },
    
    /**
     * Process a completed run for segments
     */
    async processRun(run) {
        const results = [];
        
        for (const segment of this.segments) {
            const time = this.calculateSegmentTime(run.positions, segment);
            
            if (time) {
                const result = {
                    segmentId: segment.id,
                    segmentName: segment.name,
                    time: time.time,
                    speed: time.speed,
                    date: run.date,
                    isPersonalBest: false
                };
                
                // Check if personal best
                const currentPB = this.personalBests[segment.id];
                if (!currentPB || time.time < currentPB.time) {
                    result.isPersonalBest = true;
                    result.previousPB = currentPB;
                    
                    this.personalBests[segment.id] = {
                        time: time.time,
                        speed: time.speed,
                        date: run.date,
                        runId: run.id
                    };
                    
                    await this.savePersonalBests();
                    
                    // Check for KOM/QOM (mock)
                    const leaderboard = this.leaderboards[segment.id];
                    if (leaderboard && time.time < leaderboard[0].time) {
                        result.isKOM = true;
                    }
                }
                
                results.push(result);
            }
        }
        
        return results;
    },
    
    /**
     * Get leaderboard for a segment
     */
    getLeaderboard(segmentId, options = {}) {
        const segment = this.segments.find(s => s.id === segmentId);
        if (!segment) return null;
        
        const leaderboard = [...(this.leaderboards[segmentId] || [])];
        const personalBest = this.personalBests[segmentId];
        
        // Add user's personal best to leaderboard
        if (personalBest) {
            const userEntry = {
                rank: 0,
                time: personalBest.time,
                speed: personalBest.speed,
                userId: 'current_user',
                displayName: 'You',
                date: personalBest.date,
                isPersonal: true
            };
            
            // Find insertion point
            let insertIndex = leaderboard.findIndex(e => e.time > personalBest.time);
            if (insertIndex === -1) insertIndex = leaderboard.length;
            
            leaderboard.splice(insertIndex, 0, userEntry);
            
            // Update ranks
            leaderboard.forEach((e, i) => e.rank = i + 1);
        }
        
        return {
            segment,
            entries: leaderboard.slice(0, options.limit || 10),
            totalEntries: leaderboard.length,
            userRank: personalBest ? leaderboard.find(e => e.isPersonal)?.rank : null
        };
    },
    
    /**
     * Format time for display (mm:ss.ms)
     */
    formatTime(ms) {
        const totalSeconds = Math.floor(ms / 1000);
        const minutes = Math.floor(totalSeconds / 60);
        const seconds = totalSeconds % 60;
        const milliseconds = Math.floor((ms % 1000) / 10);
        
        return `${minutes}:${seconds.toString().padStart(2, '0')}.${milliseconds.toString().padStart(2, '0')}`;
    },
    
    /**
     * Get difficulty color
     */
    getDifficultyColor(difficulty) {
        const colors = {
            easy: '#4CAF50',
            medium: '#2196F3',
            hard: '#FF9800',
            expert: '#F44336'
        };
        return colors[difficulty] || '#9E9E9E';
    },
    
    /**
     * Render segments list UI
     */
    renderSegmentsList(container) {
        const segments = this.getAllSegments();
        
        // SECURITY FIX: Escape user content
        container.innerHTML = `
            <div class="segments-header">
                <h2>${I18n.t('segments')}</h2>
                <span class="segments-count">${segments.length} segments</span>
            </div>
            <div class="segments-list">
                ${segments.map(s => this.renderSegmentCard(s)).join('')}
            </div>
        `;
        
        // Add click handlers
        container.querySelectorAll('.segment-card').forEach(card => {
            card.addEventListener('click', () => {
                const segmentId = card.dataset.segmentId;
                this.showSegmentDetail(segmentId);
            });
        });
    },
    
    /**
     * Render segment card HTML
     */
    renderSegmentCard(segment) {
        const pb = segment.personalBest;
        const topTime = segment.leaderboard[0];
        
        // SECURITY FIX: Escape all user content
        return `
            <div class="segment-card" data-segment-id="${SecurityUtils.escapeHTML(segment.id)}">
                <div class="segment-difficulty" style="background: ${this.getDifficultyColor(segment.difficulty)}"></div>
                <div class="segment-info">
                    <h3>${SecurityUtils.escapeHTML(segment.name)}</h3>
                    <p class="segment-desc">${SecurityUtils.escapeHTML(segment.description)}</p>
                    <div class="segment-stats">
                        <span>📏 ${(segment.distance / 1000).toFixed(1)} km</span>
                        <span>⛰️ ${segment.vertical} m</span>
                        <span>📐 ${segment.avgSlope}°</span>
                    </div>
                </div>
                <div class="segment-times">
                    ${pb ? `
                        <div class="segment-pb">
                            <span class="label">${I18n.t('personalBest')}</span>
                            <span class="time">${this.formatTime(pb.time)}</span>
                        </div>
                    ` : '<div class="segment-no-pb">No time yet</div>'}
                    ${topTime ? `
                        <div class="segment-kom">
                            <span class="label">${I18n.t('kingOfMountain')}</span>
                            <span class="time">${this.formatTime(topTime.time * 1000)}</span>
                        </div>
                    ` : ''}
                </div>
            </div>
        `;
    },
    
    /**
     * Show segment detail modal
     */
    showSegmentDetail(segmentId) {
        const data = this.getLeaderboard(segmentId, { limit: 10 });
        if (!data) return;
        
        const { segment, entries, userRank } = data;
        
        const modal = document.createElement('div');
        modal.className = 'modal segment-modal';
        // SECURITY FIX: Escape all user content
        modal.innerHTML = `
            <div class="modal-content">
                <div class="segment-header">
                    <h2>${SecurityUtils.escapeHTML(segment.name)}</h2>
                    <button class="btn-close" onclick="this.closest('.modal').remove()">×</button>
                </div>
                <p class="segment-description">${SecurityUtils.escapeHTML(segment.description)}</p>
                <div class="segment-meta">
                    <span class="difficulty-badge" style="background: ${this.getDifficultyColor(segment.difficulty)}">
                        ${I18n.t(`difficulty${segment.difficulty.charAt(0).toUpperCase() + segment.difficulty.slice(1)}`)}
                    </span>
                    <span>📏 ${(segment.distance / 1000).toFixed(2)} km</span>
                    <span>⛰️ ${segment.vertical} m</span>
                </div>
                
                <div class="leaderboard-section">
                    <h3>${I18n.t('leaderboard')}</h3>
                    ${userRank ? `<p class="user-rank">Your rank: #${userRank}</p>` : ''}
                    <div class="leaderboard-list">
                        ${entries.map((e, i) => `
                            <div class="leaderboard-entry ${e.isPersonal ? 'is-personal' : ''}">
                                <span class="rank">${e.rank}</span>
                                <span class="name">${SecurityUtils.escapeHTML(e.displayName)}</span>
                                <span class="time">${this.formatTime(e.time * 1000)}</span>
                                <span class="speed">${e.speed.toFixed(1)} km/h</span>
                            </div>
                        `).join('')}
                    </div>
                </div>
            </div>
        `;
        
        document.body.appendChild(modal);
    }
};

// Initialize
Segments.init();
