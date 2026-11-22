import Foundation

/// Read only the guest's declared/packaged locales. Never edit game assets.
/// Games using custom localization engines can still be given a manual preference.
enum BloomBoxGuestLanguageCatalog {
    static let manualChoices = [
        "es", "es-MX", "en", "en-GB", "pt-BR", "pt-PT",
        "fr", "de", "it", "ja", "ko", "zh-Hans", "zh-Hant",
        "ru", "ar", "tr", "nl", "pl", "hi"
    ]

    static func normalized(_ identifier: String) -> String? {
        let value = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "-")
        guard value.count >= 2, value.count <= 35,
              value.lowercased() != "base" else { return nil }
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        guard let language = parts.first, (2...8).contains(language.count),
              parts.allSatisfy({ !$0.isEmpty && $0.count <= 8 &&
                  $0.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) } }) else {
            return nil
        }
        return value
    }

    /// Keep a general language fallback when a regional variant was selected.
    static func preferredLanguages(for identifier: String) -> [String] {
        guard let normalized = normalized(identifier) else { return [] }
        let parts = normalized.split(separator: "-")
        return (1...parts.count).reversed().map {
            parts.prefix($0).joined(separator: "-")
        }
    }

    static func detect(in appBundleURL: URL, fileManager fm: FileManager = .default) -> [String] {
        func safeDirectory(_ url: URL) -> Bool {
            guard let attributes = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else {
                return false
            }
            return attributes.isDirectory == true && attributes.isSymbolicLink != true
        }

        func directories(in url: URL) -> [URL] {
            guard safeDirectory(url) else { return [] }
            let children = (try? fm.contentsOfDirectory(
                at: url, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles])) ?? []
            return Array(children.filter(safeDirectory).prefix(1024))
        }

        guard safeDirectory(appBundleURL) else { return [] }
        var found = Set<String>()
        func add(_ identifier: String) {
            if let language = normalized(identifier) { found.insert(language) }
        }

        // Info.plist can advertise locales even when no top-level *.lproj exists.
        if let plist = try? Data(contentsOf: appBundleURL.appendingPathComponent("Info.plist")),
           let root = try? PropertyListSerialization.propertyList(from: plist, options: [], format: nil),
           let info = root as? [String: Any],
           let declared = info["CFBundleLocalizations"] as? [String] {
            declared.forEach(add)
        }

        // Inspect shallow resource bundles/frameworks only. Never descend into
        // game data, read translations, traverse symlinks or enumerate recursively.
        let rootChildren = directories(in: appBundleURL)
        var candidateBundles = [appBundleURL]
        let packageTypes: Set<String> = ["bundle", "framework", "appex"]
        for child in rootChildren {
            let kind = child.pathExtension.lowercased()
            if packageTypes.contains(kind) { candidateBundles.append(child) }
            let name = child.lastPathComponent
            if name == "Frameworks" || name == "PlugIns" || name == "Resources" {
                for nested in directories(in: child)
                    where packageTypes.contains(nested.pathExtension.lowercased()) {
                    candidateBundles.append(nested)
                }
            }
        }

        for bundle in candidateBundles {
            for resourceDir in [bundle, bundle.appendingPathComponent("Resources", isDirectory: true)] {
                for item in directories(in: resourceDir) where item.pathExtension.lowercased() == "lproj" {
                    add(item.deletingPathExtension().lastPathComponent)
                }
            }
        }
        return found.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
}
