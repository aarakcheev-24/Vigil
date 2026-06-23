import SwiftUI

/// Один источник правды для нейминга — поменяй здесь, чтобы переименовать всё приложение.
enum Brand {
    static let appName = "Vigil"
    static let tagline = "keeps your Mac awake while your agents work"
    /// SF Symbol в строке меню
    static let menuBarSymbol = "laptopcomputer"
    static let accent = Color(red: 0.20, green: 0.52, blue: 1.0)   // системный синий
    static let good   = Color(red: 0.30, green: 0.85, blue: 0.39)  // зелёный батареи
}
