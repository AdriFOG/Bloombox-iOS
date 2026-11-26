import Foundation
import Security

/// Check existence only, never retrieve credential values or query passwords.
@MainActor
enum BloomBoxAppleAccount {
    private static func presence(_ account: String) -> BloomBoxAccountPolicy.Presence {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.kdt.livecontainer",
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: false,
            kSecReturnAttributes as String: false,
            kSecReturnRef as String: false
        ]
        switch SecItemCopyMatching(query as CFDictionary, nil) {
        case errSecSuccess: return .present
        case errSecItemNotFound: return .absent
        default: return .unknown
        }
    }

    static func state() -> BloomBoxAccountPolicy.State {
        guard UserDefaults.sideStoreExist() else { return .unavailable }
        return BloomBoxAccountPolicy.state(available: true,
            email: presence("appleIDEmailAddress"),
            token: presence("appleIDXcodeToken"),
            adsid: presence("appleIDAdsid"))
    }

    /// Use the original bundled SideStore login and 2FA, not a replica form.
    static func open(mode: String) async throws {
        guard UserDefaults.sideStoreExist() else {
            throw NSError(domain: "BloomBoxAccount", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "SideStore is not included in this build."])
        }
        let defaults = LCUtils.appGroupUserDefault
        let request = BloomBoxAccountPolicy.request(mode: mode)
        defaults.set(request, forKey: BloomBoxAccountPolicy.requestKey)
        defaults.synchronize()
        do {
            let app = LCAppModel(appInfo: BuiltInSideStoreAppInfo.shared)
            try await app.runApp(multitask: false, bundleIdOverride: "builtinSideStore")
        } catch {
            let current = defaults.dictionary(forKey: BloomBoxAccountPolicy.requestKey)?["id"] as? String
            if current == (request["id"] as? String) {
                defaults.removeObject(forKey: BloomBoxAccountPolicy.requestKey)
            }
            throw error
        }
    }
}

