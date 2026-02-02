/**
 * Internationalization (i18n) Module
 * HIGH-008: Add Internationalization Support
 * 
 * Supports: English (en), German (de), French (fr), Italian (it), Spanish (es)
 * Auto-detects browser locale, stores user preference
 */

const I18n = {
    // Current language
    currentLang: localStorage.getItem('ski-app-lang') || this.detectBrowserLanguage(),
    
    // Supported languages
    supportedLangs: ['en', 'de', 'fr', 'it', 'es'],
    
    // Translations
    strings: {
        en: {
            // App
            appName: 'KitzSki Tracker',
            tagline: 'Track your ski runs',
            
            // Navigation
            startTracking: 'Start Tracking',
            stopTracking: 'Stop Tracking',
            pauseTracking: 'Pause',
            resumeTracking: 'Resume',
            saveRun: 'Save Run',
            discardRun: 'Discard',
            history: 'History',
            achievements: 'Achievements',
            settings: 'Settings',
            close: 'Close',
            back: 'Back',
            
            // Stats
            speed: 'Speed',
            maxSpeed: 'Max Speed',
            avgSpeed: 'Avg Speed',
            distance: 'Distance',
            vertical: 'Vertical Drop',
            duration: 'Duration',
            altitude: 'Altitude',
            slope: 'Slope',
            
            // Units
            km: 'km',
            m: 'm',
            kmh: 'km/h',
            min: 'min',
            
            // Tracking
            trackingActive: 'Tracking Active',
            trackingPaused: 'Tracking Paused',
            gpsSearching: 'Searching for GPS...',
            gpsReady: 'GPS Ready',
            
            // Runs
            runCompleted: 'Run Completed!',
            runsToday: 'Runs Today',
            totalRuns: 'Total Runs',
            bestRun: 'Best Run',
            
            // Achievements
            achievementUnlocked: 'Achievement Unlocked!',
            viewAchievements: 'View Achievements',
            
            // Segments
            segments: 'Segments',
            leaderboard: 'Leaderboard',
            personalBest: 'Personal Best',
            kingOfMountain: 'King of the Mountain',
            queenOfMountain: 'Queen of the Mountain',
            
            // Photos
            takePhoto: 'Take Photo',
            photoCaptured: 'Photo Captured',
            skiAlbum: 'Ski Album',
            
            // 3D View
            view3D: '3D View',
            replay: 'Replay',
            
            // Audio
            audioAnnouncements: 'Audio Announcements',
            speedAnnouncements: 'Speed Announcements',
            
            // Export/Import
            exportGPX: 'Export GPX',
            importGPX: 'Import GPX',
            shareRun: 'Share Run',
            
            // Slopes
            slopesOpen: 'Slopes Open',
            liftsOpen: 'Lifts Open',
            conditions: 'Conditions',
            
            // Errors
            errorGPS: 'GPS Error',
            errorMap: 'Map Error',
            errorSave: 'Save Error',
            errorLoad: 'Load Error',
            
            // Confirmations
            confirmDelete: 'Delete this run?',
            confirmDiscard: 'Discard current tracking?',
            yes: 'Yes',
            no: 'No',
            cancel: 'Cancel',
            
            // Time
            today: 'Today',
            yesterday: 'Yesterday',
            thisWeek: 'This Week',
            thisMonth: 'This Month',
            
            // Onboarding
            welcomeTitle: 'Welcome to KitzSki Tracker',
            welcomeText: 'Track your ski runs, compete on segments, and share your achievements.',
            permissionGPS: 'We need GPS permission to track your runs accurately.',
            tutorialStart: 'Tap the big button to start tracking your ski run.',
            tutorialStop: 'Tap again when you finish your run to save it.',
            
            // Settings
            language: 'Language',
            theme: 'Theme',
            darkMode: 'Dark Mode',
            lightMode: 'Light Mode',
            autoTheme: 'Auto',
            units: 'Units',
            metric: 'Metric',
            imperial: 'Imperial',
            batteryOptimization: 'Battery Optimization',
            highAccuracy: 'High Accuracy GPS',
            
            // Difficulty
            difficultyEasy: 'Easy',
            difficultyMedium: 'Medium', 
            difficultyHard: 'Hard',
            difficultyExpert: 'Expert',
            
            // Weather
            weather: 'Weather',
            temperature: 'Temperature',
            snowConditions: 'Snow Conditions',
            visibility: 'Visibility',
            
            // Voice
            voiceControl: 'Voice Control',
            voiceStart: 'Say "Start tracking"',
            voiceStop: 'Say "Stop tracking"',
            voiceSpeed: 'Say "What\'s my speed?"',
            
            // Deep linking
            sharedRun: 'Shared Run',
            openRun: 'Open Run',
            
            // Misc
            loading: 'Loading...',
            saving: 'Saving...',
            offline: 'Offline Mode',
            online: 'Back Online',
            retry: 'Retry',
            unknown: 'Unknown'
        },
        
        de: {
            // App
            appName: 'KitzSki Tracker',
            tagline: 'Tracke deine Skiausfahrten',
            
            // Navigation
            startTracking: 'Tracking Starten',
            stopTracking: 'Tracking Beenden',
            pauseTracking: 'Pausieren',
            resumeTracking: 'Fortsetzen',
            saveRun: 'Fahrt Speichern',
            discardRun: 'Verwerfen',
            history: 'Verlauf',
            achievements: 'Erfolge',
            settings: 'Einstellungen',
            close: 'Schließen',
            back: 'Zurück',
            
            // Stats
            speed: 'Geschwindigkeit',
            maxSpeed: 'Max. Geschwindigkeit',
            avgSpeed: 'Durchschnitt',
            distance: 'Strecke',
            vertical: 'Höhenmeter',
            duration: 'Dauer',
            altitude: 'Höhe',
            slope: 'Hang',
            
            // Units
            km: 'km',
            m: 'm',
            kmh: 'km/h',
            min: 'Min',
            
            // Tracking
            trackingActive: 'Tracking Aktiv',
            trackingPaused: 'Tracking Pausiert',
            gpsSearching: 'Suche GPS...',
            gpsReady: 'GPS Bereit',
            
            // Runs
            runCompleted: 'Fahrt Abgeschlossen!',
            runsToday: 'Fahrten Heute',
            totalRuns: 'Gesamtfahrten',
            bestRun: 'Beste Fahrt',
            
            // Achievements
            achievementUnlocked: 'Erfolg Freigeschaltet!',
            viewAchievements: 'Erfolge Anzeigen',
            
            // Segments
            segments: 'Segmente',
            leaderboard: 'Rangliste',
            personalBest: 'Persönlicher Rekord',
            kingOfMountain: 'König des Berges',
            queenOfMountain: 'Königin des Berges',
            
            // Photos
            takePhoto: 'Foto Aufnehmen',
            photoCaptured: 'Foto Gespeichert',
            skiAlbum: 'Skialbum',
            
            // 3D View
            view3D: '3D Ansicht',
            replay: 'Wiederholung',
            
            // Audio
            audioAnnouncements: 'Audio-Ansagen',
            speedAnnouncements: 'Geschwindigkeitsansagen',
            
            // Export/Import
            exportGPX: 'GPX Exportieren',
            importGPX: 'GPX Importieren',
            shareRun: 'Fahrt Teilen',
            
            // Slopes
            slopesOpen: 'Pisten Offen',
            liftsOpen: 'Lifte Offen',
            conditions: 'Verhältnisse',
            
            // Errors
            errorGPS: 'GPS Fehler',
            errorMap: 'Kartenfehler',
            errorSave: 'Speicherfehler',
            errorLoad: 'Ladefehler',
            
            // Confirmations
            confirmDelete: 'Diese Fahrt löschen?',
            confirmDiscard: 'Aktuelles Tracking verwerfen?',
            yes: 'Ja',
            no: 'Nein',
            cancel: 'Abbrechen',
            
            // Time
            today: 'Heute',
            yesterday: 'Gestern',
            thisWeek: 'Diese Woche',
            thisMonth: 'Dieser Monat',
            
            // Onboarding
            welcomeTitle: 'Willkommen beim KitzSki Tracker',
            welcomeText: 'Tracke deine Skiausfahrten, messe dich auf Segmenten und teile deine Erfolge.',
            permissionGPS: 'Wir benötigen GPS-Berechtigung zum genauen Tracking.',
            tutorialStart: 'Tippe auf den großen Button, um deine Skifahrt zu starten.',
            tutorialStop: 'Tippe erneut, wenn du deine Fahrt beenden möchtest.',
            
            // Settings
            language: 'Sprache',
            theme: 'Design',
            darkMode: 'Dunkelmodus',
            lightMode: 'Hellmodus',
            autoTheme: 'Automatisch',
            units: 'Einheiten',
            metric: 'Metrisch',
            imperial: 'Imperial',
            batteryOptimization: 'Batterie-Optimierung',
            highAccuracy: 'Hochgenaues GPS',
            
            // Difficulty
            difficultyEasy: 'Leicht',
            difficultyMedium: 'Mittel', 
            difficultyHard: 'Schwer',
            difficultyExpert: 'Expert',
            
            // Weather
            weather: 'Wetter',
            temperature: 'Temperatur',
            snowConditions: 'Schneeverhältnisse',
            visibility: 'Sicht',
            
            // Voice
            voiceControl: 'Sprachsteuerung',
            voiceStart: 'Sag "Tracking starten"',
            voiceStop: 'Sag "Tracking beenden"',
            voiceSpeed: 'Sag "Wie schnell bin ich?"',
            
            // Deep linking
            sharedRun: 'Geteilte Fahrt',
            openRun: 'Fahrt Öffnen',
            
            // Misc
            loading: 'Laden...',
            saving: 'Speichern...',
            offline: 'Offline-Modus',
            online: 'Wieder Online',
            retry: 'Wiederholen',
            unknown: 'Unbekannt'
        },
        
        fr: {
            // App
            appName: 'KitzSki Tracker',
            tagline: 'Suivez vos sorties ski',
            
            // Navigation
            startTracking: 'Démarrer',
            stopTracking: 'Arrêter',
            pauseTracking: 'Pause',
            resumeTracking: 'Reprendre',
            saveRun: 'Sauvegarder',
            discardRun: 'Abandonner',
            history: 'Historique',
            achievements: 'Succès',
            settings: 'Paramètres',
            close: 'Fermer',
            back: 'Retour',
            
            // Stats
            speed: 'Vitesse',
            maxSpeed: 'Vitesse Max',
            avgSpeed: 'Moyenne',
            distance: 'Distance',
            vertical: 'Dénivelé',
            duration: 'Durée',
            altitude: 'Altitude',
            slope: 'Pente',
            
            // Units
            km: 'km',
            m: 'm',
            kmh: 'km/h',
            min: 'min',
            
            // Tracking
            trackingActive: 'Suivi Actif',
            trackingPaused: 'En Pause',
            gpsSearching: 'Recherche GPS...',
            gpsReady: 'GPS Prêt',
            
            // Runs
            runCompleted: 'Sortie Terminée!',
            runsToday: 'Sorties Aujourd\'hui',
            totalRuns: 'Sorties Totales',
            bestRun: 'Meilleure Sortie',
            
            // Achievements
            achievementUnlocked: 'Succès Débloqué!',
            viewAchievements: 'Voir les Succès',
            
            // Segments
            segments: 'Segments',
            leaderboard: 'Classement',
            personalBest: 'Record Personnel',
            kingOfMountain: 'Roi de la Montagne',
            queenOfMountain: 'Reine de la Montagne',
            
            // Photos
            takePhoto: 'Prendre Photo',
            photoCaptured: 'Photo Capturée',
            skiAlbum: 'Album Ski',
            
            // 3D View
            view3D: 'Vue 3D',
            replay: 'Rejouer',
            
            // Audio
            audioAnnouncements: 'Annonces Audio',
            speedAnnouncements: 'Annonces de Vitesse',
            
            // Export/Import
            exportGPX: 'Exporter GPX',
            importGPX: 'Importer GPX',
            shareRun: 'Partager',
            
            // Slopes
            slopesOpen: 'Pistes Ouvertes',
            liftsOpen: 'Remontées Ouvertes',
            conditions: 'Conditions',
            
            // Errors
            errorGPS: 'Erreur GPS',
            errorMap: 'Erreur Carte',
            errorSave: 'Erreur Sauvegarde',
            errorLoad: 'Erreur Chargement',
            
            // Confirmations
            confirmDelete: 'Supprimer cette sortie?',
            confirmDiscard: 'Abandonner le suivi actuel?',
            yes: 'Oui',
            no: 'Non',
            cancel: 'Annuler',
            
            // Time
            today: 'Aujourd\'hui',
            yesterday: 'Hier',
            thisWeek: 'Cette Semaine',
            thisMonth: 'Ce Mois',
            
            // Settings
            language: 'Langue',
            theme: 'Thème',
            darkMode: 'Mode Sombre',
            lightMode: 'Mode Clair',
            autoTheme: 'Auto',
            units: 'Unités',
            metric: 'Métrique',
            imperial: 'Impérial',
            batteryOptimization: 'Optimisation Batterie',
            highAccuracy: 'GPS Haute Précision',
            
            // Difficulty
            difficultyEasy: 'Facile',
            difficultyMedium: 'Moyen', 
            difficultyHard: 'Difficile',
            difficultyExpert: 'Expert',
            
            // Misc
            loading: 'Chargement...',
            saving: 'Sauvegarde...',
            offline: 'Mode Hors-ligne',
            online: 'De Retour En-ligne',
            retry: 'Réessayer',
            unknown: 'Inconnu'
        },
        
        it: {
            // App
            appName: 'KitzSki Tracker',
            tagline: 'Traccia le tue discese',
            
            // Navigation
            startTracking: 'Inizia',
            stopTracking: 'Ferma',
            pauseTracking: 'Pausa',
            resumeTracking: 'Riprendi',
            saveRun: 'Salva',
            discardRun: 'Annulla',
            history: 'Cronologia',
            achievements: 'Obiettivi',
            settings: 'Impostazioni',
            close: 'Chiudi',
            back: 'Indietro',
            
            // Stats
            speed: 'Velocità',
            maxSpeed: 'Velocità Max',
            avgSpeed: 'Media',
            distance: 'Distanza',
            vertical: 'Dislivello',
            duration: 'Durata',
            altitude: 'Altitudine',
            slope: 'Pendenza',
            
            // Units
            km: 'km',
            m: 'm',
            kmh: 'km/h',
            min: 'min',
            
            // Tracking
            trackingActive: 'Tracciamento Attivo',
            trackingPaused: 'In Pausa',
            gpsSearching: 'Ricerca GPS...',
            gpsReady: 'GPS Pronto',
            
            // Runs
            runCompleted: 'Discesa Completata!',
            runsToday: 'Discese Oggi',
            totalRuns: 'Discese Totali',
            bestRun: 'Miglior Discesa',
            
            // Achievements
            achievementUnlocked: 'Obiettivo Sbloccato!',
            viewAchievements: 'Vedi Obiettivi',
            
            // Segments
            segments: 'Segmenti',
            leaderboard: 'Classifica',
            personalBest: 'Record Personale',
            kingOfMountain: 'Re della Montagna',
            queenOfMountain: 'Regina della Montagna',
            
            // Photos
            takePhoto: 'Scatta Foto',
            photoCaptured: 'Foto Catturata',
            skiAlbum: 'Album Sci',
            
            // 3D View
            view3D: 'Vista 3D',
            replay: 'Replay',
            
            // Audio
            audioAnnouncements: 'Annunci Audio',
            speedAnnouncements: 'Annunci Velocità',
            
            // Export/Import
            exportGPX: 'Esporta GPX',
            importGPX: 'Importa GPX',
            shareRun: 'Condividi',
            
            // Slopes
            slopesOpen: 'Piste Aperte',
            liftsOpen: 'Impianti Aperti',
            conditions: 'Condizioni',
            
            // Errors
            errorGPS: 'Errore GPS',
            errorMap: 'Errore Mappa',
            errorSave: 'Errore Salvataggio',
            errorLoad: 'Errore Caricamento',
            
            // Confirmations
            confirmDelete: 'Eliminare questa discesa?',
            confirmDiscard: 'Annullare il tracciamento?',
            yes: 'Sì',
            no: 'No',
            cancel: 'Annulla',
            
            // Time
            today: 'Oggi',
            yesterday: 'Ieri',
            thisWeek: 'Questa Settimana',
            thisMonth: 'Questo Mese',
            
            // Settings
            language: 'Lingua',
            theme: 'Tema',
            darkMode: 'Modalità Scura',
            lightMode: 'Modalità Chiara',
            autoTheme: 'Auto',
            units: 'Unità',
            metric: 'Metrico',
            imperial: 'Imperiale',
            batteryOptimization: 'Ottimizzazione Batteria',
            highAccuracy: 'GPS Alta Precisione',
            
            // Difficulty
            difficultyEasy: 'Facile',
            difficultyMedium: 'Medio', 
            difficultyHard: 'Difficile',
            difficultyExpert: 'Esperto',
            
            // Misc
            loading: 'Caricamento...',
            saving: 'Salvataggio...',
            offline: 'Modalità Offline',
            online: 'Di Nuovo Online',
            retry: 'Riprova',
            unknown: 'Sconosciuto'
        },
        
        es: {
            // App
            appName: 'KitzSki Tracker',
            tagline: 'Registra tus bajadas',
            
            // Navigation
            startTracking: 'Iniciar',
            stopTracking: 'Detener',
            pauseTracking: 'Pausa',
            resumeTracking: 'Reanudar',
            saveRun: 'Guardar',
            discardRun: 'Descartar',
            history: 'Historial',
            achievements: 'Logros',
            settings: 'Ajustes',
            close: 'Cerrar',
            back: 'Atrás',
            
            // Stats
            speed: 'Velocidad',
            maxSpeed: 'Velocidad Max',
            avgSpeed: 'Media',
            distance: 'Distancia',
            vertical: 'Desnivel',
            duration: 'Duración',
            altitude: 'Altitud',
            slope: 'Pendiente',
            
            // Units
            km: 'km',
            m: 'm',
            kmh: 'km/h',
            min: 'min',
            
            // Tracking
            trackingActive: 'Seguimiento Activo',
            trackingPaused: 'Pausado',
            gpsSearching: 'Buscando GPS...',
            gpsReady: 'GPS Listo',
            
            // Runs
            runCompleted: '¡Bajada Completada!',
            runsToday: 'Bajadas Hoy',
            totalRuns: 'Bajadas Totales',
            bestRun: 'Mejor Bajada',
            
            // Achievements
            achievementUnlocked: '¡Logro Desbloqueado!',
            viewAchievements: 'Ver Logros',
            
            // Segments
            segments: 'Segmentos',
            leaderboard: 'Clasificación',
            personalBest: 'Récord Personal',
            kingOfMountain: 'Rey de la Montaña',
            queenOfMountain: 'Reina de la Montaña',
            
            // Photos
            takePhoto: 'Tomar Foto',
            photoCaptured: 'Foto Capturada',
            skiAlbum: 'Álbum de Esquí',
            
            // 3D View
            view3D: 'Vista 3D',
            replay: 'Repetición',
            
            // Audio
            audioAnnouncements: 'Anuncios de Audio',
            speedAnnouncements: 'Anuncios de Velocidad',
            
            // Export/Import
            exportGPX: 'Exportar GPX',
            importGPX: 'Importar GPX',
            shareRun: 'Compartir',
            
            // Slopes
            slopesOpen: 'Pistas Abiertas',
            liftsOpen: 'Remontes Abiertos',
            conditions: 'Condiciones',
            
            // Errors
            errorGPS: 'Error GPS',
            errorMap: 'Error Mapa',
            errorSave: 'Error Guardar',
            errorLoad: 'Error Cargar',
            
            // Confirmations
            confirmDelete: '¿Eliminar esta bajada?',
            confirmDiscard: '¿Descartar seguimiento actual?',
            yes: 'Sí',
            no: 'No',
            cancel: 'Cancelar',
            
            // Time
            today: 'Hoy',
            yesterday: 'Ayer',
            thisWeek: 'Esta Semana',
            thisMonth: 'Este Mes',
            
            // Settings
            language: 'Idioma',
            theme: 'Tema',
            darkMode: 'Modo Oscuro',
            lightMode: 'Modo Claro',
            autoTheme: 'Auto',
            units: 'Unidades',
            metric: 'Métrico',
            imperial: 'Imperial',
            batteryOptimization: 'Optimización Batería',
            highAccuracy: 'GPS Alta Precisión',
            
            // Difficulty
            difficultyEasy: 'Fácil',
            difficultyMedium: 'Medio', 
            difficultyHard: 'Difícil',
            difficultyExpert: 'Experto',
            
            // Misc
            loading: 'Cargando...',
            saving: 'Guardando...',
            offline: 'Modo Offline',
            online: 'De Vuelta Online',
            retry: 'Reintentar',
            unknown: 'Desconocido'
        }
    },
    
    /**
     * Detect browser language
     */
    detectBrowserLanguage() {
        const lang = navigator.language || navigator.userLanguage || 'en';
        const shortLang = lang.split('-')[0].toLowerCase();
        return this.supportedLangs.includes(shortLang) ? shortLang : 'en';
    },
    
    /**
     * Get translation for key
     */
    t(key, params = {}) {
        const langStrings = this.strings[this.currentLang] || this.strings.en;
        let text = langStrings[key] || this.strings.en[key] || key;
        
        // Replace params
        Object.keys(params).forEach(param => {
            text = text.replace(`{{${param}}}`, params[param]);
        });
        
        return text;
    },
    
    /**
     * Set language
     */
    setLanguage(lang) {
        if (this.supportedLangs.includes(lang)) {
            this.currentLang = lang;
            localStorage.setItem('ski-app-lang', lang);
            document.documentElement.setAttribute('lang', lang);
            this.updatePageTitle();
            return true;
        }
        return false;
    },
    
    /**
     * Get current language
     */
    getLanguage() {
        return this.currentLang;
    },
    
    /**
     * Get supported languages
     */
    getSupportedLanguages() {
        return [
            { code: 'en', name: 'English', flag: '🇬🇧' },
            { code: 'de', name: 'Deutsch', flag: '🇩🇪' },
            { code: 'fr', name: 'Français', flag: '🇫🇷' },
            { code: 'it', name: 'Italiano', flag: '🇮🇹' },
            { code: 'es', name: 'Español', flag: '🇪🇸' }
        ];
    },
    
    /**
     * Update page title
     */
    updatePageTitle() {
        document.title = this.t('appName');
    },
    
    /**
     * Format number according to locale
     */
    formatNumber(num, decimals = 1) {
        return num.toLocaleString(this.currentLang, {
            minimumFractionDigits: decimals,
            maximumFractionDigits: decimals
        });
    },
    
    /**
     * Format date according to locale
     */
    formatDate(date) {
        const d = new Date(date);
        const now = new Date();
        const diffDays = Math.floor((now - d) / (1000 * 60 * 60 * 24));
        
        if (diffDays === 0) return this.t('today');
        if (diffDays === 1) return this.t('yesterday');
        
        return d.toLocaleDateString(this.currentLang, {
            year: 'numeric',
            month: 'short',
            day: 'numeric'
        });
    },
    
    /**
     * Initialize i18n
     */
    init() {
        document.documentElement.setAttribute('lang', this.currentLang);
        this.updatePageTitle();
        console.log(`[I18n] Initialized with language: ${this.currentLang}`);
    }
};

// Auto-initialize
I18n.init();
