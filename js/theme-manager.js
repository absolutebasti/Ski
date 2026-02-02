/**
 * KitzSki Tracker - Theme Manager
 * MEDIUM-006: Dark Mode Toggle (Auto/System/Default)
 * 
 * Manages dark/light mode switching with system preference detection.
 */

const ThemeManager = {
    currentTheme: 'dark',
    STORAGE_KEY: 'ski-theme-preference',
    
    /**
     * Initialize theme manager
     */
    init() {
        // Check for saved preference
        const savedTheme = this.getSavedTheme();
        
        if (savedTheme) {
            this.setTheme(savedTheme);
        } else {
            // Check system preference
            if (window.matchMedia && window.matchMedia('(prefers-color-scheme: light)').matches) {
                this.setTheme('light');
            } else {
                this.setTheme('dark');
            }
        }
        
        // Listen for system theme changes
        if (window.matchMedia) {
            window.matchMedia('(prefers-color-scheme: light)').addEventListener('change', (e) => {
                // Only auto-switch if user hasn't set a preference
                if (!this.getSavedTheme()) {
                    this.setTheme(e.matches ? 'light' : 'dark');
                }
            });
        }
        
        console.log('[ThemeManager] Initialized with theme:', this.currentTheme);
    },
    
    /**
     * Set theme
     * @param {string} theme - 'dark', 'light', or 'auto'
     */
    setTheme(theme) {
        const root = document.documentElement;
        
        if (theme === 'auto') {
            // Use system preference
            const prefersLight = window.matchMedia && 
                window.matchMedia('(prefers-color-scheme: light)').matches;
            theme = prefersLight ? 'light' : 'dark';
        }
        
        this.currentTheme = theme;
        
        if (theme === 'light') {
            root.setAttribute('data-theme', 'light');
            document.body.classList.add('theme-light');
            document.body.classList.remove('theme-dark');
        } else {
            root.removeAttribute('data-theme');
            document.body.classList.add('theme-dark');
            document.body.classList.remove('theme-light');
        }
        
        // Update meta theme-color for mobile browsers
        const metaThemeColor = document.querySelector('meta[name="theme-color"]');
        if (metaThemeColor) {
            metaThemeColor.setAttribute('content', theme === 'light' ? '#f0f0f0' : '#0a0a1a');
        }
        
        // Emit theme change event
        window.dispatchEvent(new CustomEvent('themechange', { detail: { theme } }));
        
        return theme;
    },
    
    /**
     * Get current theme
     * @returns {string} Current theme name
     */
    getTheme() {
        return this.currentTheme;
    },
    
    /**
     * Toggle between dark and light
     * @returns {string} New theme
     */
    toggle() {
        const newTheme = this.currentTheme === 'dark' ? 'light' : 'dark';
        this.setTheme(newTheme);
        this.saveTheme(newTheme);
        return newTheme;
    },
    
    /**
     * Save theme preference
     * @param {string} theme - Theme to save
     */
    saveTheme(theme) {
        try {
            localStorage.setItem(this.STORAGE_KEY, theme);
        } catch (e) {
            console.warn('[ThemeManager] Could not save theme preference');
        }
    },
    
    /**
     * Get saved theme preference
     * @returns {string|null} Saved theme or null
     */
    getSavedTheme() {
        try {
            return localStorage.getItem(this.STORAGE_KEY);
        } catch (e) {
            return null;
        }
    },
    
    /**
     * Clear saved preference (use system default)
     */
    useSystemDefault() {
        try {
            localStorage.removeItem(this.STORAGE_KEY);
        } catch (e) {
            console.warn('[ThemeManager] Could not clear theme preference');
        }
        
        // Apply system preference
        if (window.matchMedia && window.matchMedia('(prefers-color-scheme: light)').matches) {
            this.setTheme('light');
        } else {
            this.setTheme('dark');
        }
    },
    
    /**
     * Create theme toggle button HTML
     * @returns {HTMLElement} Toggle button
     */
    createToggleButton() {
        const button = document.createElement('button');
        button.className = 'theme-toggle-btn';
        button.setAttribute('aria-label', 'Toggle theme');
        this.updateToggleButton(button);
        
        button.addEventListener('click', () => {
            const newTheme = this.toggle();
            this.updateToggleButton(button);
        });
        
        // Update button when theme changes externally
        window.addEventListener('themechange', () => {
            this.updateToggleButton(button);
        });
        
        return button;
    },
    
    /**
     * Update toggle button appearance
     * @param {HTMLElement} button - Toggle button
     */
    updateToggleButton(button) {
        const isDark = this.currentTheme === 'dark';
        button.innerHTML = isDark ? '🌙' : '☀️';
        button.title = isDark ? 'Switch to light mode' : 'Switch to dark mode';
    }
};

// CSS for light theme (add to styles.css)
const themeCSS = `
[data-theme="light"] {
    --bg-primary: #f5f5f5;
    --bg-secondary: #ffffff;
    --bg-tertiary: #e8e8e8;
    --text-primary: #1a1a1a;
    --text-secondary: #4a4a4a;
    --text-tertiary: #6a6a6a;
    --border-color: #d0d0d0;
    --accent-color: #007AFF;
    --accent-secondary: #5856D6;
    --success-color: #34C759;
    --warning-color: #FF9500;
    --error-color: #FF3B30;
    --card-bg: #ffffff;
    --map-bg: #e5e5e5;
}

.theme-light {
    background-color: var(--bg-primary);
    color: var(--text-primary);
}

.theme-light .panel,
.theme-light .card,
.theme-light .modal-content {
    background-color: var(--card-bg);
    border-color: var(--border-color);
}

.theme-light .btn-secondary {
    background-color: var(--bg-tertiary);
    color: var(--text-primary);
}

.theme-toggle-btn {
    background: none;
    border: none;
    font-size: 24px;
    cursor: pointer;
    padding: 8px;
    border-radius: 50%;
    transition: transform 0.2s;
}

.theme-toggle-btn:hover {
    transform: scale(1.1);
}
`;

// Inject CSS
const styleSheet = document.createElement('style');
styleSheet.textContent = themeCSS;
document.head.appendChild(styleSheet);

// Initialize on DOM ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => ThemeManager.init());
} else {
    ThemeManager.init();
}

// Make available globally
window.ThemeManager = ThemeManager;
