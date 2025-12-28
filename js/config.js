/**
 * KitzSki Tracker - Configuration
 * 
 * This file loads environment variables for the app.
 * In production (Vercel/Netlify), these are injected at build time.
 * For local development, edit the values below or use .env file.
 */

const Config = {
    // Mapbox API Token
    // Get your free token at: https://mapbox.com
    MAPBOX_TOKEN: '',
    
    // App Settings
    APP_NAME: 'KitzSki Tracker',
    VERSION: '1.0.0',
    
    // Default map center (Kitzbühel)
    DEFAULT_CENTER: [12.3913, 47.4491],
    DEFAULT_ZOOM: 13,
    
    // GPS Settings
    GPS_HIGH_ACCURACY: true,
    GPS_MAX_AGE: 1000,
    GPS_TIMEOUT: 10000,
    MIN_ACCURACY_METERS: 30,
    
    /**
     * Initialize config from environment
     * Attempts to load from .env file for local development
     */
    async init() {
        try {
            // Try to load .env file (local development)
            const response = await fetch('/.env');
            if (response.ok) {
                const text = await response.text();
                this.parseEnv(text);
            }
        } catch (e) {
            // .env not available, use defaults or injected values
            console.log('Using default configuration');
        }
        
        // Check for window-level config (for build-time injection)
        if (window.__ENV__) {
            Object.assign(this, window.__ENV__);
        }
        
        return this;
    },
    
    /**
     * Parse .env file content
     */
    parseEnv(content) {
        const lines = content.split('\n');
        for (const line of lines) {
            const trimmed = line.trim();
            // Skip comments and empty lines
            if (!trimmed || trimmed.startsWith('#')) continue;
            
            const [key, ...valueParts] = trimmed.split('=');
            const value = valueParts.join('=').trim();
            
            if (key && value) {
                this[key.trim()] = value;
            }
        }
    },
    
    /**
     * Check if Mapbox is configured
     */
    hasMapbox() {
        return this.MAPBOX_TOKEN && 
               this.MAPBOX_TOKEN.length > 10 && 
               !this.MAPBOX_TOKEN.includes('your_');
    }
};

// Make Config available globally
window.Config = Config;

