#!/usr/bin/env python3
"""Source contract tests for BloomBox 3.3 stability improvements."""
from pathlib import Path

root = Path(__file__).resolve().parents[2]
ui = root / "LiveContainerSwiftUI" / "Views"
home = (ui / "BloomBox/BloomBoxHomeScreen.swift").read_text()
news = (ui / "BloomBox/BloomBoxNewsPage.swift").read_text()
gamebox = (ui / "BloomBox/BloomBoxGameBoxV2Screen.swift").read_text()
host = (ui / "AppList/LCAppListView.swift").read_text()
visuals = (ui / "BloomBox/BloomBoxLauncherVisuals.swift").read_text()
files = (ui / "BloomBox/BloomBoxFilesView.swift").read_text()
folder = (ui / "BloomBox/BloomBoxFolderPanel.swift").read_text()
tabs = (ui / "LCTabView.swift").read_text()

assert "var openInstall: () -> Void" in news and "bloombox.news.install" in news
assert "openInstall: openInstall" in home
assert "UTType(importedAs: \"com.android.package-archive\")" in host
assert "types: [.ipa, .tipa," in host

assert 'BloomBoxGameBoxV2HiddenApps' in gamebox
assert 'showHiddenApps.toggle()' in gamebox
assert 'setHidden(app, hidden: !hiddenIDs.contains(key(app)))' in gamebox
assert 'showHiddenApps || !hiddenIDs.contains' in gamebox
assert 'gameBoxInstalledAPKs' in host
assert 'Documents/TranslationLayer' in host
assert 'names.contains(where: { $0.lowercased().hasSuffix(".apk") })' in host
assert 'BloomBoxPendingHuskLaunchKey' in host and 'BloomBoxPendingHuskLaunchKey' in home
assert 'launchLibraryKey(pendingKey)' in home, "Android GameBox launch must pass through Home/Husk"

assert 'BloomBoxProfileThemeBackdrop().ignoresSafeArea()' in files
assert 'if #available(iOS 16.0, *)' in files
assert 'scrollContentBackground(.hidden)' in files
assert 'blur(radius: openFolder != nil ? 24' in home
assert 'Color.black.opacity(0.045)' in folder
assert '.glassEffect(.clear.interactive(false), in: shape)' in visuals

assert 'BloomBoxTemporaryStorage.cleanupIfNeeded()' in tabs
assert 'Timer.publish(every: 600' in tabs
print("PASS BloomBox 3.3 presentation, installation routing and storage contracts")
