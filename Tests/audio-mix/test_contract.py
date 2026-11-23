#!/usr/bin/env python3
"""Contract: only opted-in guest audio sessions mix with MediaBloom.

BloomBox and MediaBloom are independent installations. Only a supported
opted-in guest uses this policy; no global device volume or host session edits.
"""
from pathlib import Path
root = Path(".")
mix = (root/"LiveContainer/BloomBoxAudioMix.inc").read_text()
bootstrap = (root/"LiveContainer/LCBootstrap.m").read_text()
settings = (root/"LiveContainerSwiftUI/Views/AppList/AppSettings/LCAppSettingsView.swift").read_text()
menu = (root/"LiveContainerSwiftUI/Views/BloomBox/BloomBoxHomeContextMenu.swift").read_text()
home = (root/"LiveContainerSwiftUI/Views/BloomBox/BloomBoxHomeScreen.swift").read_text()
store = (root/"LiveContainerSwiftUI/Views/BloomBox/BloomBoxAudioMixStore.swift").read_text()
assert 'BloomBoxAudioMixEnabledV1.' in mix
assert 'BloomBoxAudioMixEnabledV1.' in store
assert 'if (isSideStore || !lcSharedDefaults || lcGuestAppId.length == 0)' in mix
assert 'if (!BBAudioMixEnabledForCurrentGuest()) return;' in mix
assert 'AVAudioSessionCategorySoloAmbient' in mix
assert 'AVAudioSessionCategoryAmbient' in mix
assert 'BBAudioDuckOthers | BBAudioInterruptSpokenAudio' in mix
assert 'setCategory:error:' in mix
assert 'setCategory:withOptions:error:' in mix
assert 'setCategory:mode:options:error:' in mix
assert 'setCategory:mode:routeSharingPolicy:options:error:' in mix
assert 'if (policy == 0 && BBAudioMixEnabledForCurrentGuest())' in mix
assert 'BBAudioMixInstallForGuestIfEnabled();' in bootstrap
assert bootstrap.count('BBAudioMixInstallForGuestIfEnabled();') == 2, "regular/LiveProcess paths required"
assert '#include "BloomBoxAudioMix.inc"' in bootstrap
assert 'BloomBoxSimultaneousAudioToggle(bundleID: model.bundleIdentifier)' in settings
assert '"Permitir audio simultáneo"' in settings
assert 'wrappedValue: false' in settings
assert 'let simultaneousAudioEnabled: Bool' in menu
assert 'let toggleSimultaneousAudio: () -> Void' in menu
assert 'actions.toggleSimultaneousAudio' in menu
assert 'BloomBoxAudioMixStore.setEnabled' in home
assert 'BloomBoxAudioMixStore.isEnabled' in home
assert 'LiveContainerPreferencesAdapter.defaults' in home
assert 'LCUtils.appGroupUserDefault' not in home
for disallowed in ("MPVolumeView", "setVolume:", "setOutputVolume:", "duckOthers | MixWithOthers"):
    assert disallowed not in mix, disallowed
print("PASS: scoped mix policy, all setters, off by default, both guest paths, UI and adapter boundary")
