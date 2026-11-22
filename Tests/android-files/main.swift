import Foundation

// Executable regression tests for the SAME path policy shipped in BloomBox.
// These use temporary local Husk-shaped directories; they never alter app data.
let fm = FileManager.default
let sandbox = fm.temporaryDirectory.appendingPathComponent("BloomBox-Husk-Paths-" + UUID().uuidString, isDirectory: true)
defer { try? fm.removeItem(at: sandbox) }

let root = sandbox.appendingPathComponent("Husk/Documents/TranslationLayer/test-game", isDirectory: true)
let sibling = sandbox.appendingPathComponent("Husk/Documents/TranslationLayer/test-game-sibling", isDirectory: true)
let elsewhere = sandbox.appendingPathComponent("outside", isDirectory: true)
try fm.createDirectory(at: root, withIntermediateDirectories: true)
try fm.createDirectory(at: sibling, withIntermediateDirectories: true)
try fm.createDirectory(at: elsewhere, withIntermediateDirectories: true)

func assertInside(_ candidate: URL, expected: [String], label: String) throws {
    let actual = try BloomBoxHuskPathPolicy.relativeComponents(of: candidate, under: root)
    try BloomBoxHuskPathPolicy.validateDestination(candidate, under: root)
    precondition(actual == expected, "\(label): got \(actual), expected \(expected)")
}
func assertOutside(_ candidate: URL, label: String) {
    do {
        try BloomBoxHuskPathPolicy.validateDestination(candidate, under: root)
        fatalError("\(label): unexpectedly accepted")
    } catch BloomBoxHuskPathPolicy.Failure.outsideRoot {
        // Correct: never let data escape the selected game's directory.
    } catch {
        fatalError("\(label): wrong failure \(error)")
    }
}

try assertInside(root, expected: [], label: "game root itself")
try assertInside(root.appendingPathComponent("obb", isDirectory: true),
                 expected: ["obb"], label: "missing OBB folder")
try assertInside(root.appendingPathComponent("sdcard/Android/data/com.bloombox.testapp", isDirectory: true),
                 expected: ["sdcard", "Android", "data", "com.bloombox.testapp"], label: "missing Android/data")
try assertInside(root.appendingPathComponent("files", isDirectory: true),
                 expected: ["files"], label: "private files")
try assertInside(root.appendingPathComponent("obb/main.1.com.bloombox.testapp.obb", isDirectory: false),
                 expected: ["obb", "main.1.com.bloombox.testapp.obb"], label: "OBB file")
let rootPathWithSlash = URL(fileURLWithPath: root.path + "/", isDirectory: true)
try assertInside(rootPathWithSlash.appendingPathComponent("obb", isDirectory: true),
                 expected: ["obb"], label: "trailing slash on root")
assertOutside(sibling.appendingPathComponent("main.obb"), label: "sibling-prefix collision")
assertOutside(root.appendingPathComponent("../test-game-sibling/main.obb"), label: "dot-dot traversal")
assertOutside(elsewhere.appendingPathComponent("main.obb"), label: "external destination")

// A system-level alias of a parent is permitted only when both URLs refer
// to the same real game. An alias under the game that escapes is not.
let alias = sandbox.appendingPathComponent("alias", isDirectory: true)
try fm.createSymbolicLink(at: alias, withDestinationURL: sandbox.appendingPathComponent("Husk", isDirectory: true))
let aliasedRoot = alias.appendingPathComponent("Documents/TranslationLayer/test-game", isDirectory: true)
let canonicalOBB = root.appendingPathComponent("obb", isDirectory: true)
let parts = try BloomBoxHuskPathPolicy.relativeComponents(of: canonicalOBB, under: aliasedRoot)
precondition(parts == ["obb"], "system alias path should resolve to same game")
try BloomBoxHuskPathPolicy.validateDestination(canonicalOBB, under: aliasedRoot)
try BloomBoxHuskPathPolicy.validateDestination(
    aliasedRoot.appendingPathComponent("obb", isDirectory: true), under: aliasedRoot)
let escapingLink = root.appendingPathComponent("escape", isDirectory: true)
try fm.createSymbolicLink(at: escapingLink, withDestinationURL: elsewhere)
assertOutside(escapingLink.appendingPathComponent("malicious.obb"), label: "symlink escape")

// Copy raw files through the same destination guard used by the UI.
let staged = sandbox.appendingPathComponent("picked-files", isDirectory: true)
try fm.createDirectory(at: staged, withIntermediateDirectories: true)
for (relative, bytes) in [
    ("obb/main.1.com.bloombox.testapp.obb", Data(repeating: 0x4F, count: 1024)),
    ("sdcard/Android/data/com.bloombox.testapp/bloombox_test.dat",
     Data(repeating: 0x44, count: 2048))
] {
    let expected = root.appendingPathComponent(relative)
    let source = staged.appendingPathComponent(expected.lastPathComponent)
    try bytes.write(to: source)
    try BloomBoxHuskPathPolicy.validateDestination(expected, under: root)
    try fm.createDirectory(at: expected.deletingLastPathComponent(),
                           withIntermediateDirectories: true)
    try BloomBoxHuskPathPolicy.validateDestination(expected, under: root)
    try fm.copyItem(at: source, to: expected)
    let importedData = try Data(contentsOf: expected)
    precondition(importedData == bytes, "incorrect imported data")
}

// A destination may be missing, but an existing data file may not be a folder.
let fileInsteadOfFolder = root.appendingPathComponent("sdcard/Android/data/com.bloombox.testapp/conflict")
try Data([0x42]).write(to: fileInsteadOfFolder)
do {
    try BloomBoxHuskPathPolicy.validateDestination(
        fileInsteadOfFolder.appendingPathComponent("nested.dat"), under: root)
    fatalError("must refuse existing file as parent directory")
} catch BloomBoxHuskPathPolicy.ValidationFailure.nonDirectoryAncestor {
    // Correct.
}

do {
    _ = try BloomBoxHuskPathPolicy.relativeComponents(
        of: URL(string: "https://example.org/obb")!, under: root)
    fatalError("web URL must not be accepted")
} catch BloomBoxHuskPathPolicy.Failure.notFileURL {
    // Expected.
}

// The real import path now uses only vetted relative segments. Verify THAT
// path-building routine, including destinations that do not yet exist.
let cleanGame = sandbox.appendingPathComponent(
    "Husk/Documents/TranslationLayer/uninitialized-game", isDirectory: true)
try fm.createDirectory(at: cleanGame, withIntermediateDirectories: true)

let obb = try BloomBoxHuskPathPolicy.scopedURL(
    in: cleanGame, components: ["obb"], isDirectory: true)
let gameData = try BloomBoxHuskPathPolicy.scopedURL(
    in: cleanGame,
    components: ["sdcard", "Android", "data", "com.bloombox.testapp"],
    isDirectory: true)
precondition(obb.lastPathComponent == "obb")
precondition(gameData.lastPathComponent == "com.bloombox.testapp")
try fm.createDirectory(at: obb, withIntermediateDirectories: true)
try fm.createDirectory(at: gameData, withIntermediateDirectories: true)
let rawOBB = try BloomBoxHuskPathPolicy.scopedURL(
    in: cleanGame, components: ["obb", "main.1.com.bloombox.testapp.obb"],
    isDirectory: false)
let rawData = try BloomBoxHuskPathPolicy.scopedURL(
    in: cleanGame,
    components: ["sdcard", "Android", "data", "com.bloombox.testapp", "bloombox_test.dat"],
    isDirectory: false)
try Data(repeating: 0x4F, count: 256).write(to: rawOBB)
try Data(repeating: 0x44, count: 512).write(to: rawData)
let obbReadback = try Data(contentsOf: rawOBB)
let dataReadback = try Data(contentsOf: rawData)
precondition(obbReadback.count == 256)
precondition(dataReadback.count == 512)

// Shared storage is a separate, trusted root; empty parts resolve to itself.
let shared = sandbox.appendingPathComponent(
    "Husk/Documents/Shared Storage", isDirectory: true)
try fm.createDirectory(at: shared, withIntermediateDirectories: true)
let sharedDest = try BloomBoxHuskPathPolicy.scopedURL(
    in: shared, components: [], isDirectory: true)
precondition(sharedDest.standardizedFileURL.path == shared.standardizedFileURL.path)
let aliasedOBB = try BloomBoxHuskPathPolicy.scopedURL(
    in: aliasedRoot, components: ["obb"], isDirectory: true)
precondition(aliasedOBB.lastPathComponent == "obb")

// Traversal, slash injection, and symlinks are never accepted as components.
for badPart in ["..", ".", "", "../../outside", "nested/escape"] {
    do {
        _ = try BloomBoxHuskPathPolicy.scopedURL(
            in: cleanGame, components: [badPart, "file.obb"], isDirectory: false)
        fatalError("unsafe component allowed: \(badPart)")
    } catch BloomBoxHuskPathPolicy.Failure.outsideRoot {
        // Correct.
    }
}
do {
    _ = try BloomBoxHuskPathPolicy.scopedURL(
        in: root, components: ["escape", "malicious.obb"], isDirectory: false)
    fatalError("symlink escape allowed in scoped path")
} catch BloomBoxHuskPathPolicy.ValidationFailure.unsafeLink {
    // Correct.
}


// Test Husk's engine-specific real folders and case-preserving discovery.
// macOS may report /private/var where a test fixture was built under /var.
func actualPath(_ url: URL) -> String { url.resolvingSymlinksInPath().standardizedFileURL.path }
let javaGame = sandbox.appendingPathComponent("Husk/Documents/TranslationLayer/bloombox-java", isDirectory: true)
let javaRoot = javaGame.appendingPathComponent("java-data", isDirectory: true)
let javaExt = javaRoot.appendingPathComponent(
    "sdcard/android/data/com.bloombox.testapp/files", isDirectory: true)
try fm.createDirectory(at: javaExt, withIntermediateDirectories: true)
try Data(#"{"engine":"Java","abis":[],"dexCount":1}"#.utf8)
    .write(to: javaGame.appendingPathComponent("report.json"))
precondition(BloomBoxHuskRuntimeScanner.reportedFolder(in: javaGame) == "java-data")
precondition(BloomBoxHuskRuntimeScanner.preferredRuntime(in: javaGame).map(actualPath) == actualPath(javaRoot),
             "Java preferred runtime must match the real java-data directory")
let javaCandidates = BloomBoxHuskRuntimeScanner.destinations(
    in: javaGame, package: "com.bloombox.testapp", sharedRoot: nil)
precondition(javaCandidates.contains(where: {
    $0.kind == "external-files" && actualPath($0.folder) == actualPath(javaExt)
}), "must find real Java-data/sdcard/android/data/<pkg>/files")
precondition(javaCandidates.contains(where: {
    $0.kind == "data" && actualPath($0.folder) == actualPath(javaExt.deletingLastPathComponent())
}), "must find existing Android data folder")
precondition(!fm.fileExists(atPath: javaGame.appendingPathComponent("sdcard").path),
             "discovery must never create root-level sdcard")
precondition(!fm.fileExists(atPath: javaGame.appendingPathComponent("obb").path),
             "discovery must never create root-level obb")

let ue4Game = sandbox.appendingPathComponent("Husk/Documents/TranslationLayer/minecraft-dungeons", isDirectory: true)
let ue4Runtime = ue4Game.appendingPathComponent("ue4-data", isDirectory: true)
let ue4Files = ue4Runtime.appendingPathComponent("files", isDirectory: true)
try fm.createDirectory(at: ue4Files, withIntermediateDirectories: true)
try Data(#"{"engine":"Unreal Engine","abis":["arm64-v8a"],"dexCount":1}"#.utf8)
    .write(to: ue4Game.appendingPathComponent("report.json"))
precondition(BloomBoxHuskRuntimeScanner.reportedFolder(in: ue4Game) == "ue4-data")
precondition(BloomBoxHuskRuntimeScanner.preferredRuntime(in: ue4Game).map(actualPath) == actualPath(ue4Runtime),
             "UE4 runtime must match the real ue4-data directory")
let ue4Destinations = BloomBoxHuskRuntimeScanner.destinations(
    in: ue4Game, package: "com.nintendosss.spice", sharedRoot: nil)
precondition(ue4Destinations.contains(where: { actualPath($0.folder) == actualPath(ue4Files) && $0.kind == "private" }))
precondition(!ue4Destinations.contains(where: { $0.kind == "external-files" }),
             "must not invent Android/data for UE4")

let uninitialized = sandbox.appendingPathComponent(
    "Husk/Documents/TranslationLayer/no-data-yet", isDirectory: true)
try fm.createDirectory(at: uninitialized, withIntermediateDirectories: true)
let emptyDestinations = BloomBoxHuskRuntimeScanner.destinations(
    in: uninitialized, package: "com.example.app", sharedRoot: nil)
precondition(emptyDestinations.count == 1 && emptyDestinations[0].kind == "game",
             "an app without data should offer only its real root")


// Unknown future engines still work when Husk creates their own -data folder.
let futureGame = sandbox.appendingPathComponent(
    "Husk/Documents/TranslationLayer/future-engine", isDirectory: true)
let futureRuntime = futureGame.appendingPathComponent("something-new-data", isDirectory: true)
let irrelevant = futureGame.appendingPathComponent("sdcard", isDirectory: true)
try fm.createDirectory(at: futureRuntime, withIntermediateDirectories: true)
try fm.createDirectory(at: irrelevant, withIntermediateDirectories: true)
let futureCandidates = BloomBoxHuskRuntimeScanner.runtimeFolders(in: futureGame)
precondition(futureCandidates.count == 1 &&
    actualPath(futureCandidates[0]) == actualPath(futureRuntime),
    "discover the only actual -data folder, not a known-engine allowlist")
precondition(BloomBoxHuskRuntimeScanner.preferredRuntime(in: futureGame)
    .map(actualPath) == actualPath(futureRuntime))

// If two -data roots exist without evidence, do not silently pick one.
try fm.createDirectory(at: futureGame.appendingPathComponent(
    "other-data", isDirectory: true), withIntermediateDirectories: true)
precondition(BloomBoxHuskRuntimeScanner.preferredRuntime(in: futureGame) == nil,
    "ambiguous engines must fall back to manual APK container browsing")

print("PASS: engine-scan Husk relative-root destinations, raw OBB/data copy, new directories, alias and escape protection")
