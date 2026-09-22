/**
 * KitzSki Tracker - 3D Run Visualization Module
 * 
 * Provides 3D flythrough replays of ski runs using Mapbox GL JS
 * with terrain exaggeration and animated camera following
 */

const Visualization3D = {
    // Map instance for 3D view
    map: null,
    
    // Animation state
    isPlaying: false,
    animationId: null,
    currentPointIndex: 0,
    
    // Animation settings
    settings: {
        baseSpeed: 500, // ms between points at minimum speed
        minZoom: 15,
        maxZoom: 17,
        pitch: 70, // Camera tilt
        terrainExaggeration: 1.5
    },
    
    // DOM elements
    container: null,
    progressBar: null,
    speedDisplay: null,

    /**
     * Initialize 3D visualization
     * @param {string} containerId - Container element ID
     */
    init(containerId) {
        this.container = document.getElementById(containerId);
        if (!this.container) {
            console.error('3D visualization container not found');
            return false;
        }
        return true;
    },

    /**
     * Create 3D map for run visualization
     * @param {Object} run - Run data
     * @returns {Promise} Map initialization promise
     */
    async createMap(run) {
        // Clean up existing map
        if (this.map) {
            this.map.remove();
            this.map = null;
        }

        const positions = run.positions || [];
        if (positions.length < 2) {
            throw new Error('Not enough positions for 3D visualization');
        }

        // Calculate bounds for initial view
        const lats = positions.map(p => p.lat);
        const lons = positions.map(p => p.lon);
        const center = [
            (Math.min(...lons) + Math.max(...lons)) / 2,
            (Math.min(...lats) + Math.max(...lats)) / 2
        ];

        // Create map with terrain
        mapboxgl.accessToken = Config.MAPBOX_TOKEN;
        
        this.map = new mapboxgl.Map({
            container: this.container,
            style: 'mapbox://styles/mapbox/satellite-v9',
            center: center,
            zoom: 15,
            pitch: this.settings.pitch,
            bearing: 0,
            attributionControl: false,
            antialias: true
        });

        return new Promise((resolve, reject) => {
            this.map.on('load', () => {
                try {
                    this.addTerrain();
                    this.addRouteLayer(run);
                    resolve(this.map);
                } catch (error) {
                    reject(error);
                }
            });

            this.map.on('error', (e) => {
                reject(new Error('Map load failed: ' + e.error.message));
            });
        });
    },

    /**
     * Add 3D terrain to map
     */
    addTerrain() {
        if (!this.map) return;

        // Add terrain source
        this.map.addSource('mapbox-dem', {
            type: 'raster-dem',
            url: 'mapbox://mapbox.terrain-rgb',
            tileSize: 512,
            maxzoom: 14
        });

        // Enable terrain with exaggeration
        this.map.setTerrain({
            source: 'mapbox-dem',
            exaggeration: this.settings.terrainExaggeration
        });

        // Add sky layer for atmosphere
        this.map.addLayer({
            id: 'sky',
            type: 'sky',
            paint: {
                'sky-type': 'atmosphere',
                'sky-atmosphere-sun': [0.0, 0.0],
                'sky-atmosphere-sun-intensity': 15
            }
        });
    },

    /**
     * Add route layer to map
     * @param {Object} run - Run data
     */
    addRouteLayer(run) {
        const positions = run.positions || [];
        if (positions.length === 0) return;

        const coordinates = positions.map(p => [p.lon, p.lat]);

        // Add route source
        this.map.addSource('route', {
            type: 'geojson',
            data: {
                type: 'Feature',
                geometry: {
                    type: 'LineString',
                    coordinates: coordinates
                },
                properties: {
                    maxSpeed: run.maxSpeed,
                    positions: positions
                }
            }
        });

        // Add glow layer
        this.map.addLayer({
            id: 'route-glow',
            type: 'line',
            source: 'route',
            paint: {
                'line-color': '#0a84ff',
                'line-width': 12,
                'line-opacity': 0.3,
                'line-blur': 8
            }
        });

        // Add main route layer with speed-based coloring
        this.map.addLayer({
            id: 'route-line',
            type: 'line',
            source: 'route',
            paint: {
                'line-color': [
                    'interpolate',
                    ['linear'],
                    ['get', 'speed'],
                    0, '#30d158',      // Green for slow
                    30, '#ffd700',     // Yellow for medium
                    60, '#ff453a'      // Red for fast
                ],
                'line-width': 4,
                'line-opacity': 0.9
            }
        });

        // Add start marker
        const startEl = document.createElement('div');
        startEl.className = 'marker-3d marker-start';
        startEl.textContent = '🏁'; // SECURITY FIX: Use textContent instead of innerHTML
        new mapboxgl.Marker(startEl)
            .setLngLat(coordinates[0])
            .addTo(this.map);

        // Add end marker
        const endEl = document.createElement('div');
        endEl.className = 'marker-3d marker-end';
        endEl.textContent = '🏔️'; // SECURITY FIX: Use textContent instead of innerHTML
        new mapboxgl.Marker(endEl)
            .setLngLat(coordinates[coordinates.length - 1])
            .addTo(this.map);
    },

    /**
     * Start 3D flythrough animation
     * @param {Object} run - Run data
     */
    async startAnimation(run) {
        if (this.isPlaying) return;

        const positions = run.positions || [];
        if (positions.length < 2) {
            throw new Error('Not enough positions for animation');
        }

        this.isPlaying = true;
        this.currentPointIndex = 0;

        // Create map if not exists
        if (!this.map) {
            await this.createMap(run);
        }

        // Start animation loop
        this.animate(positions);
    },

    /**
     * Animation loop
     * @param {Array} positions - Array of position data
     */
    animate(positions) {
        if (!this.isPlaying || this.currentPointIndex >= positions.length - 1) {
            this.stopAnimation();
            return;
        }

        const current = positions[this.currentPointIndex];
        const next = positions[this.currentPointIndex + 1];

        // Calculate bearing (direction of travel)
        const bearing = this.calculateBearing(
            current.lat, current.lon,
            next.lat, next.lon
        );

        // Calculate zoom based on speed
        const speed = current.speed || 0;
        const zoom = this.mapSpeedToZoom(speed);

        // Calculate animation duration based on speed
        const timeDiff = next.timestamp - current.timestamp;
        const duration = Math.max(100, Math.min(1000, timeDiff / 10));

        // Update camera
        this.map.easeTo({
            center: [current.lon, current.lat],
            bearing: bearing,
            zoom: zoom,
            pitch: this.settings.pitch,
            duration: duration,
            easing: (t) => t
        });

        // Update progress
        this.updateProgress(this.currentPointIndex / positions.length);

        // Move to next point
        this.currentPointIndex++;

        // Schedule next frame
        this.animationId = setTimeout(() => {
            this.animate(positions);
        }, duration);
    },

    /**
     * Stop animation
     */
    stopAnimation() {
        this.isPlaying = false;
        if (this.animationId) {
            clearTimeout(this.animationId);
            this.animationId = null;
        }
    },

    /**
     * Pause/Resume animation
     */
    togglePause() {
        if (this.isPlaying) {
            this.stopAnimation();
        } else {
            // Resume from current position
            const positions = this.map?.getSource('route')?._data?.properties?.positions;
            if (positions) {
                this.isPlaying = true;
                this.animate(positions);
            }
        }
    },

    /**
     * Reset animation to start
     */
    resetAnimation() {
        this.stopAnimation();
        this.currentPointIndex = 0;
        this.updateProgress(0);
        
        const positions = this.map?.getSource('route')?._data?.geometry?.coordinates;
        if (positions && positions.length > 0) {
            this.map.jumpTo({
                center: positions[0],
                bearing: 0,
                zoom: this.settings.minZoom
            });
        }
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
        const toRad = (deg) => deg * Math.PI / 180;
        const toDeg = (rad) => rad * 180 / Math.PI;

        const dLon = toRad(lon2 - lon1);
        const lat1Rad = toRad(lat1);
        const lat2Rad = toRad(lat2);

        const y = Math.sin(dLon) * Math.cos(lat2Rad);
        const x = Math.cos(lat1Rad) * Math.sin(lat2Rad) -
                  Math.sin(lat1Rad) * Math.cos(lat2Rad) * Math.cos(dLon);

        let bearing = toDeg(Math.atan2(y, x));
        return (bearing + 360) % 360;
    },

    /**
     * Map speed to zoom level
     * @param {number} speed - Speed in km/h
     * @returns {number} Zoom level
     */
    mapSpeedToZoom(speed) {
        // Faster = zoom out more to see ahead
        const speedFactor = Math.min(speed / 60, 1);
        return this.settings.maxZoom - (speedFactor * (this.settings.maxZoom - this.settings.minZoom));
    },

    /**
     * Update progress display
     * @param {number} progress - Progress from 0 to 1
     */
    updateProgress(progress) {
        if (this.progressBar) {
            this.progressBar.style.width = `${progress * 100}%`;
        }
    },

    /**
     * Create 3D visualization UI
     * @param {HTMLElement} container - Container element
     */
    createUI(container) {
        const ui = document.createElement('div');
        ui.className = 'visualization-3d-ui';
        ui.innerHTML = `
            <div class="viz-3d-progress">
                <div class="viz-3d-progress-bar" id="vizProgressBar"></div>
            </div>
            <div class="viz-3d-controls">
                <button class="viz-btn" id="vizResetBtn" title="Reset">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/>
                        <path d="M3 3v5h5"/>
                    </svg>
                </button>
                <button class="viz-btn viz-play" id="vizPlayBtn" title="Play/Pause">
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor">
                        <polygon points="5 3 19 12 5 21 5 3"/>
                    </svg>
                </button>
                <button class="viz-btn" id="vizCloseBtn" title="Close">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <line x1="18" y1="6" x2="6" y2="18"/>
                        <line x1="6" y1="6" x2="18" y2="18"/>
                    </svg>
                </button>
            </div>
        `;
        
        container.appendChild(ui);
        
        // Store references
        this.progressBar = ui.querySelector('#vizProgressBar');
        
        // Bind events
        ui.querySelector('#vizResetBtn').addEventListener('click', () => this.resetAnimation());
        ui.querySelector('#vizPlayBtn').addEventListener('click', () => this.togglePause());
        ui.querySelector('#vizCloseBtn').addEventListener('click', () => this.close());
        
        return ui;
    },

    /**
     * Close 3D visualization
     */
    close() {
        this.stopAnimation();
        if (this.map) {
            this.map.remove();
            this.map = null;
        }
        if (this.container) {
            this.container.innerHTML = '';
        }
    },

    /**
     * Check if device supports 3D visualization
     * @returns {boolean} True if supported
     */
    isSupported() {
        // Check for WebGL support
        try {
            const canvas = document.createElement('canvas');
            const gl = canvas.getContext('webgl') || canvas.getContext('experimental-webgl');
            return !!gl;
        } catch (e) {
            return false;
        }
    },

    /**
     * Get performance estimate
     * @returns {string} 'high', 'medium', or 'low'
     */
    getPerformanceLevel() {
        // Check device capabilities
        const memory = navigator.deviceMemory || 4;
        const cores = navigator.hardwareConcurrency || 2;
        
        if (memory >= 4 && cores >= 4) return 'high';
        if (memory >= 2 && cores >= 2) return 'medium';
        return 'low';
    }
};

// Make Visualization3D available globally
window.Visualization3D = Visualization3D;
