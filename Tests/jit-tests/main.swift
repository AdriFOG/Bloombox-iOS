import Foundation
import CryptoKit
let key = Curve25519.Signing.PrivateKey()
let valid: [String: Any] = ["public_key": key.publicKey.rawRepresentation, "private_key": key.rawRepresentation, "identifier": UUID().uuidString]
for format in [PropertyListSerialization.PropertyListFormat.xml, .binary] {
    try BloomBoxRemotePairingRecord.validate(PropertyListSerialization.data(fromPropertyList: valid, format: format, options: 0))
}
func reject(_ value: [String: Any]) throws {
    let data = try PropertyListSerialization.data(fromPropertyList: value, format: .binary, options: 0)
    do { try BloomBoxRemotePairingRecord.validate(data); fatalError("Accepted invalid pairing") } catch {}
}
var invalid = valid; invalid["public_key"] = Data(repeating: 0, count: 32); try reject(invalid)
invalid = valid; invalid["identifier"] = " "; try reject(invalid)
invalid = valid; invalid.removeValue(forKey: "private_key"); try reject(invalid)
try reject(["HostID": "classic", "SystemBUID": "classic"])
do { try BloomBoxRemotePairingRecord.validate(Data(repeating: 1, count: 2_000_001)); fatalError("Accepted oversized data") } catch {}
print("PASS: XML/binary remote pairing; reject mismatched keys, missing keys, empty identity, classic format and oversized input.")


// Reuse previous pairing data, keep user credentials private, and prevent re-import after deletion.
let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("BloomBoxPairing-" + UUID().uuidString)
defer { try? FileManager.default.removeItem(at: tempRoot) }
let storage = BloomBoxJITPairingStorage(documentsDirectory: tempRoot.appendingPathComponent("Documents", isDirectory: true))
try FileManager.default.createDirectory(at: storage.legacyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
let original = try PropertyListSerialization.data(fromPropertyList: valid, format: .binary, options: 0)
try original.write(to: storage.legacyURL)
precondition(storage.hasRecord)
let migrated = try storage.load()
precondition(migrated == original)
precondition(FileManager.default.fileExists(atPath: storage.pairingURL.path))
try storage.remove()
precondition(!storage.hasRecord)
do { _ = try storage.load(); fatalError("Reused deleted pairing credentials") }
catch BloomBoxRemotePairingRecord.PairingError.missing { }
print("PASS: legacy pairing migration preserves bytes and deleting a pairing removes both records.")

// The bootstrapper seeds an RP record in the installed host's Application Support.
let fm = FileManager.default
try fm.createDirectory(at: storage.installerURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try original.write(to: storage.installerURL)
let seeded = try storage.load()
precondition(seeded == original)
precondition(try! Data(contentsOf: storage.installerURL) == original)
precondition(try! Data(contentsOf: storage.pairingURL) == original)
let secondKey = Curve25519.Signing.PrivateKey()
let second: [String: Any] = ["public_key": secondKey.publicKey.rawRepresentation, "private_key": secondKey.rawRepresentation, "identifier": UUID().uuidString]
let secondData = try PropertyListSerialization.data(fromPropertyList: second, format: .xml, options: 0)
try secondData.write(to: storage.installerURL)
let preserved = try storage.load()
precondition(preserved == original, "Existing record must win over installer seed")
try storage.remove()
precondition(!fm.fileExists(atPath: storage.installerURL.path))
do { _ = try storage.load(); fatalError("Reimported removed seed") }
catch BloomBoxRemotePairingRecord.PairingError.missing { }
try Data("not a pairing".utf8).write(to: storage.installerURL)
do { _ = try storage.load(); fatalError("Imported invalid seed") }
catch BloomBoxRemotePairingRecord.PairingError.invalid { }
precondition(!fm.fileExists(atPath: storage.pairingURL.path))
try fm.removeItem(at: storage.installerURL)
let alternate = tempRoot.appendingPathComponent("external.plist")
try original.write(to: alternate)
try fm.createSymbolicLink(at: storage.installerURL, withDestinationURL: alternate)
do { _ = try storage.load(); fatalError("Imported symlink seed") }
catch BloomBoxRemotePairingRecord.PairingError.invalid { }
precondition(!fm.fileExists(atPath: storage.pairingURL.path))
print("PASS: installer seed migration, existing record precedence, explicit removal, invalid and symlink rejection.")

 
// Handoff integration: the exact sideStore guest path and preferences contract.
// Synthetic keys only; no real device credentials are used by CI.
func sandbox(_ name: String) -> BloomBoxJITPairingStorage {
    BloomBoxJITPairingStorage(documentsDirectory: tempRoot.appendingPathComponent(name).appendingPathComponent("Documents", isDirectory: true))
}
func writeSeed(_ storage: BloomBoxJITPairingStorage, _ bytes: Data) throws {
    try fm.createDirectory(at: storage.installerURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try bytes.write(to: storage.installerURL)
}
let fresh = sandbox("fresh")
precondition(fresh.handOffInstallerPairing() == .missing)
precondition(!fm.fileExists(atPath: fresh.sideStorePreferencesURL.path))
var seededRecord = valid
seededRecord["alt_irk"] = Data(repeating: 7, count: 16)
let realShape = try PropertyListSerialization.data(fromPropertyList: seededRecord, format: .xml, options: 0)
try writeSeed(fresh, realShape)
try fm.createDirectory(at: fresh.sideStorePreferencesURL.deletingLastPathComponent(), withIntermediateDirectories: true)
let otherPrefs: [String: Any] = ["unrelatedPreference": 123, "isPairingReset": true]
try PropertyListSerialization.data(fromPropertyList: otherPrefs, format: .binary, options: 0).write(to: fresh.sideStorePreferencesURL)
precondition(fresh.handOffInstallerPairing() == .delivered)
precondition(try! fresh.readInstallerSeed() == realShape)
precondition(try! fresh.readCurrentPairing() == realShape)
let deliveredRemote = try fresh.readSideStoreRemote()
precondition(BloomBoxJITPairingStorage.matches(deliveredRemote, realShape))
let deliveredDict = try PropertyListSerialization.propertyList(from: deliveredRemote, format: nil) as! [String: Any]
precondition(deliveredDict["alt_irk"] as? Data == Data(repeating: 7, count: 16))
let prefs = try PropertyListSerialization.propertyList(from: Data(contentsOf: fresh.sideStorePreferencesURL), format: nil) as! [String: Any]
precondition(prefs["isPairingReset"] as? Bool == false)
precondition(prefs["activePairingProtocol"] as? String == "rppairing")
precondition(prefs["unrelatedPreference"] as? Int == 123)
precondition(fresh.handOffInstallerPairing() == .alreadyDelivered)
// Resetting SideStore later does not silently resurrect the record.
try fm.removeItem(at: fresh.sideStoreRemoteURL)
precondition(fresh.handOffInstallerPairing() == .alreadyDelivered)
precondition(!fm.fileExists(atPath: fresh.sideStoreRemoteURL.path))

let manual = sandbox("manual")
try writeSeed(manual, realShape)
try manual.save(secondData)
precondition(manual.handOffInstallerPairing() == .conflict)
precondition(try! manual.readCurrentPairing() == secondData)
precondition(!fm.fileExists(atPath: manual.sideStoreRemoteURL.path))

let existingRemote = sandbox("existingRemote")
try writeSeed(existingRemote, realShape)
try fm.createDirectory(at: existingRemote.sideStoreRemoteURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try secondData.write(to: existingRemote.sideStoreRemoteURL)
precondition(existingRemote.handOffInstallerPairing() == .conflict)
precondition(try! existingRemote.readSideStoreRemote() == secondData)
precondition(!fm.fileExists(atPath: existingRemote.pairingURL.path))

let bad = sandbox("bad")
try writeSeed(bad, Data("invalid".utf8))
precondition(bad.handOffInstallerPairing() == .invalid)
precondition(!fm.fileExists(atPath: bad.sideStoreRemoteURL.path))
let linked = sandbox("linked")
try writeSeed(linked, realShape)
let outside = tempRoot.appendingPathComponent("outsideSideStore")
try fm.createDirectory(at: outside, withIntermediateDirectories: true)
try fm.createDirectory(at: linked.documentsDirectory, withIntermediateDirectories: true)
try fm.createSymbolicLink(at: linked.documentsDirectory.appendingPathComponent("SideStore"), withDestinationURL: outside)
precondition(linked.handOffInstallerPairing() == .invalid)
precondition(!fm.fileExists(atPath: outside.appendingPathComponent("Documents").path))
print("PASS: fresh installer handoff, XML/alt_irk, exact SideStore preferences, matching records, reset preservation, conflicting records and sandbox boundaries.")


// Plan B never modifies the original files, existing credentials, or unrelated
// preferences; it is a one-time configuration for installer-seeded SideStore.
let auth = sandbox("anisette")
precondition(auth.configureInstallerAnisette() == .notApplicable)
try writeSeed(auth, realShape)
precondition(auth.handOffInstallerPairing() == .delivered)
var authPrefs = try PropertyListSerialization.propertyList(from: Data(contentsOf: auth.sideStorePreferencesURL), format: nil) as! [String: Any]
authPrefs["unrelatedSetting"] = 42
authPrefs["useOnDeviceAnisette"] = true
try PropertyListSerialization.data(fromPropertyList: authPrefs, format: .binary, options: 0).write(to: auth.sideStorePreferencesURL)
let authSeed = try auth.readInstallerSeed()
let authJit = try auth.readCurrentPairing()
let authRemote = try auth.readSideStoreRemote()
precondition(auth.configureInstallerAnisette() == .configured)
let configured = try PropertyListSerialization.propertyList(from: Data(contentsOf: auth.sideStorePreferencesURL), format: nil) as! [String: Any]
precondition(configured["useOnDeviceAnisette"] as? Bool == false)
precondition(configured["disableAnisetteRotation"] as? Bool == true)
precondition(configured["menuAnisetteURL"] as? String == "https://new.ani.sidestore.io")
precondition((configured["customAnisetteClientInfo"] as? String)?.contains("Mac OS X;") == true)
precondition(configured["customAnisetteUserAgent"] != nil)
precondition(configured["unrelatedSetting"] as? Int == 42)
precondition(configured["isPairingReset"] as? Bool == false)
precondition(configured["activePairingProtocol"] as? String == "rppairing")
precondition(try! auth.readInstallerSeed() == authSeed)
precondition(try! auth.readCurrentPairing() == authJit)
precondition(try! auth.readSideStoreRemote() == authRemote)
var userPrefs = configured
userPrefs["useOnDeviceAnisette"] = true
let userBytes = try PropertyListSerialization.data(fromPropertyList: userPrefs, format: .binary, options: 0)
try userBytes.write(to: auth.sideStorePreferencesURL)
precondition(auth.configureInstallerAnisette() == .alreadyConfigured)
precondition(try! Data(contentsOf: auth.sideStorePreferencesURL) == userBytes)
precondition(manual.configureInstallerAnisette() == .notApplicable)
precondition(linked.configureInstallerAnisette() == .notApplicable)
print("PASS: Anisette installer setup is scoped, idempotent and preserves all pairing records.")
