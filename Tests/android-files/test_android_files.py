"""Contracts for the first read-only, per-game Husk browser.

These tests guard routing and containment; they are not on-device proof of Husk access.
"""
from pathlib import Path

root = Path(__file__).resolve().parents[2]
files = (root / "LiveContainerSwiftUI/Views/BloomBox/BloomBoxFilesView.swift").read_text()
home = (root / "LiveContainerSwiftUI/Views/BloomBox/BloomBoxHomeScreen.swift").read_text()
original_store = (root / "LiveContainerSwiftUI/Views/BloomBox/BloomBoxFileStore.swift").read_text()

for token in (
    "private enum BloomBoxHuskFiles",
    'host.bundleIdentifier',
    '$0.bundleIdentifier == "com.husk.app"',
    "host.appInfo.isLocked",
    "sharedModel.isHiddenAppUnlocked",
    "BloomBoxProfileStore.active",
    'appendingPathComponent("TranslationLayer"',
    'appendingPathComponent("Shared Storage"',
    'appendingPathComponent("package.txt")',
    'appendingPathComponent("label.txt")',
    'appendingPathComponent("icon.png")',
    'contents.contains(where: { $0.pathExtension.lowercased() == "apk" })',
    "safeFolder.path.hasPrefix(safeRoot.path +",
    "isSymbolicLink != true",
    "FileManager.default.isReadableFile",
    "NavigationLink(destination: BloomBoxHuskFolderView(",
    "case .missing:",
    "case .locked:",
    "case .inaccessible(let reason):",
    "case .ready(let container, let games, let shared):",
    "Emulador Android · Instalador de APK",
    "https://itslevii.dev/docs/install",
    "https://github.com/Leviidev/Husk/releases",
    "Primera versión de solo lectura",
    "bloombox.files.android.entry",
):
    assert token in files, f"Missing Android browser contract: {token}"

new_browser = files.split("// MARK: - Husk files: read-only first milestone.", 1)[1]
for unsafe in ("FileManager.default.removeItem", "FileManager.default.moveItem",
               "FileManager.default.copyItem", "FileManager.default.createDirectory"):
    assert unsafe not in new_browser, f"Android browser must be read-only: {unsafe}"

for token in (
    'private static let filesKey = "manzana:files"',
    'private static let androidFilesKey = "manzana:androidfiles"',
    "@State private var filesPresented = false",
    "@State private var androidFilesPresented = false",
    ".sheet(isPresented: $filesPresented) { BloomBoxFilesView() }",
    ".sheet(isPresented: $androidFilesPresented) { BloomBoxAndroidFilesView() }",
    "else if key == Self.androidFilesKey { androidFilesPresented = true }",
    'key == Self.androidFilesKey ? "folder.badge.gearshape"',
):
    assert token in home, f"Missing Home shortcut contract: {token}"

assert 'appendingPathComponent("BloomBox Files"' in original_store
assert 'appendingPathComponent("Manzana Files"' in original_store
assert "typealias ManzanaFilesView = BloomBoxFilesView" in files
print("PASS: read-only Husk explorer, exact-container game mapping and visible Home links")
