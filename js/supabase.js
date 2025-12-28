/**
 * Ski Tracker - Supabase Integration
 */

const Supabase = {
    client: null,
    user: null,

    // Configuration - UPDATE THESE WITH YOUR SUPABASE CREDENTIALS
    CONFIG: {
        url: 'YOUR_SUPABASE_URL',        // e.g., https://xxxxx.supabase.co
        anonKey: 'YOUR_SUPABASE_ANON_KEY' // Found in Project Settings > API
    },

    /**
     * Initialize Supabase client
     */
    async init() {
        if (this.CONFIG.url === 'YOUR_SUPABASE_URL') {
            console.log('Supabase not configured - using local storage only');
            return false;
        }

        try {
            // Load Supabase client library
            if (!window.supabase) {
                await this.loadScript('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2');
            }

            this.client = window.supabase.createClient(
                this.CONFIG.url,
                this.CONFIG.anonKey
            );

            // Check for existing session
            const { data: { session } } = await this.client.auth.getSession();
            if (session) {
                this.user = session.user;
                console.log('Supabase: Logged in as', this.user.email);
            }

            console.log('Supabase initialized');
            return true;
        } catch (e) {
            console.error('Supabase init failed:', e);
            return false;
        }
    },

    /**
     * Load external script
     */
    loadScript(src) {
        return new Promise((resolve, reject) => {
            const script = document.createElement('script');
            script.src = src;
            script.onload = resolve;
            script.onerror = reject;
            document.head.appendChild(script);
        });
    },

    /**
     * Sign up with email
     */
    async signUp(email, password) {
        const { data, error } = await this.client.auth.signUp({
            email,
            password
        });
        if (error) throw error;
        return data;
    },

    /**
     * Sign in with email
     */
    async signIn(email, password) {
        const { data, error } = await this.client.auth.signInWithPassword({
            email,
            password
        });
        if (error) throw error;
        this.user = data.user;
        return data;
    },

    /**
     * Sign out
     */
    async signOut() {
        await this.client.auth.signOut();
        this.user = null;
    },

    /**
     * Save a run to Supabase
     */
    async saveRun(runData) {
        if (!this.client || !this.user) {
            console.log('Not logged in - saving locally only');
            return null;
        }

        const { data, error } = await this.client.from('runs').insert({
            user_id: this.user.id,
            start_time: runData.startTime,
            end_time: runData.endTime,
            duration: runData.duration,
            distance: runData.distance,
            max_speed: runData.maxSpeed,
            avg_speed: runData.avgSpeed,
            vertical_drop: runData.verticalDrop,
            start_altitude: runData.startAltitude,
            end_altitude: runData.endAltitude,
            resort: runData.resort || 'kitzbuehel',
            positions: runData.positions
        }).select().single();

        if (error) {
            console.error('Failed to save run:', error);
            return null;
        }

        console.log('Run saved to Supabase:', data.id);
        return data;
    },

    /**
     * Get all runs for current user
     */
    async getRuns() {
        if (!this.client || !this.user) return [];

        const { data, error } = await this.client
            .from('runs')
            .select('*')
            .eq('user_id', this.user.id)
            .order('start_time', { ascending: false });

        if (error) {
            console.error('Failed to get runs:', error);
            return [];
        }

        return data;
    },

    /**
     * Get personal records
     */
    async getRecords() {
        if (!this.client || !this.user) return null;

        const { data, error } = await this.client
            .from('runs')
            .select('max_speed, distance, vertical_drop')
            .eq('user_id', this.user.id);

        if (error) return null;

        return {
            maxSpeed: Math.max(...data.map(r => r.max_speed || 0)),
            maxDistance: Math.max(...data.map(r => r.distance || 0)),
            maxVertical: Math.max(...data.map(r => r.vertical_drop || 0)),
            totalRuns: data.length,
            totalDistance: data.reduce((sum, r) => sum + (r.distance || 0), 0),
            totalVertical: data.reduce((sum, r) => sum + (r.vertical_drop || 0), 0)
        };
    },

    /**
     * Get live slope status
     */
    async getSlopeStatus(resort = 'kitzbuehel') {
        if (!this.client) return null;

        const { data, error } = await this.client
            .from('slope_status')
            .select('*')
            .eq('resort', resort)
            .order('updated_at', { ascending: false })
            .limit(1)
            .single();

        if (error) return null;
        return data;
    },

    /**
     * Subscribe to real-time slope status updates
     */
    subscribeToSlopeStatus(resort, callback) {
        if (!this.client) return null;

        return this.client
            .channel('slope_status')
            .on('postgres_changes', 
                { event: '*', schema: 'public', table: 'slope_status', filter: `resort=eq.${resort}` },
                callback
            )
            .subscribe();
    },

    /**
     * Check if user is logged in
     */
    isLoggedIn() {
        return !!this.user;
    }
};

window.Supabase = Supabase;

