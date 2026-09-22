/**
 * Ski Tracker - Achievements System
 */

const Achievements = {
    // All available achievements
    list: [
        // Speed achievements
        {
            id: 'speed_30',
            name: 'Getting Started',
            description: 'Reach 30 km/h',
            icon: '🎿',
            category: 'speed',
            requirement: { type: 'maxSpeed', value: 30 },
            tier: 'bronze'
        },
        {
            id: 'speed_50',
            name: 'Picking Up Speed',
            description: 'Reach 50 km/h',
            icon: '💨',
            category: 'speed',
            requirement: { type: 'maxSpeed', value: 50 },
            tier: 'silver'
        },
        {
            id: 'speed_70',
            name: 'Speed Demon',
            description: 'Reach 70 km/h',
            icon: '⚡',
            category: 'speed',
            requirement: { type: 'maxSpeed', value: 70 },
            tier: 'gold'
        },
        {
            id: 'speed_90',
            name: 'Lightning Fast',
            description: 'Reach 90 km/h',
            icon: '🚀',
            category: 'speed',
            requirement: { type: 'maxSpeed', value: 90 },
            tier: 'platinum'
        },
        {
            id: 'speed_100',
            name: 'Centurion',
            description: 'Break 100 km/h',
            icon: '👑',
            category: 'speed',
            requirement: { type: 'maxSpeed', value: 100 },
            tier: 'legendary'
        },
        
        // Distance achievements (single run)
        {
            id: 'distance_1',
            name: 'First Kilometer',
            description: 'Ski 1 km in a single run',
            icon: '📍',
            category: 'distance',
            requirement: { type: 'distance', value: 1 },
            tier: 'bronze'
        },
        {
            id: 'distance_5',
            name: 'Explorer',
            description: 'Ski 5 km in a single run',
            icon: '🗺️',
            category: 'distance',
            requirement: { type: 'distance', value: 5 },
            tier: 'silver'
        },
        {
            id: 'distance_10',
            name: 'Marathon Skier',
            description: 'Ski 10 km in a single run',
            icon: '🏃',
            category: 'distance',
            requirement: { type: 'distance', value: 10 },
            tier: 'gold'
        },
        {
            id: 'distance_20',
            name: 'Ultra Runner',
            description: 'Ski 20 km in a single run',
            icon: '🦅',
            category: 'distance',
            requirement: { type: 'distance', value: 20 },
            tier: 'platinum'
        },
        
        // Vertical achievements (single run)
        {
            id: 'vertical_200',
            name: 'Descender',
            description: 'Drop 200m vertical in a run',
            icon: '⬇️',
            category: 'vertical',
            requirement: { type: 'verticalDrop', value: 200 },
            tier: 'bronze'
        },
        {
            id: 'vertical_500',
            name: 'Mountain Goat',
            description: 'Drop 500m vertical in a run',
            icon: '🐐',
            category: 'vertical',
            requirement: { type: 'verticalDrop', value: 500 },
            tier: 'silver'
        },
        {
            id: 'vertical_1000',
            name: 'Vertical Monster',
            description: 'Drop 1,000m vertical in a run',
            icon: '🏔️',
            category: 'vertical',
            requirement: { type: 'verticalDrop', value: 1000 },
            tier: 'gold'
        },
        {
            id: 'vertical_2000',
            name: 'Everest Descender',
            description: 'Drop 2,000m vertical in a run',
            icon: '🗻',
            category: 'vertical',
            requirement: { type: 'verticalDrop', value: 2000 },
            tier: 'platinum'
        },
        
        // Run count achievements
        {
            id: 'runs_1',
            name: 'First Tracks',
            description: 'Complete your first tracked run',
            icon: '⭐',
            category: 'runs',
            requirement: { type: 'totalRuns', value: 1 },
            tier: 'bronze'
        },
        {
            id: 'runs_5',
            name: 'Regular',
            description: 'Complete 5 runs',
            icon: '🎯',
            category: 'runs',
            requirement: { type: 'totalRuns', value: 5 },
            tier: 'bronze'
        },
        {
            id: 'runs_10',
            name: 'Dedicated',
            description: 'Complete 10 runs',
            icon: '💪',
            category: 'runs',
            requirement: { type: 'totalRuns', value: 10 },
            tier: 'silver'
        },
        {
            id: 'runs_25',
            name: 'Enthusiast',
            description: 'Complete 25 runs',
            icon: '🔥',
            category: 'runs',
            requirement: { type: 'totalRuns', value: 25 },
            tier: 'gold'
        },
        {
            id: 'runs_50',
            name: 'Ski Addict',
            description: 'Complete 50 runs',
            icon: '❄️',
            category: 'runs',
            requirement: { type: 'totalRuns', value: 50 },
            tier: 'platinum'
        },
        {
            id: 'runs_100',
            name: 'Legend',
            description: 'Complete 100 runs',
            icon: '🏆',
            category: 'runs',
            requirement: { type: 'totalRuns', value: 100 },
            tier: 'legendary'
        },
        
        // Total distance achievements
        {
            id: 'total_distance_10',
            name: 'Getting Miles',
            description: 'Ski 10 km total',
            icon: '🛤️',
            category: 'total',
            requirement: { type: 'totalDistance', value: 10 },
            tier: 'bronze'
        },
        {
            id: 'total_distance_50',
            name: 'Distance Warrior',
            description: 'Ski 50 km total',
            icon: '🌍',
            category: 'total',
            requirement: { type: 'totalDistance', value: 50 },
            tier: 'silver'
        },
        {
            id: 'total_distance_100',
            name: 'Century Club',
            description: 'Ski 100 km total',
            icon: '💯',
            category: 'total',
            requirement: { type: 'totalDistance', value: 100 },
            tier: 'gold'
        },
        
        // Total vertical achievements
        {
            id: 'total_vertical_5000',
            name: 'Altitude Junkie',
            description: 'Descend 5,000m total',
            icon: '📉',
            category: 'total',
            requirement: { type: 'totalVertical', value: 5000 },
            tier: 'silver'
        },
        {
            id: 'total_vertical_10000',
            name: 'Everest x1',
            description: 'Descend 10,000m total (height of Everest)',
            icon: '🏔️',
            category: 'total',
            requirement: { type: 'totalVertical', value: 10000 },
            tier: 'gold'
        },
        
        // Duration achievements
        {
            id: 'duration_30',
            name: 'Half Hour Hero',
            description: 'Ski for 30 minutes in one run',
            icon: '⏱️',
            category: 'time',
            requirement: { type: 'duration', value: 30 * 60 * 1000 },
            tier: 'bronze'
        },
        {
            id: 'duration_60',
            name: 'Hour Power',
            description: 'Ski for 1 hour in one run',
            icon: '⏰',
            category: 'time',
            requirement: { type: 'duration', value: 60 * 60 * 1000 },
            tier: 'silver'
        },
        {
            id: 'duration_120',
            name: 'Endurance King',
            description: 'Ski for 2 hours in one run',
            icon: '👑',
            category: 'time',
            requirement: { type: 'duration', value: 120 * 60 * 1000 },
            tier: 'gold'
        }
    ],
    
    // Unlocked achievements (loaded from storage)
    unlocked: {},
    
    /**
     * Initialize achievements
     */
    async init() {
        await this.loadUnlocked();
        console.log('Achievements loaded:', Object.keys(this.unlocked).length, 'unlocked');
    },
    
    /**
     * Load unlocked achievements from storage
     */
    async loadUnlocked() {
        try {
            const saved = await Storage.getSetting('achievements', {});
            this.unlocked = saved;
        } catch (e) {
            this.unlocked = {};
        }
    },
    
    /**
     * Save unlocked achievements
     */
    async saveUnlocked() {
        await Storage.saveSetting('achievements', this.unlocked);
    },
    
    /**
     * Check for new achievements after a run
     * @param {Object} runData - Data from the completed run
     * @returns {Array} Newly unlocked achievements
     */
    async checkAfterRun(runData) {
        const newlyUnlocked = [];
        
        // Get totals from all runs
        const allRuns = await Storage.getAllRuns();
        const totals = this.calculateTotals(allRuns);
        
        // Check each achievement
        for (const achievement of this.list) {
            // Skip if already unlocked
            if (this.unlocked[achievement.id]) continue;
            
            const { type, value } = achievement.requirement;
            let achieved = false;
            
            switch (type) {
                case 'maxSpeed':
                    achieved = runData.maxSpeed >= value;
                    break;
                case 'distance':
                    achieved = runData.distance >= value;
                    break;
                case 'verticalDrop':
                    achieved = runData.verticalDrop >= value;
                    break;
                case 'duration':
                    achieved = runData.duration >= value;
                    break;
                case 'totalRuns':
                    achieved = totals.runs >= value;
                    break;
                case 'totalDistance':
                    achieved = totals.distance >= value;
                    break;
                case 'totalVertical':
                    achieved = totals.vertical >= value;
                    break;
            }
            
            if (achieved) {
                this.unlocked[achievement.id] = {
                    unlockedAt: Date.now(),
                    runId: runData.id
                };
                newlyUnlocked.push(achievement);
            }
        }
        
        // Save if any new achievements
        if (newlyUnlocked.length > 0) {
            await this.saveUnlocked();
        }
        
        return newlyUnlocked;
    },
    
    /**
     * Calculate totals from all runs
     */
    calculateTotals(runs) {
        return {
            runs: runs.length,
            distance: runs.reduce((sum, r) => sum + (r.distance || 0), 0),
            vertical: runs.reduce((sum, r) => sum + (r.verticalDrop || 0), 0),
            duration: runs.reduce((sum, r) => sum + (r.duration || 0), 0)
        };
    },
    
    /**
     * Get all achievements with unlock status
     */
    getAll() {
        return this.list.map(a => ({
            ...a,
            isUnlocked: !!this.unlocked[a.id],
            unlockedAt: this.unlocked[a.id]?.unlockedAt
        }));
    },
    
    /**
     * Get achievements by category
     */
    getByCategory(category) {
        return this.getAll().filter(a => a.category === category);
    },
    
    /**
     * Get unlock progress
     */
    getProgress() {
        const total = this.list.length;
        const unlocked = Object.keys(this.unlocked).length;
        return {
            unlocked,
            total,
            percentage: Math.round((unlocked / total) * 100)
        };
    },
    
    /**
     * Get tier color
     */
    getTierColor(tier) {
        const colors = {
            bronze: '#cd7f32',
            silver: '#c0c0c0',
            gold: '#ffd700',
            platinum: '#e5e4e2',
            legendary: '#ff6b6b'
        };
        return colors[tier] || '#ffffff';
    }
};

window.Achievements = Achievements;

