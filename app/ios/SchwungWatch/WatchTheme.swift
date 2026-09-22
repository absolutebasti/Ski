import SwiftUI
import WatchKit

/// The graphite palette from docs/PLAN.md §11. The live screen is pure black so
/// the OLED stays dark on a chairlift.
enum WatchTheme {
    static let champagne = Color(red: 0xD9 / 255, green: 0xC3 / 255, blue: 0x9A / 255)
    static let ice = Color(red: 0xBF / 255, green: 0xE3 / 255, blue: 0xF2 / 255)
    static let danger = Color(red: 0xFF / 255, green: 0x5A / 255, blue: 0x4A / 255)
    static let textPrimary = Color(red: 0xF5 / 255, green: 0xF2 / 255, blue: 0xEA / 255)
    static let textSecondary = Color(red: 0x9A / 255, green: 0x9A / 255, blue: 0x9F / 255)
    static let surface = Color(red: 0x14 / 255, green: 0x14 / 255, blue: 0x16 / 255)
}

/// Haptics: a tap on Start, a heavier one on End — mirrors the phone.
enum Haptics {
    static func start() { WKInterfaceDevice.current().play(.start) }
    static func end() { WKInterfaceDevice.current().play(.stop) }
}
