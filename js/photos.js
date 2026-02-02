/**
 * KitzSki Tracker - Photo Integration Module
 * 
 * Handles photo capture during tracking, geotagging, and display
 * Stores only metadata (not actual photos to save space)
 */

const Photos = {
    // Current run photos
    currentRunPhotos: [],
    
    // Maximum photos per run
    MAX_PHOTOS_PER_RUN: 20,
    
    // Maximum photo metadata size (100KB as per requirements)
    MAX_METADATA_SIZE: 100 * 1024,

    /**
     * Initialize photos module
     */
    init() {
        this.currentRunPhotos = [];
    },

    /**
     * Start a new run (clear current photos)
     */
    startRun() {
        this.currentRunPhotos = [];
    },

    /**
     * End run and return captured photos for storage
     * @returns {Array} Array of photo metadata
     */
    endRun() {
        const photos = [...this.currentRunPhotos];
        this.currentRunPhotos = [];
        return photos;
    },

    /**
     * Create file input for camera capture
     * @returns {HTMLInputElement} File input element
     */
    createCameraInput() {
        const input = document.createElement('input');
        input.type = 'file';
        input.accept = 'image/*';
        input.capture = 'environment'; // Use rear camera
        input.style.display = 'none';
        return input;
    },

    /**
     * Capture a photo with geotagging
     * @param {Object} position - Current GPS position
     * @returns {Promise<Object>} Photo metadata
     */
    async capturePhoto(position) {
        return new Promise((resolve, reject) => {
            // Check if we've reached the max photos limit
            if (this.currentRunPhotos.length >= this.MAX_PHOTOS_PER_RUN) {
                reject(new Error(`Maximum ${this.MAX_PHOTOS_PER_RUN} photos per run`));
                return;
            }

            const input = this.createCameraInput();
            
            input.addEventListener('change', async (e) => {
                if (!e.target.files || e.target.files.length === 0) {
                    reject(new Error('No photo captured'));
                    return;
                }

                const file = e.target.files[0];
                
                try {
                    const photoMeta = await this.processPhoto(file, position);
                    this.currentRunPhotos.push(photoMeta);
                    resolve(photoMeta);
                } catch (error) {
                    reject(error);
                }
            });

            // Handle cancel
            input.addEventListener('cancel', () => {
                reject(new Error('Photo capture cancelled'));
            });

            input.click();
        });
    },

    /**
     * Process captured photo and extract metadata
     * @param {File} file - Photo file
     * @param {Object} position - GPS position
     * @returns {Promise<Object>} Photo metadata
     */
    async processPhoto(file, position) {
        // Generate thumbnail and get dimensions
        const thumbnail = await this.createThumbnail(file);
        const dimensions = await this.getImageDimensions(file);
        
        return {
            id: Utils.generateId(),
            timestamp: Date.now(),
            position: {
                lat: position.latitude,
                lon: position.longitude,
                altitude: position.altitude
            },
            speed: position.speed || 0,
            fileName: file.name,
            fileSize: file.size,
            mimeType: file.type,
            width: dimensions.width,
            height: dimensions.height,
            thumbnail: thumbnail, // Base64 encoded thumbnail
            caption: '' // User can add caption later
        };
    },

    /**
     * Create thumbnail from photo
     * @param {File} file - Photo file
     * @param {number} maxSize - Maximum thumbnail dimension
     * @returns {Promise<string>} Base64 thumbnail
     */
    async createThumbnail(file, maxSize = 200) {
        return new Promise((resolve, reject) => {
            const img = new Image();
            const canvas = document.createElement('canvas');
            const ctx = canvas.getContext('2d');
            
            img.onload = () => {
                // Calculate thumbnail dimensions
                let { width, height } = img;
                if (width > height) {
                    if (width > maxSize) {
                        height *= maxSize / width;
                        width = maxSize;
                    }
                } else {
                    if (height > maxSize) {
                        width *= maxSize / height;
                        height = maxSize;
                    }
                }
                
                canvas.width = width;
                canvas.height = height;
                
                // Draw thumbnail
                ctx.fillStyle = '#000';
                ctx.fillRect(0, 0, width, height);
                ctx.drawImage(img, 0, 0, width, height);
                
                // Get base64 data (JPEG for smaller size)
                const thumbnail = canvas.toDataURL('image/jpeg', 0.7);
                resolve(thumbnail);
            };
            
            img.onerror = () => reject(new Error('Failed to load image'));
            
            const reader = new FileReader();
            reader.onload = (e) => {
                img.src = e.target.result;
            };
            reader.onerror = () => reject(new Error('Failed to read file'));
            reader.readAsDataURL(file);
        });
    },

    /**
     * Get image dimensions
     * @param {File} file - Image file
     * @returns {Promise<Object>} Width and height
     */
    async getImageDimensions(file) {
        return new Promise((resolve, reject) => {
            const img = new Image();
            
            img.onload = () => {
                resolve({
                    width: img.naturalWidth,
                    height: img.naturalHeight
                });
            };
            
            img.onerror = () => reject(new Error('Failed to load image'));
            
            const reader = new FileReader();
            reader.onload = (e) => {
                img.src = e.target.result;
            };
            reader.onerror = () => reject(new Error('Failed to read file'));
            reader.readAsDataURL(file);
        });
    },

    /**
     * Get current run photos
     * @returns {Array} Current photos
     */
    getCurrentPhotos() {
        return [...this.currentRunPhotos];
    },

    /**
     * Get photo count for current run
     * @returns {number} Number of photos
     */
    getPhotoCount() {
        return this.currentRunPhotos.length;
    },

    /**
     * Delete a photo from current run
     * @param {string} photoId - Photo ID
     */
    deletePhoto(photoId) {
        this.currentRunPhotos = this.currentRunPhotos.filter(p => p.id !== photoId);
    },

    /**
     * Update photo caption
     * @param {string} photoId - Photo ID
     * @param {string} caption - New caption
     */
    updateCaption(photoId, caption) {
        const photo = this.currentRunPhotos.find(p => p.id === photoId);
        if (photo) {
            photo.caption = caption;
        }
    },

    /**
     * Get estimated storage size for current photos
     * @returns {number} Size in bytes
     */
    getStorageSize() {
        return this.currentRunPhotos.reduce((total, photo) => {
            // Estimate: thumbnail base64 is roughly 4/3 of binary size
            const thumbnailSize = photo.thumbnail ? 
                Math.ceil(photo.thumbnail.length * 0.75) : 0;
            return total + thumbnailSize + JSON.stringify(photo).length;
        }, 0);
    },

    /**
     * Check if storage limit would be exceeded
     * @returns {boolean} True if over limit
     */
    isOverStorageLimit() {
        return this.getStorageSize() > this.MAX_METADATA_SIZE;
    },

    /**
     * Render photo strip for run detail view
     * @param {Array} photos - Array of photo metadata
     * @param {HTMLElement} container - Container element
     */
    renderPhotoStrip(photos, container) {
        container.innerHTML = '';
        
        if (!photos || photos.length === 0) {
            container.style.display = 'none';
            return;
        }
        
        container.style.display = 'flex';
        container.className = 'photo-strip';
        
        for (const photo of photos) {
            const photoEl = document.createElement('div');
            photoEl.className = 'photo-thumbnail';
            photoEl.innerHTML = `
                <img src="${photo.thumbnail}" alt="Ski photo" loading="lazy">
                ${photo.caption ? `<span class="photo-caption">${photo.caption}</span>` : ''}
            `;
            
            photoEl.addEventListener('click', () => {
                this.showPhotoModal(photo);
            });
            
            container.appendChild(photoEl);
        }
    },

    /**
     * Show photo modal with full details
     * @param {Object} photo - Photo metadata
     */
    showPhotoModal(photo) {
        // Remove existing modal
        const existing = document.querySelector('.photo-modal');
        if (existing) existing.remove();
        
        const modal = document.createElement('div');
        modal.className = 'photo-modal';
        modal.innerHTML = `
            <div class="photo-modal-backdrop"></div>
            <div class="photo-modal-content">
                <button class="photo-modal-close">&times;</button>
                <img src="${photo.thumbnail}" alt="Ski photo" class="photo-modal-image">
                <div class="photo-modal-info">
                    <div class="photo-meta">
                        <span>📍 ${photo.position.lat.toFixed(5)}, ${photo.position.lon.toFixed(5)}</span>
                        <span>⚡ ${Math.round(photo.speed)} km/h</span>
                        <span>📅 ${new Date(photo.timestamp).toLocaleString()}</span>
                    </div>
                    ${photo.caption ? `<p class="photo-caption-text">${photo.caption}</p>` : ''}
                </div>
            </div>
        `;
        
        modal.querySelector('.photo-modal-backdrop').addEventListener('click', () => {
            modal.remove();
        });
        
        modal.querySelector('.photo-modal-close').addEventListener('click', () => {
            modal.remove();
        });
        
        document.body.appendChild(modal);
    },

    /**
     * Group photos by date for album view
     * @param {Array} allRuns - All runs with photos
     * @returns {Object} Photos grouped by date
     */
    groupPhotosByDate(allRuns) {
        const groups = {};
        
        for (const run of allRuns) {
            if (!run.photos || run.photos.length === 0) continue;
            
            const date = new Date(run.startTime).toISOString().split('T')[0];
            if (!groups[date]) {
                groups[date] = {
                    date: date,
                    runs: 0,
                    photos: []
                };
            }
            
            groups[date].runs++;
            groups[date].photos.push(...run.photos.map(p => ({
                ...p,
                runId: run.id
            })));
        }
        
        // Sort by date descending
        return Object.values(groups).sort((a, b) => 
            new Date(b.date) - new Date(a.date)
        );
    },

    /**
     * Render album grid for a date group
     * @param {Object} group - Date group with photos
     * @param {HTMLElement} container - Container element
     */
    renderAlbumGrid(group, container) {
        container.innerHTML = '';
        
        const header = document.createElement('div');
        header.className = 'album-date-header';
        header.innerHTML = `
            <h3>${new Date(group.date).toLocaleDateString(undefined, { 
                weekday: 'long', 
                year: 'numeric', 
                month: 'long', 
                day: 'numeric' 
            })}</h3>
            <span>${group.photos.length} photos · ${group.runs} runs</span>
        `;
        container.appendChild(header);
        
        const grid = document.createElement('div');
        grid.className = 'album-grid';
        
        for (const photo of group.photos) {
            const photoEl = document.createElement('div');
            photoEl.className = 'album-photo';
            photoEl.innerHTML = `
                <img src="${photo.thumbnail}" alt="Ski photo" loading="lazy">
            `;
            photoEl.addEventListener('click', () => {
                this.showPhotoModal(photo);
            });
            grid.appendChild(photoEl);
        }
        
        container.appendChild(grid);
    }
};

// Make Photos available globally
window.Photos = Photos;
