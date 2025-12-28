/**
 * Ski Tracker - Backend Server
 * Serves static files + scrapes KitzSki slope status
 */

const express = require('express');
const cron = require('node-cron');
const cheerio = require('cheerio');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = process.env.PORT || 3000;

// Store scraped data
let slopeStatus = {
    lastUpdated: null,
    resort: 'kitzbuehel',
    source: 'https://www.kitzski.at/de/aktuelle-info/pistenstatus.html',
    slopes: [],
    lifts: [],
    summary: {
        slopesOpen: 0,
        slopesTotal: 0,
        liftsOpen: 0,
        liftsTotal: 0
    }
};

// Load cached data on startup
const CACHE_FILE = path.join(__dirname, 'data', 'slope-status.json');

function loadCachedStatus() {
    try {
        if (fs.existsSync(CACHE_FILE)) {
            const data = fs.readFileSync(CACHE_FILE, 'utf8');
            slopeStatus = JSON.parse(data);
            console.log('Loaded cached slope status from', slopeStatus.lastUpdated);
        }
    } catch (e) {
        console.log('No cached status found');
    }
}

function saveCachedStatus() {
    try {
        const dir = path.dirname(CACHE_FILE);
        if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir, { recursive: true });
        }
        fs.writeFileSync(CACHE_FILE, JSON.stringify(slopeStatus, null, 2));
        console.log('Saved slope status to cache');
    } catch (e) {
        console.error('Failed to save cache:', e.message);
    }
}

/**
 * Scrape KitzSki slope status
 */
async function scrapeKitzSki() {
    console.log('🎿 Scraping KitzSki slope status...');
    
    try {
        const response = await fetch('https://www.kitzski.at/de/aktuelle-info/pistenstatus.html', {
            headers: {
                'User-Agent': 'Mozilla/5.0 (compatible; SkiTracker/1.0)'
            }
        });
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
        }
        
        const html = await response.text();
        const $ = cheerio.load(html);
        
        const slopes = [];
        const lifts = [];
        
        // Parse slope/lift tables
        // KitzSki uses tables or lists for status - adapt selectors as needed
        $('table tr, .piste-item, .lift-item, [class*="status"]').each((i, el) => {
            const $el = $(el);
            const name = $el.find('td:first-child, .name, .title').text().trim();
            const statusText = $el.find('td:last-child, .status, [class*="open"], [class*="closed"]').text().trim().toLowerCase();
            const statusClass = $el.attr('class') || '';
            
            if (name && name.length > 2) {
                const isOpen = statusText.includes('offen') || 
                              statusText.includes('open') || 
                              statusClass.includes('open') ||
                              statusClass.includes('offen');
                
                const item = {
                    name: name,
                    status: isOpen ? 'open' : 'closed',
                    statusText: statusText || (isOpen ? 'Offen' : 'Geschlossen')
                };
                
                // Categorize as slope or lift based on name patterns
                if (name.toLowerCase().includes('bahn') || 
                    name.toLowerCase().includes('lift') ||
                    name.toLowerCase().includes('gondel')) {
                    lifts.push(item);
                } else {
                    slopes.push(item);
                }
            }
        });
        
        // Also try parsing any JSON data embedded in the page
        const scriptContent = $('script:contains("pistenstatus")').html() || '';
        
        // Update status
        slopeStatus = {
            lastUpdated: new Date().toISOString(),
            resort: 'kitzbuehel',
            source: 'https://www.kitzski.at/de/aktuelle-info/pistenstatus.html',
            slopes: slopes,
            lifts: lifts,
            summary: {
                slopesOpen: slopes.filter(s => s.status === 'open').length,
                slopesTotal: slopes.length,
                liftsOpen: lifts.filter(l => l.status === 'open').length,
                liftsTotal: lifts.length
            },
            scraped: true
        };
        
        // If we didn't find structured data, note that manual check is needed
        if (slopes.length === 0 && lifts.length === 0) {
            slopeStatus.note = 'Page structure may have changed. Visit kitzski.at for current status.';
            slopeStatus.scraped = false;
        }
        
        saveCachedStatus();
        console.log(`✅ Scraped: ${slopes.length} slopes, ${lifts.length} lifts`);
        
    } catch (error) {
        console.error('❌ Scrape failed:', error.message);
        slopeStatus.lastError = error.message;
        slopeStatus.lastErrorTime = new Date().toISOString();
    }
    
    return slopeStatus;
}

// API endpoint for slope status
app.get('/api/status', (req, res) => {
    res.json(slopeStatus);
});

app.get('/api/status/refresh', async (req, res) => {
    await scrapeKitzSki();
    res.json(slopeStatus);
});

// Serve static files
app.use(express.static(__dirname));

// SPA fallback
app.get('*', (req, res) => {
    res.sendFile(path.join(__dirname, 'index.html'));
});

// Schedule scraping at 8:30 AM every day (Europe/Vienna timezone)
// Cron format: minute hour day month weekday
cron.schedule('30 8 * * *', () => {
    console.log('⏰ Running scheduled scrape (8:30 AM)');
    scrapeKitzSki();
}, {
    timezone: 'Europe/Vienna'
});

// Also scrape at 6:00 AM and 12:00 PM for more updates
cron.schedule('0 6,12 * * *', () => {
    console.log('⏰ Running scheduled scrape');
    scrapeKitzSki();
}, {
    timezone: 'Europe/Vienna'
});

// Start server
app.listen(PORT, () => {
    console.log(`🚀 Ski Tracker server running on port ${PORT}`);
    loadCachedStatus();
    
    // Initial scrape on startup
    scrapeKitzSki();
});

