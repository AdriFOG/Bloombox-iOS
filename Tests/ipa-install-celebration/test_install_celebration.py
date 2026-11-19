#!/usr/bin/env python3
"""Guard the genuine BloomBox installation celebration and persistent gifts."""
from pathlib import Path
import base64

root = Path(__file__).resolve().parents[2]
host = (root / "LiveContainerSwiftUI/Views/AppList/LCAppListView.swift").read_text()
home = (root / "LiveContainerSwiftUI/Views/BloomBox/BloomBoxHomeScreen.swift").read_text()
visuals = (root / "LiveContainerSwiftUI/Views/BloomBox/BloomBoxHomeChrome.swift").read_text()
brand = (root / "Scripts/brand-bloombox-final-ipa.py").read_text()

assert "beginInstallationCelebration()" in host
assert "finishInstallationCelebration()" in host
assert "installationActuallySucceeded" in host
assert "5 - Date().timeIntervalSince(installationCelebrationStarted)" in host
assert 'defaults.set(json, forKey: "BloomBoxPendingGiftKeysV1")' in host
assert "LiveContainerHomeAdapter.key(newAppModel)" in host
assert "installationCelebrationFinished" in host
assert "installProgress: Double(installProgressPercentage)" in host

assert 'BloomBoxHomeInstallationNotice(progress: installProgress,' in home
assert 'BloomBoxHomeGiftIcon(name: title(key)' in home
assert 'unopenedGiftKeys.contains(key)' in home
assert 'revealGift(key)' in home

assert "BloomBoxSleepingKirbyPlayer(animated: true)" in visuals
assert 'forResource: "BloomBoxSleepingKirby", withExtension: "gif"' in visuals
assert "animationImages = images" in visuals
assert "repeatForever(autoreverses: true)" in visuals
assert 'Text("\\(Int(amount * 100))%")' in visuals
assert "BloomBoxHomeGiftIcon" in visuals
assert "reduceMotion" in visuals
assert 'gif_target = ROOT + "BloomBoxSleepingKirby.gif"' in brand
assert "out.writestr(gif_target, gif_data)" in brand
gif = base64.b64decode((root / "Resources/Branding/BloomBoxSleepingKirby.gif.b64").read_text().strip(), validate=True)
assert gif[:6] == b"GIF89a"
assert gif[-1:] == b";"
assert len(gif) > 5000
assert gif.count(b"\\x21\\xf9\\x04") >= 6, "Expected six animated frames"

print("PASS: progress is real, minimum 5s on success, gifts persist, GIF is bundled")
