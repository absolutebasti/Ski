/**
 * Analytics Module
 * HIGH-013: Implement Analytics (Privacy-First)
 * 
 * Privacy-first analytics without cookies or personal data
 * Self-hosted compatible, GDPR compliant
 */

const Analytics = {
    // Configuration
    config: {
        enabled: true,
        endpoint: '/api/analytics', // Set to your endpoint or null for console-only
        debug: false,
        sampleRate: 1.0, // 1.0 = 100% of events
        batchSize: 10,
        flushInterval: 30000, // 30 seconds
        maxRetries: 3
    },
    
    // Event queue
    eventQueue: [],
    
    // Session data
    session: {
        id: null,
        startTime: null,
        pageViews: 0
    },
    
    // User data (anonymous)
    user: {
        id: null,
        firstVisit: null,
        visitCount: 0
    },
    
    // Performance metrics
    performance: {},
    
    /**
     * Initialize analytics
     */
    init(options = {}) {
        // Merge config
        this.config = { ...this.config, ...options };
        
        // Check for user preference (do not track)
        if (this.isDoNotTrack()) {
            this.config.enabled = false;
            console.log('[Analytics] Disabled (Do Not Track)');
            return;
        }
        
        // Initialize session
        this.initializeSession();
        this.initializeUser();
        
        // Track initial page view
        this.trackPageView();
        
        // Setup auto-flush
        setInterval(() => this.flush(), this.config.flushInterval);
        
        // Track performance metrics
        this.trackPerformance();
        
        // Setup navigation tracking for SPA
        this.setupSPATracking();
        
        console.log('[Analytics] Initialized');
    },
    
    /**
     * Check if user has Do Not Track enabled
     */
    isDoNotTrack() {
        return navigator.doNotTrack === '1' || 
               window.doNotTrack === '1' || 
               navigator.globalPrivacyControl === true;
    },
    
    /**
     * Initialize session
     */
    initializeSession() {
        this.session.id = this.generateId();
        this.session.startTime = Date.now();
        this.session.pageViews = 0;
    },
    
    /**
     * Initialize user (anonymous)
     */
    initializeUser() {
        const stored = this.getStoredUser();
        
        if (stored) {
            this.user = stored;
            this.user.visitCount++;
        } else {
            this.user = {
                id: this.generateId(),
                firstVisit: Date.now(),
                visitCount: 1
            };
        }
        
        this.storeUser();
    },
    
    /**
     * Get stored user data
     */
    getStoredUser() {
        try {
            const data = localStorage.getItem('analytics_user');
            return data ? JSON.parse(data) : null;
        } catch (e) {
            return null;
        }
    },
    
    /**
     * Store user data
     */
    storeUser() {
        try {
            localStorage.setItem('analytics_user', JSON.stringify(this.user));
        } catch (e) {
            // Storage might be full or unavailable
        }
    },
    
    /**
     * Generate anonymous ID
     */
    generateId() {
        return Date.now().toString(36) + Math.random().toString(36).substr(2, 9);
    },
    
    /**
     * Track an event
     */
    track(eventName, properties = {}, options = {}) {
        if (!this.config.enabled) return;
        
        // Sample rate check
        if (Math.random() > this.config.sampleRate) return;
        
        const event = {
            name: eventName,
            properties: {
                ...this.getDefaultProperties(),
                ...properties
            },
            timestamp: Date.now(),
            sessionId: this.session.id,
            userId: this.user.id
        };
        
        this.eventQueue.push(event);
        
        if (this.config.debug) {
            console.log('[Analytics] Event:', event);
        }
        
        // Flush if batch size reached
        if (this.eventQueue.length >= this.config.batchSize) {
            this.flush();
        }
    },
    
    /**
     * Track page view
     */
    trackPageView(path = null) {
        this.session.pageViews++;
        
        this.track('page_view', {
            path: path || window.location.pathname,
            referrer: document.referrer || null,
            title: document.title,
            pageViewsInSession: this.session.pageViews
        });
    },
    
    /**
     * Track app feature usage
     */
    trackFeature(featureName, action = 'used', properties = {}) {
        this.track('feature_used', {
            feature: featureName,
            action,
            ...properties
        });
    },
    
    /**
     * Track tracking started
     */
    trackTrackingStarted(properties = {}) {
        this.track('tracking_started', properties);
    },
    
    /**
     * Track tracking stopped
     */
    trackTrackingStopped(runStats = {}) {
        this.track('tracking_stopped', {
            duration: runStats.duration,
            distance: runStats.totalDistance,
            maxSpeed: runStats.maxSpeed,
            vertical: runStats.totalDescent
        });
    },
    
    /**
     * Track run saved
     */
    trackRunSaved(run) {
        this.track('run_saved', {
            runId: run.id,
            duration: run.duration,
            distance: run.totalDistance,
            maxSpeed: run.maxSpeed,
            vertical: run.totalDescent,
            positionCount: run.positions?.length
        });
    },
    
    /**
     * Track achievement unlocked
     */
    trackAchievementUnlocked(achievement) {
        this.track('achievement_unlocked', {
            achievementId: achievement.id,
            achievementName: achievement.name,
            tier: achievement.tier,
            category: achievement.category
        });
    },
    
    /**
     * Track segment completed
     */
    trackSegmentCompleted(segment, time) {
        this.track('segment_completed', {
            segmentId: segment.id,
            segmentName: segment.name,
            time: time,
            isPersonalBest: segment.isPersonalBest || false
        });
    },
    
    /**
     * Track error
     */
    trackError(error, context = {}) {
        this.track('error', {
            message: error.message,
            stack: error.stack,
            type: error.name,
            ...context
        });
    },
    
    /**
     * Track export/import
     */
    trackExportImport(type, format, success = true) {
        this.track('data_transfer', {
            type, // 'export' or 'import'
            format, // 'gpx', 'json', etc.
            success
        });
    },
    
    /**
     * Track sharing
     */
    trackShare(platform, contentType) {
        this.track('share', {
            platform, // 'native', 'twitter', 'facebook', etc.
            contentType // 'run', 'achievement', etc.
        });
    },
    
    /**
     * Get default properties for all events
     */
    getDefaultProperties() {
        return {
            url: window.location.href,
            viewport: {
                width: window.innerWidth,
                height: window.innerHeight
            },
            screen: {
                width: screen.width,
                height: screen.height
            },
            devicePixelRatio: window.devicePixelRatio,
            language: navigator.language,
            timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
            online: navigator.onLine,
            sessionDuration: Date.now() - this.session.startTime
        };
    },
    
    /**
     * Track performance metrics
     */
    trackPerformance() {
        if (!window.performance) return;
        
        // Wait for load event
        if (document.readyState === 'complete') {
            this.recordPerformanceMetrics();
        } else {
            window.addEventListener('load', () => {
                setTimeout(() => this.recordPerformanceMetrics(), 0);
            });
        }
    },
    
    /**
     * Record performance metrics
     */
    recordPerformanceMetrics() {
        const nav = performance.getEntriesByType('navigation')[0];
        
        if (!nav) return;
        
        this.performance = {
            dns: nav.domainLookupEnd - nav.domainLookupStart,
            tcp: nav.connectEnd - nav.connectStart,
            ttfb: nav.responseStart - nav.requestStart,
            download: nav.responseEnd - nav.responseStart,
            domProcessing: nav.domComplete - nav.domLoading,
            load: nav.loadEventEnd - nav.startTime
        };
        
        this.track('performance', this.performance);
    },
    
    /**
     * Setup SPA navigation tracking
     */
    setupSPATracking() {
        // Track history changes
        const originalPushState = history.pushState;
        history.pushState = (...args) => {
            originalPushState.apply(history, args);
            this.trackPageView(args[2]);
        };
        
        window.addEventListener('popstate', () => {
            this.trackPageView();
        });
    },
    
    /**
     * Flush event queue to server
     */
    async flush() {
        if (this.eventQueue.length === 0) return;
        if (!this.config.endpoint) {
            // Console-only mode
            if (this.config.debug) {
                console.log('[Analytics] Events (not sent):', [...this.eventQueue]);
            }
            this.eventQueue = [];
            return;
        }
        
        const events = [...this.eventQueue];
        this.eventQueue = [];
        
        try {
            const response = await fetch(this.config.endpoint, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ events }),
                keepalive: true // Send even if page unloads
            });
            
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}`);
            }
            
            if (this.config.debug) {
                console.log('[Analytics] Flushed', events.length, 'events');
            }
            
        } catch (error) {
            // Put events back in queue for retry
            this.eventQueue.unshift(...events);
            
            if (this.config.debug) {
                console.error('[Analytics] Flush failed:', error);
            }
        }
    },
    
    /**
     * Get current stats
     */
    getStats() {
        return {
            enabled: this.config.enabled,
            sessionId: this.session.id,
            sessionDuration: Date.now() - this.session.startTime,
            pageViews: this.session.pageViews,
            eventsInQueue: this.eventQueue.length,
            userVisits: this.user.visitCount,
            performance: this.performance
        };
    },
    
    /**
     * Enable analytics
     */
    enable() {
        this.config.enabled = true;
        console.log('[Analytics] Enabled');
    },
    
    /**
     * Disable analytics
     */
    disable() {
        this.config.enabled = false;
        this.flush(); // Send remaining events
        console.log('[Analytics] Disabled');
    },
    
    /**
     * Opt out completely
     */
    optOut() {
        this.disable();
        localStorage.setItem('analytics_opt_out', 'true');
        localStorage.removeItem('analytics_user');
        console.log('[Analytics] Opted out');
    },
    
    /**
     * Check if user has opted out
     */
    hasOptedOut() {
        return localStorage.getItem('analytics_opt_out') === 'true';
    },
    
    /**
     * Render privacy controls UI
     */
    renderPrivacyControls(container) {
        const isOptedOut = this.hasOptedOut();
        const isEnabled = this.config.enabled && !isOptedOut;
        
        container.innerHTML = `
            <div class="analytics-privacy">
                <h3>Privacy Settings</h3>
                <p>We collect anonymous usage data to improve the app. No personal information is tracked.</p>
                
                <div class="privacy-option">
                    <label>
                        <input type="checkbox" ${isEnabled ? 'checked' : ''} 
                               onchange="Analytics.toggleEnabled(this.checked)">
                        Enable anonymous analytics
                    </label>
                </div>
                
                <div class="privacy-stats">
                    <h4>Data Collected</h4>
                    <ul>
                        <li>✓ Feature usage (anonymized)</li>
                        <li>✓ Performance metrics</li>
                        <li>✓ Error reports</li>
                        <li>✗ No personal information</li>
                        <li>✗ No cookies</li>
                        <li>✗ No tracking across sites</li>
                    </ul>
                </div>
                
                <button class="btn-opt-out" onclick="Analytics.optOut()">
                    Opt Out Completely
                </button>
            </div>
        `;
    },
    
    /**
     * Toggle enabled state
     */
    toggleEnabled(enabled) {
        if (enabled) {
            this.enable();
            localStorage.removeItem('analytics_opt_out');
        } else {
            this.disable();
        }
    }
};

// Auto-initialize if not opted out
if (!Analytics.hasOptedOut()) {
    Analytics.init();
}
