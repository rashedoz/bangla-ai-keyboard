import Foundation

/// Identifiers shared by the host app and the keyboard extension.
public enum SharedConfig {
    public static let appGroup = "group.com.miraidev.BanglaKeyboard"
    public static let keychainService = "com.miraidev.BanglaKeyboard"
    public static let apiKeyAccount = "openai_api_key"

    /// Keychain access group including the team prefix. Injected through the
    /// `KeychainAccessGroup` Info.plist key (`$(AppIdentifierPrefix)…`) so it
    /// resolves to the right team at build time.
    public static var keychainAccessGroup: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "KeychainAccessGroup") as? String,
              // An unsigned build leaves the team prefix empty (".com…") or unexpanded.
              !value.isEmpty, !value.hasPrefix("$("), !value.hasPrefix(".") else {
            return nil
        }
        return value
    }

    public static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }
}
