/**
 * KitzSki Tracker - Configuration
 */

const Config = {
    // Mapbox API Token - Set your token here for production
    // Get your free token at: https://mapbox.com
    MAPBOX_TOKEN: 'pk.eyJ1IjoiYWJzb2x1dGViYXN0aSIsImEiOiJjbWpxMm15enkxb3JkM2VxeXdydmlwMnB6In0.q8VWl_-0LW2B3MTUDhf8hA',
    
    // App Settings
    APP_NAME: 'KitzSki',
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
     * Initialize config
     */
    async init() {
        // Try to load from .env for local dev (won't work on Vercel, that's ok)
        try {
            const response = await fetch('/.env');
            if (response.ok) {
                const text = await response.text();
                this.parseEnv(text);
            }
        } catch (e) {
            // Using bundled config
        }
        return this;
    },
    
    parseEnv(content) {
        content.split('\n').forEach(line => {
            const trimmed = line.trim();
            if (!trimmed || trimmed.startsWith('#')) return;
            const [key, ...val] = trimmed.split('=');
            if (key && val.length) {
                this[key.trim()] = val.join('=').trim();
            }
        });
    },
    
    hasMapbox() {
        return this.MAPBOX_TOKEN && 
               this.MAPBOX_TOKEN.length > 20 && 
               !this.MAPBOX_TOKEN.includes('your_');
    }
};

window.Config = Config;

