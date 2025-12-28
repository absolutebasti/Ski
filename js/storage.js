/**
 * KitzSki Tracker - IndexedDB Storage Module
 */

const Storage = {
    DB_NAME: 'KitzSkiDB',
    DB_VERSION: 1,
    db: null,

    /**
     * Initialize the database
     * @returns {Promise} Database initialization promise
     */
    async init() {
        return new Promise((resolve, reject) => {
            const request = indexedDB.open(this.DB_NAME, this.DB_VERSION);

            request.onerror = () => {
                console.error('Failed to open database');
                reject(request.error);
            };

            request.onsuccess = () => {
                this.db = request.result;
                console.log('Database opened successfully');
                resolve(this.db);
            };

            request.onupgradeneeded = (event) => {
                const db = event.target.result;

                // Runs store
                if (!db.objectStoreNames.contains('runs')) {
                    const runsStore = db.createObjectStore('runs', { keyPath: 'id' });
                    runsStore.createIndex('date', 'startTime', { unique: false });
                    runsStore.createIndex('maxSpeed', 'maxSpeed', { unique: false });
                }

                // Settings store
                if (!db.objectStoreNames.contains('settings')) {
                    db.createObjectStore('settings', { keyPath: 'key' });
                }

                // Records store
                if (!db.objectStoreNames.contains('records')) {
                    db.createObjectStore('records', { keyPath: 'type' });
                }

                console.log('Database schema created');
            };
        });
    },

    /**
     * Save a run to the database
     * @param {Object} run - Run data object
     * @returns {Promise} Save promise
     */
    async saveRun(run) {
        return new Promise((resolve, reject) => {
            const transaction = this.db.transaction(['runs'], 'readwrite');
            const store = transaction.objectStore('runs');
            const request = store.put(run);

            request.onsuccess = () => {
                console.log('Run saved:', run.id);
                resolve(run);
            };

            request.onerror = () => {
                console.error('Failed to save run');
                reject(request.error);
            };
        });
    },

    /**
     * Get all runs from the database
     * @returns {Promise<Array>} Array of runs
     */
    async getAllRuns() {
        return new Promise((resolve, reject) => {
            const transaction = this.db.transaction(['runs'], 'readonly');
            const store = transaction.objectStore('runs');
            const index = store.index('date');
            const request = index.openCursor(null, 'prev'); // Newest first
            const runs = [];

            request.onsuccess = (event) => {
                const cursor = event.target.result;
                if (cursor) {
                    runs.push(cursor.value);
                    cursor.continue();
                } else {
                    resolve(runs);
                }
            };

            request.onerror = () => {
                reject(request.error);
            };
        });
    },

    /**
     * Get a specific run by ID
     * @param {string} id - Run ID
     * @returns {Promise<Object>} Run object
     */
    async getRun(id) {
        return new Promise((resolve, reject) => {
            const transaction = this.db.transaction(['runs'], 'readonly');
            const store = transaction.objectStore('runs');
            const request = store.get(id);

            request.onsuccess = () => {
                resolve(request.result);
            };

            request.onerror = () => {
                reject(request.error);
            };
        });
    },

    /**
     * Delete a run by ID
     * @param {string} id - Run ID
     * @returns {Promise} Delete promise
     */
    async deleteRun(id) {
        return new Promise((resolve, reject) => {
            const transaction = this.db.transaction(['runs'], 'readwrite');
            const store = transaction.objectStore('runs');
            const request = store.delete(id);

            request.onsuccess = () => {
                console.log('Run deleted:', id);
                resolve();
            };

            request.onerror = () => {
                reject(request.error);
            };
        });
    },

    /**
     * Save a setting
     * @param {string} key - Setting key
     * @param {any} value - Setting value
     * @returns {Promise} Save promise
     */
    async saveSetting(key, value) {
        return new Promise((resolve, reject) => {
            const transaction = this.db.transaction(['settings'], 'readwrite');
            const store = transaction.objectStore('settings');
            const request = store.put({ key, value });

            request.onsuccess = () => resolve();
            request.onerror = () => reject(request.error);
        });
    },

    /**
     * Get a setting
     * @param {string} key - Setting key
     * @param {any} defaultValue - Default value if not found
     * @returns {Promise<any>} Setting value
     */
    async getSetting(key, defaultValue = null) {
        return new Promise((resolve, reject) => {
            const transaction = this.db.transaction(['settings'], 'readonly');
            const store = transaction.objectStore('settings');
            const request = store.get(key);

            request.onsuccess = () => {
                resolve(request.result ? request.result.value : defaultValue);
            };

            request.onerror = () => {
                reject(request.error);
            };
        });
    },

    /**
     * Save a personal record
     * @param {string} type - Record type (speed, distance, vertical)
     * @param {number} value - Record value
     * @param {string} runId - Associated run ID
     * @returns {Promise} Save promise
     */
    async saveRecord(type, value, runId) {
        return new Promise((resolve, reject) => {
            const transaction = this.db.transaction(['records'], 'readwrite');
            const store = transaction.objectStore('records');
            const request = store.put({
                type,
                value,
                runId,
                date: new Date().toISOString()
            });

            request.onsuccess = () => resolve();
            request.onerror = () => reject(request.error);
        });
    },

    /**
     * Get all personal records
     * @returns {Promise<Object>} Records object
     */
    async getRecords() {
        return new Promise((resolve, reject) => {
            const transaction = this.db.transaction(['records'], 'readonly');
            const store = transaction.objectStore('records');
            const request = store.getAll();

            request.onsuccess = () => {
                const records = {};
                request.result.forEach(record => {
                    records[record.type] = record;
                });
                resolve(records);
            };

            request.onerror = () => {
                reject(request.error);
            };
        });
    },

    /**
     * Update records if new values are higher
     * @param {Object} runData - Run data to check
     * @returns {Promise<Object>} Updated records
     */
    async updateRecords(runData) {
        const currentRecords = await this.getRecords();
        const updates = [];

        // Check speed record
        if (!currentRecords.speed || runData.maxSpeed > currentRecords.speed.value) {
            updates.push(this.saveRecord('speed', runData.maxSpeed, runData.id));
        }

        // Check distance record
        if (!currentRecords.distance || runData.distance > currentRecords.distance.value) {
            updates.push(this.saveRecord('distance', runData.distance, runData.id));
        }

        // Check vertical record
        if (!currentRecords.vertical || runData.verticalDrop > currentRecords.vertical.value) {
            updates.push(this.saveRecord('vertical', runData.verticalDrop, runData.id));
        }

        await Promise.all(updates);
        return this.getRecords();
    },

    /**
     * Export all data as JSON
     * @returns {Promise<Object>} Exported data
     */
    async exportData() {
        const runs = await this.getAllRuns();
        const records = await this.getRecords();
        const settings = await this.getAllSettings();

        return {
            exportDate: new Date().toISOString(),
            version: this.DB_VERSION,
            runs,
            records,
            settings
        };
    },

    /**
     * Get all settings
     * @returns {Promise<Object>} All settings
     */
    async getAllSettings() {
        return new Promise((resolve, reject) => {
            const transaction = this.db.transaction(['settings'], 'readonly');
            const store = transaction.objectStore('settings');
            const request = store.getAll();

            request.onsuccess = () => {
                const settings = {};
                request.result.forEach(item => {
                    settings[item.key] = item.value;
                });
                resolve(settings);
            };

            request.onerror = () => reject(request.error);
        });
    },

    /**
     * Clear all data
     * @returns {Promise} Clear promise
     */
    async clearAllData() {
        const transaction = this.db.transaction(['runs', 'settings', 'records'], 'readwrite');
        
        await Promise.all([
            new Promise((resolve, reject) => {
                const request = transaction.objectStore('runs').clear();
                request.onsuccess = () => resolve();
                request.onerror = () => reject(request.error);
            }),
            new Promise((resolve, reject) => {
                const request = transaction.objectStore('records').clear();
                request.onsuccess = () => resolve();
                request.onerror = () => reject(request.error);
            })
        ]);

        console.log('All data cleared');
    },

    /**
     * Get run count
     * @returns {Promise<number>} Number of runs
     */
    async getRunCount() {
        return new Promise((resolve, reject) => {
            const transaction = this.db.transaction(['runs'], 'readonly');
            const store = transaction.objectStore('runs');
            const request = store.count();

            request.onsuccess = () => resolve(request.result);
            request.onerror = () => reject(request.error);
        });
    }
};

// Make Storage available globally
window.Storage = Storage;

