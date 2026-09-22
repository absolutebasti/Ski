import Foundation

/// German first, English second — same rule as the phone (`AppLocale.pick`).
/// Sentence case, ski vocabulary: Abfahrt, Höhenmeter, Liftfahrt, Pause, Gefälle,
/// Skitag, Top-Speed.
enum S {
    static var isGerman: Bool {
        (Locale.preferredLanguages.first ?? "en").hasPrefix("de")
    }

    private static func pick(_ de: String, _ en: String) -> String { isGerman ? de : en }

    static var start: String { pick("Skitag starten", "Start ski day") }
    static var end: String { pick("Skitag beenden", "End ski day") }
    static var holdToEnd: String { pick("Halten zum Beenden", "Hold to end") }
    static var vertical: String { pick("Höhenmeter", "Vertical") }
    static var runs: String { pick("Abfahrten", "Runs") }
    static var topSpeed: String { pick("Top-Speed", "Top speed") }
    static var time: String { pick("Zeit", "Time") }
    static var heartRate: String { pick("Herzfrequenz", "Heart rate") }
    static var speed: String { pick("Tempo", "Speed") }
    static var altitude: String { pick("Höhe", "Altitude") }
    static var waiting: String { pick("Warte auf iPhone", "Waiting for iPhone") }
    static var noPhone: String { pick("iPhone nicht erreichbar", "iPhone not reachable") }
    static var starting: String { pick("Startet …", "Starting …") }
    static var ending: String { pick("Beendet …", "Ending …") }
    static var recording: String { pick("Läuft", "Recording") }
    static var placeholder: String { "–" }
}
