/**
 * KitzSki Tracker - Main Application
 */

const App = {
    state: 'idle', // idle, tracking, paused
    wakeLock: null,
    
    // Auto-pause settings (DISABLED - too aggressive for skiing)
    autoPauseEnabled: false,
    zeroSpeedStartTime: null,
    autoPauseThreshold: 180000, // 3 minutes (if re-enabled)
    
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
        
        // Check for emergency saved run (crash recovery)
        await this.checkEmergencyRun();
        
        // Load live slope status
        this.loadLiveStatus();
        
        console.log('🎿 Ski Tracker ready!');
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
            facilitiesGrid: document.getElementById('facilitiesGrid'),
            // Achievements elements
            achievementsBtn: document.getElementById('achievementsBtn'),
            achievementsPanel: document.getElementById('achievementsPanel'),
            closeAchievementsBtn: document.getElementById('closeAchievementsBtn'),
            achievementsList: document.getElementById('achievementsList'),
            achievementProgress: document.getElementById('achievementProgress'),
            progressFill: document.getElementById('progressFill'),
            unlockedCount: document.getElementById('unlockedCount'),
            totalCount: document.getElementById('totalCount'),
            // Live status elements
            liveStatusBtn: document.getElementById('liveStatusBtn'),
            liveDot: document.getElementById('liveDot'),
            liveStatusPanel: document.getElementById('liveStatusPanel'),
            closeLiveStatusBtn: document.getElementById('closeLiveStatusBtn'),
            liveStatusTime: document.getElementById('liveStatusTime'),
            slopesOpenCount: document.getElementById('slopesOpenCount'),
            slopesTotalCount: document.getElementById('slopesTotalCount'),
            liftsOpenCount: document.getElementById('liftsOpenCount'),
            liftsTotalCount: document.getElementById('liftsTotalCount'),
            liveSlopesList: document.getElementById('liveSlopesList'),
            liveLiftsList: document.getElementById('liveLiftsList'),
            refreshStatusBtn: document.getElementById('refreshStatusBtn'),
            // Run detail elements
            runDetailPanel: document.getElementById('runDetailPanel'),
            closeRunDetailBtn: document.getElementById('closeRunDetailBtn'),
            runDetailTitle: document.getElementById('runDetailTitle'),
            runDetailMap: document.getElementById('runDetailMap'),
            detailMaxSpeed: document.getElementById('detailMaxSpeed'),
            detailDistance: document.getElementById('detailDistance'),
            detailVertical: document.getElementById('detailVertical'),
            detailDuration: document.getElementById('detailDuration'),
            altitudeCanvas: document.getElementById('altitudeCanvas'),
            profileStartAlt: document.getElementById('profileStartAlt'),
            profileEndAlt: document.getElementById('profileEndAlt'),
            deleteRunBtn: document.getElementById('deleteRunBtn')
        };
    },

    // Run detail map instance
    runDetailMapInstance: null,
    currentDetailRunId: null,

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
        
        // Initialize achievements
        await Achievements.init();
        
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
        
        // Run details
        this.elements.closeRunDetailBtn?.addEventListener('click', () => this.hidePanel('runDetail'));
        this.elements.deleteRunBtn?.addEventListener('click', () => this.deleteCurrentDetailRun());
        
        // Achievements
        this.elements.achievementsBtn?.addEventListener('click', () => this.showAchievementsPanel());
        this.elements.closeAchievementsBtn?.addEventListener('click', () => this.hidePanel('achievements'));
        
        // Achievement category tabs
        document.querySelectorAll('.achievement-tab').forEach(tab => {
            tab.addEventListener('click', (e) => this.filterAchievements(e.target.dataset.category));
        });
        
        // Live status
        this.elements.liveStatusBtn?.addEventListener('click', () => this.showLiveStatusPanel());
        this.elements.closeLiveStatusBtn?.addEventListener('click', () => this.hidePanel('liveStatus'));
        this.elements.refreshStatusBtn?.addEventListener('click', () => this.refreshAndShowStatus());
        
        // Live status tabs
        document.querySelectorAll('.live-tab').forEach(tab => {
            tab.addEventListener('click', (e) => this.switchLiveTab(e.target.dataset.tab));
        });
        
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
        
        // Auto-save when page closes (prevent data loss)
        window.addEventListener('beforeunload', (e) => this.handleBeforeUnload(e));
        window.addEventListener('pagehide', () => this.emergencySave());
    },

    /**
     * Handle before unload - warn if tracking
     */
    handleBeforeUnload(e) {
        if (this.state === 'tracking' || this.state === 'paused') {
            // Emergency save
            this.emergencySave();
            
            // Show confirmation dialog
            e.preventDefault();
            e.returnValue = 'You have an active run. Are you sure you want to leave?';
            return e.returnValue;
        }
    },

    /**
     * Emergency save current run data
     */
    async emergencySave() {
        if (this.state === 'idle') return;
        
        try {
            const runData = Stats.getRunData();
            if (runData.distance > 0.01 || runData.duration > 10000) {
                // Save to localStorage as backup (faster than IndexedDB)
                localStorage.setItem('emergencyRun', JSON.stringify({
                    ...runData,
                    savedAt: Date.now(),
                    wasTracking: this.state === 'tracking'
                }));
                console.log('Emergency save completed');
            }
        } catch (e) {
            console.error('Emergency save failed:', e);
        }
    },

    /**
     * Check for emergency saved run on startup
     */
    async checkEmergencyRun() {
        const saved = localStorage.getItem('emergencyRun');
        if (saved) {
            try {
                const runData = JSON.parse(saved);
                const age = Date.now() - runData.savedAt;
                
                // Only recover if less than 1 hour old
                if (age < 3600000) {
                    const recover = confirm(
                        `Found unsaved run from ${Math.round(age / 60000)} minutes ago.\n` +
                        `Distance: ${runData.distance.toFixed(2)} km\n` +
                        `Max Speed: ${Math.round(runData.maxSpeed)} km/h\n\n` +
                        `Would you like to save it?`
                    );
                    
                    if (recover) {
                        await Storage.saveRun(runData);
                        await Storage.updateRecords(runData);
                        await Stats.updateRunCount();
                        alert('Run recovered and saved!');
                    }
                }
                
                localStorage.removeItem('emergencyRun');
            } catch (e) {
                localStorage.removeItem('emergencyRun');
            }
        }
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
        const pauseBtnText = document.getElementById('pauseBtnText');
        
        if (this.state === 'tracking') {
            this.state = 'paused';
            GPSTracker.pause();
            Stats.pauseTimer();
            if (pauseBtnText) pauseBtnText.textContent = 'Resume';
            this.elements.pauseBtn?.classList.add('paused');
        } else if (this.state === 'paused') {
            this.state = 'tracking';
            GPSTracker.resume();
            Stats.resumeTimer();
            if (pauseBtnText) pauseBtnText.textContent = 'Pause';
            this.elements.pauseBtn?.classList.remove('paused');
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
            
            // Check for new achievements
            const newAchievements = await Achievements.checkAfterRun(runData);
            if (newAchievements.length > 0) {
                this.showAchievementUnlock(newAchievements[0]);
                // Queue additional achievements
                for (let i = 1; i < newAchievements.length; i++) {
                    setTimeout(() => this.showAchievementUnlock(newAchievements[i]), i * 3000);
                }
            }
            
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
        
        // Auto-pause logic (for lift rides)
        this.checkAutoPause(position.smoothedSpeed || position.speed);
    },

    /**
     * Check if should auto-pause - DISABLED
     * Skiing involves too many natural stops (lifts, queues, resting)
     * Manual pause/resume is better for skiing
     */
    checkAutoPause(speed) {
        // Disabled - continuous tracking is better for skiing
        return;
    },

    /**
     * Handle GPS error
     * @param {Object} error - Error object
     */
    handleGPSError(error) {
        console.error('GPS Error:', error);
        
        if (error.code === 1) { // Permission denied
            this.showGPSModal();
        } else {
            // Show toast for other errors
            this.showToast(error.message || 'GPS error occurred', 'error');
        }
    },

    /**
     * Show a toast notification
     * @param {string} message - Message to show
     * @param {string} type - Toast type (info, error, success)
     */
    showToast(message, type = 'info') {
        // Remove existing toast
        const existing = document.querySelector('.toast');
        if (existing) existing.remove();
        
        const toast = document.createElement('div');
        toast.className = `toast toast-${type}`;
        toast.innerHTML = `
            <span class="toast-icon">${type === 'error' ? '⚠️' : type === 'success' ? '✓' : 'ℹ️'}</span>
            <span class="toast-message">${message}</span>
        `;
        
        document.body.appendChild(toast);
        
        // Animate in
        requestAnimationFrame(() => toast.classList.add('show'));
        
        // Auto-remove after 4 seconds
        setTimeout(() => {
            toast.classList.remove('show');
            setTimeout(() => toast.remove(), 300);
        }, 4000);
    },

    /**
     * Update control button visibility
     */
    updateControlButtons() {
        const { startBtn, pauseBtn, stopBtn } = this.elements;
        const pauseBtnText = document.getElementById('pauseBtnText');
        
        if (this.state === 'idle') {
            startBtn?.classList.remove('hidden');
            pauseBtn?.classList.add('hidden');
            stopBtn?.classList.add('hidden');
            if (pauseBtnText) pauseBtnText.textContent = 'Pause';
        } else {
            startBtn?.classList.add('hidden');
            pauseBtn?.classList.remove('hidden');
            stopBtn?.classList.remove('hidden');
        }
        
        console.log('Button state updated:', this.state);
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
        } else if (panel === 'runDetail') {
            this.elements.runDetailPanel?.classList.add('hidden');
            // Clean up the map
            if (this.runDetailMapInstance) {
                this.runDetailMapInstance.remove();
                this.runDetailMapInstance = null;
            }
        } else if (panel === 'liveStatus') {
            this.elements.liveStatusPanel?.classList.add('hidden');
        } else if (panel === 'achievements') {
            this.elements.achievementsPanel?.classList.add('hidden');
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
     * Render slopes list with live status
     */
    renderSlopes(slopes) {
        const filtered = this.currentSlopeFilter === 'all' 
            ? slopes 
            : slopes.filter(s => s.difficulty === this.currentSlopeFilter);
        
        // Get live status data if available
        const liveSlopes = this.liveStatus?.slopes || [];
        
        this.elements.slopesList.innerHTML = filtered.map(slope => {
            // Check if this slope has live status
            const liveData = liveSlopes.find(ls => 
                ls.name.toLowerCase().includes(slope.name.toLowerCase()) ||
                slope.name.toLowerCase().includes(ls.name.toLowerCase())
            );
            const isOpen = liveData?.status === 'open';
            const hasStatus = !!liveData;
            
            return `
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
                    ${hasStatus ? `<div class="status-dot ${isOpen ? 'open' : 'closed'}"></div>` : ''}
                </div>
            `;
        }).join('');
    },

    /**
     * Render lifts list with live status
     */
    renderLifts(lifts) {
        const filtered = this.currentLiftFilter === 'all' 
            ? lifts 
            : lifts.filter(l => l.type === this.currentLiftFilter);
        
        // Get live status data if available
        const liveLifts = this.liveStatus?.lifts || [];
        
        const liftIcons = {
            gondola: '🚡',
            chairlift: '🪑',
            dragLift: '⬆️'
        };
        
        this.elements.liftsList.innerHTML = filtered.map(lift => {
            // Check if this lift has live status
            const liveData = liveLifts.find(ll => 
                ll.name.toLowerCase().includes(lift.name.toLowerCase()) ||
                lift.name.toLowerCase().includes(ll.name.toLowerCase())
            );
            const isOpen = liveData?.status === 'open';
            const hasStatus = !!liveData;
            
            return `
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
                    ${hasStatus ? `<div class="status-dot ${isOpen ? 'open' : 'closed'}"></div>` : ''}
                </div>
            `;
        }).join('');
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
        
        // Add click handlers for each history item
        this.elements.historyList.querySelectorAll('.history-item').forEach(item => {
            item.addEventListener('click', () => this.showRunDetail(item.dataset.id));
        });
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
     * Show run detail with route map
     * @param {string} runId - Run ID
     */
    async showRunDetail(runId) {
        const run = await Storage.getRun(runId);
        if (!run) {
            this.showToast('Run not found', 'error');
            return;
        }
        
        this.currentDetailRunId = runId;
        
        // Update title
        const date = new Date(run.startTime);
        this.elements.runDetailTitle.textContent = `${Utils.formatDate(date)} at ${Utils.formatTime(date)}`;
        
        // Update stats
        this.elements.detailMaxSpeed.textContent = Math.round(run.maxSpeed);
        this.elements.detailDistance.textContent = run.distance.toFixed(2);
        this.elements.detailVertical.textContent = Math.round(run.verticalDrop);
        this.elements.detailDuration.textContent = Utils.formatDuration(run.duration);
        
        // Show panel first so map container has size
        this.elements.runDetailPanel?.classList.remove('hidden');
        
        // Initialize map after a short delay for DOM to settle
        setTimeout(() => {
            this.initRunDetailMap(run);
            this.drawAltitudeProfile(run);
        }, 100);
    },
    
    /**
     * Initialize run detail map with route
     * @param {Object} run - Run data
     */
    initRunDetailMap(run) {
        // Clean up existing map
        if (this.runDetailMapInstance) {
            this.runDetailMapInstance.remove();
        }
        
        const positions = run.positions || [];
        if (positions.length === 0) {
            this.elements.runDetailMap.innerHTML = '<div style="display:flex;align-items:center;justify-content:center;height:100%;color:var(--text-tertiary);font-size:13px;">No GPS data recorded</div>';
            return;
        }
        
        // Create map
        mapboxgl.accessToken = Config.MAPBOX_TOKEN;
        
        this.runDetailMapInstance = new mapboxgl.Map({
            container: 'runDetailMap',
            style: 'mapbox://styles/mapbox/dark-v11',
            center: [positions[0].lon, positions[0].lat],
            zoom: 14,
            attributionControl: false
        });
        
        const map = this.runDetailMapInstance;
        
        map.on('load', () => {
            // Create route coordinates
            const coordinates = positions.map(p => [p.lon, p.lat]);
            
            // Add route line with gradient based on speed
            map.addSource('route', {
                type: 'geojson',
                data: {
                    type: 'Feature',
                    geometry: {
                        type: 'LineString',
                        coordinates: coordinates
                    }
                }
            });
            
            // Route glow (background)
            map.addLayer({
                id: 'route-glow',
                type: 'line',
                source: 'route',
                paint: {
                    'line-color': '#00ff88',
                    'line-width': 8,
                    'line-blur': 4,
                    'line-opacity': 0.4
                }
            });
            
            // Route line
            map.addLayer({
                id: 'route-line',
                type: 'line',
                source: 'route',
                paint: {
                    'line-color': '#00ff88',
                    'line-width': 3,
                    'line-opacity': 0.9
                }
            });
            
            // Add start marker (green)
            new mapboxgl.Marker({ color: '#22c55e' })
                .setLngLat(coordinates[0])
                .addTo(map);
            
            // Add end marker (red)
            new mapboxgl.Marker({ color: '#ef4444' })
                .setLngLat(coordinates[coordinates.length - 1])
                .addTo(map);
            
            // Fit bounds to show entire route
            const bounds = coordinates.reduce((bounds, coord) => {
                return bounds.extend(coord);
            }, new mapboxgl.LngLatBounds(coordinates[0], coordinates[0]));
            
            map.fitBounds(bounds, {
                padding: 40,
                maxZoom: 15,
                duration: 0
            });
        });
    },
    
    /**
     * Draw altitude profile chart
     * @param {Object} run - Run data
     */
    drawAltitudeProfile(run) {
        const canvas = this.elements.altitudeCanvas;
        if (!canvas) return;
        
        const ctx = canvas.getContext('2d');
        const positions = run.positions || [];
        
        // Set canvas size
        const rect = canvas.parentElement.getBoundingClientRect();
        canvas.width = rect.width * window.devicePixelRatio;
        canvas.height = rect.height * window.devicePixelRatio;
        ctx.scale(window.devicePixelRatio, window.devicePixelRatio);
        
        const width = rect.width;
        const height = rect.height;
        
        // Get altitudes
        const altitudes = positions.filter(p => p.alt !== null && p.alt !== undefined).map(p => p.alt);
        
        if (altitudes.length < 2) {
            ctx.fillStyle = 'rgba(255,255,255,0.2)';
            ctx.font = '12px system-ui';
            ctx.textAlign = 'center';
            ctx.fillText('No altitude data', width / 2, height / 2);
            return;
        }
        
        const minAlt = Math.min(...altitudes);
        const maxAlt = Math.max(...altitudes);
        const range = maxAlt - minAlt || 1;
        
        // Update labels
        this.elements.profileStartAlt.textContent = `${Math.round(altitudes[0])}m`;
        this.elements.profileEndAlt.textContent = `${Math.round(altitudes[altitudes.length - 1])}m`;
        
        // Draw gradient background
        const gradient = ctx.createLinearGradient(0, 0, 0, height);
        gradient.addColorStop(0, 'rgba(0, 255, 136, 0.3)');
        gradient.addColorStop(1, 'rgba(0, 255, 136, 0.05)');
        
        // Draw path
        ctx.beginPath();
        ctx.moveTo(0, height);
        
        altitudes.forEach((alt, i) => {
            const x = (i / (altitudes.length - 1)) * width;
            const y = height - ((alt - minAlt) / range) * (height - 10) - 5;
            ctx.lineTo(x, y);
        });
        
        ctx.lineTo(width, height);
        ctx.closePath();
        ctx.fillStyle = gradient;
        ctx.fill();
        
        // Draw line
        ctx.beginPath();
        altitudes.forEach((alt, i) => {
            const x = (i / (altitudes.length - 1)) * width;
            const y = height - ((alt - minAlt) / range) * (height - 10) - 5;
            if (i === 0) ctx.moveTo(x, y);
            else ctx.lineTo(x, y);
        });
        ctx.strokeStyle = '#00ff88';
        ctx.lineWidth = 2;
        ctx.stroke();
    },
    
    /**
     * Delete the current detail run
     */
    async deleteCurrentDetailRun() {
        if (!this.currentDetailRunId) return;
        
        if (confirm('Are you sure you want to delete this run?')) {
            await Storage.deleteRun(this.currentDetailRunId);
            this.hidePanel('runDetail');
            await this.loadHistory();
            await Stats.updateRunCount();
            this.showToast('Run deleted', 'success');
        }
    },

    /**
     * Show achievements panel
     */
    showAchievementsPanel() {
        this.elements.achievementsPanel?.classList.remove('hidden');
        this.renderAchievements('all');
        this.updateAchievementProgress();
    },
    
    /**
     * Render achievements list
     */
    renderAchievements(category = 'all') {
        const achievements = category === 'all' 
            ? Achievements.getAll()
            : Achievements.getByCategory(category);
        
        // Sort: unlocked first, then by tier
        const tierOrder = { legendary: 0, platinum: 1, gold: 2, silver: 3, bronze: 4 };
        achievements.sort((a, b) => {
            if (a.isUnlocked && !b.isUnlocked) return -1;
            if (!a.isUnlocked && b.isUnlocked) return 1;
            return tierOrder[a.tier] - tierOrder[b.tier];
        });
        
        this.elements.achievementsList.innerHTML = achievements.map(a => `
            <div class="achievement-card ${a.isUnlocked ? 'unlocked' : 'locked'}" data-tier="${a.tier}">
                <div class="achievement-icon">${a.icon}</div>
                <div class="achievement-info">
                    <div class="achievement-name">${a.name}</div>
                    <div class="achievement-description">${a.description}</div>
                </div>
                <div class="achievement-badge">${a.tier}</div>
            </div>
        `).join('');
    },
    
    /**
     * Update achievement progress display
     */
    updateAchievementProgress() {
        const progress = Achievements.getProgress();
        
        this.elements.unlockedCount.textContent = progress.unlocked;
        this.elements.totalCount.textContent = progress.total;
        this.elements.progressFill.setAttribute('stroke-dasharray', `${progress.percentage}, 100`);
    },
    
    /**
     * Filter achievements by category
     */
    filterAchievements(category) {
        document.querySelectorAll('.achievement-tab').forEach(tab => {
            tab.classList.toggle('active', tab.dataset.category === category);
        });
        this.renderAchievements(category);
    },
    
    /**
     * Show achievement unlock toast
     */
    showAchievementUnlock(achievement) {
        // Remove existing toast
        const existing = document.querySelector('.achievement-toast');
        if (existing) existing.remove();
        
        const toast = document.createElement('div');
        toast.className = 'achievement-toast';
        toast.innerHTML = `
            <div class="achievement-toast-header">🎉 Achievement Unlocked!</div>
            <div class="achievement-toast-icon">${achievement.icon}</div>
            <div class="achievement-toast-name">${achievement.name}</div>
            <div class="achievement-toast-description">${achievement.description}</div>
            <div class="achievement-toast-tier">${achievement.tier}</div>
        `;
        
        document.body.appendChild(toast);
        
        // Trigger animation
        requestAnimationFrame(() => {
            toast.classList.add('show');
        });
        
        // Vibrate
        Utils.vibrate([100, 50, 100, 50, 200]);
        
        // Auto-dismiss after 3 seconds
        setTimeout(() => {
            toast.classList.remove('show');
            setTimeout(() => toast.remove(), 400);
        }, 3000);
    },

    /**
     * Show live status panel
     */
    async showLiveStatusPanel() {
        this.elements.liveStatusPanel?.classList.remove('hidden');
        await this.fetchLiveStatus();
    },
    
    /**
     * Fetch live status from Supabase
     */
    async fetchLiveStatus() {
        try {
            // Show loading state
            this.elements.liveSlopesList.innerHTML = `
                <div class="status-loading">
                    <div class="loading-spinner"></div>
                    <span>Loading status...</span>
                </div>
            `;
            this.elements.liveLiftsList.innerHTML = this.elements.liveSlopesList.innerHTML;
            
            // Try to get from Supabase
            if (!Supabase.client) {
                await Supabase.init();
            }
            
            const data = await Supabase.getSlopeStatus('kitzbuehel');
            
            if (data) {
                this.liveStatus = data;
                this.renderLiveStatus(data);
                this.updateLiveDot(data);
            } else {
                this.renderNoLiveData();
            }
        } catch (e) {
            console.error('Failed to fetch live status:', e);
            this.renderNoLiveData();
        }
    },
    
    /**
     * Render live status data
     */
    renderLiveStatus(data) {
        // Update summary counts
        this.elements.slopesOpenCount.textContent = data.slopes_open || 0;
        this.elements.slopesTotalCount.textContent = data.slopes_total || 0;
        this.elements.liftsOpenCount.textContent = data.lifts_open || 0;
        this.elements.liftsTotalCount.textContent = data.lifts_total || 0;
        
        // Update time
        if (data.updated_at) {
            const time = new Date(data.updated_at);
            this.elements.liveStatusTime.textContent = `Updated ${Utils.formatDate(time)} at ${Utils.formatTime(time)}`;
        }
        
        // Render slopes
        const slopes = data.slopes || [];
        if (slopes.length > 0) {
            this.elements.liveSlopesList.innerHTML = slopes.map(slope => `
                <div class="status-item">
                    <div class="status-indicator ${slope.status}"></div>
                    <span class="status-name">${slope.name}</span>
                    ${slope.difficulty ? `<span class="status-type">${slope.difficulty}</span>` : ''}
                </div>
            `).join('');
        } else {
            this.elements.liveSlopesList.innerHTML = `
                <div class="status-no-data">
                    <div class="icon">🎿</div>
                    <p>No slope data available</p>
                </div>
            `;
        }
        
        // Render lifts
        const lifts = data.lifts || [];
        if (lifts.length > 0) {
            this.elements.liveLiftsList.innerHTML = lifts.map(lift => `
                <div class="status-item">
                    <div class="status-indicator ${lift.status}"></div>
                    <span class="status-name">${lift.name}</span>
                    ${lift.type ? `<span class="status-type">${lift.type}</span>` : ''}
                </div>
            `).join('');
        } else {
            this.elements.liveLiftsList.innerHTML = `
                <div class="status-no-data">
                    <div class="icon">🚡</div>
                    <p>No lift data available</p>
                </div>
            `;
        }
    },
    
    /**
     * Render no live data state
     */
    renderNoLiveData() {
        this.elements.slopesOpenCount.textContent = '--';
        this.elements.slopesTotalCount.textContent = '--';
        this.elements.liftsOpenCount.textContent = '--';
        this.elements.liftsTotalCount.textContent = '--';
        this.elements.liveStatusTime.textContent = 'No data available';
        
        const noDataHtml = `
            <div class="status-no-data">
                <div class="icon">📡</div>
                <p>No live data available yet</p>
                <p style="font-size: 12px; margin-top: 8px;">Tap "Refresh Status" to fetch latest data</p>
            </div>
        `;
        
        this.elements.liveSlopesList.innerHTML = noDataHtml;
        this.elements.liveLiftsList.innerHTML = noDataHtml;
    },
    
    /**
     * Update live dot indicator
     */
    updateLiveDot(data) {
        const dot = this.elements.liveDot;
        if (!dot) return;
        
        dot.classList.remove('active', 'partial', 'closed');
        
        if (data && data.slopes_total > 0) {
            const openPct = (data.slopes_open / data.slopes_total) * 100;
            if (openPct > 80) {
                dot.classList.add('active');
            } else if (openPct > 0) {
                dot.classList.add('partial');
            } else {
                dot.classList.add('closed');
            }
        }
    },
    
    /**
     * Switch live status tab
     */
    switchLiveTab(tab) {
        document.querySelectorAll('.live-tab').forEach(t => t.classList.remove('active'));
        document.querySelectorAll('.live-tab-content').forEach(c => c.classList.remove('active'));
        
        document.querySelector(`.live-tab[data-tab="${tab}"]`)?.classList.add('active');
        document.getElementById(`live${tab.charAt(0).toUpperCase() + tab.slice(1)}Tab`)?.classList.add('active');
    },
    
    /**
     * Refresh and show status (calls the scraper)
     */
    async refreshAndShowStatus() {
        const btn = this.elements.refreshStatusBtn;
        const originalHtml = btn.innerHTML;
        
        btn.innerHTML = '<div class="loading-spinner" style="width:16px;height:16px;"></div> Refreshing...';
        btn.disabled = true;
        
        try {
            // Call the Edge Function to scrape fresh data
            const response = await fetch(`${Config.SUPABASE_URL}/functions/v1/scrape-slopes`, {
                headers: {
                    'Authorization': `Bearer ${Config.SUPABASE_ANON_KEY}`
                }
            });
            
            if (response.ok) {
                this.showToast('Status updated!', 'success');
                // Wait a moment for DB to update, then fetch
                setTimeout(() => this.fetchLiveStatus(), 1000);
            } else {
                throw new Error('Failed to refresh');
            }
        } catch (e) {
            console.error('Refresh failed:', e);
            this.showToast('Could not refresh status', 'error');
        } finally {
            btn.innerHTML = originalHtml;
            btn.disabled = false;
        }
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
     * Load live slope status from Supabase
     */
    async loadLiveStatus() {
        const liveStatus = document.getElementById('liveStatus');
        const liveText = liveStatus?.querySelector('.live-text');
        
        try {
            // Initialize Supabase if not already
            if (!Supabase.client) {
                await Supabase.init();
            }
            
            // Get status from Supabase
            const resort = Resorts.getCurrent();
            const data = await Supabase.getSlopeStatus(resort?.id || 'kitzbuehel');
            
            if (data && data.slopes_total > 0) {
                const openPct = Math.round((data.slopes_open / data.slopes_total) * 100);
                liveText.textContent = `${data.slopes_open}/${data.slopes_total} open`;
                
                liveStatus.classList.remove('closed', 'partial');
                if (openPct === 0) {
                    liveStatus.classList.add('closed');
                } else if (openPct < 80) {
                    liveStatus.classList.add('partial');
                }
                
                // Store for details panel
                this.liveStatus = data;
            } else if (data) {
                liveText.textContent = 'Status available';
                this.liveStatus = data;
            } else {
                liveText.textContent = 'Live';
            }
        } catch (e) {
            console.log('Live status not available:', e.message);
            if (liveText) liveText.textContent = 'Live';
        }
    },

    /**
     * Manually refresh slope status (calls the Edge Function)
     */
    async refreshSlopeStatus() {
        const liveStatus = document.getElementById('liveStatus');
        const liveText = liveStatus?.querySelector('.live-text');
        
        if (liveText) liveText.textContent = 'Updating...';
        
        try {
            const config = {
                url: Config.SUPABASE_URL,
                anonKey: Config.SUPABASE_ANON_KEY
            };
            
            const response = await fetch(`${config.url}/functions/v1/scrape-slopes`, {
                headers: {
                    'Authorization': `Bearer ${config.anonKey}`
                }
            });
            
            if (response.ok) {
                const data = await response.json();
                console.log('Scraper response:', data);
                
                // Reload status from database
                setTimeout(() => this.loadLiveStatus(), 1000);
            }
        } catch (e) {
            console.error('Failed to refresh status:', e);
            this.loadLiveStatus();
        }
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

