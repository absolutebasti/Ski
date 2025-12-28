/**
 * KitzSki Tracker - Map Module
 * Using Mapbox GL JS for interactive ski map
 */

const SkiMap = {
    map: null,
    userMarker: null,
    userMarkerEl: null,
    trackLine: null,
    isInitialized: false,
    
    // Kitzbühel ski area center coordinates
    KITZBUEHEL_CENTER: [12.3913, 47.4491],
    DEFAULT_ZOOM: 13,
    TRACKING_ZOOM: 15,
    
    // Mapbox configuration - loaded from Config
    MAPBOX_TOKEN: null, // Set via Config.init() from .env
    
    // Trail colors by difficulty
    trailColors: {
        easy: '#4ade80',      // Green - beginner
        intermediate: '#3b82f6', // Blue - intermediate  
        advanced: '#ef4444',     // Red - advanced
        expert: '#000000',       // Black - expert
        default: '#94a3b8'       // Gray - unknown
    },

    /**
     * Initialize the map
     * @param {string} containerId - Map container element ID
     * @param {string} accessToken - Mapbox access token (optional, uses Config)
     */
    async init(containerId = 'map', accessToken = null) {
        if (this.isInitialized) return;

        // Get token from Config, parameter, or fallback
        const token = accessToken || Config.MAPBOX_TOKEN || this.MAPBOX_TOKEN;
        
        // Check if we have a valid token
        if (!token || token.includes('your_') || token.length < 20) {
            console.log('No valid Mapbox token - map disabled');
            this.showMapError(containerId);
            return;
        }
        
        // Set access token
        mapboxgl.accessToken = token;
        
        try {
            // Create map instance with dark style
            this.map = new mapboxgl.Map({
                container: containerId,
                style: 'mapbox://styles/mapbox/dark-v11',
                center: this.KITZBUEHEL_CENTER,
                zoom: this.DEFAULT_ZOOM,
                pitch: 40,
                bearing: 0,
                antialias: true
            });

            // Wait for map to load
            await new Promise((resolve, reject) => {
                this.map.on('load', resolve);
                this.map.on('error', reject);
            });

            // Add navigation controls (zoom)
            this.map.addControl(new mapboxgl.NavigationControl({
                showCompass: true,
                showZoom: true,
                visualizePitch: true
            }), 'top-right');

            // Add terrain for 3D effect
            this.map.addSource('mapbox-dem', {
                type: 'raster-dem',
                url: 'mapbox://mapbox.mapbox-terrain-dem-v1',
                tileSize: 512,
                maxzoom: 14
            });
            
            this.map.setTerrain({ source: 'mapbox-dem', exaggeration: 1.2 });

            // Add sky layer
            this.map.addLayer({
                id: 'sky',
                type: 'sky',
                paint: {
                    'sky-type': 'atmosphere',
                    'sky-atmosphere-sun': [0.0, 0.0],
                    'sky-atmosphere-sun-intensity': 15
                }
            });

            // Initialize tracking line source
            this.map.addSource('track', {
                type: 'geojson',
                data: {
                    type: 'Feature',
                    properties: {},
                    geometry: {
                        type: 'LineString',
                        coordinates: []
                    }
                }
            });

            // Add track line layer
            this.map.addLayer({
                id: 'track-line',
                type: 'line',
                source: 'track',
                layout: {
                    'line-join': 'round',
                    'line-cap': 'round'
                },
                paint: {
                    'line-color': '#00d4ff',
                    'line-width': 4,
                    'line-opacity': 0.8
                }
            });

            // Add track glow effect
            this.map.addLayer({
                id: 'track-glow',
                type: 'line',
                source: 'track',
                layout: {
                    'line-join': 'round',
                    'line-cap': 'round'
                },
                paint: {
                    'line-color': '#00d4ff',
                    'line-width': 12,
                    'line-opacity': 0.3,
                    'line-blur': 4
                }
            }, 'track-line');

            // Load ski trails
            await this.loadSkiTrails();

            // Create user marker
            this.createUserMarker();

            this.isInitialized = true;
            console.log('Map initialized successfully');

        } catch (error) {
            console.error('Failed to initialize map:', error);
            this.showMapError(containerId);
        }
    },

    /**
     * Show error message when map fails to load
     * @param {string} containerId - Container element ID
     */
    showMapError(containerId) {
        const container = document.getElementById(containerId);
        if (container) {
            container.innerHTML = `
                <div style="
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    justify-content: center;
                    height: 100%;
                    background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
                    color: #fff;
                    text-align: center;
                    padding: 2rem;
                ">
                    <div style="font-size: 3rem; margin-bottom: 1rem;">🗺️</div>
                    <p style="font-size: 0.875rem; opacity: 0.7;">Map unavailable</p>
                    <p style="font-size: 0.75rem; opacity: 0.5; margin-top: 0.5rem;">
                        GPS tracking will still work
                    </p>
                </div>
            `;
        }
    },

    /**
     * Load Kitzbühel ski trails
     */
    async loadSkiTrails() {
        try {
            const resort = window.Resorts?.getCurrent();
            const trailsFile = resort?.trailsFile || '/assets/trails/kitzbuehel.geojson';
            const response = await fetch(trailsFile);
            
            if (!response.ok) {
                console.log('No ski trails data available');
                return;
            }

            const trailsData = await response.json();

            // Add trails source
            this.map.addSource('ski-trails', {
                type: 'geojson',
                data: trailsData
            });

            // Add trails layer
            this.map.addLayer({
                id: 'ski-trails-line',
                type: 'line',
                source: 'ski-trails',
                layout: {
                    'line-join': 'round',
                    'line-cap': 'round'
                },
                paint: {
                    'line-color': [
                        'match',
                        ['get', 'difficulty'],
                        'easy', this.trailColors.easy,
                        'intermediate', this.trailColors.intermediate,
                        'advanced', this.trailColors.advanced,
                        'expert', this.trailColors.expert,
                        this.trailColors.default
                    ],
                    'line-width': 3,
                    'line-opacity': 0.7
                }
            }, 'track-glow');

            // Add trail labels
            this.map.addLayer({
                id: 'ski-trails-labels',
                type: 'symbol',
                source: 'ski-trails',
                layout: {
                    'symbol-placement': 'line',
                    'text-field': ['get', 'name'],
                    'text-size': 12,
                    'text-font': ['DIN Pro Medium', 'Arial Unicode MS Regular']
                },
                paint: {
                    'text-color': '#ffffff',
                    'text-halo-color': '#000000',
                    'text-halo-width': 1
                }
            });

            console.log('Ski trails loaded');

        } catch (error) {
            console.log('Could not load ski trails:', error.message);
        }
    },

    /**
     * Create user position marker
     */
    createUserMarker() {
        // Create marker element
        this.userMarkerEl = document.createElement('div');
        this.userMarkerEl.className = 'user-marker-container';
        this.userMarkerEl.innerHTML = `
            <div class="user-marker-pulse"></div>
            <div class="user-marker"></div>
        `;

        // Add styles
        const style = document.createElement('style');
        style.textContent = `
            .user-marker-container {
                position: relative;
                width: 60px;
                height: 60px;
            }
            .user-marker-pulse {
                position: absolute;
                top: 50%;
                left: 50%;
                transform: translate(-50%, -50%);
                width: 60px;
                height: 60px;
                background: rgba(0, 212, 255, 0.3);
                border-radius: 50%;
                animation: markerPulse 2s infinite;
            }
            .user-marker {
                position: absolute;
                top: 50%;
                left: 50%;
                transform: translate(-50%, -50%);
                width: 20px;
                height: 20px;
                background: #00d4ff;
                border: 3px solid white;
                border-radius: 50%;
                box-shadow: 0 2px 10px rgba(0, 0, 0, 0.3);
            }
            @keyframes markerPulse {
                0% { transform: translate(-50%, -50%) scale(0.5); opacity: 1; }
                100% { transform: translate(-50%, -50%) scale(1.5); opacity: 0; }
            }
        `;
        document.head.appendChild(style);

        // Create mapbox marker
        this.userMarker = new mapboxgl.Marker({
            element: this.userMarkerEl,
            anchor: 'center'
        });
    },

    /**
     * Update user position on map
     * @param {number} lng - Longitude
     * @param {number} lat - Latitude
     * @param {boolean} centerMap - Whether to center map on position
     */
    updateUserPosition(lng, lat, centerMap = false) {
        if (!this.isInitialized || !this.userMarker) return;

        // Update marker position
        this.userMarker.setLngLat([lng, lat]).addTo(this.map);

        // Center map if requested
        if (centerMap) {
            this.map.easeTo({
                center: [lng, lat],
                zoom: this.TRACKING_ZOOM,
                duration: 1000
            });
        }
    },

    /**
     * Add position to track line
     * @param {number} lng - Longitude
     * @param {number} lat - Latitude
     */
    addToTrack(lng, lat) {
        if (!this.isInitialized) return;

        const source = this.map.getSource('track');
        if (!source) return;

        const data = source._data;
        data.geometry.coordinates.push([lng, lat]);
        source.setData(data);
    },

    /**
     * Clear the current track
     */
    clearTrack() {
        if (!this.isInitialized) return;

        const source = this.map.getSource('track');
        if (source) {
            source.setData({
                type: 'Feature',
                properties: {},
                geometry: {
                    type: 'LineString',
                    coordinates: []
                }
            });
        }
    },

    /**
     * Center map on user's current position
     */
    centerOnUser() {
        if (!this.isInitialized || !this.userMarker) return;

        const lngLat = this.userMarker.getLngLat();
        if (lngLat) {
            this.map.flyTo({
                center: [lngLat.lng, lngLat.lat],
                zoom: this.TRACKING_ZOOM,
                duration: 1000
            });
        }
    },

    /**
     * Center map on Kitzbühel ski area
     */
    centerOnKitzbuehel() {
        if (!this.isInitialized) return;

        this.map.flyTo({
            center: this.KITZBUEHEL_CENTER,
            zoom: this.DEFAULT_ZOOM,
            pitch: 45,
            duration: 2000
        });
    },

    /**
     * Set map style (for day/night modes)
     * @param {string} style - Mapbox style URL
     */
    setStyle(style) {
        if (this.isInitialized) {
            this.map.setStyle(style);
        }
    },

    /**
     * Display a completed run track
     * @param {Array} positions - Array of position objects
     */
    displayRunTrack(positions) {
        if (!this.isInitialized || positions.length === 0) return;

        const coordinates = positions.map(p => [p.lon, p.lat]);

        const source = this.map.getSource('track');
        if (source) {
            source.setData({
                type: 'Feature',
                properties: {},
                geometry: {
                    type: 'LineString',
                    coordinates
                }
            });

            // Fit map to track bounds
            const bounds = coordinates.reduce((bounds, coord) => {
                return bounds.extend(coord);
            }, new mapboxgl.LngLatBounds(coordinates[0], coordinates[0]));

            this.map.fitBounds(bounds, {
                padding: 50,
                duration: 1000
            });
        }
    },

    /**
     * Remove user marker from map
     */
    hideUserMarker() {
        if (this.userMarker) {
            this.userMarker.remove();
        }
    },

    /**
     * Resize map (call when container size changes)
     */
    resize() {
        if (this.isInitialized) {
            this.map.resize();
        }
    },

    /**
     * Destroy the map instance
     */
    destroy() {
        if (this.map) {
            this.map.remove();
            this.map = null;
            this.isInitialized = false;
        }
    }
};

// Make SkiMap available globally
window.SkiMap = SkiMap;

