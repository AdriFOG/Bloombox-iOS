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

assert 'settings["orientation"] = mode' in home
assert "LiveBoardOrientation.beginGuest(appKey: appKey" in home
assert "LiveBoardOrientation.endGuest(appKey: appKey" in home
assert "containerFolder: container.folderName" in home
assert 'try await host.runApp(multitask: true, containerFolderName: game.containerFolder)' in home
assert "waitForHuskDebugger(appName:" in home
assert '"debugger_attached", "awaiting_guest", "completed"' in home
assert "max(0, 3 - Date().timeIntervalSince(started))" in home
assert "AppSceneViewController.bloomBoxSendURL(" in home
assert "huskStartingGame" in home
assert "return success" not in home.split("private func openHuskGame(", 1)[1].split("@ViewBuilder private func huskMenu", 1)[0]

assert "+ (BOOL)bloomBoxSendURL:" in scene_h
assert "[self openURLScheme:" not in scene_m  # only a controller should deliver to its own scene
assert "[target openURLScheme:urlString]" in scene_m
assert "strongToWeakObjectsMapTable" in scene_m
assert "BloomBoxGuestSceneDidExit" in scene_m
print("PASS: Husk APK import, orientation, staged debugger and deep-link contract")
