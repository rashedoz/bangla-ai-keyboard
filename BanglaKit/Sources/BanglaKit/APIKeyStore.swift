import Foundation
import Security

/// Stores the user's OpenAI API key in the Keychain, shared between the app
/// and the keyboard through a keychain access group.
///
/// If the access group isn't available (e.g. an unsigned simulator build with
/// no development team), it falls back to the App Group container so the
/// keyboard can still read the key. That fallback is only used in the simulator.
public struct APIKeyStore {
    public var service: String
    public var account: String
    public var accessGroup: String?
    public var fallbackDefaults: UserDefaults?

    public init(
        service: String = SharedConfig.keychainService,
        account: String = SharedConfig.apiKeyAccount,
        accessGroup: String? = SharedConfig.keychainAccessGroup,
        fallbackDefaults: UserDefaults? = APIKeyStore.simulatorFallback
    ) {
        self.service = service
        self.account = account
        self.accessGroup = accessGroup
        self.fallbackDefaults = fallbackDefaults
    }

    public static var simulatorFallback: UserDefaults? {
        #if targetEnvironment(simulator)
        return SharedConfig.sharedDefaults
        #else
        return nil
        #endif
    }

    private var fallbackKey: String { "fallback.\(account)" }

    private func baseQuery() -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        if let accessGroup { query[kSecAttrAccessGroup as String] = accessGroup }
        return query
    }

    public func load() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
           let data = item as? Data,
           let key = String(data: data, encoding: .utf8), !key.isEmpty {
            return key
        }
        if let fallback = fallbackDefaults?.string(forKey: fallbackKey), !fallback.isEmpty {
            return fallback
        }
        return nil
    }

    @discardableResult
    public func save(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return delete() }
        let data = Data(trimmed.utf8)

        SecItemDelete(baseQuery() as CFDictionary)
        var add = baseQuery()
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(add as CFDictionary, nil)

        if status == errSecSuccess {
            fallbackDefaults?.removeObject(forKey: fallbackKey)
            return true
        }
        if let fallbackDefaults {
            fallbackDefaults.set(trimmed, forKey: fallbackKey)
            return true
        }
        return false
    }

    @discardableResult
    public func delete() -> Bool {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        fallbackDefaults?.removeObject(forKey: fallbackKey)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// "sk-…abcd" style preview so the full key is never shown.
    public static func masked(_ key: String) -> String {
        guard key.count > 8 else { return String(repeating: "•", count: key.count) }
        return "\(key.prefix(3))…\(key.suffix(4))"
    }
}
