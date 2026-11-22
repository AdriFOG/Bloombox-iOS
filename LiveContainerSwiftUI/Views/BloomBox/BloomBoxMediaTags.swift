// BloomBox -> MediaBloom shared app labels, independent of the launcher category.
// Tagging does not migrate, reinstall, or modify the guest bundle.
import Foundation

enum BloomBoxMediaTag: String, CaseIterable, Identifiable {
    case automatic = "auto"
    case music = "music"
    case video = "video"
    case excluded = "none"

    var id: String { rawValue }
}

enum BloomBoxMediaTagStore {
    static let prefix = "BloomBoxMediaTagV1."

    static func key(for bundleID: String) -> String {
        prefix + bundleID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func selection(for bundleID: String, defaults: UserDefaults) -> BloomBoxMediaTag {
        guard !bundleID.isEmpty,
              let stored = defaults.string(forKey: key(for: bundleID)),
              let value = BloomBoxMediaTag(rawValue: stored) else {
            return .automatic
        }
        return value
    }

    static func set(_ tag: BloomBoxMediaTag, for bundleID: String, defaults: UserDefaults) {
        guard !bundleID.isEmpty else { return }
        let key = key(for: bundleID)
        if tag == .automatic {
            // No explicit override: leave legacy auto-discovery alone.
            defaults.removeObject(forKey: key)
        } else {
            defaults.set(tag.rawValue, forKey: key)
        }
    }
}
