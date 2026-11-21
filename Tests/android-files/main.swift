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
    precondition(actual == expected, "\(label): got \(actual), expected \(expected)")
}
func assertOutside(_ candidate: URL, label: String) {
    do {
        let components = try BloomBoxHuskPathPolicy.relativeComponents(of: candidate, under: root)
        fatalError("\(label): unexpectedly accepted \(components)")
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
let escapingLink = root.appendingPathComponent("escape", isDirectory: true)
try fm.createSymbolicLink(at: escapingLink, withDestinationURL: elsewhere)
assertOutside(escapingLink.appendingPathComponent("malicious.obb"), label: "symlink escape")

do {
    _ = try BloomBoxHuskPathPolicy.relativeComponents(
        of: URL(string: "https://example.org/obb")!, under: root)
    fatalError("web URL must not be accepted")
} catch BloomBoxHuskPathPolicy.Failure.notFileURL {
    // Expected.
}
print("PASS: Husk path containment allows new OBB/data directories and rejects escapes")
