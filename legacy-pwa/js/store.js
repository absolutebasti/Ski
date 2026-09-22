/**
 * Central State Management Module
 * HIGH-016: Implement Proper State Management
 * 
 * Centralized state store with reactive updates
 * Similar to Redux but lightweight for this app
 */

const Store = {
    // State tree
    state: {
        // App state
        app: {
            initialized: false,
            version: '1.0.0',
            online: navigator.onLine,
            theme: localStorage.getItem('theme') || 'dark'
        },
        
        // UI state
        ui: {
            activePanel: null,
            modalOpen: false,
            sidebarOpen: false,
            loading: false,
            notifications: []
        },
        
        // Tracking state
        tracking: {
            status: 'idle', // idle, tracking, paused
            startTime: null,
            pauseTime: null,
            positions: [],
            currentRun: null,
            runCount: 0,
            stats: {
                distance: 0,
                duration: 0,
                maxSpeed: 0,
                currentSpeed: 0,
                altitude: 0,
                vertical: 0
            }
        },
        
        // User state
        user: {
            id: null,
            isAuthenticated: false,
            preferences: {
                autoStart: false,
                audioAnnouncements: true,
                metricUnits: true,
                highAccuracyGPS: true
            },
            stats: {
                totalRuns: 0,
                totalDistance: 0,
                totalVertical: 0,
                totalDuration: 0,
                favoriteResort: null
            }
        },
        
        // Data state
        data: {
            runs: [],
            achievements: [],
            segments: [],
            resorts: [],
            loaded: false
        },
        
        // Device state
        device: {
            gpsAvailable: false,
            gpsActive: false,
            batteryLevel: null,
            batteryCharging: false,
            barometerAvailable: false,
            heartRateAvailable: false,
            bluetoothAvailable: 'bluetooth' in navigator
        }
    },
    
    // Reducers
    reducers: {},
    
    // Subscribers
    subscribers: {},
    
    // Middleware
    middleware: [],
    
    // Action history (for dev tools)
    history: [],
    maxHistory: 100,
    
    /**
     * Initialize the store
     */
    init() {
        // Load persisted state
        this.loadPersistedState();
        
        // Setup online/offline listeners
        window.addEventListener('online', () => this.dispatch('SET_ONLINE', true));
        window.addEventListener('offline', () => this.dispatch('SET_ONLINE', false));
        
        // Setup battery monitoring
        this.initBatteryMonitoring();
        
        // Register default reducers
        this.registerDefaultReducers();
        
        console.log('[Store] Initialized');
        
        // Mark as initialized
        this.state.app.initialized = true;
        this.notify('app');
    },
    
    /**
     * Register a reducer
     */
    registerReducer(actionType, reducer) {
        if (!this.reducers[actionType]) {
            this.reducers[actionType] = [];
        }
        this.reducers[actionType].push(reducer);
    },
    
    /**
     * Register default reducers
     */
    registerDefaultReducers() {
        // App reducers
        this.registerReducer('SET_ONLINE', (state, online) => {
            state.app.online = online;
        });
        
        this.registerReducer('SET_THEME', (state, theme) => {
            state.app.theme = theme;
            localStorage.setItem('theme', theme);
            document.documentElement.setAttribute('data-theme', theme);
        });
        
        // Tracking reducers
        this.registerReducer('TRACKING_START', (state) => {
            state.tracking.status = 'tracking';
            state.tracking.startTime = Date.now();
            state.tracking.positions = [];
            state.tracking.stats = {
                distance: 0,
                duration: 0,
                maxSpeed: 0,
                currentSpeed: 0,
                altitude: 0,
                vertical: 0
            };
        });
        
        this.registerReducer('TRACKING_PAUSE', (state) => {
            state.tracking.status = 'paused';
            state.tracking.pauseTime = Date.now();
        });
        
        this.registerReducer('TRACKING_RESUME', (state) => {
            state.tracking.status = 'tracking';
            // Adjust start time to account for pause duration
            const pauseDuration = Date.now() - state.tracking.pauseTime;
            state.tracking.startTime += pauseDuration;
            state.tracking.pauseTime = null;
        });
        
        this.registerReducer('TRACKING_STOP', (state, runData) => {
            state.tracking.status = 'idle';
            state.tracking.runCount++;
            state.user.stats.totalRuns++;
            
            if (runData) {
                state.user.stats.totalDistance += runData.distance || 0;
                state.user.stats.totalVertical += runData.vertical || 0;
                state.user.stats.totalDuration += runData.duration || 0;
            }
            
            // Reset tracking state
            state.tracking.startTime = null;
            state.tracking.pauseTime = null;
            state.tracking.positions = [];
        });
        
        this.registerReducer('TRACKING_POSITION', (state, position) => {
            state.tracking.positions.push(position);
            state.tracking.stats.currentSpeed = position.speed || 0;
            state.tracking.stats.altitude = position.altitude || 0;
            
            if (position.speed > state.tracking.stats.maxSpeed) {
                state.tracking.stats.maxSpeed = position.speed;
            }
        });
        
        this.registerReducer('TRACKING_STATS', (state, stats) => {
            state.tracking.stats = { ...state.tracking.stats, ...stats };
        });
        
        // Data reducers
        this.registerReducer('SET_RUNS', (state, runs) => {
            state.data.runs = runs;
            state.data.loaded = true;
        });
        
        this.registerReducer('ADD_RUN', (state, run) => {
            state.data.runs.unshift(run);
        });
        
        this.registerReducer('DELETE_RUN', (state, runId) => {
            state.data.runs = state.data.runs.filter(r => r.id !== runId);
        });
        
        this.registerReducer('SET_ACHIEVEMENTS', (state, achievements) => {
            state.data.achievements = achievements;
        });
        
        this.registerReducer('UNLOCK_ACHIEVEMENT', (state, achievementId) => {
            const achievement = state.data.achievements.find(a => a.id === achievementId);
            if (achievement && !achievement.unlocked) {
                achievement.unlocked = true;
                achievement.unlockedAt = Date.now();
            }
        });
        
        // UI reducers
        this.registerReducer('SET_PANEL', (state, panel) => {
            state.ui.activePanel = panel;
        });
        
        this.registerReducer('OPEN_MODAL', (state) => {
            state.ui.modalOpen = true;
        });
        
        this.registerReducer('CLOSE_MODAL', (state) => {
            state.ui.modalOpen = false;
        });
        
        this.registerReducer('TOGGLE_SIDEBAR', (state) => {
            state.ui.sidebarOpen = !state.ui.sidebarOpen;
        });
        
        this.registerReducer('SET_LOADING', (state, loading) => {
            state.ui.loading = loading;
        });
        
        this.registerReducer('ADD_NOTIFICATION', (state, notification) => {
            state.ui.notifications.push({
                id: Date.now(),
                ...notification
            });
        });
        
        this.registerReducer('REMOVE_NOTIFICATION', (state, notificationId) => {
            state.ui.notifications = state.ui.notifications.filter(n => n.id !== notificationId);
        });
        
        // User reducers
        this.registerReducer('SET_USER', (state, user) => {
            state.user = { ...state.user, ...user };
        });
        
        this.registerReducer('SET_PREFERENCE', (state, { key, value }) => {
            state.user.preferences[key] = value;
            this.persistPreferences();
        });
        
        // Device reducers
        this.registerReducer('SET_GPS_AVAILABLE', (state, available) => {
            state.device.gpsAvailable = available;
        });
        
        this.registerReducer('SET_GPS_ACTIVE', (state, active) => {
            state.device.gpsActive = active;
        });
        
        this.registerReducer('SET_BATTERY', (state, { level, charging }) => {
            state.device.batteryLevel = level;
            state.device.batteryCharging = charging;
        });
        
        this.registerReducer('SET_BAROMETER_AVAILABLE', (state, available) => {
            state.device.barometerAvailable = available;
        });
        
        this.registerReducer('SET_HEART_RATE_AVAILABLE', (state, available) => {
            state.device.heartRateAvailable = available;
        });
    },
    
    /**
     * Dispatch an action
     */
    dispatch(actionType, payload = null) {
        // Create action object
        const action = {
            type: actionType,
            payload,
            timestamp: Date.now()
        };
        
        // Apply middleware
        for (const mw of this.middleware) {
            const result = mw(action, this.state);
            if (result === false) return; // Middleware cancelled action
        }
        
        // Execute reducers
        const reducers = this.reducers[actionType] || [];
        const prevState = JSON.parse(JSON.stringify(this.state)); // Deep clone for history
        
        for (const reducer of reducers) {
            reducer(this.state, payload);
        }
        
        // Add to history
        if (this.history.length >= this.maxHistory) {
            this.history.shift();
        }
        this.history.push({
            action,
            prevState,
            timestamp: Date.now()
        });
        
        // Notify subscribers
        this.notifyFromAction(actionType);
        
        // Debug log
        if (this.state.app.debug) {
            console.log('[Store] Action:', actionType, payload);
        }
        
        return action;
    },
    
    /**
     * Get state (or slice of state)
     */
    getState(path = null) {
        if (!path) return this.state;
        
        const keys = path.split('.');
        let value = this.state;
        
        for (const key of keys) {
            if (value === null || value === undefined) return undefined;
            value = value[key];
        }
        
        return value;
    },
    
    /**
     * Subscribe to state changes
     */
    subscribe(path, callback) {
        if (!this.subscribers[path]) {
            this.subscribers[path] = [];
        }
        
        this.subscribers[path].push(callback);
        
        // Return unsubscribe function
        return () => {
            const index = this.subscribers[path].indexOf(callback);
            if (index > -1) {
                this.subscribers[path].splice(index, 1);
            }
        };
    },
    
    /**
     * Notify subscribers for an action type
     */
    notifyFromAction(actionType) {
        // Map action types to state paths
        const pathMap = {
            'TRACKING_': 'tracking',
            'SET_RUNS': 'data.runs',
            'ADD_RUN': 'data.runs',
            'DELETE_RUN': 'data.runs',
            'SET_ACHIEVEMENTS': 'data.achievements',
            'UNLOCK_ACHIEVEMENT': 'data.achievements',
            'SET_PANEL': 'ui.activePanel',
            'SET_THEME': 'app.theme',
            'SET_USER': 'user',
            'SET_PREFERENCE': 'user.preferences'
        };
        
        for (const prefix in pathMap) {
            if (actionType.startsWith(prefix) || actionType === prefix) {
                this.notify(pathMap[prefix]);
            }
        }
    },
    
    /**
     * Notify subscribers for a path
     */
    notify(path) {
        const subscribers = this.subscribers[path];
        if (!subscribers) return;
        
        const value = this.getState(path);
        
        for (const callback of subscribers) {
            try {
                callback(value, path);
            } catch (e) {
                console.error('[Store] Subscriber error:', e);
            }
        }
    },
    
    /**
     * Add middleware
     */
    use(middleware) {
        this.middleware.push(middleware);
    },
    
    /**
     * Time travel debugging
     */
    timeTravel(index) {
        if (index < 0 || index >= this.history.length) return false;
        
        const entry = this.history[index];
        this.state = JSON.parse(JSON.stringify(entry.prevState));
        
        // Notify all subscribers
        Object.keys(this.subscribers).forEach(path => this.notify(path));
        
        return true;
    },
    
    /**
     * Get action history
     */
    getHistory() {
        return this.history.map((h, i) => ({
            index: i,
            action: h.action.type,
            timestamp: h.timestamp
        }));
    },
    
    /**
     * Load persisted state
     */
    loadPersistedState() {
        try {
            // Load user preferences
            const prefs = localStorage.getItem('userPreferences');
            if (prefs) {
                this.state.user.preferences = JSON.parse(prefs);
            }
            
            // Load theme
            const theme = localStorage.getItem('theme');
            if (theme) {
                this.state.app.theme = theme;
            }
        } catch (e) {
            console.error('[Store] Failed to load persisted state:', e);
        }
    },
    
    /**
     * Persist preferences
     */
    persistPreferences() {
        try {
            const result = SecurityUtils.safeLocalStorageSet('userPreferences', JSON.stringify(this.state.user.preferences));
            if (!result.success && result.fallback === 'indexeddb') {
                // Fallback to IndexedDB
                SecurityUtils.fallbackToIndexedDB('userPreferences', JSON.stringify(this.state.user.preferences))
                    .catch(err => console.error('[Store] Failed to persist preferences to fallback:', err));
            }
        } catch (e) {
            console.error('[Store] Failed to persist preferences:', e);
            ErrorTracker?.handleError(e, { context: 'persistPreferences' });
        }
    },
    
    /**
     * Initialize battery monitoring
     */
    async initBatteryMonitoring() {
        if ('getBattery' in navigator) {
            try {
                const battery = await navigator.getBattery();
                
                const updateBattery = () => {
                    this.dispatch('SET_BATTERY', {
                        level: battery.level * 100,
                        charging: battery.charging
                    });
                };
                
                battery.addEventListener('levelchange', updateBattery);
                battery.addEventListener('chargingchange', updateBattery);
                
                updateBattery();
            } catch (e) {
                console.warn('[Store] Battery API not available');
            }
        }
    },
    
    /**
     * Create a bound action creator
     */
    createAction(type) {
        return (payload) => this.dispatch(type, payload);
    },
    
    /**
     * Connect a component to the store
     */
    connect(mapState, mapActions) {
        return (component) => {
            // Subscribe to state changes
            const state = mapState ? mapState(this.state) : {};
            const actions = mapActions ? mapActions(this.dispatch.bind(this)) : {};
            
            // Return connected component
            return {
                ...component,
                ...state,
                ...actions
            };
        };
    },
    
    /**
     * Reset store to initial state
     */
    reset() {
        this.state = {
            app: {
                initialized: false,
                version: '1.0.0',
                online: navigator.onLine,
                theme: 'dark'
            },
            ui: {
                activePanel: null,
                modalOpen: false,
                sidebarOpen: false,
                loading: false,
                notifications: []
            },
            tracking: {
                status: 'idle',
                startTime: null,
                pauseTime: null,
                positions: [],
                currentRun: null,
                runCount: 0,
                stats: {
                    distance: 0,
                    duration: 0,
                    maxSpeed: 0,
                    currentSpeed: 0,
                    altitude: 0,
                    vertical: 0
                }
            },
            user: {
                id: null,
                isAuthenticated: false,
                preferences: {
                    autoStart: false,
                    audioAnnouncements: true,
                    metricUnits: true,
                    highAccuracyGPS: true
                },
                stats: {
                    totalRuns: 0,
                    totalDistance: 0,
                    totalVertical: 0,
                    totalDuration: 0,
                    favoriteResort: null
                }
            },
            data: {
                runs: [],
                achievements: [],
                segments: [],
                resorts: [],
                loaded: false
            },
            device: {
                gpsAvailable: false,
                gpsActive: false,
                batteryLevel: null,
                batteryCharging: false,
                barometerAvailable: false,
                heartRateAvailable: false,
                bluetoothAvailable: 'bluetooth' in navigator
            }
        };
        
        this.history = [];
        
        // Notify all subscribers
        Object.keys(this.subscribers).forEach(path => this.notify(path));
    }
};

// Initialize on load
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => Store.init());
} else {
    Store.init();
}
