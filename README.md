# 🎿 KitzSki Tracker

A Progressive Web App for real-time ski tracking at the Kitzbühel ski area. Track your speed, distance, altitude, and more - all from your iPhone!

![KitzSki Tracker](assets/icons/icon-192.svg)

## Features

- 🚀 **Real-time Speed** - GPS-powered speed tracking in km/h
- 📏 **Distance Tracking** - Total kilometers skied
- ⬇️ **Vertical Drop** - Meters descended per run
- 🏔️ **Altitude** - Current elevation display
- 🗺️ **Interactive Map** - Kitzbühel trails with live position
- 📊 **Run History** - Save and review all your runs
- 🏆 **Personal Records** - Track your all-time bests
- 📱 **Works Offline** - Full functionality on the mountain
- 🌙 **Dark Mode** - Premium alpine theme

## Quick Start

### Option 1: Local Development

```bash
# Navigate to project directory
cd /Users/sebastianfackelmann/Documents/Projects/SKI_APP

# Start a local server
npx serve .

# Open http://localhost:3000 in your browser
```

### Option 2: Deploy to Vercel (Recommended)

1. Push this code to a GitHub repository
2. Go to [vercel.com](https://vercel.com) and sign in with GitHub
3. Click "New Project" and import your repository
4. Click "Deploy" - your app will be live in seconds!

### Option 3: Deploy to Netlify

1. Go to [netlify.com](https://netlify.com)
2. Drag and drop the `SKI_APP` folder onto the page
3. Your app will be deployed instantly!

## Installing on iPhone

1. Open your deployed URL in **Safari** (not Chrome)
2. Tap the **Share** button (box with arrow)
3. Scroll down and tap **"Add to Home Screen"**
4. Tap **"Add"** in the top right
5. The app will appear on your home screen!

When launched from the home screen, the app runs full-screen like a native app.

## Mapbox Setup (Optional)

For the interactive map to work, you need a Mapbox access token:

1. Create a free account at [mapbox.com](https://www.mapbox.com/)
2. Copy your public access token
3. Edit `js/map.js` and replace the `MAPBOX_TOKEN` value:

```javascript
MAPBOX_TOKEN: 'pk.your_actual_token_here',
```

> **Note:** The app works perfectly without Mapbox - GPS tracking and all stats still function. The map area will show a placeholder.

## Usage

1. **Start Tracking** - Tap the blue "Start Tracking" button
2. **Grant Location** - Allow GPS access when prompted
3. **Ski!** - The app automatically tracks your speed, distance, and altitude
4. **Stop & Save** - Tap "Stop & Save" to end your run
5. **View History** - Tap the clock icon to see past runs

## Technical Details

- **No App Store Required** - PWA works immediately
- **GPS Accuracy** - Uses high-accuracy mode for precise tracking
- **Offline Storage** - IndexedDB stores runs locally (up to 500MB)
- **Battery Optimized** - Screen wake lock prevents sleep while tracking

## File Structure

```
SKI_APP/
├── index.html          # Main app shell
├── manifest.json       # PWA configuration
├── sw.js               # Service worker (offline support)
├── css/
│   └── styles.css      # Dark mode styling
├── js/
│   ├── app.js          # Main application logic
│   ├── gps-tracker.js  # GPS engine
│   ├── map.js          # Map integration
│   ├── stats.js        # Statistics
│   ├── storage.js      # IndexedDB
│   └── utils.js        # Helpers
└── assets/
    ├── icons/          # App icons
    └── kitzbuehel-trails.geojson
```

## Browser Support

- ✅ Safari iOS 11.3+
- ✅ Chrome Android
- ✅ Chrome Desktop
- ✅ Firefox
- ✅ Edge

## Tips for Best Results

- **GPS Signal** - Start tracking outdoors for best accuracy
- **Stay in Safari** - iOS requires Safari for PWA installation
- **Battery** - Close other apps to extend battery life
- **Cold Weather** - Keep phone warm in your pocket between runs

## Troubleshooting

**GPS not working?**
- Ensure Location Services are enabled in Settings
- Reload the page and grant permission again

**Map not loading?**
- Add your Mapbox token (see setup above)
- Check your internet connection

**App not installing?**
- Must use Safari on iOS
- Must be served over HTTPS (or localhost)

## License

MIT License - Feel free to modify and share!

---

Built with ❄️ for the slopes of Kitzbühel

