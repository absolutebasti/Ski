/**
 * Ski Tracker - Configuration
 * 
 * ⚠️  UPDATE THESE VALUES WITH YOUR CREDENTIALS  ⚠️
 */

const Config = {
    // Mapbox API Token - Get yours at: https://mapbox.com
    // For production, set in .env file (see .env.example)
    MAPBOX_TOKEN: 'YOUR_MAPBOX_TOKEN_HERE',
    
    // Supabase - Get these from: Supabase Dashboard > Settings > API
    // The anon key is safe to expose publicly (security is via Row Level Security)
    // For production, set in .env file (see .env.example)
    SUPABASE_URL: 'YOUR_SUPABASE_URL_HERE',
    SUPABASE_ANON_KEY: 'YOUR_SUPABASE_ANON_KEY_HERE',
    
    // App Settings
    APP_NAME: 'Ski Tracker',
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
     * HIGH-008: Handle missing .env file gracefully in production
     */
    async init() {
        // Try to load from .env for local dev (won't work in production, that's ok)
        try {
            const response = await fetch('/.env');
            if (response.ok) {
                const text = await response.text();
                this.parseEnv(text);
                Logger.debug('Config loaded from .env file');
            } else if (response.status === 404) {
                // Expected in production - .env file not served
                Logger.debug('Using bundled config (.env not found - expected in production)');
            }
        } catch (e) {
            // Using bundled config - this is expected behavior in production
            Logger.debug('Using bundled config (fetch failed - expected in production)');
        }
        
        // Log config status (without exposing actual keys)
        if (this.hasMapbox()) {
            Logger.debug('Mapbox: configured');
        } else {
            Logger.warn('Mapbox: not configured - map features will be limited');
        }
        
        if (this.hasSupabase()) {
            Logger.debug('Supabase: configured');
        } else {
            Logger.debug('Supabase: not configured - using local storage only');
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

