import Foundation

// MARK: - Full-Screen Mode

enum FullScreenMode: String, CaseIterable {
    case alwaysShow = "alwaysShow"
    case hoverReveal = "hoverReveal"
    case alwaysHide = "alwaysHide"

    var displayName: String {
        switch self {
        case .alwaysShow: return "Always Show"
        case .hoverReveal: return "Reveal on Hover"
        case .alwaysHide: return "Always Hide"
        }
    }
}

@MainActor @Observable
final class Settings {
    // MARK: - Keys & Defaults

    private enum Key {
        static let palettePosition = "palettePosition"
        static let fullScreenMode = "paletteFullScreenMode"
        static let legacyHideOnFullScreen = "paletteHideOnFullScreen"
    }

    private static let defaults: [String: Any] = [
        Key.palettePosition: PalettePosition.topRight.rawValue,
        Key.fullScreenMode: FullScreenMode.hoverReveal.rawValue,
    ]

    // MARK: - Properties

    var palettePosition: PalettePosition {
        didSet { UserDefaults.standard.set(palettePosition.rawValue, forKey: Key.palettePosition) }
    }

    var fullScreenMode: FullScreenMode {
        didSet { UserDefaults.standard.set(fullScreenMode.rawValue, forKey: Key.fullScreenMode) }
    }

    // MARK: - Init

    init() {
        // Migrate legacy paletteHideOnFullScreen (Bool) → fullScreenMode (enum).
        // Legacy true  → .alwaysHide  (preserves old default behavior, minimum surprise).
        // Legacy false → .alwaysShow  (preserves user's explicit choice).
        // Do this BEFORE registering defaults so the "has user value?" check is accurate
        // — `register(defaults:)` would make `object(forKey:)` return the default value.
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Key.legacyHideOnFullScreen) != nil,
           defaults.object(forKey: Key.fullScreenMode) == nil {
            let legacy = defaults.bool(forKey: Key.legacyHideOnFullScreen)
            let migrated: FullScreenMode = legacy ? .alwaysHide : .alwaysShow
            defaults.set(migrated.rawValue, forKey: Key.fullScreenMode)
            defaults.removeObject(forKey: Key.legacyHideOnFullScreen)
        }

        defaults.register(defaults: Self.defaults)

        let posRaw = defaults.string(forKey: Key.palettePosition) ?? ""
        self.palettePosition = PalettePosition(rawValue: posRaw) ?? .topRight

        let modeRaw = defaults.string(forKey: Key.fullScreenMode) ?? ""
        self.fullScreenMode = FullScreenMode(rawValue: modeRaw) ?? .hoverReveal
    }
}
