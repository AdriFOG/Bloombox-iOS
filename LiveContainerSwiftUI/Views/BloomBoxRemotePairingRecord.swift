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
            // This exact path belongs to the installed host. Do not search other
            // applications, follow symlinks, or replace an existing pairing.
            let details = try installerURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            guard details.isRegularFile == true, details.isSymbolicLink == false,
                  installerURL.resolvingSymlinksInPath() == documentsDirectory.deletingLastPathComponent().resolvingSymlinksInPath().appendingPathComponent("Library/Application Support/rp_pairing_file.plist").standardizedFileURL,
                  let size = details.fileSize, size > 0, size < BloomBoxRemotePairingRecord.maximumBytes else {
                throw BloomBoxRemotePairingRecord.PairingError.invalid
            }
            source = installerURL
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
        for file in [pairingURL, legacyURL, installerURL] where fm.fileExists(atPath: file.path) {
            try fm.removeItem(at: file)
        }
    }
}
