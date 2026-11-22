"""Files hub and iOS app-container regression contracts."""
from pathlib import Path
root = Path(__file__).resolve().parents[2]
files = (root / "LiveContainerSwiftUI/Views/BloomBox/BloomBoxFilesView.swift").read_text()
home = (root / "LiveContainerSwiftUI/Views/BloomBox/BloomBoxHomeScreen.swift").read_text()
profile = (root / "LiveContainerSwiftUI/Views/BloomBox/BloomBoxProfileVisuals.swift").read_text()
for token in (
    "struct BloomBoxFilesHubView: View",
    "struct BloomBoxIOSFilesView: View",
    "private struct BloomBoxIOSAppFilesView: View",
    '"bloombox.files.choose.ios"',
    '"bloombox.files.choose.android"',
    ".sheet(isPresented: $ios) { BloomBoxIOSFilesView() }",
    ".sheet(isPresented: $android) { BloomBoxAndroidFilesView() }",
    "BloomBoxProfileStore.active",
    "BloomBoxProfileStore.mapping(for: profile.id, appKey: key)",
    "app.uiContainers.first(where:",
    "($0.appIdentifier == nil || $0.appIdentifier == app.bundleIdentifier)",
    "root.path == expected.path",
    "LCPath.lcGroupDataPath : LCPath.dataPath",
    'sourceLabel: "iOS"',
    '"Share / Export"',
    "BloomBoxHuskPathPolicy.relativeComponents",
    "BloomBoxHuskDataImport.installDirect(",
):
    assert token in files, f"Missing scoped Files feature: {token}"
assert 'BloomBoxProfileContainerAdapter.containerForLaunch' not in files
assert '.sheet(isPresented: $newsFilesPresented) {\n            BloomBoxFilesHubView()' in home
assert '.sheet(isPresented: $androidFilesPresented) { BloomBoxFilesHubView() }' in home
assert 'if key == Self.androidFilesKey { return englishUI ? "Files" : "Archivos" }' in home
assert 'Color(red: 0.10, green: 0.11, blue: 0.22).opacity(0.97)' not in profile
assert '.background(.ultraThinMaterial,' in profile
print("PASS: glass profiles and selectable iOS/Android Files with scoped editing")
