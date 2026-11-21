"""Regression checks: iOS ports discovery is isolated from Android and the old IPA App Store."""
from pathlib import Path

root = Path(__file__).resolve().parents[2]
provider = (root / "LiveContainerSwiftUI/Views/BloomBox/BloomBoxPortStore.swift").read_text()
ios = (root / "LiveContainerSwiftUI/Views/BloomBox/BloomBoxIOSPortsSection.swift").read_text()
store = (root / "LiveContainerSwiftUI/Views/BloomBox/BloomBoxRemoteStores.swift").read_text()
app_list = (root / "LiveContainerSwiftUI/Views/AppList/LCAppListView.swift").read_text()

assert 'iosPorts = catalog.filter { $0.platforms?.contains("ios") == true }' in provider
assert 'ports = catalog.filter { $0.platforms?.contains("android") == true }' in provider
assert 'result.schema == "openportsgames/catalog"' in provider
assert 'result.version == 2' in provider
assert "static let shared = BloomBoxPortCatalog()" in provider

assert 'BloomBoxIOSPortsSection(search: query)' in store
assert 'Text("iPhone").tag(3)' in store
assert 'case 3: base = []' in store
assert 'BloomBoxAppStore(apps:' not in ios
assert 'BloomBoxAppCatalog.shared' in store
assert 'if section == 3 {' in store

assert 'port.downloads ?? []' in ios
assert 'port.sourceURL' in ios
assert 'item.safeURL' in ios
assert 'port.coverURL' in ios
assert '.frame(width: 82, height: 106)' in ios
assert 'No direct IPA installation without a reviewed release and SHA-256' in ios
assert 'NSNotification.InstallAppNotification' not in ios
assert 'BloomBoxPortStoreInstallAPK' not in ios
assert 'func importAPK(' in app_list
print("PASS: iPhone discovery is iOS-only and does not change existing IPA install policy or Android Store.")
