"""Regression contracts for Husk engine discovery and user-controlled file editing.

These check source wiring; Foundation tests exercise real path construction.
"""
from pathlib import Path

base = Path(__file__).resolve().parents[2]
files = (base / "LiveContainerSwiftUI/Views/BloomBox/BloomBoxFilesView.swift").read_text()
store = (base / "LiveContainerSwiftUI/Views/BloomBox/BloomBoxFileStore.swift").read_text()
home = (base / "LiveContainerSwiftUI/Views/BloomBox/BloomBoxHomeScreen.swift").read_text()

for expected in (
    "private enum BloomBoxHuskFiles",
    '$0.bundleIdentifier == "com.husk.app"',
    "BloomBoxProfileStore.active",
    'appendingPathComponent("TranslationLayer"',
    'appendingPathComponent("Shared Storage"',
    'appendingPathComponent("package.txt")',
    'appendingPathComponent("label.txt")',
    'appendingPathComponent("icon.png")',
    "case .missing:",
    "case .locked:",
    "case .inaccessible(let reason):",
    "case .ready(let container, let games, let shared):",
    "Emulador Android · Instalador de APK",
    "https://itslevii.dev/docs/install",
    "bloombox.files.android.entry",
    "private struct BloomBoxHuskGameView",
    "BloomBoxHuskRuntimeScanner.destinations(",
    "BloomBoxHuskRuntimeScanner.preferredRuntime(",
    "Elige una carpeta existente abajo.",
    "private struct BloomBoxHuskFolderView",
    "createFolder()",
    "renameSelected()",
    "deleteSelected()",
    'Image(systemName: "folder.badge.plus")',
    "FileManager.default.moveItem(at: item, to: renamed)",
    "FileManager.default.removeItem(at: item)",
    "BloomBoxHuskDataImport.installDirect(",
    "replaceExisting: replaced",
    "replaceExisting: replace",
    "startAccessingSecurityScopedResource()",
    "stopAccessingSecurityScopedResource()",
    "NSFileCoordinator().coordinate(",
    "BloomBoxArchive.unpack(source: readable, destination: contents)",
    "try fm.replaceItemAt(target, withItemAt: temp,",
    "try fm.copyItem(at: entry, to: target)",
    "try BloomBoxHuskPathPolicy.relativeComponents(",
):
    assert expected in files, f"Missing Android Files/editing contract: {expected}"

for expected in (
    "enum BloomBoxHuskRuntimeScanner",
    '"java-data", "ue4-data", "unity-data", "cocos-data"',
    '"minecraft-data", "sdl-data", "gta-data", "godot-data"',
    '"report.json"',
    'case "Unreal Engine": return "ue4-data"',
    'if engine == "Unity 6" { return "java-data" }',
    'case "Minecraft": return "minecraft-data"',
    'case "Python", "Java", "libGDX", "React Native", ".NET / Xamarin", "Flutter"',
    "existingPath(runtime,",
    'label: name + " · Android/data/files"',
    'label: name + " · Android/data"',
    'label: name + " · Android/obb"',
    'DEST-03: no se encontró la carpeta de Husk.',
    "static func scopedURL(in root:",
    "if isSymbolicLink(current)",
):
    assert expected in store or expected in files, f"Missing engine-scanning contract: {expected}"

# The previous importer constructed fake gameRoot/obb and gameRoot/sdcard
# paths regardless of engine. This is gone; only real folders can be targeted.
assert "private enum BloomBoxHuskImportMode" not in files
assert "static func destination(for game:" not in files
assert "makeTarget(root: root, components: targetParts)" not in files
assert 'options: [.skipsHiddenFiles]' not in files.split("static func files(in folder:", 1)[1].split("struct BloomBoxAndroidFilesView", 1)[0]
assert 'static func installDirect(' in files
assert "fileExists(atPath: targetRoot.path)" not in files  # must be existing folder via isDirectory
assert "Never overwrite existing saves" not in files  # explicit user replacement now available

for expected in (
    'private static let filesKey = "manzana:files"',
    'private static let androidFilesKey = "manzana:androidfiles"',
    ".sheet(isPresented: $androidFilesPresented) { BloomBoxAndroidFilesView() }",
):
    assert expected in home, f"Missing Home shortcut: {expected}"

assert 'appendingPathComponent("BloomBox Files"' in store
assert 'appendingPathComponent("Manzana Files"' in store
assert "typealias ManzanaFilesView = BloomBoxFilesView" in files

print("PASS: Husk detects engine folders, imports to existing destinations, and exposes editing controls")
