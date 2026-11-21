"""Contracts for Husk browsing and opt-in OBB/data imports.

These are structural regression checks, not proof of on-device file-provider behavior.
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
    "Explora archivos e importa datos de juegos",
    "bloombox.files.android.entry",
):
    assert token in files, f"Missing Android browser contract: {token}"

# Navigation does not mutate the game; only the explicit importer may write.
readonly_browser = files.split("// MARK: - Husk files: read-only first milestone.", 1)[1].split(
    "// MARK: - Native Husk data import", 1
)[0]
for unsafe in ("FileManager.default.removeItem", "FileManager.default.moveItem",
               "FileManager.default.copyItem", "FileManager.default.createDirectory"):
    assert unsafe not in readonly_browser, f"Navigation must be read-only: {unsafe}"

writer = files.split("// MARK: - Native Husk data import", 1)[1]
for expected in (
    "private enum BloomBoxHuskImportMode",
    "case obb",
    "case androidData",
    "case privateFiles",
    "case shared",
    'case .obb: return ["obb"]',
    'return ["sdcard", "Android", "data", package]',
    'return ["files"]',
    'sharedRoot.lastPathComponent == "Shared Storage"',
    "BloomBoxHuskPathPolicy.scopedURL(",  # fixed-root relative import paths
    "let targetParts = try relativeParts(for: game, mode: mode)",
    "isSymbolicLink == true",
    "source.startAccessingSecurityScopedResource()",
    "source.stopAccessingSecurityScopedResource()",
    "NSFileCoordinator().coordinate(readingItemAt:",
    "BloomBoxArchive.unpack(source: readable, destination: prepared)",
    "fm.fileExists(atPath: target.path)",
    "result.skipped += 1",
    "fm.copyItem(at: item, to: target)",
    "created.reversed()",
    "MultitaskManager.isUsing(container: containerID)",
    "LCSharedUtils.getContainerUsingLCScheme(withFolderName: containerID)",
    "BloomBoxHuskGameView(",
    'fileImporter(isPresented: $picking, allowedContentTypes: [.item, .folder]',
    "Importar · Conservar archivos existentes",
):
    assert expected in writer or expected in files, f"Missing safe importer contract: {expected}"
assert "FileManager.default.removeItem(at: game.directory)" not in writer
assert "FileManager.default.removeItem(at: target)" not in writer
# The old raw absolute-path comparison rejected every real Husk import.
# Never bring it back while importing app-constructed OBB/data destinations.
assert "RUTA-02" not in writer
assert "try verify(target, in: root)" not in writer
assert "static func scopedURL(in root:" not in writer
assert 'components: targetParts + [file.lastPathComponent]' in writer
assert 'copyContents(from: content, into: root, components: targetParts' in writer
assert 'return try checkedURL(in: root,' in writer
assert 'static func scopedURL(in root:' in original_store
assert 'if isSymbolicLink(current)' in original_store


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
print("PASS: Husk browser, scoped OBB/data importer, conflict protection, and Home links")
