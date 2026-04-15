import Foundation

@MainActor @Observable
final class Settings {
    // MARK: - Keys & Defaults

    private enum Key {
        static let palettePosition = "palettePosition"
        static let hideOnFullScreen = "paletteHideOnFullScreen"
    }

    private static let defaults: [String: Any] = [
        Key.palettePosition: PalettePosition.topRight.rawValue,
        Key.hideOnFullScreen: true,
    ]

    // MARK: - Properties

    var palettePosition: PalettePosition {
        didSet { UserDefaults.standard.set(palettePosition.rawValue, forKey: Key.palettePosition) }
    }

    var hideOnFullScreen: Bool {
        didSet { UserDefaults.standard.set(hideOnFullScreen, forKey: Key.hideOnFullScreen) }
    }

    // MARK: - Init

    init() {
        UserDefaults.standard.register(defaults: Self.defaults)

        let posRaw = UserDefaults.standard.string(forKey: Key.palettePosition) ?? ""
        self.palettePosition = PalettePosition(rawValue: posRaw) ?? .topRight
        self.hideOnFullScreen = UserDefaults.standard.bool(forKey: Key.hideOnFullScreen)
    }
}
