// SPDX-License-Identifier: AGPL-3.0-only
import SwiftUI
import UIKit
import UniformTypeIdentifiers

// Nova owns only presentation and a profile-scoped workspace. All application
// lifecycle operations remain in BloomBox's existing Home adapter.
struct BloomBoxNovaWorkspace: Codable, Equatable {
    struct Folder: Codable, Equatable {
        var name: String
        var apps: [String]
    }

    static let capacity = 20
    static func emptyPage() -> [String?] { Array(repeating: nil, count: capacity) }
    var pages: [[String?]] = [Self.emptyPage()]
    var dock: [String?] = Array(repeating: nil, count: 4)
    var known: [String] = []
    var folders: [String: Folder] = [:]
    var columns = 4
    var labels = true
    var iconShape = 0
    var wallpaper = 0

    mutating func reconcile(_ installed: [String]) {
        let valid = Set(installed)
        columns = columns == 5 ? 5 : 4
        iconShape = min(2, max(0, iconShape))
        wallpaper = min(3, max(0, wallpaper))
        for id in Array(folders.keys) {
            folders[id]?.apps.removeAll { !valid.contains($0) }
            if folders[id]?.apps.isEmpty != false { folders.removeValue(forKey: id) }
        }
        let allowed = valid.union(folders.keys)
        pages = pages.map { page in
            var result = Array(page.prefix(Self.capacity))
            result += Array(repeating: nil, count: Self.capacity - result.count)
            return result.map { key in key.flatMap { allowed.contains($0) ? $0 : nil } }
        }
        if pages.isEmpty { pages = [Self.emptyPage()] }
        dock = Array(dock.prefix(4)) + Array(repeating: nil, count: max(0, 4 - dock.count))
        dock = dock.map { key in key.flatMap { allowed.contains($0) ? $0 : nil } }
        // Deduplicate damaged or old workspace state without deleting guest data.
        var seen = Set<String>()
        for i in dock.indices {
            if let key = dock[i], !seen.insert(key).inserted { dock[i] = nil }
        }
        for i in pages.indices {
            for j in pages[i].indices {
                if let key = pages[i][j], !seen.insert(key).inserted { pages[i][j] = nil }
            }
        }
        for id in folders.keys.sorted() {
            folders[id]?.apps = (folders[id]?.apps ?? []).filter { seen.insert($0).inserted }
            if folders[id]?.apps.isEmpty != false {
                folders.removeValue(forKey: id)
                remove(id)
            }
        }
        let previous = Set(known)
        for key in installed where !previous.contains(key) && !seen.contains(key) {
            add(key, preferred: 0)
            seen.insert(key)
        }
        known = installed.filter { valid.contains($0) }
    }

    func contains(_ key: String) -> Bool {
        dock.contains(key) || pages.contains { $0.contains(key) } ||
        folders.values.contains { $0.apps.contains(key) }
    }

    mutating func remove(_ key: String) {
        for i in pages.indices {
            for j in pages[i].indices where pages[i][j] == key { pages[i][j] = nil }
        }
        for i in dock.indices where dock[i] == key { dock[i] = nil }
        for id in Array(folders.keys) {
            folders[id]?.apps.removeAll { $0 == key }
            if folders[id]?.apps.isEmpty == true {
                folders.removeValue(forKey: id)
                for i in pages.indices {
                    for j in pages[i].indices where pages[i][j] == id { pages[i][j] = nil }
                }
                for i in dock.indices where dock[i] == id { dock[i] = nil }
            }
        }
    }

    mutating func add(_ key: String, preferred: Int) {
        remove(key)
        if pages.indices.contains(preferred), let slot = pages[preferred].firstIndex(of: nil) {
            pages[preferred][slot] = key
        } else if let i = pages.firstIndex(where: { $0.contains(nil) }),
                  let slot = pages[i].firstIndex(of: nil) {
            pages[i][slot] = key
        } else {
            pages.append(Self.emptyPage())
            pages[pages.count - 1][0] = key
        }
    }

    mutating func place(_ key: String, page: Int, slot: Int) {
        guard pages.indices.contains(page), pages[page].indices.contains(slot),
              pages[page][slot] != key else { return }
        let displaced = pages[page][slot]
        // Swap in-place when moving within a workspace or dock.
        let sourcePage = pages.firstIndex { $0.contains(key) }
        let sourceSlot = sourcePage.flatMap { pages[$0].firstIndex(of: key) }
        let sourceDock = dock.firstIndex(of: key)
        remove(key)
        pages[page][slot] = key
        if let displaced {
            if let sourcePage, let sourceSlot { pages[sourcePage][sourceSlot] = displaced }
            else if let sourceDock { dock[sourceDock] = displaced }
            else { add(displaced, preferred: page) }
        }
    }

    mutating func placeInDock(_ key: String, slot: Int, page: Int) {
        guard dock.indices.contains(slot), dock[slot] != key else { return }
        let displaced = dock[slot]
        let sourcePage = pages.firstIndex { $0.contains(key) }
        let sourceSlot = sourcePage.flatMap { pages[$0].firstIndex(of: key) }
        let sourceDock = dock.firstIndex(of: key)
        remove(key)
        dock[slot] = key
        if let displaced {
            if let sourcePage, let sourceSlot { pages[sourcePage][sourceSlot] = displaced }
            else if let sourceDock { dock[sourceDock] = displaced }
            else { add(displaced, preferred: page) }
        }
    }

    mutating func createFolder(_ first: String, _ second: String, name: String, page: Int) {
        guard first != second, folders[first] == nil, folders[second] == nil else { return }
        remove(first)
        remove(second)
        let id = "nova-folder:" + UUID().uuidString
        folders[id] = Folder(name: name, apps: [first, second])
        add(id, preferred: page)
    }

    mutating func dissolve(_ id: String, page: Int) {
        guard let folder = folders.removeValue(forKey: id) else { return }
        remove(id)
        for key in folder.apps { add(key, preferred: page) }
    }

    mutating func removePage(_ index: Int) {
        guard pages.count > 1, pages.indices.contains(index) else { return }
        let removed = pages.remove(at: index).compactMap { $0 }
        for key in removed { add(key, preferred: min(index, pages.count - 1)) }
    }
}

// All Nova surfaces are deliberately opaque, with plain controls. System
// pickers, guest settings and installer actions are owned by their existing hosts.
struct BloomBoxNovaV2View: View {
    let profileID: String
    let keys: [String]
    let name: (String) -> String
    let icon: (String, CGFloat) -> AnyView
    let isGuest: (String) -> Bool
    let hasGift: (String) -> Bool
    let canJIT: (String) -> Bool
    let isAndroid: (String) -> Bool
    let launch: (String) -> Void
    let launchJIT: (String) -> Void
    let manage: (String) -> Void
    let uninstall: (String) -> Void
    let orientation: (String, String) -> Void
    let openInstall: () -> Void
    let openInterface: () -> Void
    let openManagement: () -> Void
    let openGameBox: () -> Void
    let openSettings: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("BloomBoxPreferredLanguage", store: LiveContainerPreferencesAdapter.defaults)
    private var language = "system"
    @State private var workspace = BloomBoxNovaWorkspace()
    @State private var loaded = false
    @State private var page = 0
    @State private var drawer = false
    @State private var editing = false
    @State private var settings = false
    @State private var query = ""
    @State private var selected: String?
    @State private var folder: String?
    @State private var folderSource: String?
    @State private var importWallpaper = false
    @State private var photo: UIImage?
    @State private var wallpaperError = false
    @FocusState private var searching: Bool

    private let panel = Color(red: 0.11, green: 0.13, blue: 0.15)
    private let raised = Color(red: 0.18, green: 0.21, blue: 0.23)
    private let accent = Color(red: 0.54, green: 0.87, blue: 0.64)
    private var english: Bool {
        language == "en" || (language == "system" &&
            (Locale.preferredLanguages.first ?? "en").lowercased().hasPrefix("en"))
    }
    private func t(_ en: String, _ es: String) -> String { english ? en : es }
    private var defaults: UserDefaults { LiveContainerPreferencesAdapter.defaults }
    private var storageKey: String { "BloomBoxNovaWorkspaceV2/" + profileID }
    private var distinctKeys: [String] {
        var seen = Set<String>()
        return keys.filter { seen.insert($0).inserted }
    }
    private var visibleKeys: [String] {
        distinctKeys.filter { query.isEmpty || name($0).localizedCaseInsensitiveContains(query) }
            .sorted { name($0).localizedStandardCompare(name($1)) == .orderedAscending }
    }
    private var grid: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 5), count: workspace.columns)
    }
    private var wallpaperURL: URL {
        let safe = profileID.filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BloomBoxNovaV2", isDirectory: true)
            .appendingPathComponent(safe + ".jpg")
    }
    private func displayName(_ key: String) -> String { workspace.folders[key]?.name ?? name(key) }
    private func valid(_ key: String) -> Bool { distinctKeys.contains(key) || workspace.folders[key] != nil }
    private func animate(_ action: () -> Void) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.20), action)
    }

    var body: some View {
        ZStack {
            wallpaperView
            if drawer {
                drawerView.transition(.move(edge: .bottom))
            } else {
                homeView
            }
            if settings { settingsView.zIndex(3) }
            if let folder { folderView(folder).zIndex(4) }
            if let selected { contextPanel(selected).zIndex(5) }
            if let folderSource { folderPicker(folderSource).zIndex(6) }
        }
        .foregroundStyle(Color.white)
        .background(panel.ignoresSafeArea())
        .onAppear {
            guard !loaded else { return }
            if let data = defaults.data(forKey: storageKey),
               let saved = try? JSONDecoder().decode(BloomBoxNovaWorkspace.self, from: data) {
                workspace = saved
            }
            workspace.reconcile(distinctKeys)
            photo = UIImage(contentsOfFile: wallpaperURL.path)
            loaded = true
            save()
        }
        .onChange(of: distinctKeys) { new in
            guard loaded else { return }
            workspace.reconcile(new)
            page = min(page, workspace.pages.count - 1)
            if let selected, !valid(selected) { self.selected = nil }
            if let folder, workspace.folders[folder] == nil { self.folder = nil }
        }
        .onChange(of: workspace) { _ in if loaded { save() } }
        .fileImporter(isPresented: $importWallpaper, allowedContentTypes: [.image]) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                guard data.count <= 15_000_000, let image = UIImage(data: data),
                      let jpeg = image.jpegData(compressionQuality: 0.86) else {
                    wallpaperError = true
                    return
                }
                try FileManager.default.createDirectory(at: wallpaperURL.deletingLastPathComponent(),
                                                        withIntermediateDirectories: true)
                try jpeg.write(to: wallpaperURL, options: .atomic)
                photo = image
                workspace.wallpaper = 3
            } catch { wallpaperError = true }
        }
        .alert(t("Wallpaper could not be loaded", "No se pudo cargar el fondo"), isPresented: $wallpaperError) {
            Button("OK", role: .cancel) {}
        }
        .accessibilityIdentifier("bloombox.nova.v2")
    }

    private func save() {
        if let data = try? JSONEncoder().encode(workspace) { defaults.set(data, forKey: storageKey) }
    }

    private var wallpaperView: some View {
        ZStack {
            switch workspace.wallpaper {
            case 1: Color(red: 0.07, green: 0.20, blue: 0.16)
            case 2: Color(red: 0.12, green: 0.15, blue: 0.30)
            case 3:
                if let photo {
                    GeometryReader { geometry in
                        Image(uiImage: photo).resizable().scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    }
                } else { panel }
            default: Color(red: 0.07, green: 0.09, blue: 0.11)
            }
        }.ignoresSafeArea()
    }

    private var homeView: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Text("Nova").font(.system(size: 22, weight: .bold))
                Spacer()
                control(editing ? "checkmark" : "pencil", editing ? t("Done", "Listo") : t("Edit Home", "Editar inicio")) {
                    animate { editing.toggle() }
                }
                control("gearshape", t("Nova settings", "Ajustes de Nova")) { animate { settings = true } }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            if editing { editorBar }
            TabView(selection: $page) {
                ForEach(workspace.pages.indices, id: \.self) { index in
                    GeometryReader { geo in
                        let size = min(58, max(30, (geo.size.width - 34) / CGFloat(workspace.columns) - 14))
                        ScrollView {
                            LazyVGrid(columns: grid, spacing: 12) {
                                ForEach(0..<BloomBoxNovaWorkspace.capacity, id: \.self) { slot in
                                    slotView(workspace.pages[index][slot], size: size, dockSlot: nil, pageIndex: index, slot: slot)
                                }
                            }
                            .padding(12)
                            .frame(minHeight: geo.size.height, alignment: .bottom)
                        }
                    }.tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            pageControl
            Button {
                animate { drawer = true; query = ""; editing = false }
            } label: {
                Image(systemName: "chevron.up").font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(t("Open app drawer", "Abrir cajón de apps"))
            dockView
        }
        .simultaneousGesture(DragGesture(minimumDistance: 50).onEnded { value in
            guard !editing, abs(value.translation.height) > abs(value.translation.width) * 1.5,
                  value.translation.height < -70 else { return }
            animate { drawer = true; query = "" }
        })
    }

    private var editorBar: some View {
        HStack {
            Button { workspace.pages.append(BloomBoxNovaWorkspace.emptyPage()); page = workspace.pages.count - 1 } label: {
                Label(t("New page", "Nueva página"), systemImage: "plus")
            }
            Spacer()
            Button {
                workspace.removePage(page)
                page = min(page, workspace.pages.count - 1)
            } label: { Label(t("Remove page", "Quitar página"), systemImage: "minus") }
                .disabled(workspace.pages.count <= 1)
        }.font(.caption.weight(.semibold)).buttonStyle(.plain)
            .padding(12).background(raised).padding(.horizontal, 12)
    }

    private var pageControl: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(workspace.pages.indices, id: \.self) { index in
                    Button { animate { page = index } } label: {
                        Capsule().fill(page == index ? accent : Color.gray)
                            .frame(width: page == index ? 18 : 6, height: 6)
                            .frame(minWidth: 22, minHeight: 28)
                    }.buttonStyle(.plain)
                        .accessibilityLabel(t("Page", "Página") + " \(index + 1)")
                }
            }
        }.fixedSize(horizontal: workspace.pages.count < 10, vertical: true)
    }

    private var dockView: some View {
        HStack(spacing: 8) {
            ForEach(workspace.dock.indices, id: \.self) { index in
                slotView(workspace.dock[index], size: 45, dockSlot: index, pageIndex: page, slot: index)
            }
            Button { animate { drawer = true; query = ""; editing = false } } label: {
                Image(systemName: "circle.grid.3x3.fill")
                    .font(.system(size: 26)).foregroundStyle(accent)
                    .frame(width: 46, height: 46)
            }.buttonStyle(.plain).accessibilityLabel(t("All apps", "Todas las apps"))
        }.padding(12).background(panel, in: RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, 12).padding(.bottom, 8)
    }

    private var drawerView: some View {
        VStack(spacing: 12) {
            HStack {
                control("chevron.down", t("Back to Home", "Volver al inicio")) {
                    searching = false; animate { drawer = false }
                }
                Text(t("All apps", "Todas las apps")).font(.title2.bold())
                Spacer()
                control("plus", t("Install app", "Instalar app"), action: openInstall)
                control("gearshape", t("Settings", "Ajustes")) { animate { settings = true } }
            }.padding(.horizontal, 14).padding(.top, 10)
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(accent)
                TextField(t("Search apps", "Buscar aplicaciones"), text: $query)
                    .textFieldStyle(.plain).focused($searching)
                    .autocorrectionDisabled(true)
                if !query.isEmpty { control("xmark", t("Clear search", "Borrar búsqueda")) { query = "" } }
            }.padding(12).background(raised, in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 14)
            ScrollView {
                if visibleKeys.isEmpty {
                    Text(t("No matching apps", "No hay aplicaciones")).foregroundStyle(Color.gray).padding(35)
                } else {
                    LazyVGrid(columns: grid, spacing: 18) {
                        ForEach(visibleKeys, id: \.self) { key in tile(key, size: 48, alwaysLabel: true) }
                    }.padding(14)
                }
            }
            Spacer(minLength: 0)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(panel.ignoresSafeArea())
    }

    @ViewBuilder private func slotView(_ key: String?, size: CGFloat, dockSlot: Int?, pageIndex: Int, slot: Int) -> some View {
        let content = Group {
            if let key, valid(key) {
                tile(key, size: size, alwaysLabel: false)
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(editing ? Color.gray : Color.clear, style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .frame(width: size, height: size)
                    .frame(maxWidth: .infinity, minHeight: size + 20)
            }
        }
        if editing {
            content.onDrop(of: [UTType.plainText], isTargeted: nil) { providers in
                acceptDrop(providers, pageIndex: pageIndex, slot: slot, dockSlot: dockSlot)
            }
        } else { content }
    }

    private func acceptDrop(_ providers: [NSItemProvider], pageIndex: Int, slot: Int, dockSlot: Int?) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else { return false }
        provider.loadObject(ofClass: NSString.self) { value, _ in
            guard let value = value as? String, value.hasPrefix("nova-drag:") else { return }
            let key = String(value.dropFirst("nova-drag:".count))
            DispatchQueue.main.async {
                guard valid(key) else { return }
                if let dockSlot { workspace.placeInDock(key, slot: dockSlot, page: pageIndex) }
                else { workspace.place(key, page: pageIndex, slot: slot) }
            }
        }
        return true
    }

    @ViewBuilder private func tile(_ key: String, size: CGFloat, alwaysLabel: Bool) -> some View {
        let content = VStack(spacing: 4) {
            tileImage(key, size: size)
            if workspace.labels || alwaysLabel {
                Text(displayName(key)).font(.system(size: 11, weight: .medium))
                    .lineLimit(1).truncationMode(.tail)
            }
        }
        .frame(maxWidth: .infinity, minHeight: size + 20)
        .contentShape(Rectangle())
        .gesture(LongPressGesture(minimumDuration: 0.38).exclusively(before: TapGesture()).onEnded { result in
            switch result {
            case .first: searching = false; animate { selected = key }
            case .second:
                if editing { animate { selected = key } } else { activate(key) }
            }
        })
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(displayName(key))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { if editing { selected = key } else { activate(key) } }
        .accessibilityAction(named: Text(t("App options", "Opciones de app"))) { selected = key }
        if editing { content.onDrag { NSItemProvider(object: ("nova-drag:" + key) as NSString) } }
        else { content }
    }

    private func tileImage(_ key: String, size: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            if let item = workspace.folders[key] {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 2), spacing: 2) {
                    ForEach(Array(item.apps.prefix(4)), id: \.self) { child in
                        icon(child, size * 0.32).frame(width: size * 0.32, height: size * 0.32).clipped()
                    }
                }.padding(5).frame(width: size, height: size).background(raised)
            } else {
                icon(key, size).frame(width: size, height: size)
                if hasGift(key) {
                    Image(systemName: "gift.fill").font(.caption).foregroundStyle(panel)
                        .padding(4).background(accent, in: Circle())
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: workspace.iconShape == 0 ? size * 0.20 : workspace.iconShape == 1 ? size / 2 : 2))
    }

    private func activate(_ key: String) {
        guard valid(key) else { return }
        if workspace.folders[key] != nil { animate { folder = key }; return }
        searching = false
        if !hasGift(key) { animate { drawer = false; folder = nil; query = "" } }
        launch(key)
    }

    private func control(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 17, weight: .semibold))
                .frame(width: 42, height: 42).background(raised, in: RoundedRectangle(cornerRadius: 9))
        }.buttonStyle(.plain).accessibilityLabel(label)
    }

    private func actionRow(_ label: String, _ symbol: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol).frame(width: 22)
                Text(label).frame(maxWidth: .infinity, alignment: .leading)
            }.font(.subheadline.weight(.medium)).padding(12)
                .foregroundStyle(destructive ? Color.red : Color.white)
                .background(raised, in: RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain)
    }

    private func modal<Content: View>(_ title: String, close: @escaping () -> Void, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text(title).font(.title3.bold()).lineLimit(1)
                Spacer()
                control("xmark", t("Close", "Cerrar"), action: close)
            }
            ScrollView { VStack(alignment: .leading, spacing: 8, content: content) }
        }.padding(16).frame(maxWidth: 440)
            .background(panel, in: RoundedRectangle(cornerRadius: 20))
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.75).ignoresSafeArea().onTapGesture(perform: close))
    }

    private func contextPanel(_ key: String) -> some View {
        modal(displayName(key), close: { selected = nil }) {
            if workspace.folders[key] != nil {
                actionRow(t("Open folder", "Abrir carpeta"), "folder") { selected = nil; folder = key }
                actionRow(t("Dissolve folder", "Deshacer carpeta"), "folder.badge.minus") {
                    workspace.dissolve(key, page: page); selected = nil
                }
            } else {
                actionRow(t("Open", "Abrir"), "play.fill") { selected = nil; activate(key) }
                if canJIT(key) {
                    actionRow(t("Launch with JIT", "Abrir con JIT"), "bolt.fill") {
                        selected = nil; drawer = false; folder = nil; launchJIT(key)
                    }
                    actionRow(t("App settings", "Ajustes de app"), "gearshape") { selected = nil; manage(key) }
                }
                if isAndroid(key) {
                    actionRow(t("Portrait", "Vertical"), "iphone") { selected = nil; orientation(key, "portrait") }
                    actionRow(t("Landscape", "Horizontal"), "iphone.landscape") { selected = nil; orientation(key, "landscape") }
                    actionRow(t("Ask every launch", "Preguntar al abrir"), "arrow.triangle.2.circlepath") { selected = nil; orientation(key, "hybrid") }
                }
                actionRow(t("Add to Home", "Añadir al inicio"), "house") { workspace.add(key, preferred: page); selected = nil; drawer = false }
                actionRow(t("Create folder", "Crear carpeta"), "folder.badge.plus") { selected = nil; folderSource = key }
                if isGuest(key) {
                    actionRow(t("Uninstall", "Desinstalar"), "trash", destructive: true) { selected = nil; uninstall(key) }
                }
            }
            actionRow(t("Pin to dock", "Fijar en dock"), "rectangle.bottomthird.inset.filled") {
                workspace.placeInDock(key, slot: workspace.dock.firstIndex(of: nil) ?? 3, page: page)
                selected = nil; drawer = false
            }
            if workspace.contains(key) {
                actionRow(t("Remove shortcut", "Quitar acceso"), "minus.circle") {
                    if workspace.folders[key] != nil { workspace.folders.removeValue(forKey: key) }
                    workspace.remove(key); selected = nil
                }
            }
        }
    }

    private func folderPicker(_ first: String) -> some View {
        modal(t("Choose another app", "Elige otra app"), close: { folderSource = nil }) {
            ForEach(distinctKeys.filter { $0 != first }, id: \.self) { second in
                actionRow(name(second), "plus") {
                    workspace.createFolder(first, second, name: t("Folder", "Carpeta"), page: page)
                    folderSource = nil; folder = nil; drawer = false
                }
            }
        }
    }

    private func folderView(_ id: String) -> some View {
        modal(workspace.folders[id]?.name ?? t("Folder", "Carpeta"), close: { folder = nil }) {
            TextField(t("Folder name", "Nombre de carpeta"), text: Binding(
                get: { workspace.folders[id]?.name ?? "" },
                set: { workspace.folders[id]?.name = String($0.prefix(40)) }
            )).textFieldStyle(.plain).padding(12).background(raised, in: RoundedRectangle(cornerRadius: 8))
            LazyVGrid(columns: grid, spacing: 14) {
                ForEach(workspace.folders[id]?.apps ?? [], id: \.self) { key in tile(key, size: 46, alwaysLabel: true) }
            }
        }
    }

    private var settingsView: some View {
        modal(t("Nova settings", "Ajustes de Nova"), close: { settings = false }) {
            Text(t("Home layout", "Diseño del inicio")).font(.headline).foregroundStyle(accent)
            actionRow(t("Columns", "Columnas") + ": \(workspace.columns)", "square.grid.3x3") {
                workspace.columns = workspace.columns == 4 ? 5 : 4
            }
            actionRow(t("Icon labels", "Nombres de apps"), workspace.labels ? "checkmark.square" : "square") {
                workspace.labels.toggle()
            }
            actionRow(t("Icon shape", "Forma del icono") + ": " +
                      [t("Rounded", "Redondeado"), t("Circle", "Círculo"), t("Square", "Cuadrado")][workspace.iconShape], "app") {
                workspace.iconShape = (workspace.iconShape + 1) % 3
            }
            Text(t("Wallpaper", "Fondo de pantalla")).font(.headline).foregroundStyle(accent).padding(.top, 8)
            actionRow(t("Solid color", "Color sólido"), "paintpalette") { workspace.wallpaper = (workspace.wallpaper + 1) % 3 }
            actionRow(t("Choose image", "Elegir imagen"), "photo") { importWallpaper = true }
            Text(t("BloomBox", "BloomBox")).font(.headline).foregroundStyle(accent).padding(.top, 8)
            actionRow(t("Install app", "Instalar app"), "plus") { settings = false; openInstall() }
            actionRow(t("Manage apps", "Administrar apps"), "square.grid.2x2") { settings = false; openManagement() }
            actionRow("GameBox", "gamecontroller") { settings = false; openGameBox() }
            actionRow(t("Change launcher", "Cambiar launcher"), "arrow.left.arrow.right") { settings = false; openInterface() }
            actionRow(t("BloomBox settings", "Ajustes de BloomBox"), "gearshape") { settings = false; openSettings() }
        }
    }
}
