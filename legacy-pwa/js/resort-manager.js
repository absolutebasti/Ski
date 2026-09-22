/**
 * Multi-Resort Support Module
 * HIGH-010: Implement Multi-Resort Support
 * 
 * Enables tracking at multiple ski resorts with resort-specific data
 */

const ResortManager = {
    // Current resort
    currentResort: null,
    
    // Available resorts
    resorts: {
        kitzbuehel: {
            id: 'kitzbuehel',
            name: 'Kitzbühel',
            country: 'AT',
            region: 'Tyrol',
            center: { lat: 47.4491, lon: 12.3913 },
            bounds: {
                north: 47.47,
                south: 47.41,
                east: 12.45,
                west: 12.32
            },
            elevation: {
                base: 800,
                summit: 2000
            },
            trailsUrl: '/assets/trails/kitzbuehel.geojson',
            pisteMapUrl: '/assets/maps/kitzbuehel-piste.jpg',
            scraper: 'bergfex-kitzbuehel',
            difficulty: {
                easy: 30,
                medium: 45,
                hard: 20,
                expert: 5
            },
            lifts: 56,
            slopes: 92,
            kilometers: 233,
            features: ['3D terrain', 'Segment leaderboards', 'Photo spots'],
            season: { start: '11-01', end: '04-30' }
        },
        
        zellamsee: {
            id: 'zellamsee',
            name: 'Zell am See-Kaprun',
            country: 'AT',
            region: 'Salzburg',
            center: { lat: 47.2918, lon: 12.7952 },
            bounds: {
                north: 47.32,
                south: 47.25,
                east: 12.85,
                west: 12.74
            },
            elevation: {
                base: 757,
                summit: 3029
            },
            trailsUrl: '/assets/trails/zellamsee.geojson',
            pisteMapUrl: '/assets/maps/zellamsee-piste.jpg',
            scraper: 'bergfex-zellamsee',
            difficulty: {
                easy: 35,
                medium: 40,
                hard: 20,
                expert: 5
            },
            lifts: 52,
            slopes: 80,
            kilometers: 210,
            features: ['Glacier skiing', 'High altitude', 'Lake views'],
            season: { start: '10-15', end: '05-15' }
        },
        
        ischgl: {
            id: 'ischgl',
            name: 'Ischgl',
            country: 'AT',
            region: 'Tyrol',
            center: { lat: 47.0123, lon: 10.2886 },
            bounds: {
                north: 47.04,
                south: 46.99,
                east: 10.34,
                west: 10.23
            },
            elevation: {
                base: 1377,
                summit: 2872
            },
            trailsUrl: '/assets/trails/ischgl.geojson',
            pisteMapUrl: '/assets/maps/ischgl-piste.jpg',
            scraper: 'bergfex-ischgl',
            difficulty: {
                easy: 25,
                medium: 45,
                hard: 22,
                expert: 8
            },
            lifts: 45,
            slopes: 73,
            kilometers: 239,
            features: ['Après-ski', 'Snow park', 'Cross-border (CH)'],
            season: { start: '11-20', end: '05-01' }
        },
        
        solden: {
            id: 'solden',
            name: 'Sölden',
            country: 'AT',
            region: 'Tyrol',
            center: { lat: 46.9667, lon: 11.0167 },
            bounds: {
                north: 47.00,
                south: 46.93,
                east: 11.08,
                west: 10.95
            },
            elevation: {
                base: 1377,
                summit: 3340
            },
            trailsUrl: '/assets/trails/solden.geojson',
            pisteMapUrl: '/assets/maps/solden-piste.jpg',
            scraper: 'bergfex-solden',
            difficulty: {
                easy: 30,
                medium: 40,
                hard: 22,
                expert: 8
            },
            lifts: 33,
            slopes: 72,
            kilometers: 198,
            features: ['3 glaciers', 'James Bond location', 'Rettenbach glacier'],
            season: { start: '09-15', end: '05-01' }
        },
        
        lech: {
            id: 'lech',
            name: 'Lech-Zürs',
            country: 'AT',
            region: 'Vorarlberg',
            center: { lat: 47.2167, lon: 10.1333 },
            bounds: {
                north: 47.25,
                south: 47.18,
                east: 10.20,
                west: 10.06
            },
            elevation: {
                base: 1450,
                summit: 2811
            },
            trailsUrl: '/assets/trails/lech.geojson',
            pisteMapUrl: '/assets/maps/lech-piste.jpg',
            scraper: 'bergfex-lech',
            difficulty: {
                easy: 32,
                medium: 43,
                hard: 19,
                expert: 6
            },
            lifts: 88,
            slopes: 110,
            kilometers: 307,
            features: ['Arlberg circuit', 'Luxury resort', 'Powder snow'],
            season: { start: '12-01', end: '04-30' }
        },
        
        stanton: {
            id: 'stanton',
            name: 'St. Anton am Arlberg',
            country: 'AT',
            region: 'Tyrol',
            center: { lat: 47.1167, lon: 10.2667 },
            bounds: {
                north: 47.15,
                south: 47.08,
                east: 10.33,
                west: 10.20
            },
            elevation: {
                base: 1304,
                summit: 2811
            },
            trailsUrl: '/assets/trails/stanton.geojson',
            pisteMapUrl: '/assets/maps/stanton-piste.jpg',
            scraper: 'bergfex-stanton',
            difficulty: {
                easy: 25,
                medium: 40,
                hard: 25,
                expert: 10
            },
            lifts: 85,
            slopes: 116,
            kilometers: 305,
            features: ['Expert terrain', 'Arlberg circuit', 'Challenging slopes'],
            season: { start: '12-01', end: '04-30' }
        }
    },
    
    // User's favorite resorts
    favorites: [],
    
    // Last visited
    lastVisited: null,
    
    /**
     * Initialize resort manager
     */
    async init() {
        await this.loadPreferences();
        
        // Detect current resort from GPS if available
        if (navigator.geolocation) {
            this.detectCurrentResort();
        }
        
        console.log('[ResortManager] Initialized with', Object.keys(this.resorts).length, 'resorts');
    },
    
    /**
     * Load user preferences
     */
    async loadPreferences() {
        try {
            const data = await Storage.get('resortPreferences');
            if (data) {
                this.favorites = data.favorites || [];
                this.lastVisited = data.lastVisited || null;
                this.currentResort = data.currentResort || null;
            }
        } catch (e) {
            console.error('[ResortManager] Failed to load preferences:', e);
        }
    },
    
    /**
     * Save user preferences
     */
    async savePreferences() {
        try {
            await Storage.set('resortPreferences', {
                favorites: this.favorites,
                lastVisited: this.lastVisited,
                currentResort: this.currentResort
            });
        } catch (e) {
            console.error('[ResortManager] Failed to save preferences:', e);
        }
    },
    
    /**
     * Get all available resorts
     */
    getAllResorts() {
        return Object.values(this.resorts).map(r => ({
            ...r,
            isFavorite: this.favorites.includes(r.id),
            isCurrent: this.currentResort === r.id
        }));
    },
    
    /**
     * Get resort by ID
     */
    getResort(id) {
        return this.resorts[id] || null;
    },
    
    /**
     * Get current resort
     */
    getCurrentResort() {
        if (this.currentResort) {
            return this.getResort(this.currentResort);
        }
        return null;
    },
    
    /**
     * Switch to a resort
     */
    async switchResort(resortId) {
        const resort = this.resorts[resortId];
        if (!resort) {
            throw new Error(`Resort not found: ${resortId}`);
        }
        
        this.currentResort = resortId;
        this.lastVisited = resortId;
        
        await this.savePreferences();
        
        // Update map if available
        if (typeof Map !== 'undefined' && Map.setCenter) {
            Map.setCenter([resort.center.lon, resort.center.lat]);
        }
        
        // Load resort-specific data
        await this.loadResortData(resortId);
        
        console.log(`[ResortManager] Switched to ${resort.name}`);
        
        // Track analytics
        if (typeof Analytics !== 'undefined') {
            Analytics.track('resort_switched', { resortId });
        }
        
        return resort;
    },
    
    /**
     * Load resort-specific data
     */
    async loadResortData(resortId) {
        const resort = this.resorts[resortId];
        
        // Load trail data
        if (resort.trailsUrl) {
            try {
                const response = await SecurityUtils.safeFetch(resort.trailsUrl);
                if (response.ok) {
                    const trails = await response.json();
                    // Store or process trails
                    console.log(`[ResortManager] Loaded ${trails.features?.length || 0} trails for ${resort.name}`);
                }
            } catch (e) {
                console.warn('[ResortManager] Failed to load trails:', e);
                ErrorTracker?.handleError(e, { context: 'loadResortData' });
            }
        }
        
        // Load slope status
        if (resort.scraper) {
            this.loadSlopeStatus(resortId);
        }
    },
    
    /**
     * Load slope status for resort
     */
    async loadSlopeStatus(resortId) {
        // This would call the scraper function
        console.log(`[ResortManager] Loading slope status for ${resortId}`);
    },
    
    /**
     * Detect current resort from GPS position
     */
    detectCurrentResort() {
        navigator.geolocation.getCurrentPosition(
            (position) => {
                const resort = this.findResortByPosition(
                    position.coords.latitude,
                    position.coords.longitude
                );
                
                if (resort && resort.id !== this.currentResort) {
                    console.log(`[ResortManager] Auto-detected resort: ${resort.name}`);
                    // Optionally auto-switch
                    // this.switchResort(resort.id);
                }
            },
            (error) => {
                console.warn('[ResortManager] Failed to detect resort:', error);
            },
            { timeout: 10000 }
        );
    },
    
    /**
     * Find resort by GPS coordinates
     */
    findResortByPosition(lat, lon) {
        for (const resort of Object.values(this.resorts)) {
            if (this.isPositionInBounds(lat, lon, resort.bounds)) {
                return resort;
            }
        }
        return null;
    },
    
    /**
     * Check if position is within resort bounds
     */
    isPositionInBounds(lat, lon, bounds) {
        return lat >= bounds.south && 
               lat <= bounds.north && 
               lon >= bounds.west && 
               lon <= bounds.east;
    },
    
    /**
     * Toggle favorite status
     */
    async toggleFavorite(resortId) {
        const index = this.favorites.indexOf(resortId);
        
        if (index > -1) {
            this.favorites.splice(index, 1);
        } else {
            this.favorites.push(resortId);
        }
        
        await this.savePreferences();
        return index === -1; // Returns true if added
    },
    
    /**
     * Get favorite resorts
     */
    getFavorites() {
        return this.favorites
            .map(id => this.resorts[id])
            .filter(Boolean);
    },
    
    /**
     * Get nearby resorts sorted by distance
     */
    getNearbyResorts(lat, lon, limit = 5) {
        const resorts = Object.values(this.resorts).map(r => ({
            ...r,
            distance: this.calculateDistance(lat, lon, r.center.lat, r.center.lon)
        }));
        
        resorts.sort((a, b) => a.distance - b.distance);
        
        return resorts.slice(0, limit);
    },
    
    /**
     * Calculate distance between coordinates
     */
    calculateDistance(lat1, lon1, lat2, lon2) {
        const R = 6371; // Earth's radius in km
        const dLat = (lat2 - lat1) * Math.PI / 180;
        const dLon = (lon2 - lon1) * Math.PI / 180;
        const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
                  Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
                  Math.sin(dLon/2) * Math.sin(dLon/2);
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
        return R * c;
    },
    
    /**
     * Get runs for a specific resort
     */
    async getResortRuns(resortId) {
        try {
            const allRuns = await Storage.getAllRuns();
            return allRuns.filter(run => run.resortId === resortId);
        } catch (e) {
            console.error('[ResortManager] Failed to get resort runs:', e);
            return [];
        }
    },
    
    /**
     * Get resort statistics
     */
    async getResortStats(resortId) {
        const runs = await this.getResortRuns(resortId);
        
        if (runs.length === 0) {
            return null;
        }
        
        const totalDistance = runs.reduce((sum, r) => sum + (r.totalDistance || 0), 0);
        const totalVertical = runs.reduce((sum, r) => sum + (r.totalDescent || 0), 0);
        const totalDuration = runs.reduce((sum, r) => sum + (r.duration || 0), 0);
        const maxSpeed = Math.max(...runs.map(r => r.maxSpeed || 0));
        
        return {
            runs: runs.length,
            totalDistance,
            totalVertical,
            totalDuration,
            maxSpeed,
            avgDistance: totalDistance / runs.length
        };
    },
    
    /**
     * Check if resort is in season
     */
    isInSeason(resortId) {
        const resort = this.resorts[resortId];
        if (!resort || !resort.season) return true;
        
        const now = new Date();
        const currentYear = now.getFullYear();
        const start = new Date(`${currentYear}-${resort.season.start}`);
        const end = new Date(`${currentYear}-${resort.season.end}`);
        
        // Handle season crossing year boundary
        if (end < start) {
            end.setFullYear(currentYear + 1);
        }
        
        return now >= start && now <= end;
    },
    
    /**
     * Render resort selector UI
     */
    renderResortSelector(container) {
        const resorts = this.getAllResorts();
        const current = this.getCurrentResort();
        
        // SECURITY FIX: Escape all user content to prevent XSS
        container.innerHTML = `
            <div class="resort-selector">
                <h3>${I18n.t('selectResort') || 'Select Resort'}</h3>
                <div class="resort-list">
                    ${resorts.map(r => `
                        <div class="resort-item ${r.isCurrent ? 'current' : ''}" 
                             data-resort-id="${SecurityUtils.escapeHTML(r.id)}"
                             onclick="ResortManager.switchResort('${SecurityUtils.escapeHTML(r.id)}')">
                            <div class="resort-flag">🇦🇹</div>
                            <div class="resort-info">
                                <h4>${SecurityUtils.escapeHTML(r.name)}</h4>
                                <span>${r.slopes} slopes • ${r.lifts} lifts</span>
                            </div>
                            ${r.isCurrent ? '<span class="current-badge">Current</span>' : ''}
                            <button class="btn-favorite ${r.isFavorite ? 'active' : ''}" 
                                    onclick="event.stopPropagation(); ResortManager.toggleFavorite('${SecurityUtils.escapeHTML(r.id)}')">
                                ${r.isFavorite ? '★' : '☆'}
                            </button>
                        </div>
                    `).join('')}
                </div>
            </div>
        `;
    },
    
    /**
     * Render resort info panel
     */
    renderResortInfo(container) {
        const resort = this.getCurrentResort();
        
        if (!resort) {
            container.textContent = 'No resort selected';
            return;
        }
        
        // SECURITY FIX: Escape all user content to prevent XSS
        container.innerHTML = `
            <div class="resort-info-panel">
                <h2>${SecurityUtils.escapeHTML(resort.name)}</h2>
                <div class="resort-meta">
                    <span>🇦🇹 ${SecurityUtils.escapeHTML(resort.region)}, ${SecurityUtils.escapeHTML(resort.country)}</span>
                    <span class="season-badge ${this.isInSeason(resort.id) ? 'open' : 'closed'}">
                        ${this.isInSeason(resort.id) ? 'In Season' : 'Out of Season'}
                    </span>
                </div>
                <div class="resort-stats">
                    <div class="stat">
                        <span class="value">${resort.slopes}</span>
                        <span class="label">Slopes</span>
                    </div>
                    <div class="stat">
                        <span class="value">${resort.lifts}</span>
                        <span class="label">Lifts</span>
                    </div>
                    <div class="stat">
                        <span class="value">${resort.kilometers}</span>
                        <span class="label">km</span>
                    </div>
                    <div class="stat">
                        <span class="value">${resort.elevation.summit - resort.elevation.base}</span>
                        <span class="label">m vertical</span>
                    </div>
                </div>
                <div class="difficulty-distribution">
                    ${Object.entries(resort.difficulty).map(([level, pct]) => `
                        <div class="difficulty-bar ${level}" style="width: ${pct}%"></div>
                    `).join('')}
                </div>
                <div class="resort-features">
                    ${resort.features.map(f => `<span class="feature">${f}</span>`).join('')}
                </div>
            </div>
        `;
    }
};

// Initialize
ResortManager.init();
