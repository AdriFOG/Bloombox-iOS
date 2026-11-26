import Foundation
import CryptoKit

/// BloomBox's remote pairing validation. No private keys are logged or uploaded.
enum BloomBoxRemotePairingRecord {
    static let maximumBytes = 2_000_000

    enum PairingError: LocalizedError {
        case invalid
        case missing

        var errorDescription: String? {
            switch self {
            case .invalid:
                return "Choose a valid remote pairing file. A classic USB pairing file cannot be used for on-device JIT."
            case .missing:
                return "Import a remote pairing file in BloomBox JIT setup first."
            }
        }
    }

    static func validate(_ data: Data) throws {
        guard !data.isEmpty, data.count < maximumBytes,
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let publicKey = plist["public_key"] as? Data, publicKey.count == 32,
              let privateKey = plist["private_key"] as? Data, privateKey.count == 32,
              let identifier = plist["identifier"] as? String,
              !identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              identifier.count <= 256,
              let signingKey = try? Curve25519.Signing.PrivateKey(rawRepresentation: privateKey),
              signingKey.publicKey.rawRepresentation == publicKey else {
            throw PairingError.invalid
        }
    }
}

/// Migrates pairing data from the previous launcher directory without losing it on updates.
/// Legacy and installer sources are retained for rollback; explicit Remove pairing file deletes local copies.
struct BloomBoxJITPairingStorage {
    let documentsDirectory: URL

    init(documentsDirectory: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]) {
        self.documentsDirectory = documentsDirectory
    }

    var pairingURL: URL {
        documentsDirectory.appendingPathComponent("BloomBoxJIT/pairingFile.plist")
    }

    var legacyURL: URL {
        documentsDirectory.appendingPathComponent("StrataJIT/pairingFile.plist")
    }

    /// siboot seeds the installed host sandbox, not BloomBox’s Documents directory.
    var installerURL: URL {
        documentsDirectory.deletingLastPathComponent()
            .appendingPathComponent("Library/Application Support/rp_pairing_file.plist")
    }

    private var installerPathIsLocal: Bool {
        let sandbox = documentsDirectory.deletingLastPathComponent().resolvingSymlinksInPath()
        let expected = sandbox.appendingPathComponent("Library/Application Support/rp_pairing_file.plist")
        return installerURL.resolvingSymlinksInPath().standardizedFileURL.path == expected.standardizedFileURL.path
    }

    // SideInstaller 2.2.0 uses these paths and settings for modern SideStore:
    // https://github.com/FrizzleM/SideInstaller/blob/v2.2.0/ios-app/PairingTargets.swift
    // The bundled fork's PairingFileManager (044bd72a) reads UTF-8 XML and
    // requires isPairingReset=false plus an active/preferred protocol.
    var sideStoreRemoteURL: URL {
        documentsDirectory.appendingPathComponent("SideStore/Documents/PairingFile_RemoteRP.plist")
    }

    var sideStorePreferencesURL: URL {
        documentsDirectory.appendingPathComponent("SideStore/Library/Preferences/com.SideStore.SideStore.plist")
    }

    private var handoffMarker: URL {
        installerURL.deletingLastPathComponent().appendingPathComponent("BloomBoxInstallerPairingHandoff-v1")
    }

    enum HandoffResult: String {
        case missing, invalid, conflict, delivered, alreadyDelivered, failed
    }

    private func isLocal(_ url: URL) -> Bool {
        let root = documentsDirectory.deletingLastPathComponent()
        let resolvedRoot = root.resolvingSymlinksInPath().standardizedFileURL.path
        let relative = url.standardizedFileURL.path.dropFirst(root.standardizedFileURL.path.count)
        return relative.hasPrefix("/") &&
            url.resolvingSymlinksInPath().standardizedFileURL.path == resolvedRoot + relative
    }

    private func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path) ||
            (try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)) != nil
    }

    private func readLocal(_ url: URL) throws -> Data {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard isLocal(url), values.isRegularFile == true, values.isSymbolicLink == false,
              let size = values.fileSize, size > 0, size < BloomBoxRemotePairingRecord.maximumBytes else {
            throw BloomBoxRemotePairingRecord.PairingError.invalid
        }
        let data = try Data(contentsOf: url)
        guard data.count < BloomBoxRemotePairingRecord.maximumBytes else {
            throw BloomBoxRemotePairingRecord.PairingError.invalid
        }
        return data
    }

    func readInstallerSeed() throws -> Data {
        guard exists(installerURL) else { throw BloomBoxRemotePairingRecord.PairingError.missing }
        let data = try readLocal(installerURL)
        try BloomBoxRemotePairingRecord.validate(data)
        return data
    }

    func readSideStoreRemote() throws -> Data {
        guard exists(sideStoreRemoteURL) else { throw BloomBoxRemotePairingRecord.PairingError.missing }
        let data = try readLocal(sideStoreRemoteURL)
        try BloomBoxRemotePairingRecord.validate(data)
        return data
    }

    // Preserve every known remote key, including the optional alt_irk.
    // Do not manufacture a USB/lockdown pairing or pass mixed records to SideStore.
    static func remoteXML(_ data: Data) throws -> Data {
        try BloomBoxRemotePairingRecord.validate(data)
        guard let dict = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            throw BloomBoxRemotePairingRecord.PairingError.invalid
        }
        let keys: Set<String> = ["private_key", "public_key", "identifier", "alt_irk"]
        return try PropertyListSerialization.data(fromPropertyList: dict.filter { keys.contains($0.key) }, format: .xml, options: 0)
    }

    static func matches(_ lhs: Data, _ rhs: Data) -> Bool {
        guard let a = try? remoteXML(lhs), let b = try? remoteXML(rhs),
              let ad = try? PropertyListSerialization.propertyList(from: a, format: nil) as? NSDictionary,
              let bd = try? PropertyListSerialization.propertyList(from: b, format: nil) as? NSDictionary else { return false }
        return ad.isEqual(bd)
    }

    private func preferences() throws -> [String: Any] {
        guard exists(sideStorePreferencesURL) else { return [:] }
        guard let dict = try PropertyListSerialization.propertyList(from: readLocal(sideStorePreferencesURL), format: nil) as? [String: Any] else {
            throw BloomBoxRemotePairingRecord.PairingError.invalid
        }
        return dict
    }

    // Called in the HOST on cold launch, never from SideStore or a guest.
    // A successful hand-off is one-time so a deliberate later reset stays reset.
    // If anything existing disagrees, require a deliberate manual import instead.
    func handOffInstallerPairing() -> HandoffResult {
        let fm = FileManager.default
        guard exists(installerURL) else { return .missing }
        let seed: Data
        do { seed = try readInstallerSeed() }
        catch BloomBoxRemotePairingRecord.PairingError.invalid { return .invalid }
        catch { return .failed }
        guard isLocal(handoffMarker), isLocal(sideStoreRemoteURL), isLocal(sideStorePreferencesURL),
              isLocal(pairingURL), isLocal(legacyURL) else { return .invalid }
        if exists(handoffMarker) { return .alreadyDelivered }
        do {
            // Do not overwrite even an invalid or old manually managed record.
            for file in [pairingURL, legacyURL] where exists(file) {
                guard Self.matches(try readLocal(file), seed) else { return .conflict }
            }
            for name in ["PairingFile_Lockdown.plist", "ALTPairingFile.mobiledevicepairing"] {
                if exists(sideStoreRemoteURL.deletingLastPathComponent().appendingPathComponent(name)) { return .conflict }
            }
            let remoteExists = exists(sideStoreRemoteURL)
            if remoteExists {
                guard Self.matches(try readSideStoreRemote(), seed) else { return .conflict }
            }
            var prefs = try preferences()
            if let active = prefs["activePairingProtocol"] as? String, active != "rppairing" { return .conflict }
            if let preferred = prefs["preferredPairingProtocol"] as? String, preferred != "rppairing" { return .conflict }
            // Existing explicit reset is not undone if we already delivered a seed (marker above).
            let xml = try Self.remoteXML(seed)
            if !exists(pairingURL) { try save(seed) }
            if !remoteExists {
                try fm.createDirectory(at: sideStoreRemoteURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try xml.write(to: sideStoreRemoteURL, options: [.withoutOverwriting, .completeFileProtection])
            }
            guard Self.matches(try readSideStoreRemote(), seed),
                  Self.matches(try load(), seed) else { return .failed }
            if prefs["isPairingReset"] as? Bool != false || prefs["activePairingProtocol"] as? String != "rppairing" {
                prefs["isPairingReset"] = false
                prefs["activePairingProtocol"] = "rppairing"
                let bytes = try PropertyListSerialization.data(fromPropertyList: prefs, format: .binary, options: 0)
                try fm.createDirectory(at: sideStorePreferencesURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try bytes.write(to: sideStorePreferencesURL, options: [.atomic, .completeFileProtection])
            }
            let verified = try preferences()
            guard verified["isPairingReset"] as? Bool == false,
                  verified["activePairingProtocol"] as? String == "rppairing" else { return .failed }
            try Data("delivered".utf8).write(to: handoffMarker, options: [.atomic, .completeFileProtection])
            return .delivered
        } catch { return .failed }
    }

    var hasRecord: Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: pairingURL.path) || fm.fileExists(atPath: legacyURL.path)
    }

    func save(_ data: Data) throws {
        try BloomBoxRemotePairingRecord.validate(data)
        try FileManager.default.createDirectory(at: pairingURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try data.write(to: pairingURL, options: [.atomic, .completeFileProtection])
    }

    func load() throws -> Data {
        let fm = FileManager.default
        let source: URL
        if fm.fileExists(atPath: pairingURL.path) {
            source = pairingURL
        } else if fm.fileExists(atPath: legacyURL.path) {
            source = legacyURL
        } else if fm.fileExists(atPath: installerURL.path) {
            let data = try readInstallerSeed()
            try save(data)
            return data
        } else {
            throw BloomBoxRemotePairingRecord.PairingError.missing
        }
        let data = try Data(contentsOf: source)
        try BloomBoxRemotePairingRecord.validate(data)
        if source != pairingURL { try save(data) }
        return data
    }

    func remove() throws {
        let fm = FileManager.default
        // Explicit removal also removes the seed from this app’s own sandbox,
        // so it cannot be silently re-imported at the next launch.
        let localFiles = installerPathIsLocal ? [pairingURL, legacyURL, installerURL] : [pairingURL, legacyURL]
        for file in localFiles where fm.fileExists(atPath: file.path) {
            try fm.removeItem(at: file)
        }
    }
}
