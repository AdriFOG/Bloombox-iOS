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
    'root.appendingPathComponent("obb"',
    'root.appendingPathComponent("sdcard/Android/data/" + package',
    'root.appendingPathComponent("files"',
    'sharedRoot.lastPathComponent == "Shared Storage"',
    "safeFolder.path",  # path confinement and root-bound traversal
    "try verify(target, in: root)",
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
