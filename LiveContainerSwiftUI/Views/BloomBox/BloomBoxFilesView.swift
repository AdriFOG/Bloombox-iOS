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
            options: []
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
    var sourceLabel = "Husk"

    @State private var entries: [URL] = []
    @State private var error: String?
    @State private var preview: BloomBoxFileSelection?
    @State private var exporting: BloomBoxFileSelection?
    @State private var importing = false
    @State private var chosen: [URL] = []
    @State private var importConfirmation = false
    @State private var replaceExisting = false
    @State private var busy = false
    @State private var creating = false
    @State private var newName = ""
    @State private var renameItem: URL?
    @State private var renameVisible = false
    @State private var deleteItem: URL?
    @State private var deleteVisible = false
    @State private var message: String?

    private var english: Bool { BloomBoxL10n.isEnglish }

    var body: some View {
        List {
            Section {
                Label((english ? "File manager · " : "Gestor de archivos · ") + sourceLabel,
                      systemImage: "folder.fill.badge.gearshape")
                    .font(.footnote)
                Text(english
                     ? "Changes to game files can break the game or erase saves."
                     : "Los cambios pueden dañar el juego o borrar partidas.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if let error { Text(error).foregroundStyle(.red) }
            if entries.isEmpty && error == nil {
                Text(english ? "This folder is empty." : "Esta carpeta está vacía.")
                    .foregroundStyle(.secondary)
            }
            ForEach(entries, id: \.path) { entry in
                let directory = (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?
                    .isDirectory == true
                Group {
                    if directory {
                        NavigationLink(destination: BloomBoxHuskFolderView(
                            root: root, current: entry, title: entry.lastPathComponent,
                            sourceLabel: sourceLabel)) {
                            Label(entry.lastPathComponent, systemImage: "folder.fill")
                        }
                    } else {
                        Button { preview = BloomBoxFileSelection(url: entry) } label: {
                            Label(entry.lastPathComponent, systemImage: "doc.fill")
                        }
                    }
                }
                .contextMenu {
                    if !directory {
                        Button(english ? "Share / Export" : "Compartir / Exportar",
                               systemImage: "square.and.arrow.up") {
                            exporting = BloomBoxFileSelection(url: entry)
                        }
                    }
                    Button(english ? "Rename" : "Renombrar", systemImage: "pencil") {
                        renameItem = entry
                        newName = entry.lastPathComponent
                        renameVisible = true
                    }
                    Button(english ? "Delete" : "Eliminar", systemImage: "trash",
                           role: .destructive) {
                        deleteItem = entry
                        deleteVisible = true
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        deleteItem = entry
                        deleteVisible = true
                    } label: { Label(english ? "Delete" : "Eliminar", systemImage: "trash") }
                }
            }
            Section {
                Toggle(english ? "Replace existing on import"
                               : "Reemplazar archivos al importar", isOn: $replaceExisting)
                    .font(.subheadline)
                if busy { ProgressView(english ? "Importing…" : "Importando…") }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button { importing = true } label: {
                    Image(systemName: "square.and.arrow.down")
                }.disabled(busy)
                    .accessibilityLabel(english ? "Import into this folder" : "Importar aquí")
                Button {
                    newName = ""
                    creating = true
                } label: { Image(systemName: "folder.badge.plus") }
                    .disabled(busy)
                    .accessibilityLabel(english ? "New folder" : "Nueva carpeta")
            }
        }
        .onAppear(perform: reload)
        .refreshable { reload() }
        .sheet(item: $preview) { BloomBoxFilePreview(url: $0.url) }
        .sheet(item: $exporting) { BloomBoxShareFile(url: $0.url) }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.item, .folder],
                      allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                chosen = urls
                importConfirmation = !urls.isEmpty
            case .failure(let failure): message = failure.localizedDescription
            }
        }
        .confirmationDialog(english ? "Import here?" : "¿Importar en esta carpeta?",
                            isPresented: $importConfirmation, titleVisibility: .visible) {
            Button(replaceExisting
                   ? (english ? "Import and replace" : "Importar y reemplazar")
                   : (english ? "Import and keep existing" : "Importar sin reemplazar")) {
                importHere()
            }
            Button(english ? "Cancel" : "Cancelar", role: .cancel) { chosen = [] }
        } message: {
            Text(current.path + (replaceExisting
                 ? (english ? "\nExisting data will be replaced." : "\nSe reemplazarán archivos existentes.")
                 : ""))
        }
        .alert(english ? "New folder" : "Nueva carpeta", isPresented: $creating) {
            TextField(english ? "Name" : "Nombre", text: $newName)
            Button(english ? "Create" : "Crear") { createFolder() }
            Button(english ? "Cancel" : "Cancelar", role: .cancel) {}
        }
        .alert(english ? "Rename" : "Renombrar", isPresented: $renameVisible) {
            TextField(english ? "Name" : "Nombre", text: $newName)
            Button(english ? "Rename" : "Renombrar") { renameSelected() }
            Button(english ? "Cancel" : "Cancelar", role: .cancel) {}
        }
        .confirmationDialog(english ? "Delete this item?" : "¿Eliminar este archivo o carpeta?",
                            isPresented: $deleteVisible, titleVisibility: .visible) {
            Button(english ? "Delete permanently" : "Eliminar definitivamente",
                   role: .destructive) { deleteSelected() }
            Button(english ? "Cancel" : "Cancelar", role: .cancel) { deleteItem = nil }
        } message: {
            Text((deleteItem?.lastPathComponent ?? "") +
                 (english ? "\nThis cannot be undone." : "\nNo se puede deshacer."))
        }
        .alert((english ? "Files · " : "Archivos · ") + sourceLabel,
               isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") { message = nil }
        } message: { Text(message ?? "") }
    }

    private func safeURL(_ parts: [String], directory: Bool) throws -> URL {
        try BloomBoxHuskDataImport.checkedURL(
            in: root, components: parts, isDirectory: directory)
    }

    private func currentParts() throws -> [String] {
        try BloomBoxHuskPathPolicy.relativeComponents(of: current, under: root)
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

    private func createFolder() {
        do {
            let folder = try safeURL(currentParts() + [newName], directory: true)
            try FileManager.default.createDirectory(at: folder,
                withIntermediateDirectories: false)
            reload()
        } catch { message = error.localizedDescription }
    }

    private func renameSelected() {
        guard let item = renameItem else { return }
        defer { renameItem = nil }
        do {
            let relative = try BloomBoxHuskPathPolicy.relativeComponents(of: item, under: root)
            guard !relative.isEmpty else { throw BloomBoxHuskPathPolicy.Failure.outsideRoot }
            let renamed = try safeURL(Array(relative.dropLast()) + [newName],
                                      directory: BloomBoxHuskFiles.isDirectory(item))
            try FileManager.default.moveItem(at: item, to: renamed)
            reload()
        } catch { message = error.localizedDescription }
    }

    private func deleteSelected() {
        guard let item = deleteItem else { return }
        defer { deleteItem = nil }
        do {
            let relative = try BloomBoxHuskPathPolicy.relativeComponents(of: item, under: root)
            guard !relative.isEmpty else { throw BloomBoxHuskPathPolicy.Failure.outsideRoot }
            _ = try safeURL(relative, directory: BloomBoxHuskFiles.isDirectory(item))
            try FileManager.default.removeItem(at: item)
            reload()
        } catch { message = error.localizedDescription }
    }

    private func importHere() {
        guard !busy, !chosen.isEmpty else { return }
        let selected = chosen
        chosen = []
        let current = current
        let root = root
        let replace = replaceExisting
        busy = true
        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try BloomBoxHuskDataImport.installDirect(
                        selected, into: current, under: root, replaceExisting: replace)
                }.value
                reload()
                message = english ? "Copied \(result.copied), skipped \(result.skipped)."
                    : "Copiados \(result.copied), omitidos \(result.skipped)."
            } catch { message = error.localizedDescription }
            busy = false
        }
    }
}

// MARK: - Native Husk data import (Takopi-inspired guarded copying)
//
// Native Husk maps Android/obb to the APK directory's obb/ fallback and
// Android/data/<package> to the *game-local* sdcard/Android/data/<package>.
// Do not route these into iOS Downloads or another game's directory.
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

    static func checkedURL(in root: URL, components: [String], isDirectory: Bool) throws -> URL {
        do {
            return try BloomBoxHuskPathPolicy.scopedURL(
                in: root, components: components, isDirectory: isDirectory)
        } catch BloomBoxHuskPathPolicy.Failure.outsideRoot {
            throw ImportError.invalidTarget("DEST-01: nombre de carpeta o archivo no válido.")
        } catch BloomBoxHuskPathPolicy.Failure.notFileURL {
            throw ImportError.invalidTarget("DEST-02: el contenedor de Husk no es una carpeta local.")
        } catch BloomBoxHuskPathPolicy.ValidationFailure.missingGameDirectory {
            throw ImportError.invalidTarget("DEST-03: no se encontró la carpeta de Husk.")
        } catch BloomBoxHuskPathPolicy.ValidationFailure.nonDirectoryAncestor {
            throw ImportError.invalidTarget("DEST-04: una ruta intermedia es un archivo.")
        } catch BloomBoxHuskPathPolicy.ValidationFailure.unsafeLink {
            throw ImportError.unsafeLink
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

    /// Copy directly into an EXISTING, user-selected Husk folder. The caller
    /// decides whether to replace files; never invent runtime or OBB folders.
    static func installDirect(_ sources: [URL], into existingFolder: URL,
                              under authorizedRoot: URL,
                              replaceExisting: Bool) throws -> Result {
        let fm = FileManager.default
        let parts = try BloomBoxHuskPathPolicy.relativeComponents(
            of: existingFolder, under: authorizedRoot)
        let targetRoot = try checkedURL(in: authorizedRoot,
                                        components: parts, isDirectory: true)
        guard BloomBoxHuskFiles.isDirectory(targetRoot) else {
            throw ImportError.invalidTarget("Esa carpeta ya no existe. Actualiza el explorador.")
        }

        var summary = Result()
        for source in sources {
            let access = source.startAccessingSecurityScopedResource()
            defer { if access { source.stopAccessingSecurityScopedResource() } }
            let scratch = fm.temporaryDirectory.appendingPathComponent(
                "BloomBox-Husk-Import-" + UUID().uuidString, isDirectory: true)
            try fm.createDirectory(at: scratch, withIntermediateDirectories: false)
            defer { try? fm.removeItem(at: scratch) }
            let contents = scratch.appendingPathComponent("prepared", isDirectory: true)
            try fm.createDirectory(at: contents, withIntermediateDirectories: false)

            var sourceIsDir: ObjCBool = false
            let pickedFolder = fm.fileExists(atPath: source.path, isDirectory: &sourceIsDir)
                && sourceIsDir.boolValue
            var coordinatorError: NSError?
            var stagingError: Error?
            NSFileCoordinator().coordinate(
                readingItemAt: source, options: pickedFolder ? [.forUploading] : [],
                error: &coordinatorError
            ) { readable in
                do {
                    let flags = try readable.resourceValues(forKeys: [.isSymbolicLinkKey])
                    if flags.isSymbolicLink == true { throw ImportError.unsafeLink }
                    var folder: ObjCBool = false
                    guard fm.fileExists(atPath: readable.path, isDirectory: &folder) else {
                        throw ImportError.invalidTarget(
                            "No se puede leer el archivo seleccionado: " + source.lastPathComponent)
                    }
                    if !folder.boolValue && readable.pathExtension.lowercased() == "zip" {
                        try BloomBoxArchive.unpack(source: readable, destination: contents)
                    } else {
                        // A .obb or .dat is an ordinary file, not necessarily a ZIP.
                        let name = pickedFolder ? source.lastPathComponent : readable.lastPathComponent
                        let output = contents.appendingPathComponent(name)
                        try fm.copyItem(at: readable, to: output)
                    }
                } catch { stagingError = error }
            }
            if let coordinatorError { throw coordinatorError }
            if let stagingError { throw stagingError }

            func copyTree(_ folder: URL, _ segments: [String]) throws {
                let entries = try fm.contentsOfDirectory(
                    at: folder, includingPropertiesForKeys: [
                        .isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey
                    ], options: [.skipsHiddenFiles])
                for entry in entries {
                    let type = try entry.resourceValues(forKeys: [
                        .isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey
                    ])
                    if type.isSymbolicLink == true { throw ImportError.unsafeLink }
                    let relative = segments + [entry.lastPathComponent]
                    if type.isDirectory == true {
                        let target = try checkedURL(in: authorizedRoot,
                            components: parts + relative, isDirectory: true)
                        if !fm.fileExists(atPath: target.path) {
                            try fm.createDirectory(at: target, withIntermediateDirectories: false)
                        }
                        guard BloomBoxHuskFiles.isDirectory(target) else {
                            throw ImportError.invalidTarget("No es una carpeta: " + entry.lastPathComponent)
                        }
                        try copyTree(entry, relative)
                    } else if type.isRegularFile == true {
                        let target = try checkedURL(in: authorizedRoot,
                            components: parts + relative, isDirectory: false)
                        if fm.fileExists(atPath: target.path) {
                            if !replaceExisting {
                                summary.skipped += 1
                                continue
                            }
                            // Stage replacement in the same directory, then swap.
                            let temp = target.deletingLastPathComponent()
                                .appendingPathComponent(".bloombox-" + UUID().uuidString)
                            try fm.copyItem(at: entry, to: temp)
                            do {
                                _ = try fm.replaceItemAt(target, withItemAt: temp,
                                    backupItemName: nil, options: [])
                            } catch {
                                try? fm.removeItem(at: temp)
                                throw error
                            }
                        } else {
                            try fm.copyItem(at: entry, to: target)
                        }
                        summary.copied += 1
                    } else {
                        throw ImportError.invalidSource
                    }
                }
            }
            try copyTree(contents, [])
        }
        return summary
    }

}

private struct BloomBoxHuskGameView: View {
    let game: BloomBoxHuskFiles.Game
    let containerID: String
    let sharedRoot: URL?

    @State private var refreshVersion = 0
    private var english: Bool { BloomBoxL10n.isEnglish }

    /// The game's actual existing engine folder, never a made-up destination.
    /// An ambiguous set of -data folders must not be guessed: the APK
    /// container remains available for manual browsing in that case.
    private var runtime: URL? {
        _ = refreshVersion
        return BloomBoxHuskRuntimeScanner.preferredRuntime(in: game.directory)
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(game.name).font(.headline)
                    if let package = game.packageID {
                        Text(package).font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(.vertical, 4)
            }

            Section {
                NavigationLink(destination: BloomBoxHuskFolderView(
                    root: game.directory, current: game.directory,
                    title: english ? "APK container" : "Contenedor del APK")) {
                    HStack(spacing: 13) {
                        Image(systemName: "shippingbox.fill")
                            .font(.title3).foregroundStyle(.green).frame(width: 32)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(english ? "APK container" : "Contenedor del APK")
                                .font(.headline)
                            Text(english ? "All files of this app" : "Todos los archivos de esta app")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 9)
                }

                if let runtime {
                    NavigationLink(destination: BloomBoxHuskFolderView(
                        root: game.directory, current: runtime,
                        title: runtime.lastPathComponent)) {
                        HStack(spacing: 13) {
                            Image(systemName: "folder.fill")
                                .font(.title3).foregroundStyle(.green).frame(width: 32)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(english ? "Game data" : "Datos del juego")
                                    .font(.headline)
                                Text(runtime.lastPathComponent)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 9)
                    }
                } else {
                    HStack(spacing: 13) {
                        Image(systemName: "folder.fill")
                            .font(.title3).foregroundStyle(.secondary).frame(width: 32)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(english ? "Game data" : "Datos del juego")
                                .font(.headline)
                            Text(english
                                 ? "No unique -data folder found; check the APK container"
                                 : "No hay una carpeta -data identificable; revisa el contenedor")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 9)
                }
            } header: {
                Text(english ? "Browse files" : "Explorar archivos")
            } footer: {
                Text(english
                     ? "Open either folder to import, rename, create, replace or delete files. Changes can affect the game."
                     : "Abre una carpeta para importar, renombrar, crear, reemplazar o borrar archivos. Los cambios pueden afectar al juego.")
            }
        }
        .navigationTitle(english ? "Game files" : "Archivos del juego")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { refreshVersion += 1 } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel(english ? "Refresh folders" : "Actualizar carpetas")
            }
        }
        .onAppear { refreshVersion += 1 }
    }
}

// MARK: - Two storage choices and a scoped file manager for iOS guest apps.

struct BloomBoxFilesHubView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var ios = false
    @State private var android = false
    private var en: Bool { BloomBoxL10n.isEnglish }

    var body: some View {
        NavigationView {
            List {
                Section {
                    Button { ios = true } label: {
                        item("apple.logo", color: .gray,
                             title: en ? "iOS Files" : "Archivos iOS",
                             subtitle: en ? "Installed BloomBox apps and documents"
                                          : "Apps instaladas y documentos de BloomBox")
                    }
                    .accessibilityIdentifier("bloombox.files.choose.ios")
                    Button { android = true } label: {
                        item("folder.fill", color: .green,
                             title: en ? "Android Files" : "Archivos Android",
                             subtitle: en ? "Husk games, data and OBB"
                                          : "Juegos Husk, datos y OBB")
                    }
                    .accessibilityIdentifier("bloombox.files.choose.android")
                } header: {
                    Text(en ? "Choose storage" : "Elige el almacenamiento")
                } footer: {
                    Text(en ? "Only files accessible to BloomBox can be managed."
                            : "Solo se pueden administrar archivos accesibles para BloomBox.")
                }
            }
            .scrollContentBackground(.hidden)
            .background { BloomBoxProfileThemeBackdrop().ignoresSafeArea() }
            .navigationTitle(en ? "Files" : "Archivos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(en ? "Done" : "Listo") { dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $ios) { BloomBoxIOSFilesView() }
        .sheet(isPresented: $android) { BloomBoxAndroidFilesView() }
    }

    private func item(_ systemImage: String, color: Color,
                      title: String, subtitle: String) -> some View {
        HStack(spacing: 15) {
            Image(systemName: systemImage)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 55, height: 55)
                .background(color, in: RoundedRectangle(cornerRadius: 15))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundStyle(.primary)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }
}

/// Never create, adopt or mutate an app container just to browse. A secondary
/// BloomBox profile only exposes its own previously created guest container.
private enum BloomBoxIOSDataAccess {
    enum Result {
        case available(root: URL, name: String)
        case unavailable(String)
    }

    static func resolve(_ app: LCAppModel, unlocked: Bool) -> Result {
        let en = BloomBoxL10n.isEnglish
        guard !app.appInfo.isLocked || unlocked else {
            return .unavailable(en ? "Unlock this app first." : "Desbloquea esta app primero.")
        }
        let profile = BloomBoxProfileStore.active
        let selected: String?
        if profile.id == BloomBoxUserProfile.primaryID {
            selected = app.uiDefaultDataFolder ?? app.appInfo.dataUUID
                ?? app.uiContainers.first?.folderName
        } else {
            let key = (app.uiIsShared ? "shared/" : "private/")
                + (app.appInfo.relativeBundlePath ?? "") + "/" + app.bundleIdentifier
            selected = BloomBoxProfileStore.mapping(for: profile.id, appKey: key)
                ?? app.uiContainers.first(where: {
                    $0.name.hasPrefix("[BloomBox:\(profile.id)]")
                        && $0.appIdentifier == app.bundleIdentifier
                })?.folderName
        }
        guard let selected,
              let container = app.uiContainers.first(where: {
                  $0.folderName == selected &&
                  ($0.appIdentifier == nil || $0.appIdentifier == app.bundleIdentifier)
              }) else {
            return .unavailable(en ? "No existing app data for this profile. Open the app first."
                                   : "Este perfil todavía no tiene datos. Abre la app primero.")
        }
        let folder = container.folderName
        guard !folder.isEmpty, folder != ".", folder != "..",
              !folder.contains("/"), !folder.contains("\\") else {
            return .unavailable(en ? "Invalid container name." : "Nombre de contenedor no válido.")
        }
        // External bookmarks and system app containers are intentionally out of scope.
        let base = container.isShared ? LCPath.lcGroupDataPath : LCPath.dataPath
        let expected = base.appendingPathComponent(folder, isDirectory: true).standardizedFileURL
        let root = container.containerURL.standardizedFileURL
        guard root.isFileURL, root.path == expected.path,
              BloomBoxHuskFiles.isDirectory(root),
              root.resolvingSymlinksInPath().path == expected.resolvingSymlinksInPath().path
        else {
            return .unavailable(en ? "This data folder is not available inside BloomBox."
                                   : "Este contenedor no está accesible dentro de BloomBox.")
        }
        return .available(root: root, name: container.name)
    }
}

struct BloomBoxIOSFilesView: View {
    @EnvironmentObject private var sharedModel: SharedModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var showPersonal = false
    @State private var revision = 0
    @State private var query = ""
    @AppStorage("darkModeIcon", store: LiveContainerPreferencesAdapter.defaults)
    private var darkIcons = false
    private var en: Bool { BloomBoxL10n.isEnglish }
    private var apps: [LCAppModel] {
        _ = revision
        let unlocked = sharedModel.isHiddenAppUnlocked
        return (sharedModel.apps + (unlocked ? sharedModel.hiddenApps : []))
            .filter {
                !($0.appInfo is BuiltInSideStoreAppInfo) &&
                (!$0.appInfo.isLocked || unlocked) &&
                (!$0.appInfo.isHidden || unlocked) &&
                (query.isEmpty ||
                 $0.displayName.localizedCaseInsensitiveContains(query) ||
                 $0.bundleIdentifier.localizedCaseInsensitiveContains(query))
            }
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    Button { showPersonal = true } label: {
                        Label(en ? "BloomBox documents" : "Documentos de BloomBox",
                              systemImage: "folder.fill")
                    }
                    .accessibilityIdentifier("bloombox.files.ios.documents")
                } footer: {
                    Text(en ? "Your saved documents are separate from guest app data."
                            : "Tus documentos están separados de los datos de las apps.")
                }
                Section {
                    if apps.isEmpty {
                        Text(en ? "No apps available in this profile."
                                : "No hay apps disponibles en este perfil.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(apps, id: \.self) { app in
                        NavigationLink(destination: BloomBoxIOSAppFilesView(app: app)) {
                            HStack(spacing: 12) {
                                // Reuse the same cached/custom guest artwork used on Home.
                                // This also reflects light/dark icons and user icon changes.
                                LiveBoardIconImage(app: app, dark: darkIcons)
                                    .frame(width: 46, height: 46)
                                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(app.displayName).font(.headline)
                                    Text(app.bundleIdentifier).font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                if app.isAppRunning {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 8)).foregroundStyle(.orange)
                                }
                            }.padding(.vertical, 3)
                        }
                        .accessibilityIdentifier("bloombox.files.ios.app")
                    }
                } header: {
                    Text(en ? "Installed apps" : "Apps instaladas")
                } footer: {
                    Text(en ? "Only containers from the current BloomBox profile are shown. Other iPhone apps cannot be accessed."
                            : "Solo contenedores del perfil activo de BloomBox. No se accede a apps externas del iPhone.")
                }
            }
            .searchable(text: $query, prompt: en ? "Find app" : "Buscar app")
            .navigationTitle(en ? "iOS Files" : "Archivos iOS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(en ? "Done" : "Listo") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { revision += 1 } label: { Image(systemName: "arrow.clockwise") }
                }
            }
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $showPersonal) { BloomBoxFilesView() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { revision += 1 }
        }
    }
}

private struct BloomBoxIOSAppFilesView: View {
    @ObservedObject var app: LCAppModel
    @EnvironmentObject private var sharedModel: SharedModel
    @State private var revision = 0
    private var en: Bool { BloomBoxL10n.isEnglish }
    private var status: BloomBoxIOSDataAccess.Result {
        _ = revision
        return BloomBoxIOSDataAccess.resolve(app, unlocked: sharedModel.isHiddenAppUnlocked)
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.displayName).font(.headline)
                    Text(app.bundleIdentifier).font(.caption).foregroundStyle(.secondary)
                    if app.isAppRunning {
                        Label(en ? "App is running: avoid editing its active files."
                                 : "App abierta: evita modificar archivos en uso.",
                              systemImage: "exclamationmark.triangle")
                            .font(.footnote).foregroundStyle(.orange)
                    }
                }
            }
            switch status {
            case .unavailable(let reason):
                Section { Text(reason).foregroundStyle(.secondary) }
            case .available(let root, let name):
                Section {
                    NavigationLink(destination: BloomBoxHuskFolderView(
                        root: root, current: root,
                        title: en ? "App data container" : "Contenedor de datos",
                        sourceLabel: "iOS")) {
                        Label(en ? "App data container" : "Contenedor de datos",
                              systemImage: "shippingbox.fill")
                    }
                    ForEach(["Documents", "Library", "tmp"].filter {
                        BloomBoxHuskFiles.isDirectory(root.appendingPathComponent($0, isDirectory: true))
                    }, id: \.self) { folder in
                        NavigationLink(destination: BloomBoxHuskFolderView(
                            root: root,
                            current: root.appendingPathComponent(folder, isDirectory: true),
                            title: folder, sourceLabel: "iOS")) {
                            Label(folder, systemImage: "folder.fill")
                        }
                    }
                } header: {
                    Text(en ? "Existing folders" : "Carpetas existentes")
                } footer: {
                    Text(en ? "Open a folder to import, export, rename or delete files. Back up saves first."
                            : "Abre una carpeta para importar, exportar, renombrar o borrar. Respalda tus datos.")
                }
                Section {
                    Text((en ? "Active container: " : "Contenedor activo: ") + name)
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(en ? "App files" : "Archivos de app")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { revision += 1 } label: { Image(systemName: "arrow.clockwise") }
            }
        }
    }
}

