// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 adri23rep-stack (original BloomBox material only).
// Additional author-attribution term under AGPLv3 section 7(b):
// see LICENSE-ADDITIONAL-TERMS.md.
//
// Opt-in game audio mixing. Labels and audio mixing are independent features.
// Preference lives in LiveContainer's shared App Group so the guest process
// can read it before its engine activates audio. No guest IPA is modified.
import Foundation

enum BloomBoxAudioMixStore {
    static let keyPrefix = "BloomBoxAudioMixEnabledV1."

    static func key(for bundleIdentifier: String) -> String {
        keyPrefix + bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func isEnabled(for bundleIdentifier: String, defaults: UserDefaults) -> Bool {
        guard !bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return defaults.bool(forKey: key(for: bundleIdentifier))
    }

    static func setEnabled(_ enabled: Bool, for bundleIdentifier: String, defaults: UserDefaults) {
        guard !bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if enabled {
            defaults.set(true, forKey: key(for: bundleIdentifier))
        } else {
            defaults.removeObject(forKey: key(for: bundleIdentifier))
        }
    }
}
