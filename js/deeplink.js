/**
 * Deep Linking Module
 * HIGH-014: Implement Deep Linking for Runs
 * 
 * Enables URL-based sharing of specific runs
 * URL format: /?run=<runId>&view=detail
 */

const DeepLink = {
    // Current URL parameters
    params: new URLSearchParams(window.location.search),
    
    /**
     * Initialize deep linking
     * Call this on app startup
     */
    init() {
        const runId = this.params.get('run');
        const view = this.params.get('view') || 'detail';
        const action = this.params.get('action');
        
        if (runId) {
            console.log(`[DeepLink] Detected shared run: ${runId}`);
            this.handleSharedRun(runId, view);
        }
        
        if (action === 'import' && this.params.get('url')) {
            this.handleImportUrl(this.params.get('url'));
        }
        
        // Listen for URL changes (for single-page app navigation)
        window.addEventListener('popstate', () => this.handlePopState());
    },
    
    /**
     * Handle a shared run URL
     */
    async handleSharedRun(runId, view) {
        try {
            // Try to load the run
            const run = await Storage.getRun(runId);
            
            if (!run) {
                // Run not found locally - could be from another user
                this.showSharedRunModal(runId);
                return;
            }
            
            // Show the run detail
            if (typeof App !== 'undefined' && App.showRunDetail) {
                setTimeout(() => {
                    App.showRunDetail(runId);
                }, 500); // Delay to let app initialize
            }
            
            // Show notification
            this.showNotification(I18n.t('sharedRun'), I18n.t('openRun'));
            
        } catch (error) {
            console.error('[DeepLink] Error loading shared run:', error);
        }
    },
    
    /**
     * Generate a shareable URL for a run
     */
    generateRunUrl(runId, options = {}) {
        const baseUrl = window.location.origin + window.location.pathname;
        const params = new URLSearchParams();
        params.set('run', runId);
        params.set('view', options.view || 'detail');
        
        if (options.ref) {
            params.set('ref', options.ref);
        }
        
        return `${baseUrl}?${params.toString()}`;
    },
    
    /**
     * Share a run using Web Share API or fallback to clipboard
     */
    async shareRun(run, options = {}) {
        const shareUrl = this.generateRunUrl(run.id, options);
        const shareTitle = `${I18n.t('appName')} - ${I18n.formatDate(run.date)}`;
        const shareText = this.generateShareText(run);
        
        // Try Web Share API first
        if (navigator.share) {
            try {
                await navigator.share({
                    title: shareTitle,
                    text: shareText,
                    url: shareUrl
                });
                console.log('[DeepLink] Shared via Web Share API');
                return true;
            } catch (error) {
                if (error.name !== 'AbortError') {
                    console.error('[DeepLink] Share failed:', error);
                }
            }
        }
        
        // Fallback to clipboard
        try {
            const shareData = `${shareTitle}\n${shareText}\n${shareUrl}`;
            await navigator.clipboard.writeText(shareData);
            this.showNotification(I18n.t('shareRun'), 'Link copied to clipboard!');
            return true;
        } catch (error) {
            console.error('[DeepLink] Clipboard copy failed:', error);
            // Final fallback: show the URL
            this.showShareModal(shareUrl, shareText);
            return false;
        }
    },
    
    /**
     * Generate share text for a run
     */
    generateShareText(run) {
        const maxSpeed = I18n.formatNumber(run.maxSpeed * 3.6); // m/s to km/h
        const distance = I18n.formatNumber(run.totalDistance / 1000); // m to km
        const vertical = Math.round(run.totalDescent || 0);
        
        return `🏔️ ${I18n.t('maxSpeed')}: ${maxSpeed} km/h\n` +
               `📏 ${I18n.t('distance')}: ${distance} km\n` +
               `⛰️ ${I18n.t('vertical')}: ${vertical} m`;
    },
    
    /**
     * Update URL without reloading page
     */
    updateUrl(path, params = {}) {
        const url = new URL(window.location);
        
        if (path) {
            url.pathname = path;
        }
        
        // Update params
        Object.keys(params).forEach(key => {
            if (params[key] === null) {
                url.searchParams.delete(key);
            } else {
                url.searchParams.set(key, params[key]);
            }
        });
        
        window.history.pushState({ path: url.pathname, params }, '', url);
    },
    
    /**
     * Clear URL parameters
     */
    clearParams(keys = []) {
        const url = new URL(window.location);
        keys.forEach(key => url.searchParams.delete(key));
        window.history.replaceState({}, '', url);
    },
    
    /**
     * Handle browser back/forward
     */
    handlePopState(event) {
        if (event.state && event.state.params) {
            const runId = event.state.params.run;
            if (runId && typeof App !== 'undefined') {
                App.showRunDetail(runId);
            }
        }
    },
    
    /**
     * Show notification toast
     */
    showNotification(title, message) {
        // Use app's notification system if available
        if (typeof Utils !== 'undefined' && Utils.showToast) {
            Utils.showToast(`${title}: ${message}`);
        } else {
            console.log(`[DeepLink] ${title}: ${message}`);
        }
    },
    
    /**
     * Show shared run modal for runs not found locally
     */
    showSharedRunModal(runId) {
        const modal = document.createElement('div');
        modal.className = 'modal shared-run-modal';
        modal.innerHTML = `
            <div class="modal-content">
                <h3>${I18n.t('sharedRun')}</h3>
                <p>This run was shared with you, but it's not available locally.</p>
                <p>You may need to be logged in to view shared runs from other users.</p>
                <div class="modal-actions">
                    <button class="btn-primary" onclick="this.closest('.modal').remove()">
                        ${I18n.t('close')}
                    </button>
                </div>
            </div>
        `;
        document.body.appendChild(modal);
    },
    
    /**
     * Show share modal with URL
     */
    showShareModal(url, text) {
        const modal = document.createElement('div');
        modal.className = 'modal share-modal';
        modal.innerHTML = `
            <div class="modal-content">
                <h3>${I18n.t('shareRun')}</h3>
                <textarea class="share-text" readonly>${text}\n\n${url}</textarea>
                <div class="modal-actions">
                    <button class="btn-secondary" onclick="this.closest('.modal').remove()">
                        ${I18n.t('close')}
                    </button>
                    <button class="btn-primary" onclick="this.previousElementSibling.previousElementSibling.select(); document.execCommand('copy'); this.textContent='Copied!'">
                        Copy
                    </button>
                </div>
            </div>
        `;
        document.body.appendChild(modal);
    },
    
    /**
     * Handle import from URL
     */
    async handleImportUrl(url) {
        console.log('[DeepLink] Import from URL:', url);
        // Implementation for importing runs from external URLs
        // Would download GPX from URL and import
    },
    
    /**
     * Generate social share links
     */
    getSocialShareLinks(run) {
        const shareUrl = encodeURIComponent(this.generateRunUrl(run.id));
        const shareText = encodeURIComponent(this.generateShareText(run));
        
        return {
            twitter: `https://twitter.com/intent/tweet?text=${shareText}&url=${shareUrl}`,
            facebook: `https://www.facebook.com/sharer/sharer.php?u=${shareUrl}`,
            whatsapp: `https://wa.me/?text=${shareText}%20${shareUrl}`,
            email: `mailto:?subject=${encodeURIComponent(I18n.t('appName'))}&body=${shareText}%0A%0A${shareUrl}`
        };
    },
    
    /**
     * Create share button HTML
     */
    createShareButton(runId, options = {}) {
        const button = document.createElement('button');
        button.className = 'btn-share';
        button.innerHTML = '↗️ ' + I18n.t('shareRun');
        button.onclick = async () => {
            const run = await Storage.getRun(runId);
            if (run) {
                this.shareRun(run, options);
            }
        };
        return button;
    }
};

// Initialize on load
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => DeepLink.init());
} else {
    DeepLink.init();
}
