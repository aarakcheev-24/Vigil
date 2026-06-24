import SwiftUI

/// Один источник правды для нейминга — поменяй здесь, чтобы переименовать всё приложение.
enum Brand {
    static let appName = "Vigil"
    static let tagline = "keeps your Mac awake while your agents work"
    static let accent = Color(red: 0.20, green: 0.52, blue: 1.0)   // системный синий
    static let good   = Color(red: 0.30, green: 0.85, blue: 0.39)  // зелёный батареи
}

/// Набор иконок строки меню. Всегда монохром (template): белая на тёмном фоне,
/// чёрная на светлом — задаётся системой автоматически. Состояние показываем
/// сменой самого значка (контур → заливка), а не цветом.
enum MenuIcon: String, CaseIterable, Identifiable {
    case eye, laptop, bolt, mug, moon

    var id: String { rawValue }

    var label: String {
        switch self {
        case .eye:    return "Eye"
        case .laptop: return "Laptop"
        case .bolt:   return "Bolt"
        case .mug:    return "Coffee"
        case .moon:   return "Moon"
        }
    }

    /// Значок, когда сон НЕ удерживается (спокойное состояние) — контурный.
    var idle: String {
        switch self {
        case .eye:    return "eye"
        case .laptop: return "laptopcomputer"
        case .bolt:   return "bolt"
        case .mug:    return "cup.and.saucer"
        case .moon:   return "moon.zzz"
        }
    }

    /// Значок, когда Mac удерживается бодрым — заметно «активный» (заливка).
    var active: String {
        switch self {
        case .eye:    return "eye.fill"
        case .laptop: return "laptopcomputer.and.arrow.down"
        case .bolt:   return "bolt.fill"
        case .mug:    return "cup.and.saucer.fill"
        case .moon:   return "sun.max.fill"
        }
    }
}
