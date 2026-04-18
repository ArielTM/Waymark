import Foundation

// MARK: - Palette Visibility

enum PaletteVisibility: String, CaseIterable {
    case off = "off"
    case hiddenInFullScreen = "hiddenInFullScreen"
    case alwaysOn = "alwaysOn"

    var displayName: String {
        switch self {
        case .off: return "Off"
        case .hiddenInFullScreen: return "Hidden in Full-Screen Apps"
        case .alwaysOn: return "Always"
        }
    }
}

@MainActor @Observable
final class Settings {
    // MARK: - Keys & Defaults

    private enum Key {
        static let palettePosition = "palettePosition"
        static let paletteVisibility = "paletteVisibility"
        static let legacyFullScreenMode = "paletteFullScreenMode"
        static let legacyHideOnFullScreen = "paletteHideOnFullScreen"
    }

    private static let defaults: [String: Any] = [
        Key.palettePosition: PalettePosition.topRight.rawValue,
        Key.paletteVisibility: PaletteVisibility.alwaysOn.rawValue,
    ]

    // MARK: - Properties

    var palettePosition: PalettePosition {
        didSet { UserDefaults.standard.set(palettePosition.rawValue, forKey: Key.palettePosition) }
    }

    var paletteVisibility: PaletteVisibility {
        didSet { UserDefaults.standard.set(paletteVisibility.rawValue, forKey: Key.paletteVisibility) }
    }

    // MARK: - Init

    init() {
        let defaults = UserDefaults.standard

        // Legacy migration 1: paletteHideOnFullScreen (Bool) → paletteFullScreenMode (String).
        // legacy true  → "alwaysHide", legacy false → "alwaysShow".
        if defaults.object(forKey: Key.legacyHideOnFullScreen) != nil,
           defaults.object(forKey: Key.legacyFullScreenMode) == nil,
           defaults.object(forKey: Key.paletteVisibility) == nil {
            let legacy = defaults.bool(forKey: Key.legacyHideOnFullScreen)
            defaults.set(legacy ? "alwaysHide" : "alwaysShow", forKey: Key.legacyFullScreenMode)
            defaults.removeObject(forKey: Key.legacyHideOnFullScreen)
        }

        // Legacy migration 2: paletteFullScreenMode (FullScreenMode) → paletteVisibility (PaletteVisibility).
        // alwaysShow  → alwaysOn, hoverReveal → alwaysOn, alwaysHide → hiddenInFullScreen.
        if let legacyMode = defaults.string(forKey: Key.legacyFullScreenMode),
           defaults.object(forKey: Key.paletteVisibility) == nil {
            let migrated: PaletteVisibility
            switch legacyMode {
            case "alwaysHide": migrated = .hiddenInFullScreen
            default: migrated = .alwaysOn
            }
            defaults.set(migrated.rawValue, forKey: Key.paletteVisibility)
            defaults.removeObject(forKey: Key.legacyFullScreenMode)
        }

        defaults.register(defaults: Self.defaults)

        let posRaw = defaults.string(forKey: Key.palettePosition) ?? ""
        self.palettePosition = PalettePosition(rawValue: posRaw) ?? .topRight

        let visRaw = defaults.string(forKey: Key.paletteVisibility) ?? ""
        self.paletteVisibility = PaletteVisibility(rawValue: visRaw) ?? .alwaysOn
    }
}
