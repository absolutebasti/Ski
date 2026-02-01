# 🎿 Task Stack - Ski Project

> **Last Updated:** 2026-02-01  
> **System:** Multi-Agent Async Development  
> **Status:** Active Review Phase

---

## 🔴 CRITICAL - Immediate Action Required

### [CRITICAL-001] GPS Kalman Filtering Implementation
**Type:** Core Algorithm  
**Impact:** Data Quality  
**From:** Code Review - gps-tracker.js

**Problem:**
Current GPS smoothing uses simple moving average (`getSmoothedSpeed()`). This is insufficient for alpine environments where GPS multipath errors are common (reflections from snow, mountains).

**Evidence:**
- Line 177-198 in gps-tracker.js: Naive weighted average implementation
- Line 24-25: Fixed `minAccuracy: 50` meters - too lenient for ski tracking
- No altitude smoothing at all

**Solution:**
Implement Kalman filter or complementary filter for:
1. Position smoothing (lat/lon)
2. Speed calculation (fuse GPS speed + calculated speed)
3. Altitude smoothing (GPS altitude is notoriously noisy)

**Reference:**
- Paper: "Adaptive Kalman Filtering for GPS/INS Integration" - needed for ski environment
- Example implementation: https://github.com/wouterbulten/kalmanjs

**Acceptance Criteria:**
- [ ] Speed fluctuations reduced by >60% when stationary
- [ ] Altitude readings stable within 5m when on lift
- [ ] Position jitter eliminated at low speeds

---

### [CRITICAL-002] Service Worker Missing - PWA Not Installable
**Type:** PWA Infrastructure  
**Impact:** Core Functionality  
**From:** Code Review

**Problem:**
`sw.js` exists but is empty (0 bytes). The app registers it in app.js:1067 but there's no caching strategy.

**Impact:**
- App won't work offline despite IndexedDB usage
- No background sync for runs
- Users can't install as PWA properly
- No map tile caching

**Required Implementation:**
```javascript
// sw.js needs:
1. Precache: index.html, css/, js/, manifest.json
2. Runtime cache for map tiles (Mapbox CDN)
3. Background sync for pending runs
4. Fallback pages for offline
```

**Acceptance Criteria:**
- [ ] Lighthouse PWA audit passes (90+ score)
- [ ] App loads fully offline after first visit
- [ ] Map tiles cached for offline use (at least resort area)
- [ ] Runs saved offline sync when back online

---

### [CRITICAL-003] Missing manifest.json
**Type:** PWA Infrastructure  
**Impact:** Installability  
**From:** Code Review - index.html:16

**Problem:**
HTML references `manifest.json` but file doesn't exist in repository.

**Required Fields:**
```json
{
  "name": "KitzSki Tracker",
  "short_name": "KitzSki",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#0a0a1a",
  "theme_color": "#0a84ff",
  "icons": [...],
  "categories": ["sports", "navigation"],
  "screenshots": [...],
  "shortcuts": [...]
}
```

---

## 🟠 HIGH - Major Improvements

### [HIGH-001] Photo Integration - Ski Moments
**Type:** Feature Parity (vs Slopes)  
**Impact:** User Engagement  
**From:** Competitor Analysis

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
- [ ] Take photo during tracking
- [ ] Photo appears on run map at capture location
- [ ] Photos exportable with run data
- [ ] No significant storage bloat (<100KB metadata per photo)

---

### [HIGH-002] GPX Export/Import
**Type:** Data Portability  
**Impact:** User Retention  
**From:** Competitor Analysis

**Competitor Status:**
- All major apps (Slopes, Ski Tracks, Strava) support GPX
- This is a MUST-HAVE for serious skiers

**Implementation:**
```javascript
// Export to GPX
function runToGPX(run) {
  return `<?xml version="1.0"?>
  <gpx>
    <trk>
      <name>KitzSki Run ${date}</name>
      <trkseg>
        ${run.positions.map(p => `
          <trkpt lat="${p.lat}" lon="${p.lon}">
            <ele>${p.alt}</ele>
            <time>${new Date(p.timestamp).toISOString()}</time>
          </trkpt>
        `).join('')}
      </trkseg>
    </trk>
  </gpx>`;
}
```

**Acceptance Criteria:**
- [ ] Export any run as .gpx file
- [ ] Import GPX files (from other apps)
- [ ] Import appears in history
- [ ] Compatible with Strava, Komoot, Garmin Connect

---

### [HIGH-003] 3D Run Visualization
**Type:** Feature Parity (vs FATMAP/Slopes)  
**Impact:** WOW Factor  
**From:** Competitor Analysis

**Competitor Benchmark:**
- **Slopes:** Beautiful 3D flythrough replays (premium feature)
- **FATMAP:** Native 3D terrain with tracked route
- **Ski Tracks:** Basic 2D only

**Implementation Options:**
1. **Mapbox GL JS:** Add 3D terrain exaggeration + camera animation
   - Already have terrain in map.js:92, just need camera flythrough
2. **Deck.gl:** More advanced but heavier
3. **Canvas 2.5D:** Custom implementation (lighter)

**MVP Version:**
- "Replay" button in run detail
- Animated camera following the route
- Speed affects camera velocity

**Advanced Version:**
- Export as video (WebGL → MediaRecorder)
- Share to social media

**Acceptance Criteria:**
- [ ] 3D replay button in run detail
- [ ] Smooth camera animation following route
- [ ] Works on mobile (30fps minimum)
- [ ] Optional: export 10s video clip

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

*Managed by Reviewer Agent*  
*Last comprehensive review: 2026-02-01*
