import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// BloomBox-only document operations. Never touches guest apps, signing or RAM+.
/// A pre-existing "Manzana Files" folder stays usable to avoid losing user data.
struct BloomBoxFileStore {
    let root: URL
    private let fm = FileManager.default

    enum Failure: LocalizedError {
        case invalidName, outsideRoot, exists, invalidFile
        var errorDescription: String? {
            switch self {
            case .invalidName:
                return "Usa un nombre válido, sin diagonales, controles ni punto inicial."
            case .outsideRoot:
                return "Esta operación debe permanecer dentro de Archivos de BloomBox."
            case .exists:
                return "Ya existe un archivo o carpeta con ese nombre."
            case .invalidFile:
                return "Selecciona un archivo o carpeta válido."
            }
        }
    }

    /// An existing user folder takes priority; new installations use BloomBox.
    /// No large, error-prone file copy or rename occurs during migration.
    static func preferredRoot(in documents: URL, fm: FileManager = .default) -> URL {
        let modern = documents.appendingPathComponent("BloomBox Files", isDirectory: true)
        let previous = documents.appendingPathComponent("Manzana Files", isDirectory: true)
        if fm.fileExists(atPath: modern.path) { return modern }
        if fm.fileExists(atPath: previous.path) { return previous }
        return modern
    }

    init(root: URL) throws {
        let candidate = root.standardizedFileURL
        try fm.createDirectory(at: candidate, withIntermediateDirectories: true)
        let resolved = candidate.resolvingSymlinksInPath()
        let info = try resolved.resourceValues(forKeys: [.isDirectoryKey])
        guard info.isDirectory == true else { throw Failure.invalidFile }
        self.root = resolved
    }

    /// Resolving symbolic links before checking the boundary prevents escape.
    func checked(_ url: URL) throws -> URL {
        let resolved = url.standardizedFileURL.resolvingSymlinksInPath()
        guard resolved.path == root.path || resolved.path.hasPrefix(root.path + "/") else {
            throw Failure.outsideRoot
        }
        return resolved
    }

    private func checkedFolder(_ url: URL) throws -> URL {
        let resolved = try checked(url)
        let values = try resolved.resourceValues(forKeys: [.isDirectoryKey])
        guard values.isDirectory == true else { throw Failure.invalidFile }
        return resolved
    }

    func contents(_ folder: URL) throws -> [URL] {
        let folder = try checkedFolder(folder)
        return try fm.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: .skipsHiddenFiles
        ).filter {
            guard (try? checked($0)) != nil else { return false }
            // Avoid showing shortcuts that escape or resolve back into themselves.
            return (try? $0.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true
        }.sorted { lhs, rhs in
            let lhsFolder = (try? lhs.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            let rhsFolder = (try? rhs.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            if lhsFolder != rhsFolder { return lhsFolder }
            return lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending
        }
    }

    private func safeName(_ raw: String) throws -> String {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != ".", name != "..", !name.hasPrefix("."),
              name.utf8.count <= 255,
              !name.contains("/"), !name.contains("\\"),
              name.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else {
            throw Failure.invalidName
        }
        return name
    }

    func destination(_ raw: String, in folder: URL) throws -> URL {
        let name = try safeName(raw)
        let parent = try checkedFolder(folder)
        let target = parent.appendingPathComponent(name)
        guard !fm.fileExists(atPath: target.path) else { throw Failure.exists }
        return target
    }

    private func uniqueDestination(_ name: String, in folder: URL) throws -> URL {
        let parent = try checkedFolder(folder)
        let clean = try safeName(name)
        let ext = (clean as NSString).pathExtension
        let stem = (clean as NSString).deletingPathExtension
        for number in 1...10_000 {
            let proposed = number == 1 ? clean :
                stem + " (" + String(number) + ")" + (ext.isEmpty ? "" : "." + ext)
            let target = parent.appendingPathComponent(proposed)
            if !fm.fileExists(atPath: target.path) { return try destination(proposed, in: parent) }
        }
        throw Failure.exists
    }

    func createFolder(_ name: String, in folder: URL) throws {
        try fm.createDirectory(at: destination(name, in: folder),
                               withIntermediateDirectories: false)
    }

    func rename(_ url: URL, to name: String) throws {
        let source = try checked(url)
        let trash = root.appendingPathComponent(".Trash", isDirectory: true)
        guard source != root, source != trash, !source.path.hasPrefix(trash.path + "/") else {
            throw Failure.outsideRoot
        }
        let newName = try safeName(name)
        if newName == source.lastPathComponent { return }
        try fm.moveItem(at: source, to: destination(newName, in: source.deletingLastPathComponent()))
    }

    func importFile(_ source: URL, into folder: URL) throws {
        let properties = try source.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard properties.isRegularFile == true, properties.isSymbolicLink != true else {
            throw Failure.invalidFile
        }
        let parent = try checkedFolder(folder)
        guard !inTrash(parent) else { throw Failure.outsideRoot }
        try fm.copyItem(at: source, to: uniqueDestination(source.lastPathComponent, in: parent))
    }

    private func inTrash(_ url: URL) -> Bool {
        let trash = root.appendingPathComponent(".Trash", isDirectory: true)
        return url.path == trash.path || url.path.hasPrefix(trash.path + "/")
    }

    func trashFolder() throws -> URL {
        let folder = try checked(root.appendingPathComponent(".Trash", isDirectory: true))
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    func moveToTrash(_ url: URL) throws {
        let source = try checked(url)
        guard source != root, !inTrash(source) else { throw Failure.outsideRoot }
        try fm.moveItem(at: source, to: uniqueDestination(source.lastPathComponent, in: trashFolder()))
    }

    func restore(_ url: URL) throws {
        let source = try checked(url)
        let trash = try trashFolder()
        guard source.deletingLastPathComponent() == trash else { throw Failure.outsideRoot }
        try fm.moveItem(at: source, to: uniqueDestination(source.lastPathComponent, in: root))
    }

    private func transfer(_ url: URL, into folderURL: URL, copying: Bool) throws {
        let source = try checked(url)
        let folder = try checkedFolder(folderURL)
        guard source != root, !inTrash(source), !inTrash(folder),
              folder != source, !folder.path.hasPrefix(source.path + "/") else {
            throw Failure.outsideRoot
        }
        let sourceProperties = try source.resourceValues(forKeys: [.isSymbolicLinkKey])
        guard sourceProperties.isSymbolicLink != true else { throw Failure.invalidFile }
        if !copying && source.deletingLastPathComponent() == folder { return }
        let target = try uniqueDestination(source.lastPathComponent, in: folder)
        if copying { try fm.copyItem(at: source, to: target) }
        else { try fm.moveItem(at: source, to: target) }
    }

    func move(_ url: URL, into folder: URL) throws {
        try transfer(url, into: folder, copying: false)
    }
    func copy(_ url: URL, into folder: URL) throws {
        try transfer(url, into: folder, copying: true)
    }
}


/// Root confinement for Husk native-game data imports.
///
/// A directory URL can have an explicit trailing slash and may be presented
/// under a system alias (/var vs /private/var). Compare canonical components,
/// never a raw string prefix. This also prevents sibling-prefix confusion
/// (gameA vs gameA-backup) and traversal.
enum BloomBoxHuskPathPolicy {
    enum Failure: Error, Equatable {
        case notFileURL
        case outsideRoot
    }

    static func relativeComponents(of destination: URL, under root: URL) throws -> [String] {
        guard root.isFileURL, destination.isFileURL else { throw Failure.notFileURL }
        let lexicalRoot = root.standardizedFileURL
        let lexicalDestination = destination.standardizedFileURL
        let realRoot = lexicalRoot.resolvingSymlinksInPath()

        // Prefer checking the original spelling to expose symlinks inside
        // the game directory. A normalized root is only a fallback for
        // legitimate system-level aliases such as /var -> /private/var.
        let destinationComponents = lexicalDestination.pathComponents
        let match: URL
        if lexicalRoot.pathComponents.count <= destinationComponents.count &&
            Array(destinationComponents.prefix(lexicalRoot.pathComponents.count)) ==
                lexicalRoot.pathComponents {
            match = lexicalRoot
        } else if realRoot.pathComponents.count <= destinationComponents.count &&
            Array(destinationComponents.prefix(realRoot.pathComponents.count)) ==
                realRoot.pathComponents {
            match = realRoot
        } else {
            throw Failure.outsideRoot
        }

        let relative = Array(destinationComponents.dropFirst(match.pathComponents.count))
        var current = match
        for name in relative {
            current.appendPathComponent(name)
            // resolvingSymlinksInPath may stop at a nonexistent final file,
            // so check *every existing ancestor* with lstat instead.
            if isSymbolicLink(current) { throw Failure.outsideRoot }
        }

        // The *destination* may not exist yet. On iOS, resolvingSymlinksInPath
        // on a nonexistent leaf can leave system aliases (/var, /private/var)
        // unresolved, even when the real root is valid. Comparing the two
        // resolved whole paths incorrectly blocks every first-time import.
        // The selected root was already validated, the lexical components
        // are confined above, and lstat checked every child for symlinks.
        return relative
    }

    /// This is the actual preflight used before every native Husk import.
    /// Tests call it directly, not a weaker approximation of the UI guard.
    static func validateDestination(_ destination: URL, under root: URL) throws {
        let components = try relativeComponents(of: destination, under: root)
        let fm = FileManager.default
        let actualRoot = root.standardizedFileURL.resolvingSymlinksInPath()
        var isFolder: ObjCBool = false
        guard fm.fileExists(atPath: actualRoot.path, isDirectory: &isFolder),
              isFolder.boolValue else {
            throw ValidationFailure.missingGameDirectory
        }
        // Root was selected by Husk discovery, not supplied by imported files.
        if isSymbolicLink(root.standardizedFileURL) {
            throw ValidationFailure.unsafeLink
        }
        var cursor = root.standardizedFileURL
        for (index, segment) in components.enumerated() {
            cursor.appendPathComponent(segment)
            if isSymbolicLink(cursor) { throw ValidationFailure.unsafeLink }
            if index + 1 < components.count {
                var isDirectory: ObjCBool = false
                if fm.fileExists(atPath: cursor.path, isDirectory: &isDirectory) &&
                    !isDirectory.boolValue {
                    throw ValidationFailure.nonDirectoryAncestor
                }
            }
        }
    }

    enum ValidationFailure: Error, Equatable {
        case missingGameDirectory
        case unsafeLink
        case nonDirectoryAncestor
    }

    /// Construct an authorized descendant from independent, trusted path
    /// components. No comparison of two full iOS container paths is needed.
    /// Import modes provide fixed segments, and imported file names provide
    /// exactly one final segment. Every existing child is checked with lstat.
    static func scopedURL(in root: URL, components: [String],
                          isDirectory: Bool) throws -> URL {
        guard root.isFileURL else { throw Failure.notFileURL }
        let base = root.standardizedFileURL
        let fm = FileManager.default
        var rootIsDirectory: ObjCBool = false
        guard fm.fileExists(atPath: base.path, isDirectory: &rootIsDirectory),
              rootIsDirectory.boolValue else {
            throw ValidationFailure.missingGameDirectory
        }
        if isSymbolicLink(base) { throw ValidationFailure.unsafeLink }
        var current = base
        for (index, part) in components.enumerated() {
            guard !part.isEmpty, part != ".", part != "..",
                  !part.contains("/"), !part.contains("\\"),
                  !part.unicodeScalars.contains(where: { $0.value == 0 }) else {
                throw Failure.outsideRoot
            }
            let folder = index < components.count - 1 || isDirectory
            current.appendPathComponent(part, isDirectory: folder)
            if isSymbolicLink(current) { throw ValidationFailure.unsafeLink }
            var existingFolder: ObjCBool = false
            if fm.fileExists(atPath: current.path, isDirectory: &existingFolder) &&
                index < components.count - 1 && !existingFolder.boolValue {
                throw ValidationFailure.nonDirectoryAncestor
            }
        }
        return current
    }

    private static func isSymbolicLink(_ url: URL) -> Bool {
        var fileStat = stat()
        return url.withUnsafeFileSystemRepresentation { pointer in
            guard let pointer else { return false }
            return lstat(pointer, &fileStat) == 0 &&
                (fileStat.st_mode & mode_t(S_IFMT)) == mode_t(S_IFLNK)
        }
    }
}


/// Discovers Husk's actual per-engine data folders; never creates a guessed
/// "java-data", "sdcard", "obb", or "Android/data" directory during discovery.
/// Husk/src/app/Husk/TechnicalDetails.swift is the source of folder naming.
enum BloomBoxHuskRuntimeScanner {
    struct Destination: Identifiable {
        let id: String
        let label: String
        let folder: URL
        let root: URL
        let kind: String
    }

    static let engineDirectories = [
        "java-data", "ue4-data", "unity-data", "cocos-data",
        "minecraft-data", "sdl-data", "gta-data", "godot-data",
        "na-data", "gm-data", "flutter-data", "classic-data", "web"
    ]

    private static func readableFolder(_ url: URL) -> Bool {
        let flags = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        return flags?.isDirectory == true && flags?.isSymbolicLink != true &&
            FileManager.default.isReadableFile(atPath: url.path)
    }

    static func existingChild(_ parent: URL, named name: String) -> URL? {
        guard readableFolder(parent), !name.isEmpty,
              !name.contains("/"), name != ".", name != "..",
              let items = try? FileManager.default.contentsOfDirectory(
                at: parent, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        else { return nil }
        // Exact spelling takes precedence, then case-insensitive lookup.
        let matching = items.first(where: { $0.lastPathComponent == name })
            ?? items.first(where: {
                $0.lastPathComponent.caseInsensitiveCompare(name) == .orderedSame
            })
        guard let matching, readableFolder(matching) else { return nil }
        return matching
    }

    static func existingPath(_ root: URL, _ components: [String]) -> URL? {
        var cursor = root
        for name in components {
            guard let next = existingChild(cursor, named: name) else { return nil }
            cursor = next
        }
        return readableFolder(cursor) ? cursor : nil
    }

    static func runtimeFolders(in game: URL) -> [URL] {
        guard readableFolder(game),
              let contents = try? FileManager.default.contentsOfDirectory(
                at: game, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        else { return [] }
        // The folder name, not a fixed list of engines, is the fallback.
        // New Husk engines can introduce new <engine>-data folders.
        return contents.filter {
            $0.lastPathComponent.lowercased().hasSuffix("-data") && readableFolder($0)
        }.sorted { $0.lastPathComponent.localizedStandardCompare(
            $1.lastPathComponent) == .orderedAscending }
    }

    /// Same broad engine selection as Husk's TLReport.nativeEngine.
    /// Never trust the report alone as evidence of an existing folder.
    static func reportedFolder(in game: URL) -> String? {
        let url = game.appendingPathComponent("report.json")
        guard let raw = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: raw) as? [String: Any]
        else { return nil }
        let engine = json["engine"] as? String ?? ""
        let abis = json["abis"] as? [String] ?? []
        let dexCount = json["dexCount"] as? Int ?? 0
        let libraries = json["libraries"] as? [[String: Any]] ?? []
        if abis.isEmpty && dexCount > 0 { return "java-data" }
        if engine == "Unity 6" { return "java-data" }
        if engine.hasPrefix("Unity") { return "unity-data" }
        if engine == "Cocos" {
            return libraries.contains(where: { ($0["name"] as? String) == "libfmod.so" })
                ? "cocos-data" : "java-data"
        }
        switch engine {
        case "Minecraft": return "minecraft-data"
        case "SDL":
            return libraries.contains(where: {
                ($0["name"] as? String ?? "").hasPrefix("libdxvk")
            }) ? "sdl-data" : "java-data"
        case "Python", "Java", "libGDX", "React Native", ".NET / Xamarin", "Flutter":
            return "java-data"
        case "Unreal Engine": return "ue4-data"
        case "Rockstar": return "gta-data"
        case "Godot": return "godot-data"
        case "NativeActivity": return "na-data"
        case "GameMaker": return "gm-data"
        default: return dexCount > 0 ? "java-data" : nil
        }
    }

    static func preferredRuntime(in game: URL) -> URL? {
        let found = runtimeFolders(in: game)
        guard !found.isEmpty else { return nil }
        if let reported = reportedFolder(in: game),
           let exact = found.first(where: { $0.lastPathComponent == reported }) {
            return exact
        }
        return found.count == 1 ? found[0] : nil
    }

    /// Only folders that are already present on disk are offered as import
    /// destinations. This preserves runtime layouts and avoids fake trees.
    static func destinations(in game: URL, package: String?,
                             sharedRoot: URL?) -> [Destination] {
        guard readableFolder(game) else { return [] }
        var result: [Destination] = []
        var seen = Set<String>()
        func add(_ url: URL?, label: String, kind: String, root: URL) {
            guard let url, readableFolder(url), seen.insert(url.standardizedFileURL.path).inserted
            else { return }
            result.append(Destination(id: url.standardizedFileURL.path, label: label,
                                      folder: url, root: root, kind: kind))
        }
        let preferred = preferredRuntime(in: game)
        let folders = runtimeFolders(in: game)
        let sorted = folders.sorted {
            if $0 == preferred { return true }
            if $1 == preferred { return false }
            return $0.lastPathComponent < $1.lastPathComponent
        }
        for runtime in sorted {
            let name = runtime.lastPathComponent
            let external = existingPath(runtime, ["sdcard", "Android"])
            if let package {
                add(existingPath(runtime, ["sdcard", "Android", "data", package, "files"]),
                    label: name + " · Android/data/files", kind: "external-files", root: game)
                add(existingPath(runtime, ["sdcard", "Android", "data", package]),
                    label: name + " · Android/data", kind: "data", root: game)
                add(existingPath(runtime, ["sdcard", "Android", "obb", package]),
                    label: name + " · Android/obb", kind: "obb", root: game)
            }
            add(existingPath(external ?? runtime, external == nil ?
                             ["sdcard", "Android", "data"] : ["data"]),
                label: name + " · Android/data (sin paquete)", kind: "data-parent", root: game)
            add(existingPath(runtime, ["files"]),
                label: name + " · /data/data/files", kind: "private", root: game)
            add(existingPath(runtime, ["sdcard"]),
                label: name + " · sdcard", kind: "sdcard", root: game)
            add(runtime, label: name + " · raíz del motor", kind: "runtime", root: game)
        }
        add(existingPath(game, ["obb"]), label: "obb · junto al APK (alternativa Husk)",
            kind: "fallback-obb", root: game)
        add(sharedRoot, label: "Almacenamiento compartido · /sdcard",
            kind: "shared", root: sharedRoot ?? game)
        add(game, label: "Carpeta completa del juego", kind: "game", root: game)
        return result
    }
}


/// Recovers only BloomBox-owned, abandoned staging files.
/// Never walks Documents, Husk's data/OBB, app containers or unknown system tmp files.
enum BloomBoxTemporaryStorage {
    private struct Artifact {
        let url: URL
        let bytes: Int64
        let lastModified: Date
    }

    private static func artifact(at url: URL, using fm: FileManager) -> Artifact? {
        let keys: Set<URLResourceKey> = [
            .isSymbolicLinkKey, .isDirectoryKey, .isRegularFileKey,
            .fileSizeKey, .contentModificationDateKey
        ]
        guard let values = try? url.resourceValues(forKeys: keys),
              values.isSymbolicLink != true else { return nil }
        var bytes: Int64 = values.isRegularFile == true ? Int64(values.fileSize ?? 0) : 0
        var latest = values.contentModificationDate ?? Date.distantFuture
        if values.isDirectory == true {
            guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: Array(keys),
                                                 options: [.skipsHiddenFiles]) else { return nil }
            for case let child as URL in enumerator {
                guard let info = try? child.resourceValues(forKeys: keys),
                      info.isSymbolicLink != true else { return nil }
                if info.isRegularFile == true {
                    bytes += Int64(info.fileSize ?? 0)
                }
                if let modified = info.contentModificationDate, modified > latest {
                    latest = modified
                }
            }
        }
        return Artifact(url: url, bytes: bytes, lastModified: latest)
    }

    /// Check on launch/foreground. Young files stay untouched even above the
    /// limit because an installation or SideStore handoff may still be active.
    @discardableResult
    static func cleanupIfNeeded(root: URL = FileManager.default.temporaryDirectory,
                                thresholdBytes: Int64 = 1_000_000_000,
                                minimumAge: TimeInterval = 6 * 60 * 60,
                                now: Date = Date()) -> Int64 {
        let fm = FileManager.default
        let rootURL = root.standardizedFileURL
        guard let items = try? fm.contentsOfDirectory(at: rootURL,
                    includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                    options: [.skipsHiddenFiles]) else { return 0 }

        var candidates: [Artifact] = []
        for item in items {
            let name = item.lastPathComponent
            if name == "BloomBoxSideStoreHandoff" {
                guard let handoffs = try? fm.contentsOfDirectory(
                    at: item, includingPropertiesForKeys: [.isSymbolicLinkKey],
                    options: [.skipsHiddenFiles]) else { continue }
                for ipa in handoffs where ipa.pathExtension.lowercased() == "ipa" {
                    if let candidate = artifact(at: ipa, using: fm) { candidates.append(candidate) }
                }
            } else if name.hasPrefix("BloomBoxInstall-") ||
                        name.hasPrefix("BloomBox-Husk-Import-") ||
                        (name.hasPrefix("BloomBox-GetMoreRam-") && item.pathExtension == "ipa") {
                if let candidate = artifact(at: item, using: fm) { candidates.append(candidate) }
            }
        }
        var total = candidates.reduce(Int64(0)) { $0 + $1.bytes }
        guard total > thresholdBytes else { return 0 }
        var removed: Int64 = 0
        for candidate in candidates.sorted(by: { $0.lastModified < $1.lastModified }) {
            if total <= thresholdBytes { break }
            guard now.timeIntervalSince(candidate.lastModified) >= minimumAge else { continue }
            do {
                try fm.removeItem(at: candidate.url)
                total -= candidate.bytes
                removed += candidate.bytes
            } catch {
                NSLog("BloomBox temp cleanup skipped %@: %@", candidate.url.lastPathComponent,
                      error.localizedDescription)
            }
        }
        if removed > 0 { NSLog("BloomBox cleared %lld bytes of abandoned temporary files", removed) }
        return removed
    }
}
