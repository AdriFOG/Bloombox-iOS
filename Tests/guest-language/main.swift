import Foundation

@main
struct BloomBoxGuestLanguageTests {
    static func main() throws {
        let fm = FileManager.default
        let app = fm.temporaryDirectory.appendingPathComponent("BloomBoxLanguageTests-" + UUID().uuidString, isDirectory: true)
        defer { try? fm.removeItem(at: app) }
        try fm.createDirectory(at: app, withIntermediateDirectories: true)

        let plist: [String: Any] = [
            "CFBundleDevelopmentRegion": "en",
            "CFBundleLocalizations": ["en", "pt_BR", "Base", "not a valid locale!"]
        ]
        let bytes = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try bytes.write(to: app.appendingPathComponent("Info.plist"))

        let spanish = app.appendingPathComponent("es.lproj", isDirectory: true)
        let framework = app.appendingPathComponent("Frameworks/GameResources.framework/Resources/fr.lproj", isDirectory: true)
        let bundle = app.appendingPathComponent("Resources/Translation.bundle/de.lproj", isDirectory: true)
        try fm.createDirectory(at: spanish, withIntermediateDirectories: true)
        try fm.createDirectory(at: framework, withIntermediateDirectories: true)
        try fm.createDirectory(at: bundle, withIntermediateDirectories: true)

        let found = BloomBoxGuestLanguageCatalog.detect(in: app)
        assert(found == ["de", "en", "es", "fr", "pt-BR"], "Detected locales: \(found)")
        assert(!found.contains("Base"))
        assert(!found.contains("not a valid locale!"))
        assert(BloomBoxGuestLanguageCatalog.normalized("zh_Hant_TW") == "zh-Hant-TW")
        assert(BloomBoxGuestLanguageCatalog.normalized("../es") == nil)
        assert(BloomBoxGuestLanguageCatalog.preferredLanguages(for: "es-MX") == ["es-MX", "es"])
        assert(BloomBoxGuestLanguageCatalog.preferredLanguages(for: "zh-Hant-TW") == ["zh-Hant-TW", "zh-Hant", "zh"])
        assert(BloomBoxGuestLanguageCatalog.preferredLanguages(for: "") == [])
        assert(BloomBoxGuestLanguageCatalog.manualChoices.contains("es-MX"))
        assert(BloomBoxGuestLanguageCatalog.manualChoices.contains("es"))

        let external = fm.temporaryDirectory.appendingPathComponent("BloomBoxExternal-" + UUID().uuidString)
        defer { try? fm.removeItem(at: external) }
        try fm.createDirectory(at: external.appendingPathComponent("ru.lproj"), withIntermediateDirectories: true)
        try fm.createSymbolicLink(at: app.appendingPathComponent("GameResources.bundle"), withDestinationURL: external)
        assert(!BloomBoxGuestLanguageCatalog.detect(in: app).contains("ru"), "Must not follow symlinks")
        print("PASS: bounded language discovery, declared locales, nested bundles, safe manual options, fallback, symlink exclusion")
    }
}
