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
            highAccuracy: document.getElementById('highAccuracy'),
            // Resort elements
            resortCurrentBtn: document.getElementById('resortCurrentBtn'),
            resortFlag: document.getElementById('resortFlag'),
            resortName: document.getElementById('resortName'),
            resortKm: document.getElementById('resortKm'),
            resortLifts: document.getElementById('resortLifts'),
            resortAltitude: document.getElementById('resortAltitude'),
            resortsPanel: document.getElementById('resortsPanel'),
            closeResortsBtn: document.getElementById('closeResortsBtn'),
            resortList: document.getElementById('resortList'),
            // Resort details elements
            resortDetailsBtn: document.getElementById('resortDetailsBtn'),
            resortDetailsPanel: document.getElementById('resortDetailsPanel'),
            closeDetailsBtn: document.getElementById('closeDetailsBtn'),
            detailsPanelTitle: document.getElementById('detailsPanelTitle'),
            sectorsGrid: document.getElementById('sectorsGrid'),
            slopesList: document.getElementById('slopesList'),
            liftsList: document.getElementById('liftsList'),
            facilitiesGrid: document.getElementById('facilitiesGrid')
        };
    },

    // Resort details data
    resortDetails: null,
    currentSlopeFilter: 'all',
    currentLiftFilter: 'all',

    /**
     * Initialize all modules
     */
    async initModules() {
        // Initialize storage
        await Storage.init();
        
        // Initialize stats
        Stats.init();
        
        // Load saved resort
        await Resorts.loadSaved();
        this.updateResortUI();
        this.renderResortList();
        
        // Initialize map with current resort
        try {
            const resort = Resorts.getCurrent();
            if (resort) {
                SkiMap.KITZBUEHEL_CENTER = resort.center;
                SkiMap.DEFAULT_ZOOM = resort.zoom;
            }
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
        
        // Resort selection
        this.elements.resortCurrentBtn?.addEventListener('click', () => this.showPanel('resorts'));
        this.elements.closeResortsBtn?.addEventListener('click', () => this.hidePanel('resorts'));
        
        // Resort details
        this.elements.resortDetailsBtn?.addEventListener('click', () => this.showResortDetails());
        this.elements.closeDetailsBtn?.addEventListener('click', () => this.hidePanel('details'));
        
        // Details tabs
        document.querySelectorAll('.details-tab').forEach(tab => {
            tab.addEventListener('click', (e) => this.switchDetailsTab(e.target.dataset.tab));
        });
        
        // Slope filters
        document.querySelectorAll('.slope-filters .filter-btn').forEach(btn => {
            btn.addEventListener('click', (e) => this.filterSlopes(e.target.dataset.filter));
        });
        
        // Lift filters
        document.querySelectorAll('.lift-filters .filter-btn').forEach(btn => {
            btn.addEventListener('click', (e) => this.filterLifts(e.target.dataset.filter));
        });
        
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
     * @param {string} panel - Panel name (history, settings, or resorts)
     */
    async showPanel(panel) {
        if (panel === 'history') {
            await this.loadHistory();
            this.elements.historyPanel?.classList.remove('hidden');
        } else if (panel === 'settings') {
            this.elements.settingsPanel?.classList.remove('hidden');
        } else if (panel === 'resorts') {
            this.elements.resortsPanel?.classList.remove('hidden');
        } else if (panel === 'details') {
            this.elements.resortDetailsPanel?.classList.remove('hidden');
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
        } else if (panel === 'resorts') {
            this.elements.resortsPanel?.classList.add('hidden');
        } else if (panel === 'details') {
            this.elements.resortDetailsPanel?.classList.add('hidden');
        }
    },

    /**
     * Update resort UI elements
     */
    updateResortUI() {
        const resort = Resorts.getCurrent();
        if (!resort) return;
        
        if (this.elements.resortFlag) {
            this.elements.resortFlag.textContent = Resorts.getFlag(resort.country);
        }
        if (this.elements.resortName) {
            this.elements.resortName.textContent = resort.name;
        }
        if (this.elements.resortKm) {
            this.elements.resortKm.textContent = resort.stats.kmPiste;
        }
        if (this.elements.resortLifts) {
            this.elements.resortLifts.textContent = resort.stats.lifts;
        }
        if (this.elements.resortAltitude) {
            this.elements.resortAltitude.textContent = resort.altitude.max;
        }
    },

    /**
     * Render resort list
     */
    renderResortList() {
        if (!this.elements.resortList) return;
        
        const current = Resorts.getCurrent();
        const html = Resorts.getAll().map(resort => {
            const total = resort.difficulty.easy + resort.difficulty.intermediate + resort.difficulty.advanced;
            const easyPct = (resort.difficulty.easy / total) * 100;
            const intPct = (resort.difficulty.intermediate / total) * 100;
            const advPct = (resort.difficulty.advanced / total) * 100;
            
            return `
                <div class="resort-item ${resort.id === current?.id ? 'selected' : ''}" data-resort="${resort.id}">
                    <div class="resort-item-header">
                        <span class="resort-item-flag">${Resorts.getFlag(resort.country)}</span>
                        <div>
                            <div class="resort-item-name">${resort.name}</div>
                            <div class="resort-item-region">${resort.region}</div>
                        </div>
                    </div>
                    <div class="resort-item-stats">
                        <span class="resort-item-stat"><strong>${resort.stats.kmPiste}</strong> km</span>
                        <span class="resort-item-stat"><strong>${resort.stats.lifts}</strong> lifts</span>
                        <span class="resort-item-stat"><strong>${resort.altitude.max}</strong>m peak</span>
                    </div>
                    <div class="resort-item-famous">"${resort.famous}"</div>
                    <div class="resort-item-difficulty">
                        <div class="difficulty-bar difficulty-easy" style="width: ${easyPct}%"></div>
                        <div class="difficulty-bar difficulty-intermediate" style="width: ${intPct}%"></div>
                        <div class="difficulty-bar difficulty-advanced" style="width: ${advPct}%"></div>
                    </div>
                </div>
            `;
        }).join('');
        
        this.elements.resortList.innerHTML = html;
        
        // Add click handlers
        this.elements.resortList.querySelectorAll('.resort-item').forEach(item => {
            item.addEventListener('click', () => this.selectResort(item.dataset.resort));
        });
    },

    /**
     * Select a resort
     */
    selectResort(resortId) {
        Resorts.setCurrent(resortId);
        this.updateResortUI();
        this.renderResortList();
        
        // Update map center
        const resort = Resorts.getCurrent();
        if (resort && SkiMap.isInitialized) {
            SkiMap.map.flyTo({
                center: resort.center,
                zoom: resort.zoom,
                duration: 2000
            });
        }
        
        this.hidePanel('resorts');
    },

    /**
     * Show resort details
     */
    async showResortDetails() {
        const resort = Resorts.getCurrent();
        if (!resort) return;
        
        this.elements.detailsPanelTitle.textContent = resort.name;
        
        // Load detailed data
        try {
            const response = await fetch(`/assets/trails/${resort.id}-details.json`);
            if (response.ok) {
                this.resortDetails = await response.json();
                this.renderResortDetails();
            } else {
                this.renderNoDetails();
            }
        } catch (e) {
            this.renderNoDetails();
        }
        
        this.showPanel('details');
    },

    /**
     * Render resort details
     */
    renderResortDetails() {
        const data = this.resortDetails;
        if (!data) return;
        
        // Render sectors
        this.elements.sectorsGrid.innerHTML = data.sectors.map(sector => `
            <div class="sector-card">
                <div class="sector-name">${sector.name}</div>
                <div class="sector-stats">${sector.slopes} slopes · ${sector.lifts} lifts</div>
                <div class="sector-altitude">${sector.altitude.min}m - ${sector.altitude.max}m</div>
            </div>
        `).join('');
        
        // Render slopes
        this.renderSlopes(data.slopes);
        
        // Render lifts
        this.renderLifts(data.lifts);
        
        // Render facilities
        this.renderFacilities(data.facilities);
    },

    /**
     * Render slopes list
     */
    renderSlopes(slopes) {
        const filtered = this.currentSlopeFilter === 'all' 
            ? slopes 
            : slopes.filter(s => s.difficulty === this.currentSlopeFilter);
        
        this.elements.slopesList.innerHTML = filtered.map(slope => `
            <div class="slope-item">
                <div class="slope-difficulty ${slope.difficulty}"></div>
                <div class="slope-info">
                    <div class="slope-name ${slope.famous ? 'famous' : ''}">${slope.name}</div>
                    <div class="slope-meta">${slope.sector}</div>
                </div>
                <div class="slope-stats">
                    <div class="slope-length">${slope.length} km</div>
                    <div class="slope-drop">↓ ${slope.verticalDrop}m</div>
                </div>
            </div>
        `).join('');
    },

    /**
     * Render lifts list
     */
    renderLifts(lifts) {
        const filtered = this.currentLiftFilter === 'all' 
            ? lifts 
            : lifts.filter(l => l.type === this.currentLiftFilter);
        
        const liftIcons = {
            gondola: '🚡',
            chairlift: '🪑',
            dragLift: '⬆️'
        };
        
        this.elements.liftsList.innerHTML = filtered.map(lift => `
            <div class="lift-item">
                <span class="lift-icon">${liftIcons[lift.type] || '🚡'}</span>
                <div class="lift-info">
                    <div class="lift-name">${lift.name}</div>
                    <div class="lift-meta">${lift.sector} · ${lift.capacity} pers.</div>
                </div>
                <div class="lift-stats">
                    <div class="lift-length">${(lift.length/1000).toFixed(1)} km</div>
                    <div class="lift-rise">↑ ${lift.verticalRise}m</div>
                </div>
            </div>
        `).join('');
    },

    /**
     * Render facilities
     */
    renderFacilities(facilities) {
        const items = [
            { icon: '🍽️', value: facilities.restaurants, label: 'Restaurants' },
            { icon: '🎿', value: facilities.skiSchools, label: 'Ski Schools' },
            { icon: '🏪', value: facilities.skiRental, label: 'Rental Shops' },
            { icon: '🅿️', value: facilities.parking.toLocaleString(), label: 'Parking Spots' },
            { icon: '❄️', value: facilities.snowmaking, label: 'Snowmaking' }
        ];
        
        this.elements.facilitiesGrid.innerHTML = items.map(item => `
            <div class="facility-card">
                <div class="facility-icon">${item.icon}</div>
                <div class="facility-value">${item.value}</div>
                <div class="facility-label">${item.label}</div>
            </div>
        `).join('');
    },

    /**
     * Render no details available
     */
    renderNoDetails() {
        this.elements.sectorsGrid.innerHTML = '<p style="color: var(--text-tertiary); font-size: 13px;">Detailed data coming soon</p>';
        this.elements.slopesList.innerHTML = '';
        this.elements.liftsList.innerHTML = '';
        this.elements.facilitiesGrid.innerHTML = '';
    },

    /**
     * Switch details tab
     */
    switchDetailsTab(tab) {
        document.querySelectorAll('.details-tab').forEach(t => t.classList.remove('active'));
        document.querySelectorAll('.details-tab-content').forEach(c => c.classList.remove('active'));
        
        document.querySelector(`[data-tab="${tab}"]`)?.classList.add('active');
        document.getElementById(`${tab}Tab`)?.classList.add('active');
    },

    /**
     * Filter slopes
     */
    filterSlopes(filter) {
        this.currentSlopeFilter = filter;
        document.querySelectorAll('.slope-filters .filter-btn').forEach(btn => {
            btn.classList.toggle('active', btn.dataset.filter === filter);
        });
        if (this.resortDetails) {
            this.renderSlopes(this.resortDetails.slopes);
        }
    },

    /**
     * Filter lifts
     */
    filterLifts(filter) {
        this.currentLiftFilter = filter;
        document.querySelectorAll('.lift-filters .filter-btn').forEach(btn => {
            btn.classList.toggle('active', btn.dataset.filter === filter);
        });
        if (this.resortDetails) {
            this.renderLifts(this.resortDetails.lifts);
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

