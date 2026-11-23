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
# Regression checks from the first on-device install test:
# Same-process updates must create visible gifts without a relaunch.
assert 'Notification.Name("BloomBoxNewInstallGiftCreated")' in host
assert 'NotificationCenter.default.post(' in host
assert 'NotificationCenter.default.publisher(for:' in home
assert 'refreshNewInstallGift(notification)' in home
assert 'if giftKeysJSON != current { giftKeysJSON = current }' in home
# The installer must finish registering apps on the main actor, not dispatch
# the registration later after its success screen completes.
assert 'await MainActor.run {\n            if let appToReplace {' in host
assert '.onChange(of: sharedModel.apps.map { LiveContainerHomeAdapter.key($0) })' in home
assert 'DispatchQueue.main.async { reconcile() }' in home
# Home must use the live guest list; the native sorting snapshot can lag.
# External/embedded SideStore installations are written to Applications/
# outside the installer's current SwiftUI state. Scan both roots without
# restarting or recreating existing guest models.
assert 'private func refreshInstalledGuestsFromDisk()' in host
assert '(LCPath.bundlePath, false)' in host
assert '(LCPath.lcGroupBundlePath, true)' in host
assert 'guard !knownFolders.contains(key)' in host
assert 'sharedModel.apps.append(model)' in host
assert 'refreshInstalledGuestsFromDisk()' in host
assert 'Timer.publish(every: 1.5, on: .main, in: .common)' in host
assert 'if phase == .active { refreshInstalledGuestsFromDisk() }' in host
assert 'private var currentGuests: [LCAppModel]' in home
assert 'sharedModel.apps + apps.filter { LiveContainerHomeAdapter.isEmbeddedSigner($0) }' in home
assert 'LiveContainerHomeAdapter.visibleKeys(currentGuests)' in home
assert 'LiveContainerHomeAdapter.modelsByKey(currentGuests)' in home
assert 'sharedModel.apps + (builtInSideStore.map { [$0] } ?? [])' in host
# The APK installer now uses the same persistent gift reveal and immediate refresh.
assert 'let (installedID, freshAPK) = try await Task.detached' in host
assert 'if freshAPK {' in host
assert 'let key = "husk/" + container.folderName + "/" + installedID' in host
assert 'HuskGame(key: "husk/" + container.folderName + "/" + id' in home
assert 'Notification.Name("BloomBoxHuskLibraryChanged")' in host
assert home.count('if unopenedGiftKeys.contains(key) && !editing') >= 2
assert 'Notification.Name("BloomBoxGuestSceneDidExit")' in home
# The wizard's per-profile favorite color drives the full progress bar.
assert 'accentColor: profileAccent' in home
assert 'let accentColor: Color' in visuals
assert 'accentColor.opacity(0.55)' in visuals
assert 'accentColor.opacity(0.20)' in visuals
# Gift shakes periodically, only while shown, respecting Reduce Motion.
assert '.task(id: reduceMotion)' in visuals
assert 'rattling = true' in visuals
assert '2_700_000_000' in visuals
# No Welcome replay when the app switcher simply resumes the process.
launcher = (root / "LiveContainerSwiftUI/Views/BloomBox/BloomBoxLauncherRoot.swift").read_text()
assert 'BloomBoxWelcomeLaunchSession.hasShownInitialGreeting' in launcher
assert 'if phase == .background {' in launcher
assert 'if phase == .active {' in launcher
assert 'showProfileIntro()' in launcher
assert 'guard !BloomBoxWelcomeLaunchSession.hasShownInitialGreeting else { return }' in launcher
assert 'BloomBoxWelcomeLaunchSession.hasShownInitialGreeting = true' in launcher
assert 'gif_target = ROOT + "BloomBoxSleepingKirby.gif"' in brand
assert "out.writestr(gif_target, gif_data)" in brand
gif = base64.b64decode((root / "Resources/Branding/BloomBoxSleepingKirby.gif.b64").read_text().strip(), validate=True)
assert gif[:6] == b"GIF89a"
assert gif[-1:] == b";"
assert len(gif) > 5000
assert gif.count(bytes([0x21, 0xf9, 0x04])) >= 6, "Expected six animated frames"

print("PASS: progress is real, minimum 5s on success, gifts persist, GIF is bundled")
