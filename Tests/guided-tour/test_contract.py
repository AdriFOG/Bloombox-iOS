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
