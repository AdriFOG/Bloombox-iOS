"""Check stable learning-topic IDs and integration wiring without an iOS device."""
from pathlib import Path
import re
root = Path(__file__).resolve().parents[2]
views = root / "LiveContainerSwiftUI/Views"
bloom = views / "BloomBox"
tour = (bloom / "BloomBoxGuidedTour.swift").read_text()
host = (bloom / "BloomBoxLauncherRoot.swift").read_text()
home = (bloom / "BloomBoxHomeScreen.swift").read_text()
nova = (bloom / "BloomBoxNovaV2View.swift").read_text()
settings = (views / "Settings/LCSettingsView.swift").read_text()
topics = re.findall(r'\.init\("([a-z]+)",', tour)
assert len(topics) >= 22 and len(set(topics)) == len(topics), topics
assert topics[0] == "welcome"
destinations = set(re.findall(r'destination: "([a-z]+)"', tour))
handlers = set(re.findall(r'case "([a-z]+)":', host + home + nova))
assert destinations <= handlers, destinations - handlers
for key in ["library", "news", "dock"]:
    assert f'bloomBoxTourAnchor("{key}")' in nova
assert 'bloomBoxTourAnchor(key)' in home and 'bloomBoxTourAnchor(key)' in nova
assert 'onDismiss:' in host and 'tourAfterWizard' in host
assert 'BloomBoxTourEvents.center' in settings
assert 'BloomBoxTourSeenTopicsV1' in host
assert 'launchLibraryKey(' not in tour and 'requestLaunch(' not in tour
print(f"PASS: {len(topics)} bilingual topics, {len(destinations)} wired destinations")

# Mandatory guide has its own persisted progress; optional dismissal cannot
# complete it. The launcher controls hit testing, not a transparent overlay.
assert 'basicIDs = ["library", "install", "context", "modules", "jit", "settings"]' in tour
assert 'Self("basicfinish"' in tour
assert 'BloomBoxBasicGuideStateV2' in host and 'BloomBoxBasicGuideStepV2' in host
assert 'basicGuideState = 1' in host and 'basicGuideState = 2' in host
assert 'startBasicGuideIfNeeded()' in host
assert '.allowsHitTesting(!tourBlocksInput)' in host
assert '.allowsHitTesting(tourBlocksInput)' in host
assert 'Rectangle().fill(Color.clear).contentShape(Rectangle())' not in tour
assert 'guard !requiresBasicGuide else { return }' in host
assert 'if !required {' in tour
print("PASS: required quick start, persistent progress and touch-safe dismissal")

assert 'path.addEllipse(in: hole)' in tour and 'spotlightAction(hole)' in tour
assert 'onLongPressGesture(minimumDuration: 0.6)' in tour
assert 'BloomBoxTourEvents.focus' in home and 'BloomBoxTourEvents.focus' in nova
assert 'finishBasicVisit' in host and 'BloomBoxTourEvents.returned' in host
assert 'basicVisit = destination' in host
assert 'store: UserDefaults.standard' in host
print("PASS: circular spotlight, hands-on guide and return handling")

lab = (bloom / "BloomBoxLab.swift").read_text()
app = (root / "LiveContainerSwiftUI/App/LiveContainerSwiftUIApp.swift").read_text()
assert "labTaps >= 7" in settings
assert 'confirmation != "RESET"' in lab
assert "BloomBoxLabReset.prepareForHostStart()" in app
assert app.index("BloomBoxLabReset.prepareForHostStart()") < app.index("let fm = FileManager()")
assert '["Applications", "Data", "Tweaks", "BloomBox Files", "Manzana Files"]' in lab
assert 'resolved.path == target.standardizedFileURL.path' in lab
adapter = (views / "BloomBoxAdapters/LiveContainerPreferencesAdapter.swift").read_text()
assert 'guard !hasSharedStorage, LCSharedUtils.appGroupID() == "Unknown"' in adapter
assert 'LiveContainerPreferencesAdapter.privateFallbackDefaults' in lab
assert "LCUtils" not in lab and "LCSharedUtils" not in lab and "LCPath" not in lab
assert "removePersistentDomain" not in lab and "SecItemDelete" not in lab
assert "defaults.removeObject(forKey: pendingKey)" in lab
print("PASS: secret Lab, private reset, explicit confirmation and shared storage protection")

assert '.task(id: shouldActivateBasicGuide)' in host
assert 'basicVisit == nil && !tourVisible' in host
inspector = (bloom / "BloomBoxInspector.swift").read_text()
native = (root / "LiveContainer/LCBootstrap.m").read_text()
model = (root / "LiveContainerSwiftUI/Models/LCAppModel.swift").read_text()
assert 'BloomBoxInspectorView' in settings and 'BloomBoxInspectorStore.begin' in model
assert 'BBInspectorMark("native.main.enter")' in native and 'native.memory.sample' in native
assert 'O_NOFOLLOW' in native and 'prefix(40)' in inspector
assert 'ShareLink(item: exportURL)' in inspector and 'try report(id).write' in inspector
print("PASS: isolated inspector, bounded native logging and persistent guide activation")
