import Foundation

let fm = FileManager.default
let root = fm.temporaryDirectory.appendingPathComponent("bb-temp-test-\(UUID().uuidString)", isDirectory: true)
try fm.createDirectory(at: root, withIntermediateDirectories: true)
defer { try? fm.removeItem(at: root) }

func staged(_ name: String, size: UInt64, hoursOld: Double) throws -> URL {
    let directory = root.appendingPathComponent(name, isDirectory: true)
    try fm.createDirectory(at: directory, withIntermediateDirectories: true)
    let payload = directory.appendingPathComponent("payload.ipa")
    fm.createFile(atPath: payload.path, contents: Data())
    let handle = try FileHandle(forWritingTo: payload)
    handle.truncateFile(atOffset: size)
    handle.closeFile()
    let date = Date(timeIntervalSinceNow: -hoursOld * 3600)
    try fm.setAttributes([.modificationDate: date], ofItemAtPath: payload.path)
    try fm.setAttributes([.modificationDate: date], ofItemAtPath: directory.path)
    return directory
}

func require(_ predicate: @autoclosure () -> Bool, _ message: String) {
    if !predicate() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let old = try staged("BloomBoxInstall-abandoned", size: 700_000_000, hoursOld: 26)
let active = try staged("BloomBoxInstall-active", size: 500_000_000, hoursOld: 0)
let outside = try staged("OtherAppUserData", size: 800_000_000, hoursOld: 48)
let freed = BloomBoxTemporaryStorage.cleanupIfNeeded(root: root, minimumAge: 6 * 3600)
require(freed == 700_000_000, "should clean only old BloomBox files above 1 GB")
require(!fm.fileExists(atPath: old.path), "stale installation staging should be gone")
require(fm.fileExists(atPath: active.path), "current install must not be removed")
require(fm.fileExists(atPath: outside.path), "unowned temp data must not be removed")
require(BloomBoxTemporaryStorage.cleanupIfNeeded(root: root) == 0,
        "under-threshold cleanup should not repeat")

let second = root.appendingPathComponent("second", isDirectory: true)
try fm.createDirectory(at: second, withIntermediateDirectories: true)
let handoffOutside = root.appendingPathComponent("handoffOutside", isDirectory: true)
try fm.createDirectory(at: handoffOutside, withIntermediateDirectories: true)
let owned = handoffOutside.appendingPathComponent("user.ipa")
fm.createFile(atPath: owned.path, contents: Data())
try fm.createSymbolicLink(at: second.appendingPathComponent("BloomBoxSideStoreHandoff"),
                          withDestinationURL: handoffOutside)
_ = BloomBoxTemporaryStorage.cleanupIfNeeded(root: second, thresholdBytes: 0, minimumAge: 0)
require(fm.fileExists(atPath: owned.path), "symlinked handoff must never remove outside files")
print("PASS BloomBox safe temporary cleanup")
