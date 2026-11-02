import Foundation
import Security

// API keys live here, never in actions.json, UserDefaults or a command line
enum KeychainStore {
    private static let service = "com.baoduongg.flickwheel"

    private static func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }

    // attributes only, so asking never raises a keychain prompt
    static func exists(_ account: String) -> Bool {
        var search = query(account)
        search[kSecReturnAttributes as String] = true
        return SecItemCopyMatching(search as CFDictionary, nil) == errSecSuccess
    }

    static func read(_ account: String) -> String? {
        var search = query(account)
        search[kSecReturnData as String] = true
        var item: CFTypeRef?
        guard SecItemCopyMatching(search as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func save(_ value: String, account: String) -> Bool {
        let data = Data(value.utf8)
        if exists(account) {
            return SecItemUpdate(query(account) as CFDictionary, [kSecValueData as String: data] as CFDictionary) == errSecSuccess
        }
        var add = query(account)
        add[kSecValueData as String] = data
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    static func delete(_ account: String) {
        SecItemDelete(query(account) as CFDictionary)
    }
}
