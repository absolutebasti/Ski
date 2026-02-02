/**
 * KitzSki Tracker - Audio Announcements Module
 * 
 * Provides spoken feedback during skiing using Web Speech API
 * - Speed announcements at milestones
 * - Achievement notifications
 * - Run summary at end
 */

const Audio = {
    // Speech synthesis
    synth: window.speechSynthesis,
    
    // Settings
    settings: {
        enabled: true,
        speedMilestones: [10, 20, 30, 40, 50, 60, 70, 80, 90, 100],
        announceAchievements: true,
        announceSummary: true,
        volume: 1.0,
        rate: 1.1,
        pitch: 1.0,
        lang: 'en-US'
    },
    
    // Track announced speeds to avoid repetition
    announcedSpeeds: new Set(),
    
    // Current run state
    currentRunMaxSpeed: 0,

    /**
     * Initialize audio module
     */
    init() {
        // Load settings from storage
        this.loadSettings();
        
        // Check if speech synthesis is available
        if (!this.synth) {
            console.warn('Speech synthesis not supported');
            this.settings.enabled = false;
            return;
        }
        
        console.log('Audio announcements initialized');
    },

    /**
     * Load settings from storage
     */
    async loadSettings() {
        try {
            const saved = await Storage.getSetting('audioSettings', null);
            if (saved) {
                this.settings = { ...this.settings, ...saved };
            }
        } catch (e) {
            console.log('No saved audio settings');
        }
    },

    /**
     * Save settings to storage
     */
    async saveSettings() {
        await Storage.saveSetting('audioSettings', this.settings);
    },

    /**
     * Start a new run
     */
    startRun() {
        this.announcedSpeeds.clear();
        this.currentRunMaxSpeed = 0;
    },

    /**
     * Check and announce speed if milestone reached
     * @param {number} speed - Current speed in km/h
     */
    checkSpeedAnnouncement(speed) {
        if (!this.settings.enabled || !this.synth) return;
        if (speed <= 0) return;

        // Round to nearest integer
        const roundedSpeed = Math.round(speed);

        // Track max speed
        if (roundedSpeed > this.currentRunMaxSpeed) {
            this.currentRunMaxSpeed = roundedSpeed;
        }

        // Check if we've hit a milestone
        for (const milestone of this.settings.speedMilestones) {
            if (roundedSpeed >= milestone && !this.announcedSpeeds.has(milestone)) {
                this.announcedSpeeds.add(milestone);
                this.announceSpeed(milestone);
                break; // Only announce one milestone at a time
            }
        }
    },

    /**
     * Announce current speed
     * @param {number} speed - Speed to announce
     */
    announceSpeed(speed) {
        if (!this.settings.enabled || !this.synth) return;
        
        const text = `${speed} kilometers per hour`;
        this.speak(text);
    },

    /**
     * Announce achievement unlock
     * @param {Object} achievement - Achievement object
     */
    announceAchievement(achievement) {
        if (!this.settings.enabled || !this.settings.announceAchievements || !this.synth) return;
        
        const text = `Achievement unlocked! ${achievement.name}. ${achievement.description}`;
        this.speak(text);
    },

    /**
     * Announce run summary
     * @param {Object} runData - Run data
     */
    announceRunSummary(runData) {
        if (!this.settings.enabled || !this.settings.announceSummary || !this.synth) return;
        
        const maxSpeed = Math.round(runData.maxSpeed);
        const distance = runData.distance.toFixed(1);
        const vertical = Math.round(runData.verticalDrop);
        
        let text = `Run complete! `;
        
        if (maxSpeed > 0) {
            text += `Top speed: ${maxSpeed} kilometers per hour. `;
        }
        
        if (distance > 0) {
            text += `Distance: ${distance} kilometers. `;
        }
        
        if (vertical > 0) {
            text += `Vertical drop: ${vertical} meters. `;
        }
        
        this.speak(text);
    },

    /**
     * Speak text using speech synthesis
     * @param {string} text - Text to speak
     */
    speak(text) {
        if (!this.synth) return;
        
        // Cancel any ongoing speech
        this.synth.cancel();
        
        const utterance = new SpeechSynthesisUtterance(text);
        utterance.rate = this.settings.rate;
        utterance.pitch = this.settings.pitch;
        utterance.volume = this.settings.volume;
        utterance.lang = this.settings.lang;
        
        // Try to find a good voice
        const voices = this.synth.getVoices();
        const preferredVoice = voices.find(v => 
            v.lang.startsWith('en') && (v.name.includes('Google') || v.name.includes('Samantha') || v.name.includes('Daniel'))
        ) || voices.find(v => v.lang.startsWith('en'));
        
        if (preferredVoice) {
            utterance.voice = preferredVoice;
        }
        
        this.synth.speak(utterance);
    },

    /**
     * Enable/disable audio
     * @param {boolean} enabled - Whether audio is enabled
     */
    setEnabled(enabled) {
        this.settings.enabled = enabled;
        this.saveSettings();
    },

    /**
     * Update settings
     * @param {Object} newSettings - New settings object
     */
    updateSettings(newSettings) {
        this.settings = { ...this.settings, ...newSettings };
        this.saveSettings();
    },

    /**
     * Get available voices
     * @returns {Array} Available voices
     */
    getVoices() {
        if (!this.synth) return [];
        return this.synth.getVoices();
    },

    /**
     * Test audio by speaking a test message
     */
    testAudio() {
        this.speak('Audio announcements are working. Enjoy your skiing!');
    },

    /**
     * Stop all speech
     */
    stop() {
        if (this.synth) {
            this.synth.cancel();
        }
    },

    /**
     * Check if speech synthesis is supported
     * @returns {boolean} True if supported
     */
    isSupported() {
        return 'speechSynthesis' in window;
    },

    /**
     * Create settings UI HTML
     * @returns {string} HTML string
     */
    getSettingsHTML() {
        return `
            <div class="audio-settings">
                <div class="setting-item">
                    <span>Enable Audio Announcements</span>
                    <label class="toggle">
                        <input type="checkbox" id="audioEnabled" ${this.settings.enabled ? 'checked' : ''}>
                        <span class="toggle-slider"></span>
                    </label>
                </div>
                <div class="setting-item">
                    <span>Announce Achievements</span>
                    <label class="toggle">
                        <input type="checkbox" id="audioAchievements" ${this.settings.announceAchievements ? 'checked' : ''}>
                        <span class="toggle-slider"></span>
                    </label>
                </div>
                <div class="setting-item">
                    <span>Announce Run Summary</span>
                    <label class="toggle">
                        <input type="checkbox" id="audioSummary" ${this.settings.announceSummary ? 'checked' : ''}>
                        <span class="toggle-slider"></span>
                    </label>
                </div>
                <button class="btn btn-secondary" id="testAudioBtn">Test Audio</button>
            </div>
        `;
    }
};

// Make Audio available globally
window.Audio = Audio;
