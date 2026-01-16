import Foundation
import Security

class KeychainService {
    static let shared = KeychainService()

    private let service = "com.patentradar.apikey"
    private let account = "claude-api-key"

    // Cache to avoid repeated Keychain queries
    private var cachedKey: String?
    private var hasCached = false

    private init() {}

    func saveAPIKey(_ key: String) {
        guard let data = key.data(using: .utf8) else { return }

        // Delete existing key first (without clearing cache)
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        SecItemAdd(query as CFDictionary, nil)

        // Update cache after saving
        cachedKey = key
        hasCached = true
    }

    func getAPIKey() -> String? {
        // Return cached value if available
        if hasCached {
            return cachedKey
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess,
           let data = result as? Data,
           let key = String(data: data, encoding: .utf8) {
            cachedKey = key
            hasCached = true
            return key
        }

        hasCached = true
        cachedKey = nil
        return nil
    }

    func deleteAPIKey() {
        // Clear cache
        cachedKey = nil
        hasCached = false

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)
    }

    func hasAPIKey() -> Bool {
        guard let key = getAPIKey() else { return false }
        return !key.isEmpty
    }
}
