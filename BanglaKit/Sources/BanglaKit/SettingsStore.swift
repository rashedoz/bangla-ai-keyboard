import Foundation

/// Non-secret preferences shared through the App Group.
public struct SettingsStore {
    public static let defaultModel = "gpt-4o-mini"
    public static let suggestedModels = ["gpt-4o-mini", "gpt-4.1-mini", "gpt-4o", "gpt-4.1"]

    enum Key {
        static let model = "model"
        static let lastMode = "lastMode"
        static let keyClicks = "keyClicks"
        static let haptics = "haptics"
        static let spaceAfterInsert = "spaceAfterInsert"
        static let livePreview = "livePreview"
    }

    public var defaults: UserDefaults

    public init(defaults: UserDefaults = SharedConfig.sharedDefaults) {
        self.defaults = defaults
    }

    public var model: String {
        get {
            let value = defaults.string(forKey: Key.model)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return value.isEmpty ? Self.defaultModel : value
        }
        nonmutating set { defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Key.model) }
    }

    public var lastMode: InputMode {
        get { defaults.string(forKey: Key.lastMode).flatMap(InputMode.init(rawValue:)) ?? .ai }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Key.lastMode) }
    }

    public var keyClicks: Bool {
        get { defaults.object(forKey: Key.keyClicks) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Key.keyClicks) }
    }

    public var haptics: Bool {
        get { defaults.object(forKey: Key.haptics) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Key.haptics) }
    }

    public var spaceAfterInsert: Bool {
        get { defaults.object(forKey: Key.spaceAfterInsert) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Key.spaceAfterInsert) }
    }

    /// Convert in the background whenever the user pauses typing in AI mode.
    public var livePreview: Bool {
        get { defaults.object(forKey: Key.livePreview) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Key.livePreview) }
    }
}
