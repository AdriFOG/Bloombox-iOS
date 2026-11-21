import Foundation
import SwiftUI

// MARK: - OpenPortsGames: discovery only. Husk compatibility is never a catalog filter.

private struct BloomBoxOpenPortsResponse: Decodable {
    let schema: String
    let version: Int
    let ports: [BloomBoxOpenPort]
}

private struct BloomBoxOpenPort: Decodable, Identifiable {
    struct Release: Decodable {
        let version: String?
        let date: String?
    }
    struct Artwork: Decodable {
        let src: String
        let alt: String?
    }
    struct Download: Decodable, Identifiable {
        let label: String
        let url: String
        let size: String?
        var id: String { url }
        var link: URL? { BloomBoxPortSecurity.https(url) }
    }

    let id: String
    let title: String
    let game: String?
    let kind: String?
    let genre: String?
    let portType: String?
    let status: String
    let platforms: [String]?
    let originalSystems: [String]?
    let developers: [String]?
    let sources: [String]?
    let summary: String?
    let summaryEs: String?
    let notes: String?
    let notesEs: String?
    let noOriginalGameRequired: Bool?
    let release: Release?
    let cover: Artwork?
    let downloads: [Download]?

    var sourceURL: URL? { sources?.compactMap(BloomBoxPortSecurity.https).first }
    var artworkURL: URL? { cover.flatMap { BloomBoxPortSecurity.https($0.src) } }
    var isAndroid: Bool { platforms?.contains("android") == true }
    var isValid: Bool { !id.isEmpty && id.count <= 100 && !title.isEmpty && title.count <= 140 }
    var category: String {
        switch kind {
        case "system": return "Sistemas"
        case "tool": return "Herramientas"
        default: return "Juegos"
        }
    }
    func synopsis(english: Bool) -> String {
        (english ? (summary ?? summaryEs) : (summaryEs ?? summary))
            ?? (english ? (notes ?? notesEs) : (notesEs ?? notes))
            ?? (english ? "See the original project for details." : "Consulta el proyecto original para más detalles.")
    }
    var apkDownloads: [Download] {
        (downloads ?? []).filter { $0.link?.pathExtension.lowercased() == "apk" }
    }
}

// Status belongs to BloomBox, NOT OpenPortsGames' own `verified` field.
private struct BloomBoxPortVerificationFeed: Decodable {
    let schemaVersion: Int
    let catalog: String
    let entries: [BloomBoxPortVerification]
}
private struct BloomBoxPortVerification: Decodable {
    let id: String
    let state: String
    let portVersion: String
    let testedAt: String
    let bloomboxVersion: String
    let huskVersion: String
    let device: String?
    let notesEs: String?
    let notesEn: String?

    var isValid: Bool {
        !id.isEmpty && id.count <= 100 && !portVersion.isEmpty && portVersion.count <= 80 &&
        !testedAt.isEmpty && !bloomboxVersion.isEmpty && !huskVersion.isEmpty &&
        ["verified", "issues", "incompatible"].contains(state)
    }
}

private enum BloomBoxPortSecurity {
    static func https(_ raw: String) -> URL? {
        guard raw.count <= 2048, let url = URL(string: raw),
              url.scheme?.lowercased() == "https", url.host != nil,
              url.user == nil, url.password == nil else { return nil }
        return url
    }

    // Only a release APK from the same official GitHub project may be
    // downloaded inside BloomBox. Other links remain visible externally.
    static func officialGitHubAPK(_ asset: BloomBoxOpenPort.Download,
                                  port: BloomBoxOpenPort) -> URL? {
        guard let url = asset.link, url.host?.lowercased() == "github.com",
              url.query == nil, url.fragment == nil,
              url.pathExtension.lowercased() == "apk" else { return nil }
        let path = url.path.split(separator: "/").map(String.init)
        guard path.count == 6, path[2] == "releases", path[3] == "download",
              !path[0].isEmpty, !path[1].isEmpty, !path[4].isEmpty else { return nil }
        return (port.sources ?? []).contains { raw in
            guard let source = https(raw), source.host?.lowercased() == "github.com" else { return false }
            let bits = source.path.split(separator: "/").map(String.init)
            return bits.count >= 2 &&
                bits[0].caseInsensitiveCompare(path[0]) == .orderedSame &&
                bits[1].replacingOccurrences(of: ".git", with: "")
                    .caseInsensitiveCompare(path[1]) == .orderedSame
        } ? url : nil
    }
}

@MainActor
private final class BloomBoxPortCatalog: ObservableObject {
    @Published private(set) var ports: [BloomBoxOpenPort] = []
    @Published private(set) var verifications: [String: BloomBoxPortVerification] = [:]
    @Published private(set) var refreshing = false
    @Published private(set) var lastError: String?
    @Published private(set) var lastSync: Date?

    private static let source = URL(string: "https://openportsgames.com/api/ports.json")!
    private static let badges = URL(string: "https://raw.githubusercontent.com/AdriFOG/Bloombox-Remote-Systems/main/catalog/port-verifications.json")!
    private static let cacheName = "BloomBox-OpenPortsGames-Android-v1.json"
    private static let syncKey = "BloomBoxPortStoreLastSync-v1"
    private var lastRefresh: Date?

    init() {
        lastSync = UserDefaults.standard.object(forKey: Self.syncKey) as? Date
        if let saved = try? Data(contentsOf: Self.cacheURL),
           let response = try? JSONDecoder().decode(BloomBoxOpenPortsResponse.self, from: saved),
           response.schema == "openportsgames/catalog", response.version == 2 {
            ports = response.ports.filter { $0.isAndroid && $0.isValid }
                .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        }
    }

    private static var cacheURL: URL {
        let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return folder.appendingPathComponent(cacheName)
    }

    private static func fetch(_ url: URL, maxBytes: Int) async throws -> Data {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 28
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse,
              (200...299).contains(response.statusCode),
              data.count > 0, data.count <= maxBytes else {
            throw BloomBoxPortError.unavailable
        }
        return data
    }

    func refresh(force: Bool = false) async {
        guard !refreshing else { return }
        if !force, let lastRefresh, Date().timeIntervalSince(lastRefresh) < 120 { return }
        refreshing = true
        defer { refreshing = false; lastRefresh = Date() }

        do {
            let data = try await Self.fetch(Self.source, maxBytes: 25_000_000)
            let feed = try JSONDecoder().decode(BloomBoxOpenPortsResponse.self, from: data)
            guard feed.schema == "openportsgames/catalog", feed.version == 2,
                  feed.ports.count < 15_000 else { throw BloomBoxPortError.unavailable }
            let android = feed.ports.filter { $0.isAndroid && $0.isValid }
            guard !android.isEmpty else { throw BloomBoxPortError.unavailable }
            ports = android.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            try? data.write(to: Self.cacheURL, options: .atomic)
            lastSync = Date()
            UserDefaults.standard.set(lastSync, forKey: Self.syncKey)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }

        // Independent, optional BloomBox-only badge feed. Fail closed on
        // missing/stale data: a network failure never invents a "verified" badge.
        do {
            let data = try await Self.fetch(Self.badges, maxBytes: 300_000)
            let feed = try JSONDecoder().decode(BloomBoxPortVerificationFeed.self, from: data)
            guard feed.schemaVersion == 1, feed.catalog == "openportsgames/catalog",
                  feed.entries.count <= 2500, feed.entries.allSatisfy(\.isValid),
                  Set(feed.entries.map(\.id)).count == feed.entries.count else {
                throw BloomBoxPortError.unavailable
            }
            verifications = Dictionary(uniqueKeysWithValues: feed.entries.map { ($0.id, $0) })
        } catch {
            verifications = [:]
        }
    }

    func verification(for port: BloomBoxOpenPort) -> BloomBoxPortVerification? {
        guard let record = verifications[port.id],
              let version = port.release?.version, !version.isEmpty,
              record.portVersion == version else { return nil }
        return record
    }

    func downloadAPK(_ asset: BloomBoxOpenPort.Download, for port: BloomBoxOpenPort) async throws -> URL {
        guard let url = BloomBoxPortSecurity.officialGitHubAPK(asset, port: port) else {
            throw BloomBoxPortError.unavailable
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 120
        let (temporary, response) = try await URLSession.shared.download(for: request)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              (http.expectedContentLength < 0 || http.expectedContentLength <= 900_000_000),
              let finalHost = http.url?.host?.lowercased(),
              finalHost == "github.com" || finalHost == "release-assets.githubusercontent.com" ||
              finalHost == "objects.githubusercontent.com" else {
            throw BloomBoxPortError.unavailable
        }
        let fileManager = FileManager.default
        let size = (try temporary.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size > 0 && size <= 900_000_000 else { throw BloomBoxPortError.unavailable }
        let folder = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Inbox", isDirectory: true)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appendingPathComponent("BloomBoxPortStore-" + UUID().uuidString + ".apk")
        try fileManager.moveItem(at: temporary, to: destination)
        return destination
    }
}

private enum BloomBoxPortError: LocalizedError {
    case unavailable
    var errorDescription: String? {
        "No se pudo obtener el archivo o validar el origen del APK. Abre el repositorio oficial y descárgalo manualmente."
    }
}

// MARK: - Native Port Store interface

struct BloomBoxPortStore: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("BloomBoxPreferredLanguage", store: LiveContainerPreferencesAdapter.defaults)
    private var preferredLanguage = "system"
    @StateObject private var catalog = BloomBoxPortCatalog()
    @State private var query = ""
    @State private var filter = "all"
    @State private var category = "all"
    @State private var selectedPort: BloomBoxOpenPort?

    private var english: Bool {
        preferredLanguage == "en" ||
        (preferredLanguage == "system" &&
         (Locale.preferredLanguages.first ?? "en").lowercased().hasPrefix("en"))
    }

    private var visible: [BloomBoxOpenPort] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return catalog.ports.filter { port in
            let state = catalog.verification(for: port)?.state
            if filter == "verified" && state != "verified" { return false }
            if filter == "unverified" && state != nil { return false }
            if filter == "issues" && state != "issues" && state != "incompatible" { return false }
            if category != "all" && port.kind != category && !(category == "game" && port.kind == nil) {
                return false
            }
            if term.isEmpty { return true }
            return ([port.title, port.game ?? "", port.category,
                     port.genre ?? "", port.originalSystems?.joined(separator: " ") ?? "",
                     port.developers?.joined(separator: " ") ?? ""]
                .contains { $0.localizedCaseInsensitiveContains(term) })
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "gamecontroller.fill")
                            .font(.largeTitle).foregroundStyle(.cyan)
                            .frame(width: 56, height: 56)
                            .background(.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("BloomBox Port Store").font(.title2.bold())
                            Text(english ? "Android game ports · all projects" : "Ports Android · catálogo general")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    HStack {
                        Label(english ? "\(catalog.ports.count) Android ports" : "\(catalog.ports.count) ports Android",
                              systemImage: "square.grid.2x2.fill")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            Task { await catalog.refresh(force: true) }
                        } label: {
                            Label(english ? "Refresh" : "Actualizar", systemImage: "arrow.clockwise")
                                .labelStyle(.iconOnly)
                        }.disabled(catalog.refreshing)
                    }
                    if catalog.refreshing { ProgressView(english ? "Updating catalog…" : "Actualizando catálogo…") }
                    if let lastSync = catalog.lastSync {
                        Text((english ? "Last updated: " : "Última sincronización: ") +
                             lastSync.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    if let message = catalog.lastError {
                        Label(message, systemImage: "wifi.exclamationmark")
                            .font(.footnote).foregroundStyle(.orange)
                    }
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField(english ? "Search ports, games, consoles…" : "Buscar ports, juegos, consolas…",
                                  text: $query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .padding(12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

                    Picker(english ? "Test status" : "Estado de prueba", selection: $filter) {
                        Text(english ? "All" : "Todos").tag("all")
                        Text(english ? "Verified" : "Verificados").tag("verified")
                        Text(english ? "Unverified" : "Sin verificar").tag("unverified")
                        Text(english ? "Issues" : "Problemas").tag("issues")
                    }.pickerStyle(.segmented)

                    HStack {
                        Text(english ? "Category" : "Categoría").font(.subheadline)
                        Spacer()
                        Picker(english ? "Category" : "Categoría", selection: $category) {
                            Text(english ? "All" : "Todas").tag("all")
                            Text(english ? "Games" : "Juegos").tag("game")
                            Text(english ? "Systems" : "Sistemas").tag("system")
                            Text(english ? "Tools" : "Herramientas").tag("tool")
                        }.pickerStyle(.menu)
                    }
                    if visible.isEmpty && !catalog.refreshing {
                        Text(english ? "No matching ports. Try another search." :
                             "No hay coincidencias. Prueba otra búsqueda.")
                            .foregroundStyle(.secondary).padding(.vertical, 25)
                    }
                    ForEach(visible) { port in
                        Button { selectedPort = port } label: {
                            portRow(port)
                        }.buttonStyle(.plain)
                    }
                    Divider()
                    Text(english
                         ? "Catalog data © OpenPortsGames · CC BY 4.0. BloomBox badges are independent device tests. Projects and files belong to their respective authors."
                         : "Datos del catálogo: OpenPortsGames · CC BY 4.0. Las insignias de BloomBox son pruebas independientes. Cada proyecto pertenece a sus autores.")
                        .font(.caption2).foregroundStyle(.secondary)
                    Link(english ? "Open original catalog" : "Abrir catálogo original",
                         destination: URL(string: "https://openportsgames.com/es/android/")!)
                        .font(.footnote)
                }.padding(18)
            }
            .background(BloomBoxProfileThemeBackdrop())
            .navigationTitle("Port Store")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(english ? "Close" : "Cerrar") { dismiss() }
                }
            }
            .task { await catalog.refresh() }
            .sheet(item: $selectedPort) { port in
                BloomBoxPortDetails(port: port, verification: catalog.verification(for: port),
                                    english: english, download: { asset in
                    try await catalog.downloadAPK(asset, for: port)
                }, completed: { file in
                    selectedPort = nil
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                        NotificationCenter.default.post(
                            name: Notification.Name("BloomBoxPortStoreAPKReady"),
                            object: file
                        )
                    }
                })
            }
        }.navigationViewStyle(.stack)
    }

    private func portRow(_ port: BloomBoxOpenPort) -> some View {
        HStack(alignment: .top, spacing: 12) {
            BloomBoxPortCover(url: port.artworkURL)
                .frame(width: 74, height: 88).clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 5) {
                Text(port.title).font(.headline).foregroundStyle(.primary).lineLimit(2)
                Text([port.originalSystems?.first, port.genre]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                BloomBoxPortStatusBadge(verification: catalog.verification(for: port), english: english)
                HStack(spacing: 8) {
                    if !port.apkDownloads.isEmpty {
                        Label("APK", systemImage: "arrow.down.circle")
                    }
                    Text(port.status.uppercased())
                }.font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct BloomBoxPortCover: View {
    let url: URL?
    var body: some View {
        AsyncImage(url: url) { phase in
            if case let .success(image) = phase {
                image.resizable().scaledToFill()
            } else {
                ZStack {
                    Color.indigo.opacity(0.30)
                    Image(systemName: "gamecontroller.fill").font(.largeTitle)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }.clipped()
    }
}

private struct BloomBoxPortStatusBadge: View {
    let verification: BloomBoxPortVerification?
    let english: Bool
    var body: some View {
        let state = verification?.state
        let label: String = state == "verified" ? (english ? "Verified" : "Verificado") :
            state == "issues" ? (english ? "Known issues" : "Problemas conocidos") :
            state == "incompatible" ? (english ? "Not compatible" : "No compatible") :
            (english ? "Not tested" : "Sin verificar")
        let color: Color = state == "verified" ? .green :
            state == "issues" ? .orange : state == "incompatible" ? .red : .secondary
        Label(label, systemImage: state == "verified" ? "checkmark.seal.fill" :
              state == "issues" ? "exclamationmark.triangle.fill" :
              state == "incompatible" ? "xmark.circle.fill" : "questionmark.circle")
            .font(.caption2.weight(.semibold)).foregroundStyle(color)
    }
}

private struct BloomBoxPortDetails: View {
    let port: BloomBoxOpenPort
    let verification: BloomBoxPortVerification?
    let english: Bool
    let download: (BloomBoxOpenPort.Download) async throws -> URL
    let completed: (URL) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pendingAsset: BloomBoxOpenPort.Download?
    @State private var confirmDownload = false
    @State private var downloading = false
    @State private var downloadError = ""
    @State private var showingError = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 14) {
                        BloomBoxPortCover(url: port.artworkURL)
                            .frame(width: 116, height: 145)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        VStack(alignment: .leading, spacing: 8) {
                            Text(port.title).font(.title3.bold())
                            Text(port.game ?? "").font(.subheadline).foregroundStyle(.secondary)
                            BloomBoxPortStatusBadge(verification: verification, english: english)
                            if let version = port.release?.version {
                                Text((english ? "Version: " : "Versión: ") + version)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Text(port.category).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Text(port.synopsis(english: english)).font(.body)
                    if let author = port.developers?.joined(separator: ", ") {
                        Label(author, systemImage: "person.crop.circle").font(.footnote)
                    }
                    if port.noOriginalGameRequired != true {
                        Label(english ? "This project may require your own original game files." :
                              "Este proyecto puede requerir tus propios archivos originales del juego.",
                              systemImage: "info.circle")
                            .font(.footnote).foregroundStyle(.orange)
                    }
                    if let verification {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(english ? "BloomBox test details" : "Prueba de BloomBox")
                                .font(.headline)
                            Text(verification.testedAt + " · BloomBox " + verification.bloomboxVersion +
                                 " · Husk " + verification.huskVersion).font(.caption)
                            if let notes = english ? (verification.notesEn ?? verification.notesEs) :
                                (verification.notesEs ?? verification.notesEn) {
                                Text(notes).font(.footnote)
                            }
                        }.padding(13)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 15))
                    }
                    if downloading { ProgressView(english ? "Downloading APK…" : "Descargando APK…") }
                    if !port.apkDownloads.isEmpty {
                        Text(english ? "Official Android downloads" : "Descargas Android oficiales")
                            .font(.headline)
                        ForEach(port.apkDownloads) { asset in
                            VStack(alignment: .leading, spacing: 7) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(asset.label).font(.subheadline.bold())
                                        if let size = asset.size {
                                            Text(size).font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if BloomBoxPortSecurity.officialGitHubAPK(asset, port: port) != nil {
                                        Button(english ? "Install" : "Instalar") {
                                            pendingAsset = asset
                                            confirmDownload = true
                                        }.buttonStyle(.borderedProminent).disabled(downloading)
                                    }
                                }
                                if let link = asset.link {
                                    Link(english ? "Open original download" : "Abrir descarga original",
                                         destination: link).font(.footnote)
                                }
                            }.padding(12)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    if let url = port.sourceURL {
                        Link(english ? "Official project / source" : "Proyecto original / código",
                             destination: url)
                            .font(.headline)
                    }
                    Text(english
                         ? "Only the original publisher's GitHub release APKs can be installed here. BloomBox does not host game files. Installing does not mean that Husk can run this port."
                         : "Solo se instalan directamente APK de releases oficiales de GitHub. BloomBox no aloja juegos. Instalar no significa que el port funcione en Husk.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(18)
            }
            .background(BloomBoxProfileThemeBackdrop())
            .navigationTitle(english ? "Port details" : "Detalles del port")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(english ? "Close" : "Cerrar") { dismiss() }
                }
            }
            .confirmationDialog(english ? "Download an APK from the original author?" :
                                "¿Descargar el APK desde el autor original?",
                                isPresented: $confirmDownload,
                                titleVisibility: .visible) {
                Button(english ? "Download and open installer" : "Descargar y abrir instalador") {
                    guard let asset = pendingAsset else { return }
                    downloading = true
                    Task {
                        defer { downloading = false }
                        do {
                            let saved = try await download(asset)
                            completed(saved)
                        } catch {
                            downloadError = error.localizedDescription
                            showingError = true
                        }
                    }
                }
                Button(english ? "Cancel" : "Cancelar", role: .cancel) {
                    pendingAsset = nil
                }
            } message: {
                Text(english
                     ? "Only download projects you trust. The APK will be passed to BloomBox's existing Husk installer for confirmation. Compatibility is not guaranteed."
                     : "Descarga únicamente proyectos confiables. El APK pasará al instalador existente de Husk para confirmación. No se garantiza compatibilidad.")
            }
            .alert(english ? "Download failed" : "Falló la descarga", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(downloadError)
            }
        }.navigationViewStyle(.stack)
    }
}
