/**
 * Background Geolocation Module
 * HIGH-015: Implement Background Geolocation (iOS/Android Native)
 * 
 * Provides guidance on native wrapper options for background tracking
 * Includes Capacitor integration helpers
 */

const BackgroundGeolocation = {
    // Configuration
    config: {
        // iOS settings
        ios: {
            activityType: 'Fitness',
            pauseLocationUpdatesAutomatically: false,
            showsBackgroundLocationIndicator: true,
            allowsBackgroundLocationUpdates: true,
            desiredAccuracy: 'best'
        },
        
        // Android settings
        android: {
            foregroundService: true,
            notificationTitle: 'Ski Tracking Active',
            notificationText: 'Recording your ski run',
            interval: 1000,
            fastestInterval: 500
        },
        
        // Common settings
        common: {
            distanceFilter: 5, // meters
            stopOnTerminate: false,
            startOnBoot: false,
            heartbeatInterval: 60
        }
    },
    
    // State
    state: {
        isRunning: false,
        isAvailable: false,
        hasPermission: false,
        provider: null // 'native', 'web', 'none'
    },
    
    // Callbacks
    callbacks: {
        onLocation: null,
        onError: null,
        onMotionChange: null,
        onHeartbeat: null
    },
    
    /**
     * Initialize background geolocation
     */
    async init() {
        // Check if we're in a native wrapper (Capacitor/Cordova)
        this.state.isAvailable = this.detectNativeWrapper();
        
        if (this.state.isAvailable) {
            console.log('[BackgroundGeolocation] Native wrapper detected');
            await this.initNative();
        } else {
            console.log('[BackgroundGeolocation] Web-only mode');
            this.initWeb();
        }
    },
    
    /**
     * Detect if running in native wrapper
     */
    detectNativeWrapper() {
        // Check for Capacitor
        if (typeof Capacitor !== 'undefined') {
            this.state.provider = 'capacitor';
            return true;
        }
        
        // Check for Cordova
        if (typeof cordova !== 'undefined') {
            this.state.provider = 'cordova';
            return true;
        }
        
        // Check for React Native WebView (limited)
        if (window.ReactNativeWebView) {
            this.state.provider = 'react-native';
            return true;
        }
        
        return false;
    },
    
    /**
     * Initialize native background geolocation
     */
    async initNative() {
        try {
            // Request permissions first
            const hasPermission = await this.requestPermissions();
            
            if (!hasPermission) {
                console.warn('[BackgroundGeolocation] Permissions denied');
                return false;
            }
            
            this.state.hasPermission = true;
            
            // Configure based on provider
            if (this.state.provider === 'capacitor') {
                await this.configureCapacitor();
            } else if (this.state.provider === 'cordova') {
                await this.configureCordova();
            }
            
            return true;
        } catch (error) {
            console.error('[BackgroundGeolocation] Native init failed:', error);
            return false;
        }
    },
    
    /**
     * Initialize web fallback
     */
    initWeb() {
        // Web has limited background capabilities
        // Use Page Visibility API and Wake Lock
        this.setupWebBackgroundMode();
    },
    
    /**
     * Request necessary permissions
     */
    async requestPermissions() {
        if (this.state.provider === 'capacitor') {
            // Capacitor Geolocation plugin permissions
            try {
                const { Geolocation } = Capacitor.Plugins;
                const permission = await Geolocation.requestPermissions();
                return permission.location === 'granted';
            } catch (e) {
                console.error('[BackgroundGeolocation] Permission error:', e);
                return false;
            }
        }
        
        // Web permissions
        if (navigator.permissions) {
            try {
                const result = await navigator.permissions.query({ name: 'geolocation' });
                return result.state === 'granted';
            } catch (e) {
                return false;
            }
        }
        
        return false;
    },
    
    /**
     * Configure Capacitor background geolocation
     */
    async configureCapacitor() {
        // This requires @capacitor/geolocation and @capacitor/background-task
        console.log('[BackgroundGeolocation] Configuring Capacitor...');
        
        // Setup background task
        const { BackgroundTask } = Capacitor.Plugins;
        
        // Register background task
        BackgroundTask.registerBackgroundTask('location-update', async () => {
            await this.handleBackgroundTask();
            BackgroundTask.finishBackgroundTask('location-update');
        });
    },
    
    /**
     * Handle background task (called periodically)
     */
    async handleBackgroundTask() {
        if (!this.state.isRunning) return;
        
        try {
            const { Geolocation } = Capacitor.Plugins;
            const position = await Geolocation.getCurrentPosition({
                enableHighAccuracy: true,
                timeout: 5000
            });
            
            this.handleLocation({
                latitude: position.coords.latitude,
                longitude: position.coords.longitude,
                altitude: position.coords.altitude,
                speed: position.coords.speed,
                accuracy: position.coords.accuracy,
                timestamp: position.timestamp
            });
        } catch (error) {
            console.error('[BackgroundGeolocation] Background task error:', error);
        }
    },
    
    /**
     * Configure Cordova background geolocation
     */
    async configureCordova() {
        // This requires cordova-plugin-background-geolocation
        return new Promise((resolve, reject) => {
            if (!window.BackgroundGeolocation) {
                reject(new Error('BackgroundGeolocation plugin not found'));
                return;
            }
            
            window.BackgroundGeolocation.configure({
                desiredAccuracy: window.BackgroundGeolocation.HIGH_ACCURACY,
                stationaryRadius: 20,
                distanceFilter: this.config.common.distanceFilter,
                notificationTitle: this.config.android.notificationTitle,
                notificationText: this.config.android.notificationText,
                debug: false,
                interval: this.config.android.interval,
                fastestInterval: this.config.android.fastestInterval,
                activitiesInterval: 10000,
                stopOnTerminate: this.config.common.stopOnTerminate,
                startOnBoot: this.config.common.startOnBoot,
                startForeground: this.config.android.foregroundService
            });
            
            window.BackgroundGeolocation.on('location', (location) => {
                this.handleLocation({
                    latitude: location.latitude,
                    longitude: location.longitude,
                    altitude: location.altitude,
                    speed: location.speed,
                    accuracy: location.accuracy,
                    timestamp: location.time
                });
            });
            
            window.BackgroundGeolocation.on('error', (error) => {
                this.handleError(error);
            });
            
            resolve();
        });
    },
    
    /**
     * Setup web background mode (limited)
     */
    setupWebBackgroundMode() {
        // Page Visibility API
        document.addEventListener('visibilitychange', () => {
            if (document.hidden) {
                console.log('[BackgroundGeolocation] App in background (web)');
                this.requestWakeLock();
            } else {
                console.log('[BackgroundGeolocation] App in foreground');
                this.releaseWakeLock();
            }
        });
        
        // Try to keep screen awake during tracking
        if ('wakeLock' in navigator) {
            this.requestWakeLock();
        }
    },
    
    /**
     * Request screen wake lock
     */
    async requestWakeLock() {
        if (!('wakeLock' in navigator)) return;
        
        try {
            this.wakeLock = await navigator.wakeLock.request('screen');
            console.log('[BackgroundGeolocation] Wake lock acquired');
        } catch (err) {
            console.warn('[BackgroundGeolocation] Wake lock failed:', err);
        }
    },
    
    /**
     * Release screen wake lock
     */
    async releaseWakeLock() {
        if (this.wakeLock) {
            try {
                await this.wakeLock.release();
                this.wakeLock = null;
                console.log('[BackgroundGeolocation] Wake lock released');
            } catch (err) {
                console.warn('[BackgroundGeolocation] Wake lock release failed:', err);
            }
        }
    },
    
    /**
     * Start background tracking
     */
    async start() {
        if (this.state.isRunning) {
            console.log('[BackgroundGeolocation] Already running');
            return;
        }
        
        this.state.isRunning = true;
        
        if (this.state.provider === 'capacitor') {
            // Start location updates
            const { Geolocation } = Capacitor.Plugins;
            
            this.watchId = Geolocation.watchPosition({
                enableHighAccuracy: true,
                timeout: 10000
            }, (position, err) => {
                if (err) {
                    this.handleError(err);
                    return;
                }
                
                this.handleLocation({
                    latitude: position.coords.latitude,
                    longitude: position.coords.longitude,
                    altitude: position.coords.altitude,
                    speed: position.coords.speed,
                    accuracy: position.coords.accuracy,
                    timestamp: position.timestamp
                });
            });
        } else if (this.state.provider === 'cordova') {
            window.BackgroundGeolocation.start();
        } else {
            // Web fallback - use standard watchPosition
            this.watchId = navigator.geolocation.watchPosition(
                (position) => {
                    this.handleLocation({
                        latitude: position.coords.latitude,
                        longitude: position.coords.longitude,
                        altitude: position.coords.altitude,
                        speed: position.coords.speed,
                        accuracy: position.coords.accuracy,
                        timestamp: position.timestamp
                    });
                },
                (error) => this.handleError(error),
                {
                    enableHighAccuracy: true,
                    timeout: 10000,
                    maximumAge: 5000
                }
            );
        }
        
        console.log('[BackgroundGeolocation] Started');
    },
    
    /**
     * Stop background tracking
     */
    async stop() {
        if (!this.state.isRunning) return;
        
        this.state.isRunning = false;
        
        if (this.state.provider === 'capacitor') {
            const { Geolocation } = Capacitor.Plugins;
            Geolocation.clearWatch({ id: this.watchId });
        } else if (this.state.provider === 'cordova') {
            window.BackgroundGeolocation.stop();
        } else {
            navigator.geolocation.clearWatch(this.watchId);
        }
        
        this.releaseWakeLock();
        
        console.log('[BackgroundGeolocation] Stopped');
    },
    
    /**
     * Handle location update
     */
    handleLocation(location) {
        if (this.callbacks.onLocation) {
            this.callbacks.onLocation(location);
        }
    },
    
    /**
     * Handle error
     */
    handleError(error) {
        console.error('[BackgroundGeolocation] Error:', error);
        
        if (this.callbacks.onError) {
            this.callbacks.onError(error);
        }
    },
    
    /**
     * Get current status
     */
    getStatus() {
        return { ...this.state };
    },
    
    /**
     * Check if background geolocation is available
     */
    isAvailable() {
        return this.state.isAvailable;
    },
    
    /**
     * Get setup instructions for developers
     */
    getSetupInstructions() {
        return {
            capacitor: {
                name: 'Capacitor (Recommended)',
                install: `
# Install Capacitor plugins
npm install @capacitor/geolocation @capacitor/background-task

# Sync native code
npx cap sync
                `,
                ios: `
# iOS Info.plist additions
<key>NSLocationAlwaysUsageDescription</key>
<string>Location needed for ski tracking</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Location needed for ski tracking</string>
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
    <string>processing</string>
</array>
                `,
                android: `
# Android AndroidManifest.xml additions
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />

<service android:name="com.capacitorjs.plugins.backgroundtask.BackgroundTaskService"
         android:permission="android.permission.BIND_JOB_SERVICE"
         android:exported="true" />
                `
            },
            cordova: {
                name: 'Cordova',
                install: `
# Install plugin
cordova plugin add cordova-plugin-background-geolocation
                `,
                ios: 'Same as Capacitor iOS settings',
                android: 'Same as Capacitor Android settings'
            }
        };
    },
    
    /**
     * Set callbacks
     */
    onLocation(callback) {
        this.callbacks.onLocation = callback;
    },
    
    onError(callback) {
        this.callbacks.onError = callback;
    },
    
    onMotionChange(callback) {
        this.callbacks.onMotionChange = callback;
    },
    
    onHeartbeat(callback) {
        this.callbacks.onHeartbeat = callback;
    }
};

// Initialize
BackgroundGeolocation.init();
