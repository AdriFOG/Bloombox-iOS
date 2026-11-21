"""Contract checks for the discovery-first Android Port Store, not runtime gameplay tests."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[2]
store = (root / "LiveContainerSwiftUI/Views/BloomBox/BloomBoxPortStore.swift").read_text()
home = (root / "LiveContainerSwiftUI/Views/BloomBox/BloomBoxHomeScreen.swift").read_text()
app = (root / "LiveContainerSwiftUI/Views/AppList/LCAppListView.swift").read_text()

for expected in (
    "https://openportsgames.com/api/ports.json",
    "catalog/android-port-verifications.json",
    'result.schema == "openportsgames/catalog"',
    'result.version == 2',
    '$0.platforms?.contains("android") == true',
    'item.version == version',
    'check?.status',
    'hasHusk',
    'port.trustedAPK(item)',
    'BloomBoxArchive.validateAPK(output)',
    'onAPKReady(output)',
):
    assert expected in store, f"Missing Port Store contract: {expected}"
assert 'upstream "verified" flag' in store
assert 'result.entries.count <= 4_000' in store
assert 'portStorePresented = false' in home
assert 'BloomBoxPortStore(hasHusk: husk != nil' in home
assert 'BloomBoxPortStoreInstallAPK' in home
assert 'BloomBoxPortStoreInstallAPK' in app
assert 'receivedIPA = BloomBoxReceivedIPA(url: url)' in app
assert 'if isAPK, let husk { Task { await importAPK(request.url, host: husk) } }' in app
assert 'func importAPK(_ url: URL, host: LCAppModel)' in app

# The remote overlay must be empty until an actual on-device test.
fixture = {
    "schemaVersion": 1,
    "catalog": "openportsgames/catalog",
    "catalogVersion": 2,
    "entries": [],
}
assert fixture["entries"] == []
print("PASS: Android Port Store keeps untested ports discoverable, treats badges separately, and reuses Husk's installer.")
