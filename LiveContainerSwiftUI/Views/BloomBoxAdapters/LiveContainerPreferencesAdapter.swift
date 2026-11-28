import Foundation

/// Translate BloomBox's legacy storage keys to LiveContainer's current app
/// group without changing the suite or migrating data accidentally.
/// Future upstream updates only need to change this bridge.
enum LiveContainerPreferencesAdapter {
    static var defaults: UserDefaults {
        LCUtils.appGroupUserDefault
    }

    // The reset engine may delete only host-private storage. A known or
    // ambiguous app group is always treated as shared, even if inaccessible.
    static var privateDocuments: URL { LCPath.docPath }

    static var hasSharedStorage: Bool {
        let privateDocs = LCPath.docPath.standardizedFileURL.resolvingSymlinksInPath()
        let groupDocs = LCPath.lcGroupDocPath.standardizedFileURL.resolvingSymlinksInPath()
        return privateDocs.path != groupDocs.path || LCSharedUtils.appGroupPath() != nil ||
            LCSharedUtils.appGroupID() != "Unknown"
    }

    static var privateFallbackDefaults: UserDefaults? {
        guard !hasSharedStorage, LCSharedUtils.appGroupID() == "Unknown" else { return nil }
        return defaults
    }
}
