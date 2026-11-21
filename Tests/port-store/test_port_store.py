"""BloomBox Port Store contract checks; Xcode also compiles the actual Swift screens."""
from pathlib import Path

root = Path(__file__).resolve().parents[2]
store = (root / "LiveContainerSwiftUI/Views/BloomBox/BloomBoxPortStore.swift").read_text()
home = (root / "LiveContainerSwiftUI/Views/BloomBox/BloomBoxHomeScreen.swift").read_text()
installer = (root / "LiveContainerSwiftUI/Views/AppList/LCAppListView.swift").read_text()

# One general public catalog: none of the results are discarded by Husk tests.
assert "https://openportsgames.com/api/ports.json" in store
assert "feed.ports.filter { $0.isAndroid && $0.isValid }" in store
assert "https://raw.githubusercontent.com/AdriFOG/Bloombox-Remote-Systems/main/catalog/port-verifications.json" in store
assert 'feed.schema == "openportsgames/catalog"' in store
assert 'response.schema == "openportsgames/catalog"' in store

# A badge is issued by our own feed, tied to an exact port version.
assert "record.portVersion == version" in store
assert "feed.entries.allSatisfy(\\.isValid)" in store
assert "verifications = [:]" in store
assert "let state = catalog.verification(for: port)?.state" in store
assert 'state == "verified"' in store
assert 'state == "incompatible"' in store

# Source downloads are never blindly executed: selected official GitHub
# APK goes via existing installation confirmation, not a new guest installer.
assert "officialGitHubAPK(" in store
assert 'url.host?.lowercased() == "github.com"' in store
assert 'url.pathExtension.lowercased() == "apk"' in store
assert "port.sources ?? []" in store
assert 'Notification.Name("BloomBoxPortStoreAPKReady")' in store
assert 'Notification.Name("BloomBoxPortStoreAPKReady")' in installer
assert "handleURL(url: file)" in installer
assert "receivedIPA = BloomBoxReceivedIPA(url: url)" in installer
assert "if isAPK, let husk { Task { await importAPK(request.url, host: husk) } }" in installer

# Standalone built-in Store, launched from the Home, Library or widgets.
assert 'private static let portStoreKey = "manzana:portstore"' in home
assert "BloomBoxPortStore()" in home
assert "portStorePresented = true" in home
assert 'if key == Self.portStoreKey { return "Port Store" }' in home
assert 'updateWidget(widget.id) { $0.tapActionKey = Self.portStoreKey }' in home

print("PASS: OpenPortsGames general listing, version-pinned badges, APK confirmation, Home and widget routing")
