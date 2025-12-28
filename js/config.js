/**
 * Ski Tracker - Configuration
 * 
 * ⚠️  UPDATE THESE VALUES WITH YOUR CREDENTIALS  ⚠️
 */

const Config = {
    // Mapbox API Token - Get yours at: https://mapbox.com
    MAPBOX_TOKEN: 'pk.eyJ1IjoiYWJzb2x1dGViYXN0aSIsImEiOiJjbWpxMm15enkxb3JkM2VxeXdydmlwMnB6In0.q8VWl_-0LW2B3MTUDhf8hA',
    
    // Supabase - Get these from: Supabase Dashboard > Settings > API
    // The anon key is safe to expose publicly (security is via Row Level Security)
    SUPABASE_URL: 'https://aknbxzkewrbwsaxfhalz.supabase.co',
    SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFrbmJ4emtld3Jid3NheGZoYWx6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjY5NDQ0MzYsImV4cCI6MjA4MjUyMDQzNn0.e_4D6FTQ_YKAMjaob3gP6lYFQPLUXxJe5Np73jl-DHU'
    
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

