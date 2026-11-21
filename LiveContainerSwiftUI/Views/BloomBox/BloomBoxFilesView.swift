import SwiftUI
import UniformTypeIdentifiers
import QuickLook

@MainActor
final class BloomBoxFilesModel: ObservableObject {
    @Published var entries: [URL] = []
    @Published var folder: URL?
    @Published var error: String?
    @Published var busy = false
    private(set) var store: BloomBoxFileStore?
    init() {
        do {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let store = try BloomBoxFileStore(root: BloomBoxFileStore.preferredRoot(in: documents))
            self.store = store
            folder = store.root
            reload()
        } catch { self.error = error.localizedDescription }
    }
    var isTrash: Bool { folder?.lastPathComponent == ".Trash" }
    func reload() {
        guard let store, let folder else { return }
        do { entries = try store.contents(folder) } catch { self.error = error.localizedDescription }
    }
    func run(_ action: (BloomBoxFileStore) throws -> Void) {
        guard let store else { return }
        do { try action(store); reload() } catch { self.error = error.localizedDescription }
    }
    func open(_ url: URL) {
        guard let store else { return }
        do { folder = try store.checked(url); reload() } catch { self.error = error.localizedDescription }
    }
    func importFiles(_ urls: [URL]) {
        guard let store, let folder, !busy else { return }
        busy = true
        Task {
            let failures = await Task.detached(priority: .userInitiated) {
                var failures: [String] = []
                for url in urls {
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    var coordinationError: NSError?
                    NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { readable in
                        do { try store.importFile(readable, into: folder) }
                        catch { failures.append("\(url.lastPathComponent): \(error.localizedDescription)") }
                    }
                    if let coordinationError { failures.append(coordinationError.localizedDescription) }
                }
                return failures
            }.value
            busy = false
            reload()
            if !failures.isEmpty { error = failures.joined(separator: "\n") }
        }
    }
}

struct BloomBoxFileSelection: Identifiable { let id = UUID(); let url: URL }
struct BloomBoxFileTransfer: Identifiable { let id = UUID(); let url: URL; let copying: Bool }

struct BloomBoxFilesView: View {
    @StateObject private var model = BloomBoxFilesModel()
    @Environment(\.dismiss) private var dismiss
    @State private var importing = false
    @State private var newFolder = false
    @State private var name = ""
    @State private var renaming: URL?
    @State private var preview: BloomBoxFileSelection?
    @State private var sharing: BloomBoxFileSelection?
    @State private var transferring: BloomBoxFileTransfer?
    @State private var search = ""
    @State private var showingAndroidFiles = false

    var body: some View {
        NavigationView {
            List {
                Section {
                    Button { showingAndroidFiles = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "folder.badge.gearshape")
                                .font(.title2).foregroundStyle(.green)
                                .frame(width: 34)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(BloomBoxL10n.isEnglish ? "Android files · Husk" : "Archivos Android · Husk")
                                    .font(.headline)
                                Text(BloomBoxL10n.isEnglish
                                     ? "Game folders, downloads and OBB"
                                     : "Carpetas de juegos, descargas y OBB")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 5)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("bloombox.files.android.entry")
                } header: {
                    Text(BloomBoxL10n.isEnglish ? "Storage" : "Almacenamiento")
                }
                if model.busy { ProgressView("Importando archivos…") }
                if model.entries.isEmpty && !model.busy {
                    Text(model.isTrash ? "La papelera está vacía." : "Importa documentos o crea tu primera carpeta.").foregroundStyle(.secondary)
                }
                ForEach(model.entries.filter { search.isEmpty || $0.lastPathComponent.localizedCaseInsensitiveContains(search) }, id: \.path) { url in
                    fileRow(url)
                }
            }
            .disabled(model.busy)
            .searchable(text: $search, prompt: "Buscar en esta carpeta")
            .navigationTitle(model.isTrash ? "Papelera" : (model.folder == model.store?.root ? "Archivos" : model.folder?.lastPathComponent ?? "Archivos"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if let folder = model.folder, folder != model.store?.root {
                        Button { search = ""; model.open(folder.deletingLastPathComponent()) } label: { Label("Volver", systemImage: "chevron.left") }.disabled(model.busy)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) { Button("Inicio") { dismiss() }.disabled(model.busy) }
                ToolbarItemGroup(placement: .bottomBar) {
                    if !model.isTrash {
                        Button { importing = true } label: { Label("Importar", systemImage: "square.and.arrow.down") }.disabled(model.busy)
                        Spacer()
                        Button { name = ""; newFolder = true } label: { Label("Carpeta", systemImage: "folder.badge.plus") }.disabled(model.busy)
                        Spacer()
                        Button {
                            model.run { store in model.open(try store.trashFolder()) }
                        } label: { Label("Papelera", systemImage: "trash") }.disabled(model.busy)
                    } else { Text("Los archivos se restauran en la carpeta principal.").font(.caption) }
                }
            }
        }
        .navigationViewStyle(.stack)
        .interactiveDismissDisabled(model.busy)
        .sheet(isPresented: $showingAndroidFiles) { BloomBoxAndroidFilesView() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.data], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): model.importFiles(urls)
            case .failure(let error): model.error = error.localizedDescription
            }
        }
        .alert("Nueva carpeta", isPresented: $newFolder) {
            TextField("Nombre", text: $name)
            Button("Crear") { if let folder = model.folder { model.run { try $0.createFolder(name, in: folder) } } }
            Button("Cancelar", role: .cancel) {}
        }
        .alert("Renombrar", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Nombre", text: $name)
            Button("Guardar") { if let url = renaming { model.run { try $0.rename(url, to: name) } }; renaming = nil }
            Button("Cancelar", role: .cancel) { renaming = nil }
        }
        .alert("Archivos", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("Aceptar") { model.error = nil }
        } message: { Text(model.error ?? "") }
        .sheet(item: $preview) { BloomBoxFilePreview(url: $0.url) }
        .sheet(item: $sharing) { BloomBoxShareFile(url: $0.url) }
        .sheet(item: $transferring) { selection in
            if let store = model.store {
                BloomBoxFolderPicker(store: store, source: selection.url, copying: selection.copying) { folder in
                    model.run {
                        if selection.copying { try $0.copy(selection.url, into: folder) }
                        else { try $0.move(selection.url, into: folder) }
                    }
                }
            }
        }
    }
    private func fileRow(_ url: URL) -> some View {
        let directory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        return Button {
            if model.isTrash { return }
            if directory { search = ""; model.open(url) }
            else { preview = BloomBoxFileSelection(url: url) }
        } label: {
            Label(url.lastPathComponent, systemImage: directory ? "folder.fill" : "doc.fill")
                .foregroundStyle(directory ? Color.blue : Color.primary)
                .padding(.vertical, 5)
        }
        .contextMenu {
            if model.isTrash {
                Button("Restaurar", systemImage: "arrow.uturn.backward") { model.run { try $0.restore(url) } }
            } else {
                if !directory {
                    Button("Compartir / Exportar", systemImage: "square.and.arrow.up") { sharing = BloomBoxFileSelection(url: url) }
                }
                Button("Mover a carpeta", systemImage: "folder") { transferring = BloomBoxFileTransfer(url: url, copying: false) }
                Button("Copiar a carpeta", systemImage: "doc.on.doc") { transferring = BloomBoxFileTransfer(url: url, copying: true) }
                Button("Renombrar", systemImage: "pencil") { name = url.lastPathComponent; renaming = url }
                Button("Mover a papelera", systemImage: "trash", role: .destructive) { model.run { try $0.moveToTrash(url) } }
            }
        }
    }
}

private struct BloomBoxShareFile: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: [url], applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
private struct BloomBoxFilePreview: UIViewControllerRepresentable {
    let url: URL
    func makeCoordinator() -> Coordinator { Coordinator(url) }
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController(); controller.dataSource = context.coordinator; return controller
    }
    func updateUIViewController(_ controller: QLPreviewController, context: Context) {}
    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(_ url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { url as NSURL }
    }
}


private struct BloomBoxFolderPicker: View {
    let store: BloomBoxFileStore
    let source: URL
    let copying: Bool
    let onSelect: (URL) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var current: URL?
    @State private var folders: [URL] = []
    @State private var error: String?

    var body: some View {
        NavigationView {
            List {
                if let current, current != store.root {
                    Button {
                        navigate(current.deletingLastPathComponent())
                    } label: { Label("Carpeta anterior", systemImage: "arrow.up.left") }
                }
                ForEach(folders, id: \.path) { folder in
                    Button { navigate(folder) } label: {
                        Label(folder.lastPathComponent, systemImage: "folder.fill")
                    }
                }
                if folders.isEmpty {
                    Text("No hay más carpetas aquí.").foregroundStyle(.secondary)
                }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle(copying ? "Copiar en" : "Mover a")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(copying ? "Copiar aquí" : "Mover aquí") {
                        if let current { onSelect(current); dismiss() }
                    }
                    .disabled(current == nil || (!copying && current == source.deletingLastPathComponent()))
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear { navigate(store.root) }
    }

    private func navigate(_ folder: URL) {
        do {
            let checked = try store.checked(folder)
            let sourceIsFolder = (try? source.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            let directories = try store.contents(checked).filter { url in
                guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
                    return false
                }
                return !sourceIsFolder || (url != source && !url.path.hasPrefix(source.path + "/"))
            }
            current = checked
            folders = directories
            error = nil
        } catch { self.error = error.localizedDescription }
    }
}

// Compatibility for views referenced by older launcher modules while the UI migrates.
typealias ManzanaFilesView = BloomBoxFilesView


// MARK: - Husk files: read-only first milestone.
//
// Takopi Explorer inspired the root-bound folder navigation. No writes or
// synthetic Android directories are performed. Husk's native TranslationLayer
// and its emulated Android guest are separate storage backends.
private enum BloomBoxHuskFiles {
    struct Game: Identifiable {
        let id: String
        let name: String
        let packageID: String?
        let directory: URL
        let icon: URL?
    }
    enum Status {
        case missing
        case locked
        case inaccessible(String)
        case ready(container: String, games: [Game], shared: URL?)
    }

    static func inspect(apps: [LCAppModel], unlocked: Bool) -> Status {
        guard let host = apps.first(where: { $0.bundleIdentifier == "com.husk.app" })
        else { return .missing }
        guard !host.appInfo.isLocked || unlocked else { return .locked }

        let profile = BloomBoxProfileStore.active
        let selected: String?
        if profile.id == BloomBoxUserProfile.primaryID {
            selected = host.uiDefaultDataFolder ?? host.appInfo.dataUUID
                ?? host.uiContainers.first?.folderName
        } else {
            let key = (host.uiIsShared ? "shared/" : "private/")
                + (host.appInfo.relativeBundlePath ?? "") + "/" + host.bundleIdentifier
            selected = BloomBoxProfileStore.mapping(for: profile.id, appKey: key)
                ?? host.uiContainers.first(where: {
                    $0.name.hasPrefix("[BloomBox:\(profile.id)]")
                        && $0.appIdentifier == host.bundleIdentifier
                })?.folderName
        }
        guard let selected,
              let container = host.uiContainers.first(where: { $0.folderName == selected })
        else {
            return .inaccessible("Husk no tiene un contenedor accesible en este perfil.")
        }
        let documents = container.containerURL.appendingPathComponent("Documents", isDirectory: true)
        guard isDirectory(documents) else {
            return .inaccessible("No podemos leer los documentos de Husk. Ábrelo una vez y revisa el acceso.")
        }
        let native = documents.appendingPathComponent("TranslationLayer", isDirectory: true)
        let shared = documents.appendingPathComponent("Shared Storage", isDirectory: true)
        let games: [Game] = (try? files(in: native, root: native))?.compactMap { folder in
            guard isDirectory(folder),
                  let contents = try? files(in: folder, root: native),
                  contents.contains(where: { $0.pathExtension.lowercased() == "apk" })
            else { return nil }
            let label = (try? String(contentsOf: folder.appendingPathComponent("label.txt"),
                                      encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let package = (try? String(contentsOf: folder.appendingPathComponent("package.txt"),
                                        encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let icon = folder.appendingPathComponent("icon.png")
            return Game(id: folder.lastPathComponent,
                        name: label?.isEmpty == false ? label! : folder.lastPathComponent,
                        packageID: package?.isEmpty == false ? package : nil,
                        directory: folder,
                        icon: FileManager.default.isReadableFile(atPath: icon.path) ? icon : nil)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending } ?? []
        return .ready(container: selected, games: games, shared: isDirectory(shared) ? shared : nil)
    }

    static func isDirectory(_ url: URL) -> Bool {
        let flags = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        return flags?.isDirectory == true && flags?.isSymbolicLink != true
            && FileManager.default.isReadableFile(atPath: url.path)
    }

    static func files(in folder: URL, root: URL) throws -> [URL] {
        let safeRoot = root.standardizedFileURL.resolvingSymlinksInPath()
        let safeFolder = folder.standardizedFileURL.resolvingSymlinksInPath()
        guard safeFolder.path == safeRoot.path || safeFolder.path.hasPrefix(safeRoot.path + "/")
        else { throw CocoaError(.fileReadNoPermission) }
        return try FileManager.default.contentsOfDirectory(
            at: safeFolder, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ).filter { item in
            guard (try? item.resourceValues(forKeys: [.isSymbolicLinkKey]))?
                .isSymbolicLink != true else { return false }
            return item.standardizedFileURL.resolvingSymlinksInPath().path
                .hasPrefix(safeRoot.path + "/")
        }.sorted { lhs, rhs in
            let l = (try? lhs.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
            let r = (try? rhs.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
            return l == r
                ? lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending
                : l
        }
    }
}

struct BloomBoxAndroidFilesView: View {
    @EnvironmentObject private var sharedModel: SharedModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var mode = 0
    @State private var refreshVersion = 0

    private var english: Bool { BloomBoxL10n.isEnglish }
    private var status: BloomBoxHuskFiles.Status {
        _ = refreshVersion
        return BloomBoxHuskFiles.inspect(
            apps: sharedModel.apps, unlocked: sharedModel.isHiddenAppUnlocked)
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "folder.badge.gearshape")
                            .font(.largeTitle).foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(english ? "Android files" : "Archivos Android").font(.headline)
                            Text(english ? "Game data, downloads and OBB"
                                         : "Datos de juegos, descargas y OBB")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                switch status {
                case .missing:
                    Section(header: Text("Husk")) {
                        Text(english ? "Android emulator · APK installer"
                                     : "Emulador Android · Instalador de APK")
                            .font(.headline)
                        Text(english ? "Install Husk to explore Android files."
                                     : "Instala Husk para explorar los archivos Android.")
                        if let url = URL(string: "https://itslevii.dev/docs/install") {
                            Link(english ? "Install Husk" : "Instalar Husk", destination: url)
                        }
                        if let url = URL(string: "https://github.com/Leviidev/Husk/releases") {
                            Link(english ? "Official IPA download" : "Descargar IPA oficial",
                                 destination: url)
                        }
                        Button(english ? "I installed Husk · Check" : "Ya instalé Husk · Comprobar") {
                            refreshVersion += 1
                        }
                    }
                case .locked:
                    Section {
                        Label(english ? "Husk is locked" : "Husk está bloqueado", systemImage: "lock")
                        Text(english ? "Unlock Husk in BloomBox to access its files."
                                     : "Desbloquea Husk en BloomBox para acceder a sus archivos.")
                    }
                case .inaccessible(let reason):
                    Section {
                        Label(english ? "Husk detected · No access"
                                      : "Husk detectado · Sin acceso",
                              systemImage: "exclamationmark.triangle")
                        Text(reason)
                        Button(english ? "Check again" : "Comprobar de nuevo") { refreshVersion += 1 }
                    }
                case .ready(let container, let games, let shared):
                    Section {
                        Label(english ? "Husk detected" : "Husk detectado",
                              systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(container).font(.caption).foregroundStyle(.secondary)
                        Picker(english ? "View" : "Vista", selection: $mode) {
                            Text(english ? "By game" : "Por juego").tag(0)
                            Text(english ? "Storage" : "Almacenamiento").tag(1)
                        }.pickerStyle(.segmented)
                    }
                    if mode == 0 {
                        Section(header: Text(english ? "Installed games" : "Juegos instalados")) {
                            if games.isEmpty {
                                Text(english ? "No native games in this Husk container."
                                             : "No hay juegos nativos en este contenedor de Husk.")
                                    .foregroundStyle(.secondary)
                            }
                            ForEach(games) { game in
                                NavigationLink(destination: BloomBoxHuskGameView(
                                    game: game, containerID: container, sharedRoot: shared)) {
                                    HStack(spacing: 10) {
                                        if let url = game.icon, let image = UIImage(contentsOfFile: url.path) {
                                            Image(uiImage: image).resizable().scaledToFill()
                                                .frame(width: 40, height: 40)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                        } else {
                                            Image(systemName: "gamecontroller.fill")
                                                .foregroundStyle(.green).frame(width: 40, height: 40)
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(game.name).font(.headline)
                                            if let package = game.packageID {
                                                Text(package).font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1).truncationMode(.middle)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        Section(header: Text(english ? "Shared storage · /sdcard"
                                                      : "Almacenamiento compartido · /sdcard")) {
                            if let shared {
                                NavigationLink(destination: BloomBoxHuskFolderView(
                                    root: shared, current: shared, title: "Shared Storage")) {
                                    Label(english ? "Browse shared folders"
                                                  : "Explorar carpetas compartidas",
                                          systemImage: "folder.fill")
                                }
                            } else {
                                Text(english ? "No shared storage yet. Open Husk to initialize it."
                                             : "Aún no hay almacenamiento compartido. Abre Husk para crearlo.")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Section {
                            Text(english
                                 ? "Husk's emulated Android storage is separate and may need a different bridge."
                                 : "El Android emulado por Husk usa un almacenamiento separado que requiere otro acceso.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    Section {
                        Label(english ? "Browse files and import game data"
                                      : "Explora archivos e importa datos de juegos",
                              systemImage: "folder.badge.plus")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(english ? "Android files" : "Archivos Android")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(english ? "Done" : "Listo") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { refreshVersion += 1 } label: { Image(systemName: "arrow.clockwise") }
                }
            }
        }
        .navigationViewStyle(.stack)
        .onChange(of: scenePhase) { phase in
            if phase == .active { refreshVersion += 1 }
        }
    }
}

private struct BloomBoxHuskFolderView: View {
    let root: URL
    let current: URL
    let title: String
    @State private var entries: [URL] = []
    @State private var error: String?
    @State private var preview: BloomBoxFileSelection?

    var body: some View {
        List {
            if let error { Text(error).foregroundStyle(.red) }
            if entries.isEmpty && error == nil {
                Text(BloomBoxL10n.isEnglish ? "This folder is empty."
                                            : "Esta carpeta está vacía.")
                    .foregroundStyle(.secondary)
            }
            ForEach(entries, id: \.path) { file in
                let directory = (try? file.resourceValues(forKeys: [.isDirectoryKey]))?
                    .isDirectory == true
                if directory {
                    NavigationLink(destination: BloomBoxHuskFolderView(
                        root: root, current: file, title: file.lastPathComponent)) {
                        Label(file.lastPathComponent, systemImage: "folder.fill")
                    }
                } else {
                    Button { preview = BloomBoxFileSelection(url: file) } label: {
                        Label(file.lastPathComponent, systemImage: "doc.fill")
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reload)
        .refreshable { reload() }
        .sheet(item: $preview) { BloomBoxFilePreview(url: $0.url) }
    }

    private func reload() {
        do {
            entries = try BloomBoxHuskFiles.files(in: current, root: root)
            error = nil
        } catch {
            entries = []
            self.error = error.localizedDescription
        }
    }
}


// MARK: - Native Husk data import (Takopi-inspired guarded copying)
//
// Native Husk maps Android/obb to the APK directory's obb/ fallback and
// Android/data/<package> to the *game-local* sdcard/Android/data/<package>.
// Do not route these into iOS Downloads or another game's directory.
private enum BloomBoxHuskImportMode: String, CaseIterable, Identifiable {
    case obb
    case androidData
    case privateFiles
    case shared
    var id: String { rawValue }
    var title: String {
        switch self {
        case .obb: return BloomBoxL10n.isEnglish ? "OBB expansions" : "Archivos OBB"
        case .androidData: return BloomBoxL10n.isEnglish ? "Android/data" : "Datos Android"
        case .privateFiles: return BloomBoxL10n.isEnglish ? "Private game files" : "Archivos privados"
        case .shared: return BloomBoxL10n.isEnglish ? "Shared storage" : "Almacenamiento compartido"
        }
    }
    var subtitle: String {
        switch self {
        case .obb: return "Android/obb/"
        case .androidData: return "Android/data/"
        case .privateFiles: return "/data/data/…/files/"
        case .shared: return "/sdcard/"
        }
    }
    var symbol: String {
        switch self {
        case .obb: return "archivebox.fill"
        case .androidData: return "externaldrive.fill"
        case .privateFiles: return "lock.doc.fill"
        case .shared: return "folder.fill"
        }
    }
}

private enum BloomBoxHuskDataImport {
    struct Result {
        var copied = 0
        var skipped = 0
    }

    enum ImportError: LocalizedError {
        case invalidGame, invalidPackage, invalidSource
        case invalidTarget(String)
        case noOBB, obbPackageMismatch, unsafeLink, gameBusy
        var errorDescription: String? {
            switch self {
            case .invalidGame: return "El juego o el contenedor cambió. Vuelve a abrir Archivos Android."
            case .invalidPackage: return "Husk no informó el paquete de este juego. No se pueden asignar sus datos."
            case .invalidSource: return "Selecciona archivos, carpetas o un ZIP válido."
            case .invalidTarget(let detail):
                return "No se pudo preparar el destino: " + detail
            case .noOBB: return "No se encontraron archivos .obb en la selección."
            case .obbPackageMismatch: return "Este OBB parece pertenecer a otro juego. No se importó."
            case .unsafeLink: return "Hay un enlace o una ruta insegura. No se importó."
            case .gameBusy: return "Cierra Husk y sus juegos antes de importar datos."
            }
        }
    }

    static func destination(for game: BloomBoxHuskFiles.Game, mode: BloomBoxHuskImportMode,
                            sharedRoot: URL?) throws -> URL {
        let root = game.directory
        guard root.deletingLastPathComponent().lastPathComponent == "TranslationLayer",
              BloomBoxHuskFiles.isDirectory(root),
              let children = try? BloomBoxHuskFiles.files(in: root, root: root),
              children.contains(where: { $0.pathExtension.lowercased() == "apk" })
        else { throw ImportError.invalidGame }
        switch mode {
        case .obb: return root.appendingPathComponent("obb", isDirectory: true)
        case .androidData:
            guard let package = validPackage(game.packageID) else { throw ImportError.invalidPackage }
            return root.appendingPathComponent("sdcard/Android/data/" + package, isDirectory: true)
        case .privateFiles:
            guard validPackage(game.packageID) != nil else { throw ImportError.invalidPackage }
            return root.appendingPathComponent("files", isDirectory: true)
        case .shared:
            guard let sharedRoot,
                  sharedRoot.lastPathComponent == "Shared Storage",
                  BloomBoxHuskFiles.isDirectory(sharedRoot)
            else { throw ImportError.invalidTarget("No se encontró el almacenamiento compartido de Husk.") }
            return sharedRoot
        }
    }

    static func validPackage(_ value: String?) -> String? {
        guard let value, value.count < 240, !value.isEmpty,
              !value.hasPrefix("."), !value.hasSuffix("."),
              value.contains("."),
              value.unicodeScalars.allSatisfy({
                  CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.").contains($0)
              })
        else { return nil }
        return value
    }

    // Do not confuse an unavailable destination with an unsafe one.
    // Resolve legitimate /var -> /private/var links in ancestors, but never
    // follow a symlink *inside* the authorized game or shared-storage root.
    private static func verify(_ url: URL, in root: URL) throws {
        let fm = FileManager.default
        let base = root.standardizedFileURL
        let candidate = url.standardizedFileURL
        guard base.isFileURL, candidate.isFileURL else {
            throw ImportError.invalidTarget("La selección no es una ruta local.")
        }
        let canonicalBase = base.resolvingSymlinksInPath()
        let canonicalCandidate = candidate.resolvingSymlinksInPath()
        let relativePath: String
        if candidate.path == base.path {
            relativePath = ""
        } else if candidate.path.hasPrefix(base.path + "/") {
            relativePath = String(candidate.path.dropFirst(base.path.count + 1))
        } else {
            throw ImportError.invalidTarget("La ruta sale del contenedor del juego.")
        }
        guard canonicalCandidate.path == canonicalBase.path ||
            canonicalCandidate.path.hasPrefix(canonicalBase.path + "/") else {
            throw ImportError.unsafeLink
        }
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: base.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw ImportError.invalidTarget("No se encontró la carpeta del juego. Vuelve a abrir Husk.")
        }
        // The base is the inspected per-game directory, never a path chosen by
        // the imported archive. Do not let the caller replace the base with a link.
        let baseFlags = try base.resourceValues(forKeys: [.isSymbolicLinkKey])
        guard baseFlags.isSymbolicLink != true else { throw ImportError.unsafeLink }
        var cursor = base
        for segment in relativePath.split(separator: "/") {
            cursor.appendPathComponent(String(segment))
            do {
                let flags = try cursor.resourceValues(forKeys: [
                    .isSymbolicLinkKey, .isDirectoryKey
                ])
                if flags.isSymbolicLink == true { throw ImportError.unsafeLink }
                if cursor.path != candidate.path, flags.isDirectory == false {
                    throw ImportError.invalidTarget(
                        "Una ruta intermedia no es carpeta: " + cursor.lastPathComponent)
                }
            } catch {
                let nsError = error as NSError
                // New OBB and Android/data directories are normally absent.
                // A missing component is allowed, never a dangling symlink.
                if nsError.domain == NSCocoaErrorDomain &&
                   nsError.code == NSFileReadNoSuchFileError { continue }
                throw error
            }
        }
    }

    private static func makeTarget(_ dir: URL, root: URL) throws {
        try verify(dir, in: root)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            throw ImportError.invalidTarget("No se pudo crear " + dir.lastPathComponent +
                                             ": " + error.localizedDescription)
        }
        try verify(dir, in: root)
    }

    private static func allFiles(in folder: URL) throws -> [URL] {
        let fm = FileManager.default
        var result: [URL] = []
        func walk(_ dir: URL) throws {
            let urls = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys:
                [.isDirectoryKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles])
            for file in urls {
                let values = try file.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                if values.isSymbolicLink == true { throw ImportError.unsafeLink }
                if values.isDirectory == true { try walk(file) }
                else if values.isRegularFile == true { result.append(file) }
                else { throw ImportError.invalidSource }
            }
        }
        try walk(folder)
        return result
    }

    private static func preparedDataRoot(_ folder: URL, package: String?, mode: BloomBoxHuskImportMode) -> URL {
        guard let package else { return folder }
        let fm = FileManager.default
        let android = folder.appendingPathComponent("Android/data/" + package)
        let privateData = folder.appendingPathComponent("data/data/" + package + "/files")
        if mode == .androidData, fm.fileExists(atPath: android.path) { return android }
        if mode == .privateFiles, fm.fileExists(atPath: privateData.path) { return privateData }
        let packaged = folder.appendingPathComponent(package)
        if fm.fileExists(atPath: packaged.path) { return packaged }
        // A ZIP whose only top-level folder contains the conventional Android path.
        if let items = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil),
           items.count == 1, BloomBoxHuskFiles.isDirectory(items[0]) {
            let nested = items[0]
            let android = nested.appendingPathComponent("Android/data/" + package)
            let privateData = nested.appendingPathComponent("data/data/" + package + "/files")
            if mode == .androidData, fm.fileExists(atPath: android.path) { return android }
            if mode == .privateFiles, fm.fileExists(atPath: privateData.path) { return privateData }
            // Preserve an ordinary folder such as "files" or "cache": it is
            // part of Android's destination tree, not a wrapper to discard.
        }
        return folder
    }

    private static func copyContents(from source: URL, into dest: URL, root: URL,
                                     result: inout Result, created: inout [URL]) throws {
        let fm = FileManager.default
        for item in try fm.contentsOfDirectory(at: source, includingPropertiesForKeys:
            [.isDirectoryKey, .isSymbolicLinkKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]) {
            let flags = try item.resourceValues(forKeys:
                [.isDirectoryKey, .isSymbolicLinkKey, .isRegularFileKey])
            if flags.isSymbolicLink == true { throw ImportError.unsafeLink }
            let target = dest.appendingPathComponent(item.lastPathComponent)
            try verify(target, in: root)
            if flags.isDirectory == true {
                if fm.fileExists(atPath: target.path) {
                    guard BloomBoxHuskFiles.isDirectory(target) else {
                        result.skipped += 1; continue
                    }
                } else {
                    try fm.createDirectory(at: target, withIntermediateDirectories: false)
                    created.append(target)
                }
                try copyContents(from: item, into: target, root: root,
                                 result: &result, created: &created)
            } else if flags.isRegularFile == true {
                if fm.fileExists(atPath: target.path) {
                    result.skipped += 1 // Never overwrite existing saves or data.
                    continue
                }
                try fm.copyItem(at: item, to: target)
                created.append(target)
                result.copied += 1
            } else {
                throw ImportError.invalidSource
            }
        }
    }

    static func install(_ sources: [URL], game: BloomBoxHuskFiles.Game,
                        mode: BloomBoxHuskImportMode, sharedRoot: URL?) throws -> Result {
        let fm = FileManager.default
        let target = try destination(for: game, mode: mode, sharedRoot: sharedRoot)
        let root = mode == .shared ? (sharedRoot ?? game.directory) : game.directory
        try verify(target, in: root)
        var summary = Result()
        for source in sources {
            let access = source.startAccessingSecurityScopedResource()
            defer { if access { source.stopAccessingSecurityScopedResource() } }
            let scratch = fm.temporaryDirectory.appendingPathComponent(
                "BloomBox-Husk-Import-" + UUID().uuidString, isDirectory: true)
            try fm.createDirectory(at: scratch, withIntermediateDirectories: false)
            defer { try? fm.removeItem(at: scratch) }
            let prepared = scratch.appendingPathComponent("prepared", isDirectory: true)
            var coordinationError: NSError?
            var readError: Error?
            // iCloud/document providers may need a coordinated upload snapshot
            // for folders; this yields a readable ZIP without touching originals.
            let sourceFolder = (try? source.resourceValues(
                forKeys: [.isDirectoryKey]))?.isDirectory == true
            NSFileCoordinator().coordinate(
                readingItemAt: source, options: sourceFolder ? [.forUploading] : [],
                error: &coordinationError) { readable in
                do {
                    let flags = try readable.resourceValues(forKeys:
                        [.isDirectoryKey, .isSymbolicLinkKey, .isRegularFileKey])
                    guard flags.isSymbolicLink != true else { throw ImportError.unsafeLink }
                    if readable.pathExtension.lowercased() == "zip", flags.isRegularFile == true {
                        // Existing, path-traversal-checked BloomBox ZIP extractor.
                        try BloomBoxArchive.unpack(source: readable, destination: prepared)
                    } else {
                        guard flags.isDirectory == true || flags.isRegularFile == true
                        else { throw ImportError.invalidSource }
                        try fm.createDirectory(at: prepared, withIntermediateDirectories: false)
                        try fm.copyItem(at: readable, to: prepared.appendingPathComponent(source.lastPathComponent))
                    }
                } catch { readError = error }
            }
            if let coordinationError { throw coordinationError }
            if let readError { throw readError }
            try makeTarget(target, root: root)
            var created: [URL] = []
            do {
                if mode == .obb {
                    let obbFiles = try allFiles(in: prepared).filter {
                        $0.pathExtension.lowercased() == "obb"
                    }
                    guard !obbFiles.isEmpty else { throw ImportError.noOBB }
                    for file in obbFiles {
                        if let package = validPackage(game.packageID) {
                            let filename = file.lastPathComponent
                            if filename.hasPrefix("main.") || filename.hasPrefix("patch.") {
                                let components = filename.split(separator: ".", maxSplits: 2)
                                if components.count == 3 {
                                    let namePackage = String(components[2].dropLast(4))
                                    if namePackage != package { throw ImportError.obbPackageMismatch }
                                }
                            }
                        }
                        let dest = target.appendingPathComponent(file.lastPathComponent)
                        try verify(dest, in: root)
                        if fm.fileExists(atPath: dest.path) { summary.skipped += 1; continue }
                        try fm.copyItem(at: file, to: dest)
                        created.append(dest)
                        summary.copied += 1
                    }
                } else {
                    let content = preparedDataRoot(prepared, package: validPackage(game.packageID),
                                                   mode: mode)
                    try copyContents(from: content, into: target, root: root,
                                     result: &summary, created: &created)
                }
            } catch {
                for item in created.reversed() { try? fm.removeItem(at: item) }
                throw error
            }
        }
        return summary
    }
}

private struct BloomBoxHuskGameView: View {
    let game: BloomBoxHuskFiles.Game
    let containerID: String
    let sharedRoot: URL?

    @EnvironmentObject private var sharedModel: SharedModel
    @State private var choice: BloomBoxHuskImportMode = .obb
    @State private var picking = false
    @State private var confirming = false
    @State private var chosen: [URL] = []
    @State private var busy = false
    @State private var notice: String?
    private var english: Bool { BloomBoxL10n.isEnglish }

    private var hostBusy: Bool {
        let host = sharedModel.apps.first(where: { $0.bundleIdentifier == "com.husk.app" })
        return host == nil || host?.isAppRunning == true
            || MultitaskManager.isUsing(container: containerID)
            || LCSharedUtils.getContainerUsingLCScheme(withFolderName: containerID) != nil
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 7) {
                    Text(game.name).font(.title3.bold())
                    if let package = game.packageID {
                        Text(package).font(.caption).foregroundStyle(.secondary)
                    }
                    Text(english ? "Import OBB and game data directly into Husk."
                                 : "Importa OBB y datos directamente a Husk.")
                        .font(.subheadline)
                }.padding(.vertical, 5)
                if hostBusy {
                    Label(english ? "Close Husk before importing."
                                  : "Cierra Husk antes de importar archivos.",
                          systemImage: "lock.fill").foregroundStyle(.orange)
                }
            }
            Section(header: Text(english ? "Import game data" : "Importar datos del juego")) {
                ForEach(BloomBoxHuskImportMode.allCases) { mode in
                    if mode != .shared || sharedRoot != nil {
                        Button {
                            choice = mode
                            picking = true
                        } label: {
                            HStack(spacing: 13) {
                                Image(systemName: mode.symbol).foregroundStyle(.green)
                                    .frame(width: 29)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(mode.title).foregroundStyle(.primary)
                                    Text(mode.subtitle).font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "square.and.arrow.down")
                                    .foregroundStyle(.secondary)
                            }
                        }.disabled(busy || hostBusy
                                   || ((mode == .androidData || mode == .privateFiles)
                                       && BloomBoxHuskDataImport.validPackage(game.packageID) == nil))
                    }
                }
            }
            Section(header: Text(english ? "Explore files" : "Explorar archivos")) {
                NavigationLink(destination: BloomBoxHuskFolderView(
                    root: game.directory, current: game.directory, title: game.name)) {
                    Label(english ? "View game folder" : "Ver carpeta del juego", systemImage: "folder")
                }
            }
            Section {
                Text(english
                     ? "Supports .obb, ZIP, and folders. Files are copied without overwriting existing game data."
                     : "Admite .obb, ZIP y carpetas. Copia los datos sin sobrescribir archivos existentes.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if busy { Section { ProgressView(english ? "Importing…" : "Importando…") } }
        }
        .navigationTitle(english ? "Game files" : "Archivos del juego")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $picking, allowedContentTypes: [.item, .folder],
                      allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                chosen = urls
                confirming = !urls.isEmpty
            case .failure(let error): notice = error.localizedDescription
            }
        }
        .confirmationDialog(english ? "Import these files?" : "¿Importar estos archivos?",
                            isPresented: $confirming, titleVisibility: .visible) {
            Button(english ? "Import · Keep existing files" : "Importar · Conservar archivos existentes") {
                importChosen()
            }
            Button(english ? "Cancel" : "Cancelar", role: .cancel) { chosen = [] }
        } message: {
            let count = chosen.count
            let dest = (try? BloomBoxHuskDataImport.destination(
                for: game, mode: choice, sharedRoot: sharedRoot))?.path ?? "—"
            Text("\(count) archivo(s) → \(dest)")
        }
        .alert(english ? "Game data" : "Datos del juego",
               isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button("OK") { notice = nil }
        } message: { Text(notice ?? "") }
    }

    private func importChosen() {
        guard !busy, !hostBusy, !chosen.isEmpty else {
            notice = english ? "Close Husk before importing." : "Cierra Husk antes de importar."
            return
        }
        let selected = chosen
        chosen = []
        let mode = choice
        let game = game
        let shared = sharedRoot
        busy = true
        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try BloomBoxHuskDataImport.install(selected, game: game, mode: mode,
                                                       sharedRoot: shared)
                }.value
                notice = english
                    ? "Imported \(result.copied) files. Kept \(result.skipped) existing files."
                    : "Se importaron \(result.copied) archivos. Se conservaron \(result.skipped) archivos existentes."
            } catch {
                notice = error.localizedDescription
            }
            busy = false
        }
    }
}
