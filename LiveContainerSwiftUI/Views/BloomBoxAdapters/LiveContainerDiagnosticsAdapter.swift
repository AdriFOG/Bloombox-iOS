import Foundation

/// Keep new BloomBox diagnostics independent of LiveContainer's current
/// application-group path implementation. If upstream changes its container
/// layout, only this adapter needs updating.
enum LiveContainerDiagnosticsAdapter {
    static var inspectorSharedDirectory: URL? {
        LCSharedUtils.appGroupPath()?.appendingPathComponent("Library/BloomBoxInspector", isDirectory: true)
    }

    static func inspectorApps(_ apps: [LCAppModel]) -> [BloomBoxInspectorApp] {
        apps.compactMap { app in
            guard !(app.appInfo is BuiltInSideStoreAppInfo),
                  let key = app.appInfo.relativeBundlePath, !key.isEmpty,
                  let path = app.appInfo.bundlePath() else { return nil }
            return BloomBoxInspectorApp(id: key, name: app.appInfo.displayName() ?? "App",
                bundle: URL(fileURLWithPath: path, isDirectory: true),
                jit: app.appInfo.isJITNeeded, shared: app.appInfo.isShared)
        }
    }

    static var sharedDirectory: URL? {
        // The app group can be temporarily unavailable during first launch or
        // broken signing. Host breadcrumbs must remain usable in that case.
        let root = LCSharedUtils.appGroupPath() ??
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return root?.appendingPathComponent("Library/BloomBoxDiagnostics", isDirectory: true)
    }
}
