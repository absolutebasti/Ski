/**
 * KitzSki Tracker - Main Application
 */

const App = {
    state: 'idle', // idle, tracking, paused
    wakeLock: null,
    
    // DOM elements
    elements: {},

    /**
     * Initialize the application
     */
    async init() {
        console.log('🎿 KitzSki Tracker initializing...');
        
        // Load configuration from .env
        await Config.init();
        console.log('Config loaded, Mapbox:', Config.hasMapbox() ? 'configured' : 'not configured');
        
        // Cache DOM elements
        this.cacheElements();
        
        // Initialize modules
        await this.initModules();
        
        // Set up event listeners
        this.bindEvents();
        
        // Check online status
        this.updateOnlineStatus();
        
        // Register service worker
        this.registerServiceWorker();
        
        // Load saved data
        await this.loadSavedData();
        
        console.log('🎿 KitzSki Tracker ready!');
    },

    /**
     * Cache DOM elements for performance
     */
    cacheElements() {
        this.elements = {
            startBtn: document.getElementById('startBtn'),
            pauseBtn: document.getElementById('pauseBtn'),
            stopBtn: document.getElementById('stopBtn'),
            locateBtn: document.getElementById('locateBtn'),
            historyBtn: document.getElementById('historyBtn'),
            settingsBtn: document.getElementById('settingsBtn'),
            historyPanel: document.getElementById('historyPanel'),
            settingsPanel: document.getElementById('settingsPanel'),
            closeHistoryBtn: document.getElementById('closeHistoryBtn'),
            closeSettingsBtn: document.getElementById('closeSettingsBtn'),
            historyList: document.getElementById('historyList'),
            gpsModal: document.getElementById('gpsModal'),
            grantLocationBtn: document.getElementById('grantLocationBtn'),
            offlineIndicator: document.getElementById('offlineIndicator'),
            exportDataBtn: document.getElementById('exportDataBtn'),
            clearDataBtn: document.getElementById('clearDataBtn'),
            autoPause: document.getElementById('autoPause'),
            highAccuracy: document.getElementById('highAccuracy')
        };
    },

    /**
     * Initialize all modules
     */
    async initModules() {
        // Initialize storage
        await Storage.init();
        
        // Initialize stats
        Stats.init();
        
        // Initialize map (with fallback for missing token)
        try {
            await SkiMap.init('map');
        } catch (error) {
            console.log('Map initialization skipped:', error.message);
        }
    },

    /**
     * Bind event listeners
     */
    bindEvents() {
        // Control buttons
        this.elements.startBtn?.addEventListener('click', () => this.startTracking());
        this.elements.pauseBtn?.addEventListener('click', () => this.togglePause());
        this.elements.stopBtn?.addEventListener('click', () => this.stopTracking());
        this.elements.locateBtn?.addEventListener('click', () => this.centerOnUser());
        
        // Panel buttons
        this.elements.historyBtn?.addEventListener('click', () => this.showPanel('history'));
        this.elements.settingsBtn?.addEventListener('click', () => this.showPanel('settings'));
        this.elements.closeHistoryBtn?.addEventListener('click', () => this.hidePanel('history'));
        this.elements.closeSettingsBtn?.addEventListener('click', () => this.hidePanel('settings'));
        
        // GPS permission
        this.elements.grantLocationBtn?.addEventListener('click', () => this.requestGPSPermission());
        
        // Settings
        this.elements.exportDataBtn?.addEventListener('click', () => this.exportData());
        this.elements.clearDataBtn?.addEventListener('click', () => this.clearData());
        
        // Online/offline
        window.addEventListener('online', () => this.updateOnlineStatus());
        window.addEventListener('offline', () => this.updateOnlineStatus());
        
        // Visibility change (for wake lock)
        document.addEventListener('visibilitychange', () => this.handleVisibilityChange());
    },

    /**
     * Start GPS tracking
     */
    async startTracking() {
        if (!GPSTracker.isAvailable()) {
            alert('GPS is not available on this device');
            return;
        }

        try {
            // Request permission first
            await GPSTracker.requestPermission();
            
            // Update UI
            this.state = 'tracking';
            this.updateControlButtons();
            
            // Reset and start stats
            Stats.reset();
            Stats.startTimer();
            
            // Clear previous track
            SkiMap.clearTrack();
            
            // Request wake lock
            this.wakeLock = await Utils.requestWakeLock();
            
            // Start GPS tracking
            GPSTracker.startTracking(
                (position) => this.handlePositionUpdate(position),
                (error) => this.handleGPSError(error)
            );
            
            Utils.vibrate(100);
            console.log('Tracking started');
            
        } catch (error) {
            console.error('Failed to start tracking:', error);
            this.showGPSModal();
        }
    },

    /**
     * Toggle pause/resume
     */
    togglePause() {
        if (this.state === 'tracking') {
            this.state = 'paused';
            GPSTracker.pause();
            Stats.pauseTimer();
            this.elements.pauseBtn.querySelector('span').textContent = 'Resume';
        } else if (this.state === 'paused') {
            this.state = 'tracking';
            GPSTracker.resume();
            Stats.resumeTimer();
            this.elements.pauseBtn.querySelector('span').textContent = 'Pause';
        }
        
        Utils.vibrate(50);
    },

    /**
     * Stop tracking and save run
     */
    async stopTracking() {
        if (this.state === 'idle') return;
        
        // Stop GPS
        GPSTracker.stopTracking();
        
        // Stop timer
        Stats.stopTimer();
        
        // Release wake lock
        if (this.wakeLock) {
            this.wakeLock.release();
            this.wakeLock = null;
        }
        
        // Get run data
        const runData = Stats.getRunData();
        
        // Only save if there's meaningful data
        if (runData.distance > 0.01 || runData.duration > 30000) {
            await Storage.saveRun(runData);
            await Storage.updateRecords(runData);
            await Stats.updateRunCount();
            Utils.vibrate([50, 50, 100]);
        }
        
        // Update state
        this.state = 'idle';
        this.updateControlButtons();
        
        // Reset stats display
        Stats.reset();
        
        console.log('Tracking stopped, run saved');
    },

    /**
     * Handle GPS position update
     * @param {Object} position - Position data
     */
    handlePositionUpdate(position) {
        // Update stats
        Stats.updateFromPosition(position);
        
        // Update map
        if (SkiMap.isInitialized) {
            SkiMap.updateUserPosition(position.longitude, position.latitude, false);
            SkiMap.addToTrack(position.longitude, position.latitude);
        }
    },

    /**
     * Handle GPS error
     * @param {Object} error - Error object
     */
    handleGPSError(error) {
        console.error('GPS Error:', error);
        
        if (error.code === 1) { // Permission denied
            this.showGPSModal();
        }
    },

    /**
     * Update control button visibility
     */
    updateControlButtons() {
        const { startBtn, pauseBtn, stopBtn } = this.elements;
        
        if (this.state === 'idle') {
            startBtn?.classList.remove('hidden');
            pauseBtn?.classList.add('hidden');
            stopBtn?.classList.add('hidden');
        } else {
            startBtn?.classList.add('hidden');
            pauseBtn?.classList.remove('hidden');
            stopBtn?.classList.remove('hidden');
        }
    },

    /**
     * Center map on user
     */
    async centerOnUser() {
        try {
            const position = await GPSTracker.getCurrentPosition();
            SkiMap.updateUserPosition(position.longitude, position.latitude, true);
        } catch (error) {
            console.error('Could not get position:', error);
            SkiMap.centerOnKitzbuehel();
        }
    },

    /**
     * Show panel
     * @param {string} panel - Panel name (history or settings)
     */
    async showPanel(panel) {
        if (panel === 'history') {
            await this.loadHistory();
            this.elements.historyPanel?.classList.remove('hidden');
        } else if (panel === 'settings') {
            this.elements.settingsPanel?.classList.remove('hidden');
        }
    },

    /**
     * Hide panel
     * @param {string} panel - Panel name
     */
    hidePanel(panel) {
        if (panel === 'history') {
            this.elements.historyPanel?.classList.add('hidden');
        } else if (panel === 'settings') {
            this.elements.settingsPanel?.classList.add('hidden');
        }
    },

    /**
     * Load and display run history
     */
    async loadHistory() {
        const runs = await Storage.getAllRuns();
        const records = await Storage.getRecords();
        
        Stats.updateRecords(records);
        
        if (runs.length === 0) return;
        
        const html = runs.map(run => this.renderHistoryItem(run)).join('');
        
        this.elements.historyList.innerHTML = html;
    },

    /**
     * Render a history item
     * @param {Object} run - Run data
     * @returns {string} HTML string
     */
    renderHistoryItem(run) {
        const date = new Date(run.startTime);
        return `
            <div class="history-item" data-id="${run.id}">
                <div class="history-item-header">
                    <span class="history-item-date">${Utils.formatDate(date)} ${Utils.formatTime(date)}</span>
                    <span class="history-item-duration">${Utils.formatDuration(run.duration)}</span>
                </div>
                <div class="history-item-stats">
                    <div class="history-stat">
                        <div class="history-stat-value">${Math.round(run.maxSpeed)}</div>
                        <div class="history-stat-label">Max km/h</div>
                    </div>
                    <div class="history-stat">
                        <div class="history-stat-value">${run.distance.toFixed(2)}</div>
                        <div class="history-stat-label">km</div>
                    </div>
                    <div class="history-stat">
                        <div class="history-stat-value">${Math.round(run.verticalDrop)}</div>
                        <div class="history-stat-label">Vertical m</div>
                    </div>
                </div>
            </div>
        `;
    },

    /**
     * Show GPS permission modal
     */
    showGPSModal() {
        this.elements.gpsModal?.classList.remove('hidden');
    },

    /**
     * Request GPS permission
     */
    async requestGPSPermission() {
        try {
            await GPSTracker.requestPermission();
            this.elements.gpsModal?.classList.add('hidden');
        } catch (error) {
            alert('Please enable location access in your browser settings');
        }
    },

    /**
     * Update online/offline status
     */
    updateOnlineStatus() {
        if (navigator.onLine) {
            this.elements.offlineIndicator?.classList.add('hidden');
        } else {
            this.elements.offlineIndicator?.classList.remove('hidden');
        }
    },

    /**
     * Handle visibility change (for wake lock)
     */
    async handleVisibilityChange() {
        if (document.visibilityState === 'visible' && this.state === 'tracking') {
            this.wakeLock = await Utils.requestWakeLock();
        }
    },

    /**
     * Export data as JSON
     */
    async exportData() {
        const data = await Storage.exportData();
        const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
        const url = URL.createObjectURL(blob);
        
        const a = document.createElement('a');
        a.href = url;
        a.download = `kitzski-export-${new Date().toISOString().split('T')[0]}.json`;
        a.click();
        
        URL.revokeObjectURL(url);
    },

    /**
     * Clear all data
     */
    async clearData() {
        if (confirm('Are you sure you want to delete all data? This cannot be undone.')) {
            await Storage.clearAllData();
            await this.loadHistory();
            await Stats.updateRunCount();
            alert('All data cleared');
        }
    },

    /**
     * Load saved data on startup
     */
    async loadSavedData() {
        await Stats.updateRunCount();
        const records = await Storage.getRecords();
        Stats.updateRecords(records);
    },

    /**
     * Register service worker
     */
    async registerServiceWorker() {
        if ('serviceWorker' in navigator) {
            try {
                const registration = await navigator.serviceWorker.register('/sw.js');
                console.log('Service Worker registered:', registration.scope);
            } catch (error) {
                console.log('Service Worker registration failed:', error);
            }
        }
    }
};

// Initialize app when DOM is ready
document.addEventListener('DOMContentLoaded', () => App.init());

// Make App available globally
window.App = App;

