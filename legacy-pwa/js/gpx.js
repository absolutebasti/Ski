/**
 * KitzSki Tracker - GPX Export/Import Module
 * 
 * Handles conversion between ski run data and GPX format
 * for data portability with other apps (Strava, Komoot, Garmin)
 */

const GPX = {
    /**
     * Convert a run to GPX format
     * @param {Object} run - Run data object
     * @returns {string} GPX XML string
     */
    runToGPX(run) {
        const date = new Date(run.startTime);
        const formattedDate = date.toISOString().split('T')[0];
        const resortName = Resorts.getCurrent()?.name || 'Unknown Resort';
        
        // GPX header
        let gpx = `<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="KitzSki Tracker" xmlns="http://www.topografix.com/GPX/1/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
  <metadata>
    <name>Ski Run - ${formattedDate}</name>
    <desc>Ski tracking data from ${resortName}</desc>
    <author>
      <name>KitzSki Tracker</name>
    </author>
    <time>${new Date(run.startTime).toISOString()}</time>
    <keywords>ski, alpine, skiing, snow</keywords>
  </metadata>
  <trk>
    <name>Ski Run ${formattedDate}</name>
    <type>skiing</type>
    <extensions>
      <kitzski:stats xmlns:kitzski="https://kitzski.app/gpx">
        <kitzski:maxSpeed>${run.maxSpeed.toFixed(2)}</kitzski:maxSpeed>
        <kitzski:avgSpeed>${run.avgSpeed.toFixed(2)}</kitzski:avgSpeed>
        <kitzski:verticalDrop>${run.verticalDrop}</kitzski:verticalDrop>
        <kitzski:distance>${run.distance.toFixed(3)}</kitzski:distance>
        <kitzski:duration>${run.duration}</kitzski:duration>
      </kitzski:stats>
    </extensions>
    <trkseg>`;

        // Add track points
        if (run.positions && run.positions.length > 0) {
            for (const pos of run.positions) {
                const timestamp = new Date(pos.timestamp).toISOString();
                const ele = pos.alt !== null && pos.alt !== undefined ? `<ele>${pos.alt.toFixed(1)}</ele>` : '';
                
                gpx += `
      <trkpt lat="${pos.lat.toFixed(8)}" lon="${pos.lon.toFixed(8)}">
        ${ele}
        <time>${timestamp}</time>`;
                
                // Add speed extension if available
                if (pos.speed !== null && pos.speed !== undefined) {
                    gpx += `
        <extensions>
          <kitzski:speed>${pos.speed.toFixed(2)}</kitzski:speed>
        </extensions>`;
                }
                
                gpx += `
      </trkpt>`;
            }
        }

        // GPX footer
        gpx += `
    </trkseg>
  </trk>
</gpx>`;

        return gpx;
    },

    /**
     * Export a single run as GPX file
     * @param {Object} run - Run data object
     */
    exportRun(run) {
        const gpxContent = this.runToGPX(run);
        const blob = new Blob([gpxContent], { type: 'application/gpx+xml' });
        const url = URL.createObjectURL(blob);
        
        const date = new Date(run.startTime).toISOString().split('T')[0];
        const filename = `kitzski-run-${date}-${run.id.slice(-6)}.gpx`;
        
        const a = document.createElement('a');
        a.href = url;
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        
        URL.revokeObjectURL(url);
        console.log('GPX exported:', filename);
    },

    /**
     * Export multiple runs as a single GPX file
     * @param {Array} runs - Array of run objects
     */
    exportRuns(runs) {
        if (runs.length === 0) {
            throw new Error('No runs to export');
        }

        const date = new Date().toISOString().split('T')[0];
        const resortName = Resorts.getCurrent()?.name || 'Unknown Resort';
        
        let gpx = `<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="KitzSki Tracker" xmlns="http://www.topografix.com/GPX/1/1">
  <metadata>
    <name>Ski Session - ${date}</name>
    <desc>${runs.length} runs from ${resortName}</desc>
    <time>${new Date().toISOString()}</time>
  </metadata>`;

        // Add each run as a separate track
        for (const run of runs) {
            const runDate = new Date(run.startTime).toISOString().split('T')[0];
            
            gpx += `
  <trk>
    <name>Run ${runDate}</name>
    <type>skiing</type>
    <extensions>
      <kitzski:stats xmlns:kitzski="https://kitzski.app/gpx">
        <kitzski:maxSpeed>${run.maxSpeed.toFixed(2)}</kitzski:maxSpeed>
        <kitzski:distance>${run.distance.toFixed(3)}</kitzski:distance>
        <kitzski:verticalDrop>${run.verticalDrop}</kitzski:verticalDrop>
      </kitzski:stats>
    </extensions>
    <trkseg>`;

            if (run.positions && run.positions.length > 0) {
                for (const pos of run.positions) {
                    const timestamp = new Date(pos.timestamp).toISOString();
                    const ele = pos.alt !== null ? `<ele>${pos.alt.toFixed(1)}</ele>` : '';
                    
                    gpx += `
      <trkpt lat="${pos.lat.toFixed(8)}" lon="${pos.lon.toFixed(8)}">
        ${ele}
        <time>${timestamp}</time>
      </trkpt>`;
                }
            }

            gpx += `
    </trkseg>
  </trk>`;
        }

        gpx += `
</gpx>`;

        const blob = new Blob([gpx], { type: 'application/gpx+xml' });
        const url = URL.createObjectURL(blob);
        
        const filename = `kitzski-session-${date}-${runs.length}-runs.gpx`;
        
        const a = document.createElement('a');
        a.href = url;
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        
        URL.revokeObjectURL(url);
        console.log('GPX session exported:', filename);
    },

    /**
     * Parse GPX file and convert to run data
     * @param {string} gpxContent - GPX XML string
     * @returns {Object} Parsed run data
     */
    parseGPX(gpxContent) {
        const parser = new DOMParser();
        const doc = parser.parseFromString(gpxContent, 'text/xml');
        
        // Check for parsing errors
        const parserError = doc.querySelector('parsererror');
        if (parserError) {
            throw new Error('Invalid GPX file');
        }

        const trk = doc.querySelector('trk');
        if (!trk) {
            throw new Error('No track found in GPX file');
        }

        // Extract metadata
        const name = trk.querySelector('name')?.textContent || 'Imported Run';
        const trackType = trk.querySelector('type')?.textContent || '';
        
        // Check if this looks like skiing data (or accept any outdoor activity)
        const isSkiing = trackType.toLowerCase().includes('ski') || 
                        trackType.toLowerCase().includes('snowboard') ||
                        trackType.toLowerCase().includes('snow');

        // Parse track points
        const trackpoints = trk.querySelectorAll('trkpt');
        const positions = [];
        
        for (const tp of trackpoints) {
            const lat = parseFloat(tp.getAttribute('lat'));
            const lon = parseFloat(tp.getAttribute('lon'));
            
            if (isNaN(lat) || isNaN(lon)) continue;

            const ele = tp.querySelector('ele');
            const time = tp.querySelector('time');
            const speedExt = tp.querySelector('extensions speed, extensions *[local-name()="speed"]');
            
            positions.push({
                lat: lat,
                lon: lon,
                alt: ele ? parseFloat(ele.textContent) : null,
                timestamp: time ? new Date(time.textContent).getTime() : Date.now(),
                speed: speedExt ? parseFloat(speedExt.textContent) : null
            });
        }

        if (positions.length < 2) {
            throw new Error('Not enough track points (minimum 2 required)');
        }

        // Calculate stats from positions
        const startTime = positions[0].timestamp;
        const endTime = positions[positions.length - 1].timestamp;
        const duration = endTime - startTime;

        // Calculate distance
        let distance = 0;
        let maxSpeed = 0;
        let verticalDrop = 0;
        let totalAscent = 0;
        let altitudes = [];

        for (let i = 1; i < positions.length; i++) {
            const prev = positions[i - 1];
            const curr = positions[i];
            
            // Distance
            const dist = Utils.calculateDistance(prev.lat, prev.lon, curr.lat, curr.lon);
            distance += dist;
            
            // Speed (from position or calculate)
            const timeDiff = (curr.timestamp - prev.timestamp) / 1000; // seconds
            let speed = curr.speed;
            if ((speed === null || speed === undefined) && timeDiff > 0) {
                speed = (dist / timeDiff) * 3.6; // km/h
            }
            if (speed > maxSpeed) maxSpeed = speed;
            positions[i].speed = speed || 0;
            
            // Vertical
            if (prev.alt !== null && curr.alt !== null) {
                const altDiff = prev.alt - curr.alt;
                if (altDiff > 0) {
                    verticalDrop += altDiff;
                } else {
                    totalAscent += Math.abs(altDiff);
                }
                altitudes.push(curr.alt);
            }
        }

        // Calculate average speed
        const speedReadings = positions.map(p => p.speed).filter(s => s > 1);
        const avgSpeed = speedReadings.length > 0 ? 
            speedReadings.reduce((a, b) => a + b, 0) / speedReadings.length : 0;

        // Extract stats from extensions if available
        const statsExt = trk.querySelector('extensions kitzski\\:stats, extensions *[local-name()="stats"]');
        if (statsExt) {
            const maxSpeedExt = statsExt.querySelector('kitzski\\:maxSpeed, *[local-name()="maxSpeed"]');
            const vertDropExt = statsExt.querySelector('kitzski\\:verticalDrop, *[local-name()="verticalDrop"]');
            const distExt = statsExt.querySelector('kitzski\\:distance, *[local-name()="distance"]');
            const durExt = statsExt.querySelector('kitzski\\:duration, *[local-name()="duration"]');
            
            if (maxSpeedExt) maxSpeed = parseFloat(maxSpeedExt.textContent);
            if (vertDropExt) verticalDrop = parseInt(vertDropExt.textContent);
            if (distExt) distance = parseFloat(distExt.textContent) * 1000; // km to m
            if (durExt) duration = parseInt(durExt.textContent);
        }

        return {
            id: Utils.generateId(),
            startTime: startTime,
            endTime: endTime,
            duration: duration,
            distance: distance / 1000, // Convert to km
            maxSpeed: maxSpeed,
            avgSpeed: avgSpeed,
            verticalDrop: Math.round(verticalDrop),
            startAltitude: positions[0].alt,
            endAltitude: positions[positions.length - 1].alt,
            highestAltitude: altitudes.length > 0 ? Math.max(...altitudes) : null,
            lowestAltitude: altitudes.length > 0 ? Math.min(...altitudes) : null,
            positions: positions,
            imported: true,
            importDate: Date.now()
        };
    },

    /**
     * Import GPX file and save to storage
     * @param {File} file - GPX file to import
     * @returns {Promise<Object>} Imported run data
     */
    async importFile(file) {
        return new Promise((resolve, reject) => {
            if (!file.name.endsWith('.gpx')) {
                reject(new Error('File must be a GPX file (.gpx)'));
                return;
            }

            const reader = new FileReader();
            
            reader.onload = async (e) => {
                try {
                    const gpxContent = e.target.result;
                    const runData = this.parseGPX(gpxContent);
                    
                    // Save to storage
                    await Storage.saveRun(runData);
                    await Stats.updateRunCount();
                    
                    resolve(runData);
                } catch (error) {
                    reject(error);
                }
            };
            
            reader.onerror = () => reject(new Error('Failed to read file'));
            reader.readAsText(file);
        });
    },

    /**
     * Import multiple GPX files
     * @param {FileList} files - GPX files to import
     * @returns {Promise<Array>} Array of imported runs
     */
    async importFiles(files) {
        const results = [];
        const errors = [];
        
        for (const file of files) {
            try {
                const run = await this.importFile(file);
                results.push(run);
            } catch (error) {
                errors.push({ file: file.name, error: error.message });
            }
        }
        
        return { imported: results, errors };
    },

    /**
     * Validate GPX content without importing
     * @param {string} gpxContent - GPX XML string
     * @returns {Object} Validation result
     */
    validateGPX(gpxContent) {
        try {
            const run = this.parseGPX(gpxContent);
            return {
                valid: true,
                points: run.positions.length,
                distance: run.distance,
                duration: run.duration,
                verticalDrop: run.verticalDrop
            };
        } catch (error) {
            return {
                valid: false,
                error: error.message
            };
        }
    },

    /**
     * Create import dialog HTML
     * @returns {HTMLElement} File input element
     */
    createImportInput() {
        const input = document.createElement('input');
        input.type = 'file';
        input.accept = '.gpx';
        input.multiple = true;
        input.style.display = 'none';
        return input;
    }
};

// Make GPX available globally
window.GPX = GPX;
