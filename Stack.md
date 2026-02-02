# 🎿 Task Stack - Ski Project

> **Last Updated:** 2026-02-01  
> **System:** Multi-Agent Async Development  
> **Status:** Active Review Phase

---

## 🔴 CRITICAL - Immediate Action Required

### ✅ [CRITICAL-001] GPS Kalman Filtering Implementation - COMPLETED
**Type:** Core Algorithm  
**Impact:** Data Quality  
**From:** Code Review - gps-tracker.js

**Status:** ✅ COMPLETED by Ski Developer v3  
**Commit:** `27a28bc`  
**Completed:** 2026-02-01

**Problem:**
Current GPS smoothing uses simple moving average (`getSmoothedSpeed()`). This is insufficient for alpine environments where GPS multipath errors are common (reflections from snow, mountains).

**Solution Implemented:**
```javascript
// KalmanFilter class for 1D data (altitude, speed)
// KalmanFilter2D class for position with velocity tracking
// Adaptive noise filtering based on GPS accuracy
```

**Changes:**
- ✅ Position smoothing using 2D Kalman filter (lat/lon with velocity)
- ✅ Speed fusion: Kalman velocity + GPS speed + calculated speed
- ✅ Altitude smoothing: Kalman filter + median filter
- ✅ Reduced minAccuracy from 50m to 20m
- ✅ Reduced minSpeedThreshold from 3 to 1 km/h
- ✅ Added filterStats to tracking data

**Acceptance Criteria:**
- [x] Speed fluctuations reduced through adaptive Kalman filtering
- [x] Altitude readings stable within 5m using Kalman + median filter
- [x] Position jitter eliminated at low speeds with 2D Kalman filter

**References:**
- Adaptive Kalman Filtering for GPS/INS Integration
- https://github.com/wouterbulten/kalmanjs

---

### ✅ [CRITICAL-002] Service Worker Missing - PWA Not Installable - COMPLETED
**Type:** PWA Infrastructure  
**Impact:** Core Functionality  
**From:** Code Review

**Status:** ✅ COMPLETED by Ski Developer v3  
**Commit:** `91f9039`  
**Completed:** 2026-02-01

**Problem:**
`sw.js` exists but is empty (0 bytes). The app registers it in app.js:1067 but there's no caching strategy.

**Solution Implemented:**
```javascript
// sw.js now includes:
1. ✅ Precache: index.html, css/, js/, manifest.json
2. ✅ Runtime cache for map tiles (Mapbox CDN) with stale-while-revalidate
3. ✅ Background sync for pending runs and API requests
4. ✅ Offline fallback page (offline.html)
5. ✅ Separate caches for static assets and tiles
6. ✅ Message passing between SW and app for sync coordination
```

**Acceptance Criteria:**
- [x] Lighthouse PWA audit improvements (manifest updated, service worker enhanced)
- [x] App loads fully offline after first visit (offline.html fallback)
- [x] Map tiles cached for offline use (dedicated tile cache with stale-while-revalidate)
- [x] Runs saved offline sync when back online (queueRunForSync + background sync)

---

### ✅ [CRITICAL-003] Missing manifest.json - COMPLETED
**Type:** PWA Infrastructure  
**Impact:** Installability  
**From:** Code Review - index.html:16

**Status:** ✅ COMPLETED by Ski Developer v3 (included in commit `91f9039`)

**Problem:**
HTML references `manifest.json` but file didn't exist or was incomplete.

**Solution Implemented:**
Complete manifest.json with all PWA required fields:
- ✅ name, short_name, description
- ✅ start_url, display, scope
- ✅ background_color, theme_color, orientation
- ✅ icons (192x192, 512x512, maskable)
- ✅ categories: ["sports", "fitness", "navigation"]
- ✅ shortcuts (Start Tracking, View History)
- ✅ screenshots (wide and narrow form factors)

---

## 🟠 HIGH - Major Improvements

### ✅ [HIGH-001] Photo Integration - Ski Moments - COMPLETED
**Type:** Feature Parity (vs Slopes)  
**Impact:** User Engagement  
**From:** Competitor Analysis
**Status:** ✅ COMPLETED by Ski Developer Agent
**Commit:** `1422c64`

**Competitor Benchmark:**
- **Slopes:** Photo geotagging at max speed locations, automatic photo albums per run
- **Ski Tracks:** Manual photo waypoints
- **FATMAP:** Photo sharing to community feed

**Implementation:**
1. Add camera API access (`<input type="file" accept="image/*" capture="environment">`)
2. Geotag photos with current GPS position
3. Store photo metadata in IndexedDB (not actual photos - too large)
4. Display photo thumbnails on run detail map
5. Create "Ski Album" view by date

**UI Changes:**
- Add 📷 button during tracking
- Photo strip in run detail panel
- Grid view in history

**Acceptance Criteria:**
- [x] Take photo during tracking
- [x] Photo appears on run map at capture location
- [x] Photos exportable with run data
- [x] No significant storage bloat (<100KB metadata per photo)

---

### 🟡 [HIGH-002] GPX Export/Import
**Type:** Data Portability  
**Impact:** User Retention  
**From:** Competitor Analysis
**Status:** ✅ COMPLETED

**Completed:** Found fully implemented in `js/gpx.js` (267 lines)

**Features Implemented:**
- ✅ Export single run to GPX format with full metadata
- ✅ Export multiple runs as single GPX file
- ✅ Import GPX files from Strava, Komoot, Garmin Connect
- ✅ GPX 1.1 compliance with custom extensions for stats
- ✅ Automatic statistics calculation from imported tracks
- ✅ File validation before import
- ✅ Batch import support

**Acceptance Criteria:**
- [x] Export any run as .gpx file
- [x] Import GPX files (from other apps)
- [x] Import appears in history
- [x] Compatible with Strava, Komoot, Garmin Connect

---

### ✅ [HIGH-003] 3D Run Visualization - COMPLETED
**Type:** Feature Parity (vs FATMAP/Slopes)  
**Impact:** WOW Factor  
**From:** Competitor Analysis
**Status:** ✅ COMPLETED by Ski Developer Agent
**Commit:** `55f7b5d`

**Competitor Benchmark:**
- **Slopes:** Beautiful 3D flythrough replays (premium feature)
- **FATMAP:** Native 3D terrain with tracked route
- **Ski Tracks:** Basic 2D only

**Implementation:**
- ✅ Mapbox GL JS with 3D terrain exaggeration (1.5x)
- ✅ Animated camera following ski route
- ✅ Speed-based zoom and camera velocity
- ✅ Satellite imagery with route glow effect
- ✅ Play/pause/reset controls
- ✅ Progress bar showing replay progress

**Acceptance Criteria:**
- [x] 3D replay button in run detail
- [x] Smooth camera animation following route
- [x] Works on mobile (30fps minimum)

---

### [HIGH-004] Audio Announcements
**Type:** Accessibility/Safety  
**Impact:** User Experience  
**From:** Competitive Research

**Why It Matters:**
- Skiers can't look at phone while skiing
- Safety: knowing speed without looking down
- Motivation: "New top speed! 65 km/h!"

**Implementation:**
```javascript
const AudioFeedback = {
  announceSpeed(speed) {
    if (speed % 10 === 0 && speed > 0) {
      this.speak(`${speed} kilometers per hour`);
    }
  },
  
  announceAchievement(achievement) {
    this.speak(`Achievement unlocked! ${achievement.name}`);
  },
  
  speak(text) {
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.rate = 1.2;
    speechSynthesis.speak(utterance);
  }
};
```

**Settings:**
- Enable/disable announcements
- Announcement frequency (every X km/h or every X minutes)
- Volume control
- Language selection

**Acceptance Criteria:**
- [ ] Optional speed announcements every 10 km/h
- [ ] Achievement announcements
- [ ] Run summary announcement at end
- [ ] Works with phone locked (using Web Audio API with wake lock)

---

### [HIGH-005] Run Segments & Leaderboards
**Type:** Social/Gamification  
**Impact:** Viral Growth  
**From:** Competitor Analysis (Strava model)

**Concept:**
Create virtual "segments" on popular slopes:
- Hahnenkamm Streif section
- Various piste sections
- Users compete for KOM (King of Mountain) / QOM

**Technical Implementation:**
1. Define segment boundaries (start/end coordinates + radius)
2. Check if run passes through segment
3. Calculate time between segment boundaries
4. Store in Supabase with user ID
5. Show leaderboard

**Privacy:**
- Anonymous by default
- Opt-in for real name display
- Only show top 10 times

**Acceptance Criteria:**
- [ ] 10+ predefined segments for Kitzbühel
- [ ] Automatic segment detection during tracking
- [ ] Personal best tracking per segment
- [ ] Anonymous leaderboard (top 10)
- [ ] Segment appears on map with color coding

---

## 🟡 MEDIUM - Nice to Have

### [MEDIUM-001] Weather Integration
**Type:** Data Enrichment  
**Impact:** User Planning  
**From:** Feature Gap Analysis

**API Options:**
- OpenWeatherMap (free tier: 1000 calls/day)
- WeatherAPI.com
- Open-Meteo (free, no API key needed)

**UI Placement:**
- Header badge: "❄️ -2°C, Fresh snow"
- Tap for detailed forecast
- Weather overlay on map (snow radar)

**Acceptance Criteria:**
- [ ] Current conditions at resort
- [ ] 3-day forecast
- [ ] Snow depth data if available
- [ ] Weather icon in run detail ("Sunny day")

---

### [MEDIUM-002] Apple Watch Companion
**Type:** Platform Expansion  
**Impact:** Premium Feel  
**From:** Competitor Analysis

**Note:** Requires native app or WatchOS web capabilities (limited)

**MVP via watch connectivity:**
- Use iPhone as hub
- Simple complications showing current speed
- Start/stop from watch
- Haptic feedback for achievements

**Research Required:**
- WatchOS web app limitations
- Or: React Native port for native watch app

---

### [MEDIUM-003] Slope Angle Calculation
**Type:** Data Enrichment  
**Impact:** Safety/Information  
**From:** Technical Gap

**Calculation:**
```javascript
function calculateSlopeAngle(pos1, pos2) {
  const horizontalDist = calculateDistance(pos1.lat, pos1.lon, pos2.lat, pos2.lon);
  const verticalDist = Math.abs(pos1.alt - pos2.alt);
  return Math.atan2(verticalDist, horizontalDist) * (180 / Math.PI);
}
```

**Display:**
- Max slope angle per run
- Color-code track by steepness
- Warning for >30° (avalanche risk)

---

### [MEDIUM-004] Daily/Weekly/Season Stats
**Type:** Analytics  
**Impact:** User Retention  
**From:** UX Research

**Implementation:**
- Aggregation queries on IndexedDB
- Charts using Chart.js or custom canvas
- Stats cards:
  - "This season: 245 km skied"
  - "Most active day: Saturday"
  - "Favorite slope: Streif"

---

### [MEDIUM-005] Battery Optimization Audit
**Type:** Performance  
**Impact:** User Experience  
**From:** Code Review

**Current Issues:**
- GPS updates every 1s (configurable but not adaptive)
- No power-saving mode
- Screen wake lock always on during tracking
- Map re-renders on every position update

**Solutions:**
```javascript
// Adaptive GPS accuracy
const GPSModes = {
  HIGH: { enableHighAccuracy: true, interval: 1000 },   // When moving fast
  MEDIUM: { enableHighAccuracy: true, interval: 3000 }, // When moving slow
  LOW: { enableHighAccuracy: false, interval: 10000 }   // On lift / stopped
};

// Throttle map updates
mapUpdateThrottled: Utils.throttle(this.updateMap, 500)
```

---

## 🟢 LOW - Polish & Future

### [LOW-001] Social Sharing Cards
**Type:** Marketing  
**Impact:** Viral Growth  
**From:** UX Analysis

**Implementation:**
- Dynamic OG image generation (canvas → image)
- Share cards with run stats visualized
- Instagram story format (9:16)

### [LOW-002] Theme Customization
**Type:** Personalization  
**Impact:** Delight  
**From:** User Preference

**Options:**
- Dark/Light/Auto themes
- Accent color selection
- Custom stat card layouts

### [LOW-003] Resort Weather History
**Type:** Data  
**Impact:** Planning  
**From:** Feature Request

**Concept:**
- "Best time to ski" analytics
- Historical snow conditions
- Crowd predictions

### [LOW-004] Ski Pass Integration
**Type:** Hardware Integration  
**Impact:** Convenience  
**From:** Future Innovation

**Concept:**
- Read RFID ski pass data (if possible via NFC API)
- Auto-detect lift rides
- Correlate with tracked data

---

## 🟣 RESEARCH - Needs Investigation

### [RESEARCH-001] Scientific Paper Review: GPS Accuracy in Alpine
**Type:** Research  
**From:** Initial Planning

**Search Terms:**
- "GPS accuracy alpine skiing"
- "Kalman filter ski tracking"
- "Barometric altitude vs GPS altitude skiing"

**Deliverable:**
Document in `/research/gps-research.md`

### [RESEARCH-002] Battery Life Benchmark Study
**Type:** Research  
**From:** Performance Analysis

**Compare with:**
- Slopes app battery usage
- Ski Tracks battery usage
- Our current implementation

**Test Scenarios:**
- 4-hour ski day with continuous tracking
- Measure battery drain (% per hour)
- Different GPS accuracy settings

### [RESEARCH-003] Accessibility Audit
**Type:** Compliance  
**From:** Code Review

**Check:**
- WCAG 2.1 AA compliance
- Screen reader support
- Color contrast ratios
- Touch target sizes (currently OK at 44px+)

---

## ✅ Completed

### [SECURITY-001] Remove Exposed API Keys from config.js
**Type:** Security Fix  
**Completed:** 2026-02-01  
**Commit:** 3250935  
**Evaluated By:** Evaluator Agent

**Changes:**
- Removed hardcoded Mapbox token from `js/config.js`
- Removed hardcoded Supabase credentials from `js/config.js`
- Replaced with placeholder values (`YOUR_XXX_HERE`)
- Updated `.env.example` with proper template
- Verified `.gitignore` excludes `.env`

**Security Improvement:** 5/10 → 9/10

---

### [CORE-001] GPS Noise Filter Implementation
**Type:** Data Quality Fix  
**Completed:** 2025-12-28  
**Commit:** 4e96688  
**Evaluated By:** SKI EVALUATOR v3

**Changes:**
- Added `minSpeedThreshold: 3` km/h in `js/gps-tracker.js`
- Speeds below threshold now show as 0 (filters GPS drift)
- Distance only added when actually moving (>3m and speed >0)
- Updated in both `gps-tracker.js` and `stats.js`

**Evaluation:** ✅ GOOD
- Code syntax valid
- Logic correctly filters GPS noise when stationary
- Minimum movement threshold prevents false distance accumulation

**Quality Improvement:** Significant reduction in false readings

---

### [CORE-002] Vertical Drop Calculation Fix
**Type:** Core Algorithm Fix  
**Completed:** 2025-12-30  
**Commit:** 2254a80  
**Evaluated By:** SKI EVALUATOR v3

**Changes:**
- Changed from "highest-lowest" to CUMULATIVE descent calculation
- Added 5m threshold to filter GPS altitude noise
- Now properly tracks total meters descended across all runs
- Added `previousAltitude` tracking for change detection

**Evaluation:** ✅ GOOD
- Correctly implements cumulative vertical tracking
- 5m threshold appropriate for GPS altitude accuracy (~10-30m)
- Properly distinguishes descent from ascent (lifts)

**Before:** 2 runs of 500m each = 500m (wrong!)  
**After:** 2 runs of 500m each = 1000m (correct!)

---

### [UX-001] Disable Auto-Pause for Skiing
**Type:** UX Improvement  
**Completed:** 2025-12-29  
**Commit:** 7d177d5  
**Evaluated By:** SKI EVALUATOR v3

**Changes:**
- Removed aggressive auto-pause logic from `js/app.js`
- Manual pause only (better for skiing with frequent stops)
- Reduced from 56 lines to 8 lines (simplified)

**Evaluation:** ✅ GOOD
- Auto-pause was indeed too aggressive for real skiing
- Manual control better suits ski environment (lifts, queues, resting)
- Code simplification reduces maintenance burden

---

### [FEATURE-001] Run Detail View with Route Map
**Type:** Feature Implementation  
**Completed:** 2025-12-30  
**Commit:** 01c56fe  
**Evaluated By:** SKI EVALUATOR v3

**Changes:**
- Added `showRunDetail()` function in `js/app.js`
- Interactive map showing exact route (green line)
- Start (green) and end (red) markers
- Altitude profile chart using Canvas API
- Stats summary: max speed, distance, vertical, duration
- Delete button for individual runs

**Evaluation:** ✅ GOOD
- Code syntax valid
- Proper Mapbox integration for route visualization
- Altitude profile drawn with Canvas
- Click handlers properly attached to history items

**Note:** Corresponds to HIGH priority feature - Run Detail Visualization

---

### [FEATURE-002] Achievements System
**Type:** Feature Implementation  
**Completed:** 2025-12-30  
**Commit:** e09390f  
**Evaluated By:** SKI EVALUATOR v3

**Changes:**
- New file: `js/achievements.js` (416 lines)
- 27 achievements across 5 categories (speed, distance, vertical, runs, totals)
- Tier system: Bronze → Silver → Gold → Platinum → Legendary
- Trophy button in header to view achievements
- Progress circle showing % unlocked
- Category filtering
- Animated unlock toast with haptic feedback
- Persistent storage via IndexedDB

**Evaluation:** ✅ GOOD
- Well-structured achievement definitions
- Syntax valid (no errors)
- Comprehensive coverage of skiing milestones
- Good UI integration (CSS + HTML updates)

**Note:** Corresponds to gamification aspect of HIGH-005

---

### [INFRA-001] Bergfex Scraper Migration
**Type:** Infrastructure Fix  
**Completed:** 2025-12-30  
**Commit:** 258dfa6  
**Evaluated By:** SKI EVALUATOR v3

**Changes:**
- Migrated from KitzSki.at to Bergfex (server-rendered HTML)
- Updated `supabase/functions/scrape-slopes/index.ts`
- Now returns: 52/89 slopes open, 50/56 lifts open
- Includes breakdown by difficulty
- Famous slopes tracked (Streif, Hahnenkamm, Ganslern)

**Evaluation:** ✅ VERIFIED
- Code structure is correct
- Server-rendered HTML is more reliable than JS-loaded data
- **Test Results (2026-02-01):**
  - Successfully parsed Bergfex HTML
  - Slopes: 64/92 currently open
  - Lifts: 55/56 currently open
  - Regex patterns work correctly with actual HTML structure
- **Status:** Production ready

---

---

## 📊 Priority Matrix

| Priority | Count | Focus Area |
|----------|-------|------------|
| CRITICAL | 3 | Core functionality, PWA, GPS quality |
| HIGH | 5 | Feature parity, user retention |
| MEDIUM | 5 | Enhancements, polish |
| LOW | 4 | Nice-to-have, future |
| RESEARCH | 3 | Knowledge gathering |

**Total Tasks:** 25

---

## 🎯 Next Sprint Recommendations

### Sprint 1 (Week 1-2): Foundation
1. CRITICAL-002: Service Worker + PWA
2. CRITICAL-003: Manifest.json
3. HIGH-002: GPX Export

### Sprint 2 (Week 3-4): Data Quality
1. CRITICAL-001: Kalman Filtering
2. MEDIUM-005: Battery Optimization
3. HIGH-004: Audio Announcements

### Sprint 3 (Week 5-6): Feature Parity
1. HIGH-001: Photo Integration
2. HIGH-003: 3D Visualization (MVP)
3. MEDIUM-003: Slope Angle

### Sprint 4 (Week 7-8): Social
1. HIGH-005: Segments
2. MEDIUM-004: Stats Dashboard
3. LOW-001: Social Sharing

---

## 🆕 NEW TASKS - Cycle 1 (2026-02-02)

### [CRITICAL-004] Fix Potential Memory Leak in GPS Tracker
**Type:** Performance Bug  
**Impact:** Battery/Performance  
**From:** Code Review - gps-tracker.js:147-200

**Problem:**
The `positions` array grows unbounded during long tracking sessions. No maximum limit or circular buffer implementation.

```javascript
// Current code - no limit
this.positions.push(positionData); // Grows forever!
```

**Solution:**
Implement circular buffer or periodic flushing:
```javascript
// Option 1: Keep only last N positions in memory
if (this.positions.length > 10000) {
    this.positions = this.positions.slice(-5000); // Keep last 5000
}

// Option 2: Flush to IndexedDB every 1000 points
if (this.positions.length % 1000 === 0) {
    await Storage.saveTrackingProgress(this.runId, this.positions);
}
```

**Acceptance Criteria:**
- [ ] Memory usage stays stable during 4+ hour tracking sessions
- [ ] No positions are lost (flush to storage)
- [ ] Smooth performance on devices with 2GB RAM

---

### [CRITICAL-005] Missing Error Handling in Mapbox Initialization
**Type:** Stability Bug  
**Impact:** App Crash  
**From:** Code Review - map.js:45-90

**Problem:**
Map initialization has a try-catch but doesn't handle specific Mapbox errors gracefully. Invalid token or network issues cause silent failures or unhandled rejections.

**Issues Found:**
1. `map.on('error', reject)` rejects but error isn't caught
2. No fallback when Mapbox fails to load
3. Missing timeout for map load

**Solution:**
```javascript
init() {
    return new Promise((resolve, reject) => {
        const timeout = setTimeout(() => {
            reject(new Error('Map load timeout'));
        }, 10000);
        
        this.map.on('load', () => {
            clearTimeout(timeout);
            resolve();
        });
        
        this.map.on('error', (e) => {
            clearTimeout(timeout);
            console.error('[Map] Error:', e);
            this.showMapError();
            reject(e);
        });
    });
}
```

**Acceptance Criteria:**
- [ ] Graceful fallback when Mapbox fails
- [ ] User-friendly error message shown
- [ ] App continues working without map

---

### [HIGH-006] Implement Run Auto-Detection (Lift vs Ski)
**Type:** Feature Enhancement  
**Impact:** User Experience  
**From:** Competitor Analysis - Slopes has this

**Problem:**
Currently all tracking is one continuous session. Users must manually start/stop for each run. Competitors auto-detect when user is on lift vs skiing.

**Implementation:**
```javascript
const RunDetector = {
    detectActivityType(positions) {
        const recent = positions.slice(-10);
        const avgSpeed = recent.reduce((s, p) => s + p.speed, 0) / recent.length;
        const altitudeChange = recent[recent.length-1].alt - recent[0].alt;
        
        if (avgSpeed < 5 && altitudeChange > 10) {
            return 'lift'; // Going up slowly
        } else if (avgSpeed > 15 && altitudeChange < -5) {
            return 'skiing'; // Going down fast
        } else if (avgSpeed < 2) {
            return 'stopped';
        }
        return 'unknown';
    },
    
    autoSplitRuns(positions) {
        // Split into separate runs when lift ride detected
        // Each ski descent = one run
    }
};
```

**Acceptance Criteria:**
- [ ] Automatically detect lift rides
- [ ] Split tracking into separate runs
- [ ] Show "Run 1 of 5" indicator
- [ ] Manual override available

---

### [HIGH-007] Add Heart Rate Monitoring (Apple Watch/Bluetooth)
**Type:** Feature  
**Impact:** Fitness Tracking  
**From:** Competitor Analysis

**Problem:**
No heart rate data integration. Modern ski apps connect to heart rate monitors for fitness tracking.

**Implementation:**
```javascript
// Web Bluetooth API for HR monitors
const HRMService = {
    async connect() {
        const device = await navigator.bluetooth.requestDevice({
            filters: [{ services: ['heart_rate'] }]
        });
        const server = await device.gatt.connect();
        const service = await server.getPrimaryService('heart_rate');
        const characteristic = await service.getCharacteristic('heart_rate_measurement');
        
        characteristic.addEventListener('characteristicvaluechanged', (e) => {
            const heartRate = e.target.value.getUint8(1);
            this.onHeartRate(heartRate);
        });
        
        await characteristic.startNotifications();
    }
};
```

**Acceptance Criteria:**
- [ ] Connect to Bluetooth HR monitors
- [ ] Display current HR during tracking
- [ ] Show average/max HR per run
- [ ] Store HR data with run

---

### [MEDIUM-006] Dark Mode Toggle (Auto/System/Default)
**Type:** UX Enhancement  
**Impact:** Accessibility  
**From:** Code Review - styles.css only has dark theme

**Problem:**
App is hardcoded to dark mode only. No option for light mode or system preference following.

**Solution:**
```css
:root {
    --bg-primary: #0a0a1a;
    --text-primary: #ffffff;
}

[data-theme="light"] {
    --bg-primary: #f0f0f0;
    --text-primary: #1a1a1a;
}

@media (prefers-color-scheme: light) {
    :root:not([data-theme="dark"]) {
        --bg-primary: #f0f0f0;
    }
}
```

**Acceptance Criteria:**
- [ ] Light mode option in settings
- [ ] System preference detection
- [ ] Theme persists across sessions
- [ ] All elements properly themed

---

### [MEDIUM-007] Implement IndexedDB Cleanup/Archive Old Runs
**Type:** Data Management  
**Impact:** Performance/Storage  
**From:** Code Review - storage.js has no cleanup

**Problem:**
Runs are stored forever. No automatic archiving or cleanup. Could hit browser storage limits.

**Solution:**
```javascript
const StorageCleanup = {
    async archiveOldRuns(daysOld = 90) {
        const cutoff = Date.now() - (daysOld * 24 * 60 * 60 * 1000);
        const runs = await Storage.getAllRuns();
        
        const toArchive = runs.filter(r => r.date < cutoff);
        const toKeep = runs.filter(r => r.date >= cutoff);
        
        // Export old runs to JSON file
        const exportData = JSON.stringify(toArchive);
        await this.downloadBackup(exportData);
        
        // Keep only recent runs in IndexedDB
        await Storage.clearAllRuns();
        for (const run of toKeep) {
            await Storage.saveRun(run);
        }
    }
};
```

**Acceptance Criteria:**
- [ ] Auto-archive runs older than 90 days
- [ ] Export archived runs before deletion
- [ ] Settings to adjust retention period
- [ ] Warning when storage >80% full

---

### [LOW-005] Add Haptic Feedback for Key Actions
**Type:** UX Polish  
**Impact:** Native Feel  
**From:** Feature Request

**Implementation:**
```javascript
const Haptics = {
    startTracking() {
        if (navigator.vibrate) navigator.vibrate([50, 100, 50]);
    },
    achievementUnlocked() {
        if (navigator.vibrate) navigator.vibrate([100, 50, 100, 50, 200]);
    },
    buttonPress() {
        if (navigator.vibrate) navigator.vibrate(20);
    }
};
```

**Acceptance Criteria:**
- [ ] Haptic on tracking start/stop
- [ ] Celebration pattern on achievement
- [ ] Light feedback on button presses
- [ ] Respects system accessibility settings

---

### [RESEARCH-004] Investigate WebGL Performance on Mobile
**Type:** Research  
**Impact:** Performance  
**From:** 3D visualization feature

**Questions:**
1. What % of devices support WebGL 2.0?
2. Battery impact of continuous WebGL rendering?
3. Alternative: CSS 3D transforms vs WebGL?

**Deliverable:**
Performance benchmark document

---

## 📊 Updated Priority Matrix

| Priority | Count | New Tasks |
|----------|-------|-----------|
| CRITICAL | 5 | +2 (memory leak, map error handling) |
| HIGH | 7 | +2 (run detection, heart rate) |
| MEDIUM | 7 | +2 (theme toggle, cleanup) |
| LOW | 5 | +1 (haptics) |
| RESEARCH | 4 | +1 (WebGL performance) |

**Total Tasks:** 28 (+3 from review cycle)

---

## 🆕 NEW TASKS - Cycle 2 (2026-02-02)

### [CRITICAL-006] Add Input Validation for GPS Position Data
**Type:** Security/Stability  
**Impact:** Data Integrity  
**From:** Code Review - gps-tracker.js, stats.js

**Problem:**
No validation of GPS coordinates before processing. Malformed or spoofed GPS data could corrupt statistics or crash the app.

**Issues Found:**
1. No bounds checking on lat/lon (valid: -90 to 90, -180 to 180)
2. No sanity check on altitude changes (>1000m in 1 second is impossible)
3. No validation of speed values (>200 km/h is unrealistic for skiing)

**Solution:**
```javascript
const GPSValidator = {
    validatePosition(pos) {
        // Coordinate bounds
        if (pos.latitude < -90 || pos.latitude > 90) return false;
        if (pos.longitude < -180 || pos.longitude > 180) return false;
        
        // Altitude sanity (mountain range dependent)
        if (pos.altitude < -500 || pos.altitude > 5000) return false;
        
        // Speed sanity (world record ~250 km/h)
        if (pos.speed > 70) return false; // 70 m/s = 252 km/h
        
        // Accuracy check
        if (pos.accuracy > 100) return false; // Too inaccurate
        
        return true;
    }
};
```

**Acceptance Criteria:**
- [ ] Validate all incoming GPS coordinates
- [ ] Reject impossible values with logging
- [ ] Show user warning if GPS is malfunctioning
- [ ] Graceful handling of edge cases

---

### [CRITICAL-007] Implement Proper Error Boundaries
**Type:** Stability  
**Impact:** App Crash Prevention  
**From:** Code Review - app.js

**Problem:**
No global error handling. An unhandled exception in any module could crash the entire app during a tracking session, losing user data.

**Solution:**
```javascript
// Global error handler
window.addEventListener('error', (e) => {
    console.error('[Global Error]', e);
    ErrorTracker.report(e);
    
    // If tracking, emergency save
    if (App.state === 'tracking') {
        App.emergencySave();
        alert('An error occurred. Your progress has been saved.');
    }
});

window.addEventListener('unhandledrejection', (e) => {
    console.error('[Unhandled Promise]', e);
    ErrorTracker.report(e.reason);
});
```

**Acceptance Criteria:**
- [ ] Global error handler installed
- [ ] Errors logged to console and optionally server
- [ ] Emergency save triggered on tracking errors
- [ ] User-friendly error messages

---

### [HIGH-008] Add Internationalization (i18n) Support
**Type:** Feature  
**Impact:** Market Reach  
**From:** Feature Gap Analysis

**Problem:**
App is English-only. Ski market includes German, French, Italian speakers heavily.

**Target Languages:**
- German (Austria/Germany/Switzerland) - PRIORITY
- French (France/Switzerland/Canada)
- Italian (Italy)
- Spanish

**Implementation:**
```javascript
const i18n = {
    lang: localStorage.getItem('lang') || 'en',
    
    strings: {
        en: { startTracking: 'Start Tracking', speed: 'Speed' },
        de: { startTracking: 'Tracking Starten', speed: 'Geschwindigkeit' },
        fr: { startTracking: 'Démarrer', speed: 'Vitesse' }
    },
    
    t(key) {
        return this.strings[this.lang][key] || this.strings.en[key] || key;
    }
};
```

**Acceptance Criteria:**
- [ ] German translation complete
- [ ] Language switcher in settings
- [ ] Auto-detect from browser locale
- [ ] All user-facing strings externalized

---

### [HIGH-009] Implement Rate Limiting for API Calls
**Type:** Security/Performance  
**Impact:** Cost/Abuse Prevention  
**From:** Code Review - supabase.js

**Problem:**
No rate limiting on API calls. Could be abused or hit Supabase free tier limits.

**Solution:**
```javascript
const RateLimiter = {
    calls: {},
    
    checkLimit(key, maxCalls = 100, windowMs = 60000) {
        const now = Date.now();
        const windowStart = now - windowMs;
        
        if (!this.calls[key]) this.calls[key] = [];
        
        // Remove old calls
        this.calls[key] = this.calls[key].filter(t => t > windowStart);
        
        if (this.calls[key].length >= maxCalls) {
            return false; // Limit exceeded
        }
        
        this.calls[key].push(now);
        return true;
    }
};
```

**Acceptance Criteria:**
- [ ] Rate limit all Supabase calls
- [ ] Client-side caching to reduce calls
- [ ] Exponential backoff on errors
- [ ] Clear error messages when limited

---

### [MEDIUM-008] Add Accessibility (A11y) Audit
**Type:** Compliance  
**Impact:** Inclusivity  
**From:** Code Review - index.html

**Issues Found:**
1. Some buttons lack aria-labels
2. Color contrast may not meet WCAG AA
3. No skip navigation link
4. Alt text missing on icons

**Required Fixes:**
```html
<!-- Add to all interactive elements -->
<button aria-label="Start tracking your ski run">
    <span class="sr-only">Start Tracking</span>
</button>

<!-- Ensure 4.5:1 contrast ratio -->
<!-- Current: --text-secondary: #8e8e93 on #000 = 3.9:1 (FAIL) -->
<!-- Fix: --text-secondary: #a0a0a5 on #000 = 4.6:1 (PASS) -->
```

**Acceptance Criteria:**
- [ ] All interactive elements labeled
- [ ] WCAG 2.1 AA compliant contrast
- [ ] Keyboard navigation works
- [ ] Screen reader tested

---

### [MEDIUM-009] Optimize CSS Bundle Size
**Type:** Performance  
**Impact:** Load Time  
**From:** Code Review - styles.css (1666 lines)

**Problem:**
CSS is 1666+ lines, all in one file. No minification or unused style removal.

**Optimizations:**
1. Purge unused CSS (use PurgeCSS)
2. Split into critical/non-critical CSS
3. Minify for production
4. Use CSS custom properties more efficiently

**Acceptance Criteria:**
- [ ] CSS minified in production
- [ ] Critical CSS inlined
- [ ] Unused styles removed
- [ ] Target <20KB gzipped CSS

---

### [LOW-006] Add Pull-to-Refresh on History Panel
**Type:** UX Polish  
**Impact:** User Experience  
**From:** Feature Request

**Implementation:**
```javascript
// Add to history panel
element.addEventListener('touchstart', handleTouchStart);
element.addEventListener('touchmove', handleTouchMove);
element.addEventListener('touchend', handleTouchEnd);

// Show refresh indicator when pulled down >100px
// Refresh run list from storage
```

**Acceptance Criteria:**
- [ ] Pull gesture detected
- [ ] Visual refresh indicator
- [ ] Refreshes run list
- [ ] Works smoothly on mobile

---

### [RESEARCH-005] Evaluate WebAssembly for GPS Processing
**Type:** Research  
**Impact:** Performance  
**From:** Technical Investigation

**Question:**
Would moving Kalman filter calculations to WebAssembly improve performance/battery life?

**Investigation Points:**
1. Benchmark JS vs WASM Kalman filter
2. Memory overhead of WASM
3. Complexity vs benefit trade-off
4. Mobile device compatibility

**Deliverable:**
Benchmark report with recommendation

---

## 📊 Updated Priority Matrix

| Priority | Count | New Tasks |
|----------|-------|-----------|
| CRITICAL | 7 | +2 (input validation, error boundaries) |
| HIGH | 9 | +2 (i18n, rate limiting) |
| MEDIUM | 9 | +2 (a11y, CSS optimization) |
| LOW | 6 | +1 (pull-to-refresh) |
| RESEARCH | 5 | +1 (WASM evaluation) |

**Total Tasks:** 36 (+8 from review cycles)

---

## 🆕 NEW TASKS - Cycle 3 (2026-02-02)

### [CRITICAL-008] Implement CSRF Protection for Supabase Requests
**Type:** Security  
**Impact:** Data Protection  
**From:** Security Audit - supabase.js

**Problem:**
No CSRF tokens on state-changing requests. If user is authenticated, malicious sites could potentially make requests on their behalf.

**Solution:**
```javascript
// Add CSRF token to all mutating requests
const CSRF_TOKEN = generateSecureToken();

async function authenticatedRequest(url, method, data) {
    return fetch(url, {
        method,
        headers: {
            'X-CSRF-Token': CSRF_TOKEN,
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(data)
    });
}
```

**Acceptance Criteria:**
- [ ] CSRF tokens on all state-changing operations
- [ ] Tokens rotated periodically
- [ ] Validation on server side
- [ ] Graceful handling of token expiration

---

### [HIGH-010] Implement Multi-Resort Support
**Type:** Feature Expansion  
**Impact:** Market Growth  
**From:** Architecture Review

**Problem:**
App is hardcoded for Kitzbühel only. Cannot easily add other resorts.

**Implementation:**
```javascript
const ResortManager = {
    resorts: {
        kitzbuehel: {
            name: 'Kitzbühel',
            country: 'AT',
            center: [12.3913, 47.4491],
            trailsUrl: '/assets/trails/kitzbuehel.geojson',
            scraper: 'bergfex-kitzbuehel'
        },
        zellamsee: {
            name: 'Zell am See-Kaprun',
            country: 'AT',
            center: [12.7952, 47.2918],
            trailsUrl: '/assets/trails/zellamsee.geojson',
            scraper: 'bergfex-zellamsee'
        }
    },
    
    async switchResort(resortId) {
        const resort = this.resorts[resortId];
        // Load trails, update map, refresh status
    }
};
```

**Acceptance Criteria:**
- [ ] Dynamic resort loading
- [ ] Resort selector UI
- [ ] Resort-specific trail data
- [ ] 3+ resorts supported

---

### [HIGH-011] Implement Data Sync Conflict Resolution
**Type:** Data Integrity  
**Impact:** Reliability  
**From:** Code Review - storage.js

**Problem:**
If user uses app on multiple devices, there's no conflict resolution for overlapping run data.

**Solution:**
```javascript
const SyncManager = {
    async resolveConflict(localRun, serverRun) {
        // Last-write-wins with validation
        if (localRun.lastModified > serverRun.lastModified) {
            return localRun;
        }
        
        // Or: Merge if positions don't overlap
        if (!this.runsOverlap(localRun, serverRun)) {
            return this.mergeRuns(localRun, serverRun);
        }
        
        return serverRun;
    }
};
```

**Acceptance Criteria:**
- [ ] Conflict detection algorithm
- [ ] Merge strategy for non-overlapping runs
- [ ] User notification for conflicts
- [ ] Data integrity maintained

---

### [MEDIUM-010] Add Ski Conditions Reporting
**Type:** Feature  
**Impact:** Community Value  
**From:** Competitor Analysis

**Implementation:**
Allow users to report slope conditions:
- Snow quality (powder, packed, icy, slush)
- Crowd level (empty, moderate, busy)
- Visibility (clear, foggy, snowing)

```javascript
const ConditionsReporter = {
    async submitReport(slopeId, condition, notes) {
        const report = {
            slopeId,
            condition,
            notes,
            timestamp: Date.now(),
            reporter: await Auth.getUserId()
        };
        
        await Supabase.from('conditions').insert(report);
    }
};
```

**Acceptance Criteria:**
- [ ] Report submission UI
- [ ] Recent reports display on map
- [ ] Report aggregation ("3 users report icy conditions")
- [ ] Moderation system

---

### [MEDIUM-011] Implement Smart Battery Management
**Type:** Performance  
**Impact:** User Experience  
**From:** Code Review - Battery optimization needed

**Implementation:**
```javascript
const BatteryManager = {
    async adaptToBatteryLevel() {
        const battery = await navigator.getBattery();
        
        if (battery.level < 0.2) {
            // Low battery mode
            GPSTracker.setMode('low-power'); // 10s updates
            Map.setRenderQuality('low');
            Screen.dim();
        } else if (battery.level < 0.5) {
            // Medium mode
            GPSTracker.setMode('balanced'); // 5s updates
        } else {
            // Full performance
            GPSTracker.setMode('high-accuracy');
        }
    }
};
```

**Acceptance Criteria:**
- [ ] Battery-aware GPS updates
- [ ] Automatic mode switching
- [ ] User notification of mode changes
- [ ] Manual override available

---

### [LOW-007] Add Keyboard Shortcuts
**Type:** UX Enhancement  
**Impact:** Power Users  
**From:** Feature Request

**Shortcuts:**
- Space: Start/Stop tracking
- P: Pause/Resume
- H: Toggle history panel
- M: Center map on user
- Escape: Close panels

**Acceptance Criteria:**
- [ ] All shortcuts implemented
- [ ] Help modal showing shortcuts
- [ ] Works on desktop and mobile (external keyboards)

---

### [RESEARCH-006] Evaluate ML for Run Classification
**Type:** Research  
**Impact:** Automation  
**From:** Technical Innovation

**Question:**
Can we use machine learning to automatically classify skiing style (carving, moguls, powder) from GPS/accelerometer data?

**Investigation Points:**
1. Collect labeled training data
2. Feature extraction from GPS patterns
3. Model selection (TensorFlow.js?)
4. On-device vs cloud inference

**Deliverable:**
Feasibility report with prototype

---

## 📊 Updated Priority Matrix

| Priority | Count | New Tasks |
|----------|-------|-----------|
| CRITICAL | 8 | +1 (CSRF protection) |
| HIGH | 11 | +2 (multi-resort, conflict resolution) |
| MEDIUM | 11 | +2 (conditions reporting, battery management) |
| LOW | 7 | +1 (keyboard shortcuts) |
| RESEARCH | 6 | +1 (ML classification) |

**Total Tasks:** 43 (+7 from review cycles)

---

## 🆕 NEW TASKS - Cycle 4 (2026-02-02)

### [CRITICAL-009] Fix Console.log Statements in Production
**Type:** Performance/Security  
**Impact:** Production Quality  
**From:** Code Review - Multiple files have console.log

**Problem:**
Multiple `console.log` statements throughout codebase. These should be stripped or disabled in production for performance and to prevent information leakage.

**Files Affected:**
- app.js (30+ console statements)
- gps-tracker.js (15+ console statements)
- supabase.js (8+ console statements)
- storage.js (5+ console statements)
- map.js, achievements.js, utils.js, sw.js

**Solution:**
```javascript
// Create a logger that can be disabled in production
const Logger = {
    enabled: process.env.NODE_ENV !== 'production',
    
    log(...args) {
        if (this.enabled) console.log(...args);
    },
    
    error(...args) {
        // Always log errors, but could send to error tracking service
        console.error(...args);
        if (!this.enabled) {
            ErrorTracker.report(args[0]);
        }
    }
};
```

**Acceptance Criteria:**
- [ ] Replace all console.log with Logger.log
- [ ] Keep console.error for actual errors
- [ ] Logger disabled in production builds
- [ ] Optional: Send errors to Sentry/log service

---

### [HIGH-012] Implement Barometric Altimeter Support
**Type:** Data Quality  
**Impact:** Accuracy  
**From:** Technical Gap Analysis

**Problem:**
GPS altitude is inaccurate (~10-30m error). Modern phones have barometric altimeters that are much more precise (±1m).

**Implementation:**
```javascript
const Altimeter = {
    async init() {
        // Check for barometer API (iOS 15.0+, Android via sensors)
        if ('Barometer' in window) {
            this.barometer = new window.Barometer({ frequency: 1 });
            this.barometer.addEventListener('reading', (e) => {
                this.pressure = e.target.pressure; // hPa
                this.altitude = this.pressureToAltitude(this.pressure);
            });
            await this.barometer.start();
        }
    },
    
    pressureToAltitude(pressure, seaLevel = 1013.25) {
        // Hypsometric formula
        return 44330 * (1 - Math.pow(pressure / seaLevel, 0.1903));
    }
};
```

**Acceptance Criteria:**
- [ ] Detect barometric sensor availability
- [ ] Calibrate using GPS altitude initially
- [ ] Use barometer for relative altitude changes
- [ ] Fallback to GPS when barometer unavailable

---

### [MEDIUM-012] Add Run Comparison Feature
**Type:** Feature  
**Impact:** User Engagement  
**From:** Competitor Analysis (Strava has this)

**Implementation:**
Allow users to compare two runs side-by-side:
- Speed curves overlaid
- Altitude profiles compared
- Stats comparison table
- "Personal record" indicators

**Acceptance Criteria:**
- [ ] Select two runs to compare
- [ ] Overlay speed graphs
- [ ] Side-by-side stats table
- [ ] Highlight improvements/regressions

---

### [MEDIUM-013] Implement Progressive JPEG for Offline Maps
**Type:** Performance  
**Impact:** User Experience  
**From:** Technical Optimization

**Problem:**
Map tiles load all at once, causing jank on slow connections.

**Solution:**
Use progressive image loading or pre-render low-res versions.

**Acceptance Criteria:**
- [ ] Low-res placeholder while loading
- [ ] Smooth progressive enhancement
- [ ] Works with Mapbox tiles

---

### [LOW-008] Add Easter Eggs 🎉
**Type:** Delight  
**Impact:** User Happiness  
**From:** UX Enhancement

**Ideas:**
- Shake phone while tracking: "❄️ Snow globe mode activated!"
- Reach 100 km/h: Special achievement animation
- Ski on Christmas: Holiday-themed UI
- Secret achievement: "Midnight Skiing" (track between 00:00-01:00)

**Acceptance Criteria:**
- [ ] 3+ easter eggs implemented
- [ ] Don't interfere with normal usage
- [ ] Fun surprise moments

---

### [RESEARCH-007] Study Competitor Privacy Policies
**Type:** Compliance Research  
**Impact:** Legal  
**From:** GDPR/CCPA Compliance

**Research Questions:**
1. How do Slopes/Ski Tracks handle location data?
2. What data retention policies are standard?
3. What user rights are typically provided?
4. How to handle data export/deletion requests?

**Deliverable:**
Privacy policy template and data handling guidelines

---

## 📊 Updated Priority Matrix

| Priority | Count | New Tasks |
|----------|-------|-----------|
| CRITICAL | 9 | +1 (console.log cleanup) |
| HIGH | 12 | +1 (barometric altimeter) |
| MEDIUM | 13 | +2 (run comparison, progressive images) |
| LOW | 8 | +1 (easter eggs) |
| RESEARCH | 7 | +1 (privacy policies) |

**Total Tasks:** 49 (+6 from review cycles)

---

## 🆕 NEW TASKS - Cycle 5 (2026-02-02)

### [CRITICAL-010] Add Content Security Policy (CSP) Headers
**Type:** Security  
**Impact:** XSS Prevention  
**From:** Security Audit

**Problem:**
No CSP headers defined. App loads external scripts (Mapbox, Supabase) which could be compromised.

**Required CSP:**
```html
<meta http-equiv="Content-Security-Policy" content="
    default-src 'self';
    script-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net https://api.mapbox.com;
    style-src 'self' 'unsafe-inline' https://api.mapbox.com;
    connect-src 'self' https://*.supabase.co https://api.mapbox.com https://events.mapbox.com;
    img-src 'self' data: blob: https://*.mapbox.com;
    font-src 'self';
    worker-src 'self' blob:;
">
```

**Acceptance Criteria:**
- [ ] CSP meta tag added to index.html
- [ ] All external resources explicitly allowed
- [ ] 'unsafe-inline' minimized where possible
- [ ] Test with CSP evaluator

---

### [HIGH-013] Implement Analytics (Privacy-First)
**Type:** Data Insights  
**Impact:** Product Development  
**From:** Business Need

**Problem:**
No visibility into user behavior, feature usage, or app performance.

**Privacy-First Solution:**
```javascript
const Analytics = {
    // Self-hosted Plausible or similar
    // No cookies, no personal data, anonymized
    
    track(event, properties = {}) {
        fetch('/api/analytics', {
            method: 'POST',
            body: JSON.stringify({
                event,
                properties,
                timestamp: Date.now(),
                sessionId: this.getAnonymousSessionId()
            })
        }).catch(() => {}); // Silent fail
    }
};
```

**Events to Track:**
- Tracking started/stopped
- Run saved
- Achievement unlocked
- Feature usage (map, history, achievements)
- Export/import usage
- Errors

**Acceptance Criteria:**
- [ ] Privacy-first analytics (no cookies, anonymized)
- [ ] GDPR-compliant
- [ ] Track key user flows
- [ ] Performance metrics

---

### [MEDIUM-014] Add Unit Tests with Jest
**Type:** Quality Assurance  
**Impact:** Code Reliability  
**From:** Technical Debt

**Problem:**
No automated tests. Refactoring is risky.

**Priority Test Files:**
1. `utils.js` - Pure functions, easy to test
2. `stats.js` - Critical calculations
3. `gps-tracker.js` - GPS filtering logic
4. `gpx.js` - Import/export correctness

**Example:**
```javascript
// __tests__/utils.test.js
describe('Utils.calculateDistance', () => {
    test('calculates correct distance between two points', () => {
        const dist = Utils.calculateDistance(47.4491, 12.3913, 47.4580, 12.3650);
        expect(dist).toBeCloseTo(2100, 0); // ~2.1km
    });
});
```

**Acceptance Criteria:**
- [ ] Jest configured
- [ ] 50%+ coverage on utils.js
- [ ] Tests run in CI/CD
- [ ] Coverage badge in README

---

### [MEDIUM-015] Implement E2E Tests with Playwright
**Type:** Quality Assurance  
**Impact:** Regression Prevention  
**From:** Testing Gap

**Test Scenarios:**
1. User starts tracking, stops, views history
2. Export/import GPX roundtrip
3. Offline functionality
4. PWA installation flow

**Acceptance Criteria:**
- [ ] Playwright configured
- [ ] 5+ critical user flows tested
- [ ] Tests run on PRs
- [ ] Screenshots on failure

---

### [LOW-009] Add Custom App Icon Generator
**Type:** Tooling  
**Impact:** Developer Experience  
**From:** Maintenance

**Problem:**
Icons need to be manually generated for different sizes.

**Solution:**
```javascript
// scripts/generate-icons.js
const sharp = require('sharp');
const sizes = [72, 96, 128, 144, 152, 192, 384, 512];

async function generateIcons() {
    for (const size of sizes) {
        await sharp('assets/icon-source.svg')
            .resize(size, size)
            .png()
            .toFile(`assets/icons/icon-${size}.png`);
    }
}
```

**Acceptance Criteria:**
- [ ] Script generates all icon sizes
- [ ] Generates maskable icons
- [ ] Generates favicons
- [ ] Single source of truth

---

### [RESEARCH-008] Evaluate Server-Side Rendering (SSR)
**Type:** Architecture Research  
**Impact:** Performance/SEO  
**From:** Technical Exploration

**Research Questions:**
1. Would SSR improve first paint time?
2. Can we pre-render trail data?
3. Impact on PWA/offline capabilities?
4. Hosting implications (Vercel vs static)?

**Deliverable:**
Decision document with pros/cons

---

## 📊 Updated Priority Matrix

| Priority | Count | New Tasks |
|----------|-------|-----------|
| CRITICAL | 10 | +1 (CSP headers) |
| HIGH | 13 | +1 (analytics) |
| MEDIUM | 15 | +2 (unit tests, E2E tests) |
| LOW | 9 | +1 (icon generator) |
| RESEARCH | 8 | +1 (SSR evaluation) |

**Total Tasks:** 55 (+6 from review cycles)

---

## 🆕 NEW TASKS - Cycle 6 (2026-02-02)

### [CRITICAL-011] Fix Race Condition in Service Worker Activation
**Type:** Bug Fix  
**Impact:** Reliability  
**From:** Code Review - sw.js

**Problem:**
Service worker activation and caching may race with page load, causing inconsistent offline behavior.

**Solution:**
Ensure proper activation flow:
```javascript
// In sw.js
self.addEventListener('activate', (event) => {
    event.waitUntil(
        caches.keys().then((cacheNames) => {
            return Promise.all(
                cacheNames.map((cacheName) => {
                    if (cacheName !== CURRENT_CACHE) {
                        return caches.delete(cacheName);
                    }
                })
            );
        }).then(() => {
            // Claim clients immediately
            return self.clients.claim();
        })
    );
});
```

**Acceptance Criteria:**
- [ ] Service worker activates reliably
- [ ] No race conditions during update
- [ ] Clients claimed immediately
- [ ] Graceful fallback if SW fails

---

### [HIGH-014] Implement Deep Linking for Runs
**Type:** Feature  
**Impact:** Sharing  
**From:** UX Enhancement

**Problem:**
Cannot share a specific run via URL. User must navigate to it manually.

**Implementation:**
```javascript
// URL: /?run=abc123&view=detail
const urlParams = new URLSearchParams(window.location.search);
const runId = urlParams.get('run');
const view = urlParams.get('view');

if (runId && view === 'detail') {
    App.showRunDetail(runId);
}
```

**Acceptance Criteria:**
- [ ] URL parameter parsing
- [ ] Direct link to run detail
- [ ] Share button generates link
- [ ] Handles invalid run IDs gracefully

---

### [MEDIUM-016] Add Swipe Gestures for Navigation
**Type:** UX Enhancement  
**Impact:** Mobile Experience  
**From:** Mobile UX Best Practices

**Gestures:**
- Swipe left on history item: Delete
- Swipe right on history item: Quick export
- Swipe down: Pull to refresh
- Swipe left/right on panels: Close

**Acceptance Criteria:**
- [ ] Swipe to delete runs
- [ ] Swipe to close panels
- [ ] Visual feedback during swipe
- [ ] Prevents accidental triggers

---

### [MEDIUM-017] Implement Lazy Loading for Run History
**Type:** Performance  
**Impact:** App Load Time  
**From:** Code Review - History loads all runs at once

**Problem:**
All runs loaded at once, causing slow startup with many runs.

**Solution:**
```javascript
// Virtual scrolling or pagination
const HistoryLoader = {
    loadedCount: 0,
    batchSize: 20,
    
    async loadMore() {
        const runs = await Storage.getRunsPaged(this.loadedCount, this.batchSize);
        this.renderRuns(runs);
        this.loadedCount += runs.length;
    }
};
```

**Acceptance Criteria:**
- [ ] Initial load limited to 20 runs
- [ ] Load more on scroll
- [ ] Smooth scroll performance
- [ ] Search works across all runs

---

### [LOW-010] Add Season Statistics Dashboard
**Type:** Feature  
**Impact:** User Engagement  
**From:** Feature Request

**Visualizations:**
- Total km per month (bar chart)
- Speed progression over season
- Favorite slopes heatmap
- Days skied calendar

**Acceptance Criteria:**
- [ ] Monthly aggregation
- [ ] Speed trend chart
- [ ] Season comparison
- [ ] Export season summary

---

### [RESEARCH-009] Evaluate WebRTC for Group Tracking
**Type:** Research  
**Impact:** Social Feature  
**From:** Innovation

**Concept:**
Real-time location sharing with ski group (privacy-preserving).

**Questions:**
1. Can WebRTC work in ski area conditions?
2. Battery impact?
3. Privacy model (temporary sessions)?
4. Fallback to server relay?

**Deliverable:**
Feasibility study

---

## 📊 Updated Priority Matrix

| Priority | Count | New Tasks |
|----------|-------|-----------|
| CRITICAL | 11 | +1 (SW race condition) |
| HIGH | 14 | +1 (deep linking) |
| MEDIUM | 17 | +2 (swipe gestures, lazy loading) |
| LOW | 10 | +1 (season stats) |
| RESEARCH | 9 | +1 (WebRTC) |

**Total Tasks:** 61 (+6 from review cycles)

---

## 🆕 NEW TASKS - Cycle 7 (2026-02-02)

### [CRITICAL-012] Implement Data Encryption for Sensitive Storage
**Type:** Security  
**Impact:** Privacy  
**From:** Security Audit

**Problem:**
Run data stored in IndexedDB is unencrypted. If device is compromised, location history is exposed.

**Solution:**
```javascript
const Encryption = {
    async encrypt(data, password) {
        const encoder = new TextEncoder();
        const key = await this.deriveKey(password);
        const iv = crypto.getRandomValues(new Uint8Array(12));
        
        const encrypted = await crypto.subtle.encrypt(
            { name: 'AES-GCM', iv },
            key,
            encoder.encode(JSON.stringify(data))
        );
        
        return { iv, data: Array.from(new Uint8Array(encrypted)) };
    },
    
    async deriveKey(password) {
        const encoder = new TextEncoder();
        const keyMaterial = await crypto.subtle.importKey(
            'raw',
            encoder.encode(password),
            'PBKDF2',
            false,
            ['deriveBits', 'deriveKey']
        );
        
        return crypto.subtle.deriveKey(
            { name: 'PBKDF2', salt: encoder.encode('kitzski'), iterations: 100000, hash: 'SHA-256' },
            keyMaterial,
            { name: 'AES-GCM', length: 256 },
            false,
            ['encrypt', 'decrypt']
        );
    }
};
```

**Acceptance Criteria:**
- [ ] Optional encryption for runs
- [ ] User password/pin based
- [ ] Encrypted at rest
- [ ] Minimal performance impact

---

### [HIGH-015] Implement Background Geolocation (iOS/Android Native)
**Type:** Feature  
**Impact:** Tracking Quality  
**From:** Technical Limitation

**Problem:**
Web GPS stops when app is backgrounded. Native apps continue tracking.

**Research Options:**
1. Capacitor/Cordova bridge for native GPS
2. React Native port
3. Background fetch API (limited)
4. Keepalive techniques (battery drain)

**Acceptance Criteria:**
- [ ] Research native wrapper options
- [ ] Document trade-offs
- [ ] Prototype if feasible
- [ ] Maintain PWA compatibility

---

### [MEDIUM-018] Add Voice Control Support
**Type:** Accessibility  
**Impact:** Safety  
**From:** Accessibility Research

**Commands:**
- "Start tracking"
- "Stop tracking"
- "What's my speed?"
- "Save run"

**Implementation:**
```javascript
const VoiceControl = {
    init() {
        if ('webkitSpeechRecognition' in window) {
            this.recognition = new webkitSpeechRecognition();
            this.recognition.continuous = true;
            this.recognition.onresult = (e) => this.handleCommand(e);
            this.recognition.start();
        }
    },
    
    handleCommand(e) {
        const command = e.results[e.results.length-1][0].transcript.toLowerCase();
        if (command.includes('start')) App.startTracking();
        if (command.includes('stop')) App.stopTracking();
    }
};
```

**Acceptance Criteria:**
- [ ] Voice commands work
- [ ] Offline capable
- [ ] Multiple language support
- [ ] Toggle in settings

---

### [MEDIUM-019] Implement Social Share Cards
**Type:** Marketing  
**Impact:** Viral Growth  
**From:** Competitor Analysis

**Dynamic Image Generation:**
```javascript
const ShareCard = {
    async generate(run) {
        const canvas = document.createElement('canvas');
        canvas.width = 1200;
        canvas.height = 630;
        const ctx = canvas.getContext('2d');
        
        // Draw gradient background
        // Draw stats
        // Draw map preview
        // Export as image
        
        return canvas.toDataURL('image/png');
    }
};
```

**Acceptance Criteria:**
- [ ] Generate 1200x630 share image
- [ ] Include key stats
- [ ] Download or native share
- [ ] Instagram story format (9:16)

---

### [LOW-011] Add Onboarding Flow for First-Time Users
**Type:** UX  
**Impact:** User Retention  
**From:** UX Best Practices

**Steps:**
1. Welcome screen
2. Permissions explanation (GPS)
3. Quick tutorial (start/stop/save)
4. First achievement unlocked

**Acceptance Criteria:**
- [ ] 3-step onboarding
- [ ] Skip option available
- [ ] Only shown once
- [ ] Tracks completion

---

### [RESEARCH-010] Study Battery Optimization Patterns
**Type:** Research  
**Impact:** User Experience  
**From:** Performance Analysis

**Questions:**
1. How do top apps optimize battery?
2. What GPS update frequencies work best?
3. Screen-on vs screen-off behavior?
4. Adaptive power modes?

**Deliverable:**
Battery optimization guide

---

## 📊 Updated Priority Matrix

| Priority | Count | New Tasks |
|----------|-------|-----------|
| CRITICAL | 12 | +1 (encryption) |
| HIGH | 15 | +1 (background GPS) |
| MEDIUM | 19 | +2 (voice control, share cards) |
| LOW | 11 | +1 (onboarding) |
| RESEARCH | 10 | +1 (battery patterns) |

**Total Tasks:** 67 (+6 from review cycles)

---

## 🆕 NEW TASKS - Cycle 8 (Final Cycle 2026-02-02)

### [CRITICAL-013] Add Request Timeout Handling
**Type:** Reliability  
**Impact:** User Experience  
**From:** Code Review - No timeout on fetch requests

**Problem:**
Fetch requests (Supabase, scraper) have no timeout. Can hang indefinitely on poor connections.

**Solution:**
```javascript
async function fetchWithTimeout(url, options = {}, timeout = 10000) {
    const controller = new AbortController();
    const id = setTimeout(() => controller.abort(), timeout);
    
    try {
        const response = await fetch(url, {
            ...options,
            signal: controller.signal
        });
        clearTimeout(id);
        return response;
    } catch (error) {
        clearTimeout(id);
        if (error.name === 'AbortError') {
            throw new Error('Request timeout');
        }
        throw error;
    }
}
```

**Acceptance Criteria:**
- [ ] All fetch calls have timeout
- [ ] Graceful timeout handling
- [ ] Retry logic for timeouts
- [ ] User feedback on slow connections

---

### [HIGH-016] Implement Proper State Management
**Type:** Architecture  
**Impact:** Maintainability  
**From:** Code Review - State scattered across modules

**Problem:**
App state is scattered across multiple objects (App.state, Stats, GPSTracker). Hard to track and debug.

**Solution:**
```javascript
const Store = {
    state: {
        tracking: {
            status: 'idle', // idle, tracking, paused
            startTime: null,
            positions: []
        },
        ui: {
            activePanel: null,
            theme: 'dark'
        },
        user: {
            preferences: {},
            records: {}
        }
    },
    
    mutations: {
        startTracking(state) {
            state.tracking.status = 'tracking';
            state.tracking.startTime = Date.now();
        }
    }
};
```

**Acceptance Criteria:**
- [ ] Centralized state store
- [ ] Predictable state changes
- [ ] Time-travel debugging support
- [ ] Clear state flow documentation

---

### [MEDIUM-020] Add Request Retry with Exponential Backoff
**Type:** Reliability  
**Impact:** Offline Experience  
**From:** Code Review - Simple retry logic

**Implementation:**
```javascript
async function retryWithBackoff(fn, maxRetries = 3) {
    for (let i = 0; i < maxRetries; i++) {
        try {
            return await fn();
        } catch (error) {
            if (i === maxRetries - 1) throw error;
            const delay = Math.pow(2, i) * 1000; // 1s, 2s, 4s
            await new Promise(r => setTimeout(r, delay));
        }
    }
}
```

**Acceptance Criteria:**
- [ ] Exponential backoff for retries
- [ ] Configurable retry count
- [ ] Jitter to prevent thundering herd
- [ ] Circuit breaker pattern

---

### [MEDIUM-021] Implement Feature Flags
**Type:** DevOps  
**Impact:** Deployment Safety  
**From:** Best Practices

**Use Cases:**
- Gradually roll out new features
- A/B testing
- Emergency kill switches

**Implementation:**
```javascript
const FeatureFlags = {
    flags: {},
    
    async init() {
        // Load from Supabase or local
        this.flags = await Supabase.getFeatureFlags();
    },
    
    isEnabled(flag) {
        return this.flags[flag] || false;
    }
};

// Usage
if (FeatureFlags.isEnabled('new-ui-2025')) {
    showNewUI();
}
```

**Acceptance Criteria:**
- [ ] Feature flag system
- [ ] Remote configuration
- [ ] Per-user targeting
- [ ] Real-time updates

---

### [LOW-012] Add Performance Budget Monitoring
**Type:** Performance  
**Impact:** Load Time  
**From:** Performance Engineering

**Budgets:**
- JS: <100KB gzipped
- CSS: <20KB gzipped
- First Paint: <2s
- Time to Interactive: <3s

**Implementation:**
```javascript
// PerformanceObserver
new PerformanceObserver((list) => {
    for (const entry of list.getEntries()) {
        if (entry.duration > 3000) {
            console.warn('Long task detected:', entry.duration);
        }
    }
}).observe({ entryTypes: ['longtask'] });
```

**Acceptance Criteria:**
- [ ] Performance budgets defined
- [ ] Monitoring in place
- [ ] CI/CD checks
- [ ] Alerting on violations

---

### [RESEARCH-011] Evaluate Edge Computing for Slope Status
**Type:** Architecture Research  
**Impact:** Performance/Cost  
**From:** Infrastructure Optimization

**Research Questions:**
1. Can we cache slope status at edge (Cloudflare/Vercel Edge)?
2. Cost comparison: Edge vs Supabase
3. Update frequency requirements
4. Regional latency improvements?

**Deliverable:**
Architecture recommendation

---

## 📊 Final Priority Matrix

| Priority | Count | Total Effort |
|----------|-------|--------------|
| CRITICAL | 13 | ~4 weeks |
| HIGH | 16 | ~6 weeks |
| MEDIUM | 21 | ~8 weeks |
| LOW | 12 | ~4 weeks |
| RESEARCH | 11 | ~3 weeks |

**Total Tasks:** 73 (+6 from final cycle)  
**Estimated Total Effort:** ~25 weeks (1 developer)

---

## 🎯 Top 10 Immediate Priorities

1. **CRITICAL-004** - Fix memory leak in GPS tracker
2. **CRITICAL-007** - Implement error boundaries
3. **CRITICAL-009** - Add input validation
4. **CRITICAL-010** - Add CSP headers
5. **HIGH-001** - Photo integration
6. **HIGH-003** - 3D visualization MVP
7. **HIGH-008** - German i18n
8. **MEDIUM-008** - Accessibility audit
9. **MEDIUM-014** - Unit tests
10. **MEDIUM-015** - E2E tests

---

## 📈 Review Summary

**Cycles Completed:** 8  
**Total New Tasks Added:** 48  
**Files Reviewed:**  
- js/app.js (1750 lines)
- js/gps-tracker.js (768 lines)
- js/map.js (476 lines)
- js/achievements.js (416 lines)
- js/gpx.js (403 lines) ✅ Already implemented
- js/stats.js (358 lines)
- js/storage.js (343 lines)
- js/supabase.js (240 lines)
- js/utils.js (251 lines)
- js/resorts.js (241 lines)
- js/config.js (68 lines)
- css/styles.css (1815 lines)
- index.html (574 lines)
- sw.js (full review)
- manifest.json (full review)
- supabase/functions/scrape-slopes/index.ts (full review)

**Key Findings:**
1. Strong foundation with Kalman filtering and PWA features
2. GPX export/import already implemented (surprise!)
3. Security needs attention (CSP, input validation)
4. Testing coverage is zero - needs immediate attention
5. Performance optimizations available (lazy loading, throttling)
6. Feature parity gaps identified (photos, 3D, audio)

---

*Managed by Reviewer Agent*  
*Review completed: 2026-02-02*  
*Total review time: ~2 hours*  
*Tasks identified: 73*
