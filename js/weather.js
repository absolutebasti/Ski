/**
 * KitzSki Tracker - Weather Integration
 * HIGH-018: Add Real-Time Weather Overlay
 * MEDIUM-001: Weather Integration
 * 
 * Provides weather data and overlay for ski resorts:
 * - Current conditions (temperature, wind, visibility)
 * - Snow radar overlay on map
 * - 3-hour forecast
 * - Weather-based safety alerts
 */

const WeatherService = {
    // Configuration
    API_BASE: 'https://api.open-meteo.com/v1',
    CACHE_DURATION: 10 * 60 * 1000, // 10 minutes
    
    // Cache
    cache: new Map(),
    
    /**
     * Initialize weather service
     */
    init() {
        console.log('[Weather] Service initialized');
    },
    
    /**
     * Get current weather for a location
     * @param {number} lat - Latitude
     * @param {number} lon - Longitude
     * @returns {Promise<Object>} Weather data
     */
    async getCurrentWeather(lat, lon) {
        const cacheKey = `${lat.toFixed(2)},${lon.toFixed(2)}-current`;
        
        // Check cache
        if (this.cache.has(cacheKey)) {
            const cached = this.cache.get(cacheKey);
            if (Date.now() - cached.timestamp < this.CACHE_DURATION) {
                return cached.data;
            }
        }
        
        try {
            const url = `${this.API_BASE}/forecast?latitude=${lat}&longitude=${lon}&current=temperature_2m,relative_humidity_2m,wind_speed_10m,wind_direction_10m,weather_code,visibility&timezone=auto`;
            
            const response = await fetch(url);
            if (!response.ok) throw new Error('Weather API error');
            
            const data = await response.json();
            const weather = this.parseCurrentWeather(data);
            
            // Cache result
            this.cache.set(cacheKey, {
                data: weather,
                timestamp: Date.now()
            });
            
            return weather;
        } catch (error) {
            console.error('[Weather] Failed to fetch current weather:', error);
            return null;
        }
    },
    
    /**
     * Get weather forecast
     * @param {number} lat - Latitude
     * @param {number} lon - Longitude
     * @param {number} hours - Hours to forecast (max 24)
     * @returns {Promise<Array>} Forecast data
     */
    async getForecast(lat, lon, hours = 6) {
        const cacheKey = `${lat.toFixed(2)},${lon.toFixed(2)}-forecast-${hours}`;
        
        // Check cache
        if (this.cache.has(cacheKey)) {
            const cached = this.cache.get(cacheKey);
            if (Date.now() - cached.timestamp < this.CACHE_DURATION) {
                return cached.data;
            }
        }
        
        try {
            const url = `${this.API_BASE}/forecast?latitude=${lat}&longitude=${lon}&hourly=temperature_2m,precipitation,weather_code,wind_speed_10m,snowfall&forecast_hours=${hours}&timezone=auto`;
            
            const response = await fetch(url);
            if (!response.ok) throw new Error('Weather API error');
            
            const data = await response.json();
            const forecast = this.parseForecast(data);
            
            // Cache result
            this.cache.set(cacheKey, {
                data: forecast,
                timestamp: Date.now()
            });
            
            return forecast;
        } catch (error) {
            console.error('[Weather] Failed to fetch forecast:', error);
            return null;
        }
    },
    
    /**
     * Parse current weather from API response
     * @param {Object} data - API response
     * @returns {Object} Parsed weather
     */
    parseCurrentWeather(data) {
        const current = data.current;
        
        return {
            temperature: current.temperature_2m,
            humidity: current.relative_humidity_2m,
            windSpeed: current.wind_speed_10m,
            windDirection: current.wind_direction_10m,
            visibility: current.visibility ? current.visibility / 1000 : null, // km
            condition: this.getWeatherCondition(current.weather_code),
            icon: this.getWeatherIcon(current.weather_code),
            timestamp: Date.now()
        };
    },
    
    /**
     * Parse forecast from API response
     * @param {Object} data - API response
     * @returns {Array} Parsed forecast
     */
    parseForecast(data) {
        const hourly = data.hourly;
        const forecast = [];
        
        for (let i = 0; i < hourly.time.length; i++) {
            forecast.push({
                time: new Date(hourly.time[i]),
                temperature: hourly.temperature_2m[i],
                precipitation: hourly.precipitation[i],
                snowfall: hourly.snowfall[i] || 0,
                windSpeed: hourly.wind_speed_10m[i],
                condition: this.getWeatherCondition(hourly.weather_code[i]),
                icon: this.getWeatherIcon(hourly.weather_code[i])
            });
        }
        
        return forecast;
    },
    
    /**
     * Get weather condition text from WMO code
     * @param {number} code - WMO weather code
     * @returns {string} Condition text
     */
    getWeatherCondition(code) {
        const conditions = {
            0: 'Clear sky',
            1: 'Mainly clear',
            2: 'Partly cloudy',
            3: 'Overcast',
            45: 'Foggy',
            48: 'Depositing rime fog',
            51: 'Light drizzle',
            53: 'Moderate drizzle',
            55: 'Dense drizzle',
            61: 'Slight rain',
            63: 'Moderate rain',
            65: 'Heavy rain',
            71: 'Slight snow',
            73: 'Moderate snow',
            75: 'Heavy snow',
            77: 'Snow grains',
            80: 'Slight rain showers',
            81: 'Moderate rain showers',
            82: 'Violent rain showers',
            85: 'Slight snow showers',
            86: 'Heavy snow showers',
            95: 'Thunderstorm',
            96: 'Thunderstorm with hail',
            99: 'Thunderstorm with heavy hail'
        };
        return conditions[code] || 'Unknown';
    },
    
    /**
     * Get weather icon from WMO code
     * @param {number} code - WMO weather code
     * @returns {string} Icon emoji
     */
    getWeatherIcon(code) {
        const icons = {
            0: '☀️',
            1: '🌤️',
            2: '⛅',
            3: '☁️',
            45: '🌫️',
            48: '🌫️',
            51: '🌦️',
            53: '🌧️',
            55: '🌧️',
            61: '🌧️',
            63: '🌧️',
            65: '🌧️',
            71: '🌨️',
            73: '🌨️',
            75: '❄️',
            77: '❄️',
            80: '🌦️',
            81: '🌧️',
            82: '⛈️',
            85: '🌨️',
            86: '❄️',
            95: '⛈️',
            96: '⛈️',
            99: '⛈️'
        };
        return icons[code] || '❓';
    },
    
    /**
     * Get wind direction as compass direction
     * @param {number} degrees - Wind direction in degrees
     * @returns {string} Compass direction
     */
    getWindDirection(degrees) {
        const directions = ['N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE', 'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'];
        const index = Math.round(degrees / 22.5) % 16;
        return directions[index];
    },
    
    /**
     * Format weather for display
     * @param {Object} weather - Weather data
     * @returns {string} Formatted string
     */
    formatWeather(weather) {
        if (!weather) return 'Weather unavailable';
        
        let text = `${weather.icon} ${weather.temperature}°C`;
        
        if (weather.windSpeed > 20) {
            text += ` ⚠️ ${this.getWindDirection(weather.windDirection)} ${weather.windSpeed}km/h`;
        } else if (weather.windSpeed > 10) {
            text += ` ${this.getWindDirection(weather.windDirection)} ${weather.windSpeed}km/h`;
        }
        
        return text;
    },
    
    /**
     * Check if conditions are safe for skiing
     * @param {Object} weather - Weather data
     * @returns {Object} Safety assessment
     */
    checkSafety(weather) {
        if (!weather) return { safe: true, warnings: [] };
        
        const warnings = [];
        
        if (weather.windSpeed > 50) {
            warnings.push({
                level: 'danger',
                message: 'Dangerous wind speeds - lifts may be closed'
            });
        } else if (weather.windSpeed > 30) {
            warnings.push({
                level: 'warning',
                message: 'Strong winds expected'
            });
        }
        
        if (weather.visibility && weather.visibility < 0.5) {
            warnings.push({
                level: 'danger',
                message: 'Very poor visibility - ski with caution'
            });
        } else if (weather.visibility && weather.visibility < 1) {
            warnings.push({
                level: 'warning',
                message: 'Reduced visibility'
            });
        }
        
        if (weather.condition.toLowerCase().includes('thunder')) {
            warnings.push({
                level: 'danger',
                message: 'Thunderstorm risk - seek shelter'
            });
        }
        
        return {
            safe: warnings.length === 0,
            warnings
        };
    },
    
    /**
     * Clear expired cache entries
     */
    clearExpiredCache() {
        const now = Date.now();
        for (const [key, entry] of this.cache.entries()) {
            if (now - entry.timestamp > this.CACHE_DURATION) {
                this.cache.delete(key);
            }
        }
    }
};

// Weather Overlay Manager for map integration
const WeatherOverlay = {
    map: null,
    activeLayer: null,
    
    /**
     * Initialize weather overlay
     * @param {Object} map - Mapbox map instance
     */
    init(map) {
        this.map = map;
        console.log('[WeatherOverlay] Initialized');
    },
    
    /**
     * Show weather widget on map
     * @param {number} lat - Latitude
     * @param {number} lon - Longitude
     */
    async showWeatherWidget(lat, lon) {
        const weather = await WeatherService.getCurrentWeather(lat, lon);
        
        if (!weather) return;
        
        // Remove existing widget
        this.hideWeatherWidget();
        
        // Create widget element
        const widget = document.createElement('div');
        widget.id = 'weather-widget';
        widget.className = 'weather-widget';
        widget.innerHTML = `
            <div class="weather-main">
                <span class="weather-icon">${weather.icon}</span>
                <span class="weather-temp">${weather.temperature}°C</span>
            </div>
            <div class="weather-details">
                <span>${weather.condition}</span>
                <span>Wind: ${WeatherService.getWindDirection(weather.windDirection)} ${weather.windSpeed}km/h</span>
            </div>
        `;
        
        // Add to map container
        const mapContainer = this.map.getContainer();
        mapContainer.appendChild(widget);
        
        // Check for safety warnings
        const safety = WeatherService.checkSafety(weather);
        if (!safety.safe) {
            this.showSafetyWarnings(safety.warnings);
        }
    },
    
    /**
     * Hide weather widget
     */
    hideWeatherWidget() {
        const existing = document.getElementById('weather-widget');
        if (existing) {
            existing.remove();
        }
    },
    
    /**
     * Show safety warnings
     * @param {Array} warnings - Warning objects
     */
    showSafetyWarnings(warnings) {
        warnings.forEach(warning => {
            // Use app's notification system if available
            if (window.App && window.App.showNotification) {
                window.App.showNotification(warning.message, warning.level);
            } else {
                console.warn('[Weather] Safety warning:', warning.message);
            }
        });
    },
    
    /**
     * Add snow radar overlay (placeholder for future implementation)
     * Would require weather radar tile API
     */
    async addSnowRadarOverlay() {
        // Placeholder for snow radar implementation
        // Would integrate with OpenWeatherMap or similar radar tiles
        console.log('[WeatherOverlay] Snow radar not yet implemented');
    }
};

// Make available globally
window.WeatherService = WeatherService;
window.WeatherOverlay = WeatherOverlay;
