import Foundation
import SwiftUI

// Android Port Store is discovery-first. OpenPortsGames supplies listings; BloomBox
// Remote Systems independently records only exact-version Husk compatibility tests.
// Neither the upstream "verified" flag nor an APK link implies iOS compatibility.

private struct BloomBoxPortCatalogResponse: Decodable {
    let schema: String
    let version: Int
    let ports: [BloomBoxAndroidPort]
}

private struct BloomBoxAndroidPort: Decodable, Identifiable {
    struct Release: Decodable {
        let version: String?
        let date: String?
    }
    struct Cover: Decodable {
        let src: String
        let alt: String
        let credit: String
    }
    struct Download: Decodable, Identifiable {
        let label: String
        let url: String
        let size: String?
        let note: String?
        var id: String { url }

        var safeURL: URL? { BloomBoxAndroidPort.safeHTTPS(url) }
    }

    let id: String
    let title: String
    let game: String?
    let status: String
    let platforms: [String]?
    let developers: [String]?
    let originalSystems: [String]?
    let genre: String?
    let portType: String?
    let release: Release?
    let cover: Cover?
    let summary: String?
    let summaryEs: String?
    let notes: String?
    let notesEs: String?
    let sources: [String]?
    let website: String?
    let downloads: [Download]?
    let wip: Bool?
    let noOriginalGameRequired: Bool?

    static func safeHTTPS(_ string: String) -> URL? {
        guard string.count <= 2048, let value = URL(string: string),
              value.scheme?.lowercased() == "https",
              value.host != nil, value.user == nil, value.password == nil else { return nil }
        return value
    }

    var coverURL: URL? { cover.flatMap { Self.safeHTTPS($0.src) } }
    var sourceURL: URL? {
        (sources ?? []).compactMap(Self.safeHTTPS).first ?? website.flatMap(Self.safeHTTPS)
    }
    var version: String? { release?.version }
    var hasAPK: Bool { (downloads ?? []).contains { $0.safeURL?.pathExtension.lowercased() == "apk" } }

    // Automatic handoff is restricted to assets from a GitHub release linked
    // to the upstream project's source repository. Other links open externally.
    func trustedAPK(_ download: Download) -> URL? {
        guard let url = download.safeURL,
              url.host?.lowercased() == "github.com",
              url.pathExtension.lowercased() == "apk",
              url.query == nil, url.fragment == nil else { return nil }
        let path = url.pathComponents.filter { $0 != "/" }
        guard path.count == 6, path[2] == "releases",
              path[3] == "download", !path[4].isEmpty else { return nil }
        let repo = Array(path.prefix(2))
        guard (sources ?? []).contains(where: { source in
            guard let link = Self.safeHTTPS(source),
                  link.host?.lowercased() == "github.com" else { return false }
            return Array(link.pathComponents.filter { $0 != "/" }.prefix(2)) == repo
        }) else { return nil }
        return url
    }

    func description(english: Bool) -> String {
        let value = english ? (summary ?? summaryEs) : (summaryEs ?? summary)
        return value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    func details(english: Bool) -> String {
        english ? (notes ?? notesEs ?? "") : (notesEs ?? notes ?? "")
    }
}

private struct BloomBoxPortVerificationIndex: Decodable {
    let schemaVersion: Int
    let catalog: String
    let entries: [BloomBoxPortVerification]
}

private struct BloomBoxPortVerification: Decodable {
    let id: String
    let version: String
    let status: String
    let testedAt: String?
    let notes: String?
    let notesEn: String?
    let bloomboxVersion: String?
    let huskVersion: String?

    func details(english: Bool) -> String? {
        english ? (notesEn ?? notes) : (notes ?? notesEn)
    }
}

@MainActor
private final class BloomBoxPortCatalog: ObservableObject {
    @Published private(set) var ports: [BloomBoxAndroidPort] = []
    @Published private(set) var checks: [String: BloomBoxPortVerification] = [:]
    @Published private(set) var loading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastSync: Date?
    private var refreshedAt: Date?

    private static let upstream = URL(string: "https://openportsgames.com/api/ports.json")!
    private static let compatibility = URL(string: "https://raw.githubusercontent.com/AdriFOG/Bloombox-Remote-Systems/main/catalog/android-port-verifications.json")!
    private static let catalogCache = "bloombox-android-ports-v1.json"
    private static let checksCache = "bloombox-android-checks-v1.json"

    init() {
        if let data = Self.readCache(Self.catalogCache) { acceptCatalog(data) }
        if let data = Self.readCache(Self.checksCache) { acceptChecks(data) }
    }

    private static func cacheURL(_ name: String) -> URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent(name)
    }

    private static func readCache(_ name: String) -> Data? {
        guard let url = cacheURL(name) else { return nil }
        return try? Data(contentsOf: url)
    }

    private static func saveCache(_ data: Data, name: String) {
        guard let url = cacheURL(name), data.count <= 32_000_000 else { return }
        try? data.write(to: url, options: .atomic)
    }

    @discardableResult
    private func acceptCatalog(_ data: Data) -> Bool {
        guard data.count <= 32_000_000,
              let result = try? JSONDecoder().decode(BloomBoxPortCatalogResponse.self, from: data),
              result.schema == "openportsgames/catalog", result.version == 2,
              result.ports.count <= 15_000 else { return false }
        var seen = Set<String>()
        ports = result.ports.filter {
            $0.status != "takedown" && $0.platforms?.contains("android") == true &&
            !$0.id.isEmpty && seen.insert($0.id).inserted
        }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        return true
    }

    @discardableResult
    private func acceptChecks(_ data: Data) -> Bool {
        guard data.count <= 1_000_000,
              let result = try? JSONDecoder().decode(BloomBoxPortVerificationIndex.self, from: data),
              result.schemaVersion == 1, result.catalog == "openportsgames/catalog",
              result.entries.count <= 4_000 else { return false }
        var updated: [String: BloomBoxPortVerification] = [:]
        for entry in result.entries where ["verified", "issues", "incompatible"].contains(entry.status) {
            if !entry.id.isEmpty && !entry.version.isEmpty {
                updated[entry.id] = entry
            }
        }
        checks = updated
        return true
    }

    func check(for port: BloomBoxAndroidPort) -> BloomBoxPortVerification? {
        guard let version = port.version, let item = checks[port.id],
              item.version == version else { return nil }
        return item
    }

    func refresh(force: Bool = false) async {
        if loading { return }
        if !force, let refreshedAt, Date().timeIntervalSince(refreshedAt) < 300 { return }
        loading = true
        defer { loading = false; refreshedAt = Date() }

        do {
            var request = URLRequest(url: Self.upstream)
            request.timeoutInterval = 30
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode), acceptCatalog(data) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            Self.saveCache(data, name: Self.catalogCache)
            lastSync = Date()
            errorMessage = nil
        } catch {
            errorMessage = ports.isEmpty ?
                (BloomBoxL10n.isEnglish ? "Could not load the Android catalog." : "No se pudo cargar el catálogo Android.") :
                (BloomBoxL10n.isEnglish ? "Showing previously saved catalog." : "Mostrando el catálogo guardado.")
        }

        // A missing or unreachable verification feed NEVER hides upstream ports.
        var request = URLRequest(url: Self.compatibility)
        request.timeoutInterval = 12
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if let (data, response) = try? await URLSession.shared.data(for: request),
           let http = response as? HTTPURLResponse,
           (200...299).contains(http.statusCode),
           acceptChecks(data) {
            Self.saveCache(data, name: Self.checksCache)
        }
    }
}

struct BloomBoxPortStore: View {
    let hasHusk: Bool
    let onAPKReady: (URL) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var catalog = BloomBoxPortCatalog()
    @State private var query = ""
    @State private var filter = "all"
    @State private var system = ""

    private var english: Bool { BloomBoxL10n.isEnglish }
    private var systems: [String] {
        Array(Set(catalog.ports.flatMap { $0.originalSystems ?? [] }))
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
    private var displayed: [BloomBoxAndroidPort] {
        catalog.ports.filter { port in
            if filter == "apk" && !port.hasAPK { return false }
            if filter == "verified" && catalog.check(for: port)?.status != "verified" { return false }
            if !system.isEmpty && !(port.originalSystems ?? []).contains(system) { return false }
            let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if term.isEmpty { return true }
            return ([port.title, port.game ?? "", port.genre ?? ""] +
                    (port.originalSystems ?? []) + (port.developers ?? []))
                .contains { $0.localizedStandardContains(term) }
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    HStack(spacing: 8) {
                        filterButton("all", title: english ? "All" : "Todos", icon: "square.grid.2x2.fill")
                        filterButton("apk", title: "APK", icon: "arrow.down.circle")
                        filterButton("verified", title: english ? "Verified" : "Verificados", icon: "checkmark.seal.fill")
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            systemButton("", label: english ? "All systems" : "Todas las consolas")
                            ForEach(systems, id: \.self) { value in
                                systemButton(value, label: value)
                            }
                        }.padding(.vertical, 1)
                    }
                    if let error = catalog.errorMessage {
                        Label(error, systemImage: "wifi.exclamationmark")
                            .font(.footnote).foregroundStyle(.orange)
                    }
                    if catalog.loading && catalog.ports.isEmpty {
                        ProgressView(english ? "Loading ports…" : "Cargando ports…")
                            .frame(maxWidth: .infinity).padding(40)
                    } else if displayed.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "gamecontroller").font(.largeTitle)
                            Text(english ? "No ports match these filters." : "No hay ports con estos filtros.")
                                .multilineTextAlignment(.center)
                        }.frame(maxWidth: .infinity).padding(35).foregroundStyle(.secondary)
                    } else {
                        Text(english ? "\(displayed.count) of \(catalog.ports.count) Android ports" :
                                "\(displayed.count) de \(catalog.ports.count) ports Android")
                            .font(.subheadline).foregroundStyle(.secondary)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 145, maximum: 210), spacing: 12)], spacing: 16) {
                            ForEach(displayed) { port in
                                NavigationLink(destination: BloomBoxPortDetail(
                                    port: port, check: catalog.check(for: port),
                                    hasHusk: hasHusk, onAPKReady: onAPKReady
                                )) {
                                    BloomBoxPortCard(port: port, check: catalog.check(for: port))
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(english ? "Catalog: OpenPortsGames · Compatibility: BloomBox Systems" :
                                "Catálogo: OpenPortsGames · Compatibilidad: BloomBox Systems")
                            .font(.caption).foregroundStyle(.secondary)
                        Link("OpenPortsGames · CC BY 4.0", destination: URL(string: "https://openportsgames.com/")!)
                            .font(.caption)
                        Text(english ?
                             "Some imported records belong to their original catalog authors. Verified badges only reflect exact versions tested on BloomBox and Husk." :
                             "Algunos registros importados pertenecen a sus autores originales. Las insignias solo indican versiones probadas en BloomBox y Husk.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }.padding(.top, 10)
                }.padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Port Store")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: english ? "Search Android ports" : "Buscar ports Android")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(english ? "Close" : "Cerrar") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await catalog.refresh(force: true) } } label: {
                        Image(systemName: "arrow.clockwise")
                    }.disabled(catalog.loading)
                }
            }
        }
        .navigationViewStyle(.stack)
        .task { await catalog.refresh() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("BloomBox Port Store", systemImage: "gamecontroller.fill")
                .font(.title2.bold())
            Text(english ? "Native Android ports, decompilations and recompilations." :
                    "Ports nativos, decompilaciones y recompilaciones para Android.")
                .font(.subheadline)
            Text(english ? "Not every APK is compatible with Husk. Browse freely; tests are marked separately." :
                    "No todos los APK funcionan en Husk. Explora todo el catálogo; las pruebas se marcan aparte.")
                .font(.caption).foregroundStyle(.white.opacity(0.8))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(LinearGradient(colors: [.indigo, .purple.opacity(0.85)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 24))
    }

    private func filterButton(_ key: String, title: String, icon: String) -> some View {
        Button { filter = key } label: {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(filter == key ? Color.accentColor : Color(.secondarySystemGroupedBackground),
                            in: Capsule())
                .foregroundStyle(filter == key ? Color.white : Color.primary)
        }.buttonStyle(.plain)
    }

    private func systemButton(_ key: String, label: String) -> some View {
        Button { system = key } label: {
            Text(label).font(.caption.weight(.medium))
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(system == key ? Color.accentColor.opacity(0.2) :
                            Color(.secondarySystemGroupedBackground), in: Capsule())
        }.buttonStyle(.plain)
    }
}

private struct BloomBoxPortCard: View {
    let port: BloomBoxAndroidPort
    let check: BloomBoxPortVerification?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            artwork
            Text(port.title).font(.subheadline.bold()).lineLimit(2)
            Text(port.originalSystems?.first ?? "Android")
                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            HStack(spacing: 4) {
                Image(systemName: badgeIcon)
                Text(badgeText)
            }.font(.caption2.weight(.semibold))
             .foregroundStyle(check == nil ? Color.secondary :
                              check?.status == "verified" ? Color.green : Color.orange)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var artwork: some View {
        AsyncImage(url: port.coverURL) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            ZStack {
                Color.indigo.opacity(0.2)
                Image(systemName: "gamecontroller.fill").foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity).frame(height: 138)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 13))
    }

    private var badgeIcon: String {
        switch check?.status {
        case "verified": return "checkmark.seal.fill"
        case "issues": return "exclamationmark.triangle.fill"
        case "incompatible": return "xmark.circle.fill"
        default: return "questionmark.circle"
        }
    }
    private var badgeText: String {
        let en = BloomBoxL10n.isEnglish
        switch check?.status {
        case "verified": return en ? "BloomBox verified" : "Verificado"
        case "issues": return en ? "Known issues" : "Con problemas"
        case "incompatible": return en ? "Incompatible" : "No compatible"
        default: return en ? "Not tested" : "Sin verificar"
        }
    }
}

private struct BloomBoxPortDetail: View {
    let port: BloomBoxAndroidPort
    let check: BloomBoxPortVerification?
    let hasHusk: Bool
    let onAPKReady: (URL) -> Void

    @State private var pending: BloomBoxAndroidPort.Download?
    @State private var downloading = false
    @State private var downloadError: String?
    private var english: Bool { BloomBoxL10n.isEnglish }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BloomBoxPortCard(port: port, check: check)
                    .frame(maxWidth: 240)
                Text(port.game ?? port.title).font(.title3.bold())
                Text(port.description(english: english)).font(.body)
                if !port.details(english: english).isEmpty {
                    Text(port.details(english: english)).font(.subheadline).foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Label(port.status.capitalized, systemImage: "hammer")
                    if let version = port.version {
                        Text("v" + version)
                    }
                }.font(.caption).foregroundStyle(.secondary)
                if let check {
                    Label(english ? "BloomBox test: " + check.status : "Prueba BloomBox: " + check.status,
                          systemImage: check.status == "verified" ? "checkmark.seal.fill" : "info.circle")
                        .foregroundStyle(check.status == "verified" ? .green : .orange)
                    if let detail = check.details(english: english), !detail.isEmpty {
                        Text(detail).font(.caption)
                    }
                    if let deviceVersion = check.huskVersion {
                        Text("Husk: " + deviceVersion).font(.caption2)
                    }
                    if let bb = check.bloomboxVersion {
                        Text("BloomBox: " + bb).font(.caption2)
                    }
                } else {
                    Label(english ? "Not tested in BloomBox/Husk" : "Sin probar en BloomBox/Husk",
                          systemImage: "questionmark.circle")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if port.noOriginalGameRequired != true {
                    Label(english ? "Some ports require files from a legally obtained copy of the original game." :
                            "Algunos ports requieren archivos de una copia legítima del juego original.",
                          systemImage: "info.circle")
                        .font(.caption)
                }
                if port.wip == true {
                    Label(english ? "Work in progress" : "En desarrollo",
                          systemImage: "hammer.fill").font(.caption)
                }
                Text(english ? "Official downloads" : "Descargas oficiales")
                    .font(.headline)
                if (port.downloads ?? []).isEmpty {
                    Text(english ? "No downloadable build listed." : "No hay una compilación publicada.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(port.downloads ?? []) { item in
                    if let url = item.safeURL {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(item.label).font(.subheadline.weight(.medium))
                                Spacer()
                                if let size = item.size { Text(size).font(.caption).foregroundStyle(.secondary) }
                            }
                            if let note = item.note { Text(note).font(.caption).foregroundStyle(.secondary) }
                            if port.trustedAPK(item) != nil && hasHusk {
                                Button {
                                    pending = item
                                } label: {
                                    Label(english ? "Download for Husk" : "Descargar para Husk",
                                          systemImage: "square.and.arrow.down.fill")
                                        .frame(maxWidth: .infinity)
                                }.buttonStyle(.borderedProminent).disabled(downloading)
                            } else {
                                Link(destination: url) {
                                    Label(english ? "Open publisher's download" : "Abrir descarga del autor",
                                          systemImage: "arrow.up.right.square")
                                }.font(.subheadline)
                            }
                        }
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 15))
                    }
                }
                if !hasHusk {
                    Link(english ? "Get Husk to install APKs" : "Descargar Husk para instalar APK",
                         destination: URL(string: "https://github.com/Leviidev/Husk/releases")!)
                }
                if downloading {
                    ProgressView(english ? "Downloading and checking APK…" :
                                    "Descargando y comprobando APK…")
                }
                if let source = port.sourceURL {
                    Link(english ? "Original project and source" : "Proyecto y código del autor",
                         destination: source)
                }
                Link("OpenPortsGames", destination: URL(string:
                    "https://openportsgames.com/es/ports/" + port.id)!)
                    .font(.caption)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(18)
        }
        .navigationTitle(port.title).navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            english ? "Install with Husk?" : "¿Instalar con Husk?",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } })
        ) {
            Button(english ? "Download APK" : "Descargar APK") {
                guard let item = pending else { return }
                pending = nil
                Task { await downloadAPK(item) }
            }
            Button(english ? "Cancel" : "Cancelar", role: .cancel) { pending = nil }
        } message: {
            Text(english ?
                 "BloomBox will check the APK, then ask for installation. Compatibility is not guaranteed." :
                 "BloomBox comprobará el APK y después pedirá confirmar la instalación. No se garantiza compatibilidad.")
        }
        .alert(english ? "Download failed" : "Falló la descarga",
               isPresented: Binding(get: { downloadError != nil }, set: { if !$0 { downloadError = nil } })) {
            Button("OK") { downloadError = nil }
        } message: { Text(downloadError ?? "") }
    }

    @MainActor
    private func downloadAPK(_ item: BloomBoxAndroidPort.Download) async {
        guard !downloading, hasHusk, let url = port.trustedAPK(item) else { return }
        downloading = true
        defer { downloading = false }
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 120
            let (temporary, response) = try await URLSession.shared.download(for: request)
            guard let response = response as? HTTPURLResponse,
                  (200...299).contains(response.statusCode) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            let fm = FileManager.default
            let bytes = (try temporary.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            guard bytes > 1024, bytes <= 1_500_000_000 else {
                throw CocoaError(.fileReadTooLarge)
            }
            let folder = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("PortStoreDownloads", isDirectory: true)
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            let safeTitle = String(port.id.prefix(75))
            let output = folder.appendingPathComponent(safeTitle + "-" + UUID().uuidString + ".apk")
            try fm.copyItem(at: temporary, to: output)
            do {
                try BloomBoxArchive.validateAPK(output)
                onAPKReady(output) // Existing BloomBox/Husk installer asks the user to confirm.
            } catch {
                try? fm.removeItem(at: output)
                throw error
            }
        } catch {
            downloadError = error.localizedDescription
        }
    }
}
