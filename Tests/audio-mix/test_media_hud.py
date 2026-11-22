#!/usr/bin/env python3
"""Contract: side-by-side MediaBloom volume HUD in BloomBox guests.

The native system's volume overlay and physical button action must remain
untouched. The extra HUD is observed using public AVAudioSession KVO only.
"""
from pathlib import Path

hud = Path("LiveContainer/BloomBoxMediaVolumeHUD.inc").read_text()
boot = Path("LiveContainer/LCBootstrap.m").read_text()
mix = Path("LiveContainer/BloomBoxAudioMix.inc").read_text()

assert '#include "BloomBoxMediaVolumeHUD.inc"' in boot
assert boot.count("    BBHUDInstallForGuestIfEnabled();") == 2
assert 'BBAudioMixEnabledForCurrentGuest()' in hud
assert 'AVAudioSession' in hud
assert 'forKeyPath:@"outputVolume"' in hud
assert 'NSKeyValueObservingOptionNew' in hud
assert 'NSKeyValueChangeNewKey' in hud
assert 'UIApplicationStateActive' in hud
assert 'UISceneActivationStateForegroundActive' in hud
assert 'canBecomeKeyWindow { return NO; }' in hud
assert 'BBHUDWindow.hidden = NO;' in hud
assert 'BBHUDHideAfterDelay(4)' in hud
assert 'BBHUDWindow.windowLevel = UIWindowLevelNormal + 90;' in hud
assert 'MediaBloomAudioGainV1.' in hud
assert 'com.google.ios.youtubemusic' in hud
assert 'com.google.ios.youtube' in hud
assert 'BBHUDYTMusicID' in hud and 'BBHUDYouTubeID' in hud
assert 'setFloat:bounded forKey:key' in hud
assert 'setFloat:bounded forKey:key' in hud
assert 'self.slider.maximumValue = 1' in hud
assert 'self.slider.minimumValue = 0' in hud
assert '[lcSharedDefaults synchronize]' in hud
assert 'BBHUDWindow' in hud
assert 'if (!BBAudioMixEnabledForCurrentGuest()) return;' in hud
assert 'if (isSideStore || !lcSharedDefaults || lcGuestAppId.length == 0)' in mix

# Neither root iOS volume control nor AVAudioSession activation can be
# manipulated; only the selected MediaBloom guest's App Group gain key.
for unsafe in ("MPVolumeView", "setOutputVolume:", "setActive:", "makeKeyAndVisible",
               "AVSystemController", "SystemVolumeDidChangeNotification",
               "_routeChange", "AudioServicesPlaySystemSound"):
    if unsafe == "makeKeyAndVisible":
        # Only comment refers to makeKeyAndVisible to explicitly reject it.
        assert '[BBHUDWindow makeKeyAndVisible]' not in hud
    else:
        assert unsafe not in hud, unsafe

print("PASS: opt-in extra HUD, public KVO, native volume unchanged, scoped shared gain keys")
