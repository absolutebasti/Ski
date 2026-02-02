/**
 * Sync Manager Module
 * HIGH-011: Implement Data Sync Conflict Resolution
 * 
 * Handles synchronization between local data and server
 * Includes conflict detection and resolution strategies
 */

const SyncManager = {
    // Sync configuration
    config: {
        syncInterval: 300000, // 5 minutes
        retryDelay: 5000,     // 5 seconds
        maxRetries: 3,
        batchSize: 50,
        enableAutoSync: true
    },
    
    // Sync state
    state: {
        isSyncing: false,
        lastSync: null,
        pendingChanges: [],
        conflicts: [],
        queue: []
    },
    
    // Sync status callbacks
    callbacks: {
        onSyncStart: null,
        onSyncComplete: null,
        onSyncError: null,
        onConflict: null
    },
    
    /**
     * Initialize sync manager
     */
    async init() {
        await this.loadSyncState();
        
        // Setup auto-sync if enabled
        if (this.config.enableAutoSync) {
            this.startAutoSync();
        }
        
        // Listen for online/offline events
        window.addEventListener('online', () => this.onOnline());
        window.addEventListener('offline', () => this.onOffline());
        
        console.log('[SyncManager] Initialized');
    },
    
    /**
     * Load sync state from storage
     */
    async loadSyncState() {
        try {
            const state = await Storage.get('syncState');
            if (state) {
                this.state.lastSync = state.lastSync;
                this.state.pendingChanges = state.pendingChanges || [];
            }
        } catch (e) {
            console.error('[SyncManager] Failed to load sync state:', e);
        }
    },
    
    /**
     * Save sync state
     */
    async saveSyncState() {
        try {
            await Storage.set('syncState', {
                lastSync: this.state.lastSync,
                pendingChanges: this.state.pendingChanges
            });
        } catch (e) {
            console.error('[SyncManager] Failed to save sync state:', e);
        }
    },
    
    /**
     * Start automatic sync
     */
    startAutoSync() {
        setInterval(() => {
            if (navigator.onLine && !this.state.isSyncing) {
                this.sync();
            }
        }, this.config.syncInterval);
    },
    
    /**
     * Handle coming back online
     */
    async onOnline() {
        console.log('[SyncManager] Back online, triggering sync');
        
        if (this.state.pendingChanges.length > 0) {
            await this.sync();
        }
    },
    
    /**
     * Handle going offline
     */
    onOffline() {
        console.log('[SyncManager] Gone offline');
        // Queue will be processed when back online
    },
    
    /**
     * Perform full sync
     */
    async sync() {
        if (this.state.isSyncing) {
            console.log('[SyncManager] Sync already in progress');
            return;
        }
        
        this.state.isSyncing = true;
        
        if (this.callbacks.onSyncStart) {
            this.callbacks.onSyncStart();
        }
        
        try {
            // Push local changes to server
            await this.pushChanges();
            
            // Pull remote changes
            await this.pullChanges();
            
            // Resolve any conflicts
            await this.resolveConflicts();
            
            this.state.lastSync = Date.now();
            await this.saveSyncState();
            
            console.log('[SyncManager] Sync completed');
            
            if (this.callbacks.onSyncComplete) {
                this.callbacks.onSyncComplete({
                    timestamp: this.state.lastSync,
                    conflicts: this.state.conflicts.length
                });
            }
            
        } catch (error) {
            console.error('[SyncManager] Sync failed:', error);
            
            if (this.callbacks.onSyncError) {
                this.callbacks.onSyncError(error);
            }
        } finally {
            this.state.isSyncing = false;
        }
    },
    
    /**
     * Push local changes to server
     */
    async pushChanges() {
        if (this.state.pendingChanges.length === 0) return;
        
        console.log(`[SyncManager] Pushing ${this.state.pendingChanges.length} changes`);
        
        const changes = [...this.state.pendingChanges];
        const batches = this.createBatches(changes, this.config.batchSize);
        
        for (const batch of batches) {
            try {
                // This would call your Supabase/API endpoint
                await this.uploadBatch(batch);
                
                // Remove successfully uploaded changes
                this.state.pendingChanges = this.state.pendingChanges.filter(
                    c => !batch.includes(c)
                );
            } catch (error) {
                console.error('[SyncManager] Batch upload failed:', error);
                throw error;
            }
        }
    },
    
    /**
     * Upload a batch of changes
     */
    async uploadBatch(batch) {
        // Mock implementation - replace with actual API call
        console.log('[SyncManager] Uploading batch:', batch.length);
        
        // Simulate API call
        await new Promise(resolve => setTimeout(resolve, 500));
        
        return { success: true };
    },
    
    /**
     * Pull remote changes from server
     */
    async pullChanges() {
        try {
            // Get last sync timestamp
            const since = this.state.lastSync || 0;
            
            // Fetch remote changes
            const remoteChanges = await this.fetchRemoteChanges(since);
            
            console.log(`[SyncManager] Pulled ${remoteChanges.length} remote changes`);
            
            // Apply remote changes locally
            for (const change of remoteChanges) {
                await this.applyRemoteChange(change);
            }
        } catch (error) {
            console.error('[SyncManager] Pull failed:', error);
            throw error;
        }
    },
    
    /**
     * Fetch remote changes from server
     */
    async fetchRemoteChanges(since) {
        // Mock implementation - replace with actual API call
        return [];
    },
    
    /**
     * Apply a remote change locally
     */
    async applyRemoteChange(change) {
        const { type, data, timestamp } = change;
        
        switch (type) {
            case 'RUN':
                await this.applyRunChange(data, timestamp);
                break;
            case 'ACHIEVEMENT':
                await this.applyAchievementChange(data);
                break;
            case 'SETTINGS':
                await this.applySettingsChange(data);
                break;
        }
    },
    
    /**
     * Apply run change with conflict detection
     */
    async applyRunChange(remoteRun, remoteTimestamp) {
        const localRun = await Storage.getRun(remoteRun.id);
        
        if (!localRun) {
            // No local version - just save remote
            await Storage.saveRun(remoteRun);
            return;
        }
        
        // Check for conflict
        if (localRun.lastModified && remoteTimestamp < localRun.lastModified) {
            // Local is newer - potential conflict
            const conflict = this.detectConflict(localRun, remoteRun);
            
            if (conflict) {
                this.state.conflicts.push({
                    type: 'RUN',
                    local: localRun,
                    remote: remoteRun,
                    detected: Date.now()
                });
                return;
            }
        }
        
        // No conflict or remote is newer - apply change
        await Storage.saveRun({
            ...remoteRun,
            lastSynced: Date.now()
        });
    },
    
    /**
     * Detect if there's a real conflict between local and remote
     */
    detectConflict(local, remote) {
        // If they're identical, no conflict
        if (JSON.stringify(local) === JSON.stringify(remote)) {
            return false;
        }
        
        // Check for overlapping position data
        if (local.positions && remote.positions) {
            const localTimes = new Set(local.positions.map(p => p.timestamp));
            const hasOverlap = remote.positions.some(p => localTimes.has(p.timestamp));
            
            if (hasOverlap) {
                // Check if data differs at overlapping points
                for (const remotePos of remote.positions) {
                    const localPos = local.positions.find(p => p.timestamp === remotePos.timestamp);
                    if (localPos && JSON.stringify(localPos) !== JSON.stringify(remotePos)) {
                        return true; // Real conflict
                    }
                }
            }
        }
        
        // Check for significant stat differences
        const statDiffs = ['totalDistance', 'maxSpeed', 'totalDescent'].filter(
            key => Math.abs((local[key] || 0) - (remote[key] || 0)) > 100
        );
        
        if (statDiffs.length > 0) {
            return true;
        }
        
        return false;
    },
    
    /**
     * Resolve all pending conflicts
     */
    async resolveConflicts() {
        for (const conflict of this.state.conflicts) {
            const resolution = await this.resolveConflict(conflict);
            
            if (resolution) {
                await this.applyResolution(conflict, resolution);
            }
        }
        
        // Clear resolved conflicts
        this.state.conflicts = this.state.conflicts.filter(c => !c.resolved);
    },
    
    /**
     * Resolve a single conflict
     */
    async resolveConflict(conflict) {
        const { type, local, remote } = conflict;
        
        // Strategy 1: Last-write-wins
        if (type === 'RUN') {
            const localTime = local.lastModified || 0;
            const remoteTime = remote.lastModified || 0;
            
            if (localTime > remoteTime) {
                console.log('[SyncManager] Conflict resolved: local wins (newer)');
                return { winner: 'local', data: local };
            } else {
                console.log('[SyncManager] Conflict resolved: remote wins (newer)');
                return { winner: 'remote', data: remote };
            }
        }
        
        // Strategy 2: Merge if possible
        if (type === 'RUN' && this.canMergeRuns(local, remote)) {
            const merged = this.mergeRuns(local, remote);
            console.log('[SyncManager] Conflict resolved: merged');
            return { winner: 'merged', data: merged };
        }
        
        // Strategy 3: Ask user (callback)
        if (this.callbacks.onConflict) {
            return await this.callbacks.onConflict(conflict);
        }
        
        // Default: local wins
        return { winner: 'local', data: local };
    },
    
    /**
     * Check if two runs can be merged
     */
    canMergeRuns(run1, run2) {
        // Check if they don't overlap in time
        const r1End = run1.startTime + run1.duration;
        const r2Start = run2.startTime;
        
        const r2End = run2.startTime + run2.duration;
        const r1Start = run1.startTime;
        
        // Non-overlapping if one ends before other starts
        return r1End < r2Start || r2End < r1Start;
    },
    
    /**
     * Merge two non-overlapping runs
     */
    mergeRuns(run1, run2) {
        // Sort by start time
        const [first, second] = run1.startTime < run2.startTime ? [run1, run2] : [run2, run1];
        
        return {
            id: Utils.generateId(), // New ID for merged run
            startTime: first.startTime,
            duration: (second.startTime + second.duration) - first.startTime,
            positions: [...first.positions, ...second.positions],
            totalDistance: first.totalDistance + second.totalDistance,
            totalDescent: first.totalDescent + second.totalDescent,
            maxSpeed: Math.max(first.maxSpeed, second.maxSpeed),
            mergedFrom: [run1.id, run2.id],
            lastModified: Date.now()
        };
    },
    
    /**
     * Apply conflict resolution
     */
    async applyResolution(conflict, resolution) {
        const { type } = conflict;
        
        if (resolution.winner === 'merged') {
            // Save merged version
            if (type === 'RUN') {
                await Storage.saveRun(resolution.data);
                // Delete original runs
                await Storage.deleteRun(conflict.local.id);
                await Storage.deleteRun(conflict.remote.id);
            }
        } else if (resolution.winner === 'local') {
            // Keep local, push to server
            await this.queueChange({
                type,
                action: 'UPDATE',
                data: conflict.local
            });
        } else {
            // Keep remote, save locally
            if (type === 'RUN') {
                await Storage.saveRun(conflict.remote);
            }
        }
        
        conflict.resolved = true;
    },
    
    /**
     * Queue a local change for sync
     */
    async queueChange(change) {
        this.state.pendingChanges.push({
            ...change,
            timestamp: Date.now(),
            retryCount: 0
        });
        
        await this.saveSyncState();
        
        // Trigger immediate sync if online
        if (navigator.onLine && !this.state.isSyncing) {
            this.sync();
        }
    },
    
    /**
     * Add a run to sync queue
     */
    async queueRun(run) {
        await this.queueChange({
            type: 'RUN',
            action: 'CREATE',
            data: run
        });
    },
    
    /**
     * Create batches from array
     */
    createBatches(array, size) {
        const batches = [];
        for (let i = 0; i < array.length; i += size) {
            batches.push(array.slice(i, i + size));
        }
        return batches;
    },
    
    /**
     * Get sync status
     */
    getStatus() {
        return {
            isSyncing: this.state.isSyncing,
            lastSync: this.state.lastSync,
            pendingChanges: this.state.pendingChanges.length,
            conflicts: this.state.conflicts.length,
            isOnline: navigator.onLine
        };
    },
    
    /**
     * Force sync
     */
    async forceSync() {
        return this.sync();
    },
    
    /**
     * Clear pending changes (dangerous!)
     */
    async clearPendingChanges() {
        this.state.pendingChanges = [];
        await this.saveSyncState();
    },
    
    /**
     * Set callbacks
     */
    onSyncStart(callback) {
        this.callbacks.onSyncStart = callback;
    },
    
    onSyncComplete(callback) {
        this.callbacks.onSyncComplete = callback;
    },
    
    onSyncError(callback) {
        this.callbacks.onSyncError = callback;
    },
    
    onConflict(callback) {
        this.callbacks.onConflict = callback;
    }
};

// Initialize
SyncManager.init();
