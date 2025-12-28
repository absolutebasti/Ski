/**
 * Ski Resort Data
 */

const Resorts = {
    list: [
        {
            id: 'kitzbuehel',
            name: 'Kitzbühel',
            region: 'Austria',
            country: 'AT',
            center: [12.3913, 47.4491],
            zoom: 13,
            altitude: { min: 800, max: 2000 },
            stats: {
                slopes: 170,
                lifts: 57,
                kmPiste: 170,
                snowPark: true,
                nightSki: true
            },
            difficulty: { easy: 63, intermediate: 80, advanced: 27 },
            famous: 'Hahnenkamm Streif - World\'s most challenging downhill',
            website: 'https://www.kitzbuehel.com',
            trailsFile: '/assets/trails/kitzbuehel.geojson'
        },
        {
            id: 'stanton',
            name: 'St. Anton',
            region: 'Arlberg, Austria',
            country: 'AT',
            center: [10.2683, 47.1275],
            zoom: 13,
            altitude: { min: 1304, max: 2811 },
            stats: {
                slopes: 88,
                lifts: 34,
                kmPiste: 300,
                snowPark: true,
                nightSki: false
            },
            difficulty: { easy: 49, intermediate: 123, advanced: 51 },
            famous: 'Birthplace of alpine skiing, legendary off-piste',
            website: 'https://www.stantonamarlberg.com',
            trailsFile: '/assets/trails/stanton.geojson'
        },
        {
            id: 'zermatt',
            name: 'Zermatt',
            region: 'Valais, Switzerland',
            country: 'CH',
            center: [7.7491, 46.0207],
            zoom: 12,
            altitude: { min: 1620, max: 3883 },
            stats: {
                slopes: 145,
                lifts: 52,
                kmPiste: 360,
                snowPark: true,
                nightSki: false
            },
            difficulty: { easy: 78, intermediate: 199, advanced: 20 },
            famous: 'Matterhorn views, highest ski area in Alps',
            website: 'https://www.zermatt.ch',
            trailsFile: '/assets/trails/zermatt.geojson'
        },
        {
            id: 'chamonix',
            name: 'Chamonix',
            region: 'Haute-Savoie, France',
            country: 'FR',
            center: [6.8694, 45.9237],
            zoom: 12,
            altitude: { min: 1035, max: 3842 },
            stats: {
                slopes: 69,
                lifts: 47,
                kmPiste: 155,
                snowPark: true,
                nightSki: false
            },
            difficulty: { easy: 34, intermediate: 57, advanced: 40 },
            famous: 'Vallée Blanche - 20km legendary off-piste descent',
            website: 'https://www.chamonix.com',
            trailsFile: '/assets/trails/chamonix.geojson'
        },
        {
            id: 'verbier',
            name: 'Verbier',
            region: '4 Vallées, Switzerland',
            country: 'CH',
            center: [7.2283, 46.0963],
            zoom: 13,
            altitude: { min: 1500, max: 3330 },
            stats: {
                slopes: 89,
                lifts: 37,
                kmPiste: 410,
                snowPark: true,
                nightSki: false
            },
            difficulty: { easy: 77, intermediate: 172, advanced: 38 },
            famous: 'Freeride World Tour venue, expert terrain',
            website: 'https://www.verbier.ch',
            trailsFile: '/assets/trails/verbier.geojson'
        },
        {
            id: 'valthorens',
            name: 'Val Thorens',
            region: '3 Vallées, France',
            country: 'FR',
            center: [6.5800, 45.2980],
            zoom: 13,
            altitude: { min: 2300, max: 3230 },
            stats: {
                slopes: 78,
                lifts: 31,
                kmPiste: 150,
                snowPark: true,
                nightSki: true
            },
            difficulty: { easy: 35, intermediate: 74, advanced: 28 },
            famous: 'Europe\'s highest resort, guaranteed snow',
            website: 'https://www.valthorens.com',
            trailsFile: '/assets/trails/valthorens.geojson'
        },
        {
            id: 'cortina',
            name: 'Cortina d\'Ampezzo',
            region: 'Dolomites, Italy',
            country: 'IT',
            center: [12.1357, 46.5369],
            zoom: 13,
            altitude: { min: 1224, max: 2932 },
            stats: {
                slopes: 70,
                lifts: 38,
                kmPiste: 120,
                snowPark: true,
                nightSki: false
            },
            difficulty: { easy: 35, intermediate: 67, advanced: 18 },
            famous: '2026 Winter Olympics venue, stunning Dolomite scenery',
            website: 'https://www.cortina.dolomiti.com',
            trailsFile: '/assets/trails/cortina.geojson'
        },
        {
            id: 'laax',
            name: 'LAAX',
            region: 'Graubünden, Switzerland',
            country: 'CH',
            center: [9.2586, 46.8099],
            zoom: 13,
            altitude: { min: 1100, max: 3018 },
            stats: {
                slopes: 71,
                lifts: 28,
                kmPiste: 224,
                snowPark: true,
                nightSki: true
            },
            difficulty: { easy: 51, intermediate: 83, advanced: 23 },
            famous: 'Best freestyle resort in Europe, massive snowparks',
            website: 'https://www.laax.com',
            trailsFile: '/assets/trails/laax.geojson'
        }
    ],

    current: null,

    /**
     * Get all resorts
     */
    getAll() {
        return this.list;
    },

    /**
     * Get resort by ID
     */
    getById(id) {
        return this.list.find(r => r.id === id);
    },

    /**
     * Set current resort
     */
    setCurrent(id) {
        this.current = this.getById(id);
        if (this.current) {
            Storage.saveSetting('selectedResort', id);
        }
        return this.current;
    },

    /**
     * Get current resort
     */
    getCurrent() {
        return this.current;
    },

    /**
     * Load saved resort or default
     */
    async loadSaved() {
        const savedId = await Storage.getSetting('selectedResort', 'kitzbuehel');
        return this.setCurrent(savedId);
    },

    /**
     * Get flag emoji for country
     */
    getFlag(country) {
        const flags = {
            'AT': '🇦🇹',
            'CH': '🇨🇭',
            'FR': '🇫🇷',
            'IT': '🇮🇹',
            'DE': '🇩🇪'
        };
        return flags[country] || '🏔️';
    },

    /**
     * Format altitude range
     */
    formatAltitude(resort) {
        return `${resort.altitude.min}m - ${resort.altitude.max}m`;
    },

    /**
     * Get total km of pistes
     */
    getTotalKm(resort) {
        return resort.stats.kmPiste;
    }
};

window.Resorts = Resorts;

