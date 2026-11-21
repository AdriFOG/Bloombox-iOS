"""Regression contract for BloomBox's Husk APK and staged JIT guest launch."""
from pathlib import Path

root = Path(__file__).resolve().parents[2]
archive = (root / "LiveContainerSwiftUI/Utilities/BloomBoxArchive.m").read_text()
home = (root / "LiveContainerSwiftUI/Views/BloomBox/BloomBoxHomeScreen.swift").read_text()
scene_h = (root / "MultitaskSupport/AppSceneViewController.h").read_text()
scene_m = (root / "MultitaskSupport/AppSceneViewController.m").read_text()

validator = archive.split("+ (BOOL)validateAPK:", 1)[1].split("+ (BOOL)packDirectory:", 1)[0]
assert "archive_read_support_format_zip" in validator
assert "archive_read_data_skip(reader)" in validator
assert "AndroidManifest.xml" not in validator.split("struct archive *reader", 1)[1]
assert "archive_entry_filetype(entry) != AE_IFDIR" in validator
assert "looksLikeNonemptyAPKZIP(source)" in validator
assert "unsigned int entries" in archive
assert "tailSize" in archive and "memcmp(header" in archive
assert "excessiveEntries" in validator

assert 'settings["orientation"] = mode' in home
assert "LiveBoardOrientation.beginGuest(appKey: appKey" in home
assert "LiveBoardOrientation.endGuest(appKey: appKey" in home
assert "containerFolder: container.folderName" in home
assert 'try await host.runApp(multitask: true, containerFolderName: game.containerFolder)' in home
assert "waitForHuskDebugger(" in home
assert '"debugger_attached", "awaiting_guest", "completed"' in home
assert "max(0, 3 - Date().timeIntervalSince(started))" in home
assert "AppSceneViewController.bloomBoxSendURL(" in home
assert "huskStartingGame" in home
assert "return success" not in home.split("private func openHuskGame(", 1)[1].split("@ViewBuilder private func huskMenu", 1)[0]

assert "+ (BOOL)bloomBoxSendURL:" in scene_h
assert "[target openURLScheme:urlString]" in scene_m
assert "strongToWeakObjectsMapTable" in scene_m
assert "BloomBoxGuestSceneDidExit" in scene_m
# Android game icons must expose a real, confirmed uninstall. iOS guests keep
# their existing LiveContainer uninstall path.
assert "pendingHuskUninstall = game" in home
assert 'Button(englishUI ? "Uninstall app" : "Desinstalar app"' in home
assert 'role: .destructive' in home.split("private func uninstallHuskGame(", 1)[0]
assert "private func uninstallHuskGame(_ game: HuskGame)" in home
uninstall = home.split("private func uninstallHuskGame(", 1)[1].split("@ViewBuilder private func huskMenu", 1)[0]
for guardrail in ("!host.isAppRunning", "huskLaunchingKey == nil", "huskStartingGame == nil",
                  "current.directory.standardizedFileURL", "target.deletingLastPathComponent() == root",
                  "properties.isSymbolicLink != true", "FileManager.default.removeItem(at: target)",
                  "refreshHuskGames()", "layout.removePlacement(game.key)", "reconcile()"):
    assert guardrail in uninstall, f"Missing safe APK uninstall behavior: {guardrail}"
assert '"The APK, its settings, and all local game data stored in Husk will be permanently deleted.' in home

guest = (root / "LiveContainerSwiftUI/Models/LCAppModel.swift").read_text()
assert "if wantsJIT, let fn = currentDataFolder" in guest
assert "for _ in 0..<16" in guest
assert "try await Task.sleep(nanoseconds: 250_000_000)" in guest
assert "if LCSharedUtils.getContainerUsingLCScheme(withFolderName: fn) == nil { break }" in guest
assert 'throw "Otro LiveContainer está usando los datos de esta app.' in guest
assert 'performGuest(.uninstall(key: LiveContainerHomeAdapter.key(app))' in home
print("PASS: Husk APK import, orientation, staged debugger, deep-link and uninstall contract")
