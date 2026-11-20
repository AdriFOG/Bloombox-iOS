// SPDX-License-Identifier: AGPL-3.0-only
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Portable app metadata; the LiveContainer adapter lives in LCAppListView.
struct BloomBoxNovaEntry: Identifiable {
    let id: String
    let bundleIdentifier: String
    let name: String
    let icon: UIImage?
    let requiresJIT: Bool
    let canUninstall: Bool
}

/// Android-style workspace, implemented natively for BloomBox.
/// This is not Nova Launcher source code or an Android runtime.
struct BloomBoxNovaLauncher: View {
    let entries: [BloomBoxNovaEntry]
    let profileID: String
    let profileName: String
    let accentHex: String
    let english: Bool
    let persistence: UserDefaults
    let launch: (String) -> Void
    let launchWithJIT: (String) -> Void
    let manage: (String) -> Void
    let uninstall: (String) -> Void
    let openInstall: () -> Void
    let openManagement: () -> Void
    let openSettings: () -> Void
    let openInterface: () -> Void
    let openGameBox: () -> Void

    @State private var savedWorkspaces = "{}"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var workspace = BloomBoxNovaLayout()
    @State private var page = 0
    @State private var drawerOpen = false
    @State private var search = ""
    @State private var drawerFilter = "all"
    @State private var editing = false
    @State private var settingsOpen = false
    @State private var folderOpen: String?
    @State private var renameKey: String?
    @State private var renameDraft = ""
    @State private var renameOpen = false
    @State private var uninstallKey: String?
    @State private var uninstallConfirmation = false
    @State private var launchingKey: String?
    @State private var wallpaper: UIImage?
    @State private var customWallpaper: UIImage?
    @FocusState private var searchFocused: Bool

    private func t(_ spanish: String, _ englishText: String) -> String {
        english ? englishText : spanish
    }

    private var accent: Color {
        BloomBoxWizardPalette.color(accentHex)
    }

    private var appMap: [String: BloomBoxNovaEntry] {
        Dictionary(entries.map { ($0.id, $0) }, uniquingKeysWith: { current, _ in current })
    }

    private var keys: [String] {
        var used = Set<String>()
        return (entries.map(\.id) + BloomBoxNovaLayout.builtIns)
            .filter { used.insert($0).inserted }
    }

    private var pageKeys: [String] {
        workspace.pages.indices.contains(page) ? workspace.pages[page] : []
    }

    private var drawerKeys: [String] {
        let all = keys.filter { key in
            if drawerFilter == "favorites" && !workspace.favorites.contains(key) { return false }
            if drawerFilter == "recent" && !workspace.recents.contains(key) { return false }
            return search.isEmpty ||
                name(for: key).localizedCaseInsensitiveContains(search) ||
                (appMap[key]?.bundleIdentifier.localizedCaseInsensitiveContains(search) ?? false)
        }
        if drawerFilter == "recent" || workspace.drawerSort == "recent" {
            let order = workspace.recents
            return all.sorted { a, b in
                let lhs = order.firstIndex(of: a) ?? Int.max
                let rhs = order.firstIndex(of: b) ?? Int.max
                if lhs != rhs { return lhs < rhs }
                return name(for: a).localizedStandardCompare(name(for: b)) == .orderedAscending
            }
        }
        return all.sorted {
            name(for: $0).localizedStandardCompare(name(for: $1)) == .orderedAscending
        }
    }

    private var dragType: String { UTType.plainText.identifier }
    private var grid: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: workspace.columns)
    }

    private var iconSide: CGFloat {
        let base: CGFloat = workspace.columns == 6 ? 43 : (workspace.columns == 5 ? 51 : 63)
        return base * CGFloat(workspace.iconScale)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                background.ignoresSafeArea()
                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                    if workspace.showSearch {
                        Button {
                            showDrawer(searchImmediately: true)
                        } label: {
                            HStack(spacing: 11) {
                                Image(systemName: "magnifyingglass")
                                Text(t("Busca tus aplicaciones", "Search your apps"))
                                Spacer()
                                Image(systemName: "line.3.horizontal.decrease")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 16)
                            .frame(height: 46)
                            .background(.ultraThinMaterial,
                                        in: RoundedRectangle(cornerRadius: 23))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 19)
                        .padding(.top, 18)
                    }

                    workspaceGrid
                        .frame(maxWidth: .infinity, maxHeight: .infinity,
                               alignment: .top)
                        .padding(.horizontal, 14)
                        .padding(.top, 29)
                        .contentShape(Rectangle())
                        .simultaneousGesture(DragGesture(minimumDistance: 55)
                            .onEnded { gesture in
                                guard !drawerOpen else { return }
                                let delta = gesture.translation
                                if delta.height < -75 && abs(delta.height) > abs(delta.width) {
                                    showDrawer()
                                } else if abs(delta.width) > 70 &&
                                          abs(delta.width) > abs(delta.height) {
                                    changePage(by: delta.width < 0 ? 1 : -1)
                                }
                            })
                        .onDrop(of: [dragType], isTargeted: nil) { providers in
                            acceptDrop(providers) { key in
                                workspace.moveToPage(key, page: page)
                            }
                        }

                    if editing {
                        HStack {
                            Button {
                                workspace.pages.append([])
                                page = workspace.pages.count - 1
                            } label: {
                                Label(t("Nueva página", "New page"), systemImage: "plus.square")
                            }
                            Spacer()
                            Button(t("Listo", "Done")) { editing = false }
                                .font(.footnote.weight(.bold))
                        }
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 28)
                        .padding(.bottom, 10)
                    }

                    pageIndicator
                        .padding(.bottom, 10)
                    dock
                        .padding(.horizontal, 15)
                        .padding(.bottom, 8)

                    Button { showDrawer() } label: {
                        Capsule()
                            .fill(.white.opacity(0.78))
                            .frame(width: 43, height: 5)
                            .frame(height: 25)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(t("Abrir cajón de aplicaciones", "Open app drawer"))
                }

                if drawerOpen {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                        .onTapGesture { closeDrawer() }
                        .transition(.opacity)
                        .zIndex(10)
                    drawer
                        .padding(.top, max(74, geometry.safeAreaInsets.top + 35))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(11)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .preferredColorScheme(.dark)
        .onAppear { reload() }
        .onChange(of: profileID) { _ in
            closeDrawer()
            folderOpen = nil
            reload()
        }
        .onChange(of: keys.joined(separator: "|")) { _ in
            workspace.reconcile(available: keys)
        }
        .onChange(of: workspace) { value in
            savedWorkspaces = BloomBoxNovaLayout.save(
                value, profile: profileID, into: savedWorkspaces)
            persistence.set(savedWorkspaces, forKey: "BloomBoxNovaWorkspaceV1")
        }
        .sheet(isPresented: $settingsOpen) {
            BloomBoxNovaSettingsView(
                layout: $workspace,
                availableKeys: keys,
                english: english,
                chooseWallpaper: saveCustomWallpaper,
                removeWallpaper: deleteCustomWallpaper)
        }
        .sheet(isPresented: Binding(
            get: { folderOpen != nil },
            set: { if !$0 { folderOpen = nil } }
        )) {
            folderSheet
        }
        .alert(t("Cambiar nombre", "Rename"), isPresented: $renameOpen) {
            TextField(t("Nombre", "Name"), text: $renameDraft)
            Button(t("Guardar", "Save")) {
                guard let key = renameKey else { return }
                let cleaned = String(renameDraft.trimmingCharacters(
                    in: .whitespacesAndNewlines).prefix(40))
                if let index = workspace.folders.firstIndex(where: { $0.id == key }) {
                    if !cleaned.isEmpty { workspace.folders[index].name = cleaned }
                } else {
                    if cleaned.isEmpty { workspace.aliases.removeValue(forKey: key) }
                    else { workspace.aliases[key] = cleaned }
                }
                renameKey = nil
            }
            Button(t("Cancelar", "Cancel"), role: .cancel) { renameKey = nil }
        }
        .confirmationDialog(t("¿Desinstalar esta aplicación?", "Uninstall this app?"),
                            isPresented: $uninstallConfirmation) {
            Button(t("Desinstalar", "Uninstall"), role: .destructive) {
                if let key = uninstallKey, appMap[key] != nil { uninstall(key) }
                uninstallKey = nil
            }
            Button(t("Cancelar", "Cancel"), role: .cancel) { uninstallKey = nil }
        } message: {
            Text(t("Esto elimina la aplicación administrada por BloomBox. Sus datos se conservan según las reglas del administrador.",
                   "This removes the BloomBox-managed app. Its data is retained according to the app manager's rules."))
        }
    }

    @ViewBuilder private var background: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.075, blue: 0.13),
                         Color(red: 0.12, green: 0.06, blue: 0.21),
                         Color(red: 0.025, green: 0.04, blue: 0.08)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
            if workspace.useCustomWallpaper, let customWallpaper {
                Image(uiImage: customWallpaper)
                    .resizable()
                    .scaledToFill()
                    .overlay(Color.black.opacity(0.24))
            } else if workspace.useHomeWallpaper, let wallpaper {
                Image(uiImage: wallpaper)
                    .resizable()
                    .scaledToFill()
                    .overlay(Color.black.opacity(0.32))
            }
            RadialGradient(colors: [accent.opacity(0.23), .clear],
                           center: .topTrailing, startRadius: 10, endRadius: 490)
        }
        .clipped()
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                if workspace.showClock {
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        Text(context.date, format: .dateTime.hour().minute())
                            .font(.system(size: 45, weight: .light, design: .rounded))
                            .monospacedDigit()
                    }
                }
                Text(profileName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
            }
            Spacer()
            Menu {
                Button(t("Editar escritorio", "Edit Home"), systemImage: "square.grid.3x3") {
                    editing.toggle()
                }
                Button(t("Cajón de aplicaciones", "App drawer"), systemImage: "square.grid.4x3.fill") {
                    showDrawer()
                }
                Button(t("Personalización", "Customize"), systemImage: "slider.horizontal.3") {
                    settingsOpen = true
                }
                Button(t("Cambiar interfaz", "Switch interface"), systemImage: "rectangle.3.group") {
                    openInterface()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel(t("Menú del escritorio", "Desktop menu"))
        }
    }

    private var workspaceGrid: some View {
        LazyVGrid(columns: grid, alignment: .center, spacing: 20) {
            ForEach(pageKeys, id: \.self) { key in
                tile(key, inDrawer: false)
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.84),
                   value: page)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(workspace.pages.indices, id: \.self) { index in
                Button {
                    withAnimation(.easeInOut(duration: 0.24)) { page = index }
                } label: {
                    Capsule()
                        .fill(index == page ? Color.white : Color.white.opacity(0.36))
                        .frame(width: index == page ? 22 : 6, height: 6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(t("Página", "Page")) \(index + 1)")
            }
        }
        .frame(height: 18)
    }

    private var dock: some View {
        HStack(spacing: 2) {
            ForEach(workspace.dock, id: \.self) { key in
                tile(key, inDrawer: false, inDock: true)
                    .frame(maxWidth: .infinity)
            }
            if workspace.dock.count < BloomBoxNovaLayout.dockCapacity {
                Button { showDrawer() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 23, weight: .medium))
                        .foregroundStyle(.white.opacity(0.58))
                        .frame(maxWidth: .infinity, minHeight: 64)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 29, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 29)
            .strokeBorder(.white.opacity(0.12), lineWidth: 1))
        .onDrop(of: [dragType], isTargeted: nil) { providers in
            acceptDrop(providers) { key in _ = workspace.moveToDock(key) }
        }
    }

    @ViewBuilder private func tile(_ key: String, inDrawer: Bool,
                                   inDock: Bool = false) -> some View {
        let content = VStack(spacing: inDock ? 0 : 6) {
            icon(key, side: inDock ? min(iconSide, 59) : iconSide)
                .scaleEffect(launchingKey == key && workspace.animation == "zoom" && !reduceMotion ? 1.17 : 1)
                .offset(y: launchingKey == key && workspace.animation == "slide" && !reduceMotion ? -25 : 0)
                .opacity(launchingKey == key && workspace.animation == "fade" ? 0.35 : 1)
            if workspace.showLabels && !inDock {
                Text(name(for: key))
                    .font(.system(size: workspace.columns == 6 ? 10 : 11,
                                  weight: .medium, design: .rounded))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.75), radius: 4, y: 1)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: inDock ? 62 : (workspace.showLabels ? 92 : 70),
               alignment: .top)
        .contentShape(Rectangle())
        .onTapGesture { activate(key) }
        .contextMenu { contextActions(for: key, fromDrawer: inDrawer) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(name(for: key))
        if editing || inDrawer {
            content
                .onDrag { NSItemProvider(object: key as NSString) }
                .onDrop(of: [dragType], isTargeted: nil) { providers in
                    acceptDrop(providers) { source in
                        guard source != key else { return }
                        if key.hasPrefix("folder:") {
                            workspace.move(source, into: key)
                        } else if source.hasPrefix("folder:") {
                            workspace.moveToPage(source, page: page, before: key)
                        } else {
                            _ = workspace.createFolder(with: source, and: key)
                        }
                    }
                }
        } else {
            content
        }
    }

    @ViewBuilder private func icon(_ key: String, side: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: workspace.roundIcons ? side / 2 : side * 0.23,
                                     style: .continuous)
        ZStack {
            if let picture = appMap[key]?.icon {
                Image(uiImage: picture)
                    .resizable()
                    .scaledToFill()
            } else if key.hasPrefix("folder:"),
                      let folder = workspace.folders.first(where: { $0.id == key }) {
                shape.fill(.white.opacity(0.22))
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: side * 0.45, weight: .medium))
                    .foregroundStyle(.white)
                Text("\(folder.apps.count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(x: side * 0.32, y: side * 0.33)
            } else {
                shape.fill(builtInColor(for: key))
                Image(systemName: builtInSymbol(for: key))
                    .font(.system(size: side * 0.44, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: side, height: side)
        .clipShape(shape)
        .overlay(shape.strokeBorder(.white.opacity(0.16), lineWidth: 1))
        .shadow(color: .black.opacity(0.27), radius: 7, y: 5)
    }

    @ViewBuilder private func contextActions(for key: String, fromDrawer: Bool) -> some View {
        if key.hasPrefix("folder:") {
            Button(t("Abrir carpeta", "Open folder"), systemImage: "folder") {
                folderOpen = key
            }
            Button(t("Renombrar carpeta", "Rename folder"), systemImage: "pencil") {
                rename(key)
            }
            Button(t("Deshacer carpeta", "Dissolve folder"), systemImage: "folder.badge.minus") {
                workspace.dissolve(key)
            }
        } else {
            Button(t("Abrir", "Open"), systemImage: "arrow.up.forward.app") {
                activate(key)
            }
            if let app = appMap[key] {
                if app.requiresJIT {
                    Button(t("Abrir con JIT", "Launch with JIT"), systemImage: "bolt.fill") {
                        launchWithJIT(key)
                    }
                }
                Button(t("Información de app", "App info"), systemImage: "info.circle") {
                    manage(key)
                }
            }
            Button(workspace.favorites.contains(key) ? t("Quitar favorito", "Unfavorite")
                   : t("Añadir favorito", "Favorite"), systemImage: "star") {
                workspace.toggleFavorite(key)
            }
            if fromDrawer || workspace.hiddenFromHome.contains(key) {
                Button(t("Añadir al escritorio", "Add to Home"), systemImage: "plus.square") {
                    workspace.addToHome(key, page: page)
                    closeDrawer()
                }
            } else {
                Button(t("Quitar del escritorio", "Remove from Home"), systemImage: "minus.circle") {
                    workspace.removeFromHome(key)
                }
            }
            if workspace.dock.contains(key) {
                Button(t("Sacar del Dock", "Remove from Dock"), systemImage: "minus") {
                    workspace.removeFromDock(key)
                }
            } else if workspace.dock.count < BloomBoxNovaLayout.dockCapacity {
                Button(t("Añadir al Dock", "Add to Dock"), systemImage: "rectangle.bottomthird.inset.filled") {
                    _ = workspace.moveToDock(key)
                }
            }
            Menu(t("Mover a página", "Move to page"), systemImage: "square.on.square") {
                ForEach(workspace.pages.indices, id: \.self) { index in
                    Button("\(t("Página", "Page")) \(index + 1)") {
                        workspace.moveToPage(key, page: index)
                        closeDrawer()
                    }
                }
                Button(t("Nueva página", "New page"), systemImage: "plus") {
                    workspace.moveToPage(key, page: workspace.pages.count)
                    closeDrawer()
                }
            }
            if !workspace.folders.isEmpty {
                Menu(t("Añadir a carpeta", "Add to folder"), systemImage: "folder.badge.plus") {
                    ForEach(workspace.folders) { folder in
                        Button(folder.name) { workspace.move(key, into: folder.id) }
                    }
                }
            }
            Button(t("Renombrar acceso", "Rename shortcut"), systemImage: "pencil") {
                rename(key)
            }
            if let app = appMap[key], app.canUninstall {
                Divider()
                Button(t("Desinstalar", "Uninstall"), systemImage: "trash", role: .destructive) {
                    uninstallKey = key
                    uninstallConfirmation = true
                }
            }
        }
        Button(t("Editar escritorio", "Edit Home"), systemImage: "square.grid.3x3") {
            editing = true
            closeDrawer()
        }
    }

    private var drawer: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(.white.opacity(0.5))
                .frame(width: 38, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 18)
                .onTapGesture { closeDrawer() }
                .gesture(DragGesture(minimumDistance: 14).onEnded { gesture in
                    if gesture.translation.height > 45 { closeDrawer() }
                })
            HStack {
                Text(t("Todas las aplicaciones", "All apps"))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Spacer()
                Button { closeDrawer() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 31, height: 31)
                        .background(.white.opacity(0.11), in: Circle())
                }
            }
            .padding(.horizontal, 22)
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(t("Buscar apps", "Search apps"), text: $search)
                    .focused($searchFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if !search.isEmpty {
                    Button { search = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(13)
            .background(.white.opacity(0.10),
                        in: RoundedRectangle(cornerRadius: 15))
            .padding(.horizontal, 20)
            .padding(.top, 16)
            HStack(spacing: 7) {
                filterButton("all", t("Todas", "All"))
                filterButton("favorites", t("Favoritas", "Favorites"))
                filterButton("recent", t("Recientes", "Recent"))
                Spacer(minLength: 0)
                Button { settingsOpen = true } label: {
                    Image(systemName: "slider.horizontal.3")
                        .frame(width: 35, height: 34)
                }
            }
            .padding(.horizontal, 19)
            .padding(.vertical, 13)
            ScrollView {
                if drawerKeys.isEmpty {
                    VStack(spacing: 11) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 39))
                        Text(t("No encontramos aplicaciones", "No matching apps"))
                            .font(.subheadline)
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 65)
                } else if workspace.drawerList {
                    LazyVStack(spacing: 4) {
                        ForEach(drawerKeys, id: \.self) { key in
                            HStack(spacing: 13) {
                                icon(key, side: 42)
                                Text(name(for: key))
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 7)
                            .contentShape(Rectangle())
                            .onTapGesture { activate(key) }
                            .contextMenu { contextActions(for: key, fromDrawer: true) }
                        }
                    }
                } else {
                    LazyVGrid(columns: grid, spacing: 21) {
                        ForEach(drawerKeys, id: \.self) { key in
                            tile(key, inDrawer: true)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 9)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .foregroundStyle(.white)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 30))
        .ignoresSafeArea(edges: .bottom)
    }

    private func filterButton(_ value: String, _ title: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { drawerFilter = value }
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 11)
                .frame(height: 34)
                .background(drawerFilter == value ? accent : .white.opacity(0.10),
                            in: Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var folderSheet: some View {
        if let id = folderOpen, let folder = workspace.folders.first(where: { $0.id == id }) {
            NavigationView {
                ScrollView {
                    LazyVGrid(columns: grid, spacing: 20) {
                        ForEach(folder.apps, id: \.self) { key in
                            VStack(spacing: 5) {
                                icon(key, side: iconSide)
                                Text(name(for: key))
                                    .font(.caption2)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity)
                            .onTapGesture {
                                folderOpen = nil
                                activate(key)
                            }
                            .contextMenu {
                                Button(t("Sacar de carpeta", "Remove from folder"),
                                       systemImage: "folder.badge.minus") {
                                    workspace.remove(key, from: id)
                                }
                                if let app = appMap[key] {
                                    Button(t("Información", "App info"),
                                           systemImage: "info.circle") { manage(key) }
                                }
                            }
                        }
                    }
                    .padding(22)
                }
                .navigationTitle(folder.name)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(t("Renombrar", "Rename")) { rename(id) }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(t("Listo", "Done")) { folderOpen = nil }
                    }
                }
            }
            .navigationViewStyle(.stack)
            .preferredColorScheme(.dark)
        } else {
            EmptyView()
        }
    }

    private func name(for key: String) -> String {
        if let alias = workspace.aliases[key] { return alias }
        if let folder = workspace.folders.first(where: { $0.id == key }) { return folder.name }
        if let app = appMap[key] { return app.name }
        switch key {
        case "nova:install": return t("Instalar IPA", "Install IPA")
        case "nova:gamebox": return "GameBox"
        case "nova:management": return t("Mis aplicaciones", "My apps")
        case "nova:settings": return t("Ajustes", "Settings")
        case "nova:interface": return t("Cambiar launcher", "Switch launcher")
        default: return key
        }
    }

    private func builtInSymbol(for key: String) -> String {
        switch key {
        case "nova:install": return "square.and.arrow.down.fill"
        case "nova:gamebox": return "gamecontroller.fill"
        case "nova:management": return "square.grid.2x2.fill"
        case "nova:settings": return "gearshape.fill"
        case "nova:interface": return "rectangle.3.group.fill"
        default: return "app.fill"
        }
    }

    private func builtInColor(for key: String) -> Color {
        switch key {
        case "nova:install": return .green
        case "nova:gamebox": return .indigo
        case "nova:management": return .cyan
        case "nova:settings": return .gray
        default: return accent
        }
    }

    private func activate(_ key: String) {
        if key.hasPrefix("folder:") {
            folderOpen = key
            return
        }
        guard launchingKey == nil else { return }
        workspace.recordLaunch(key)
        let action: () -> Void = {
            switch key {
            case "nova:install": openInstall()
            case "nova:gamebox": openGameBox()
            case "nova:management": openManagement()
            case "nova:settings": openSettings()
            case "nova:interface": openInterface()
            default:
                if appMap[key] != nil { launch(key) }
            }
        }
        closeDrawer()
        if reduceMotion || workspace.animation == "none" {
            action()
            return
        }
        withAnimation(.spring(response: 0.22, dampingFraction: 0.64)) {
            launchingKey = key
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            launchingKey = nil
            action()
        }
    }

    private func rename(_ key: String) {
        renameKey = key
        renameDraft = name(for: key)
        renameOpen = true
    }

    private func changePage(by offset: Int) {
        guard !workspace.pages.isEmpty else { return }
        let newPage = min(max(page + offset, 0), workspace.pages.count - 1)
        withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.86)) {
            page = newPage
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func showDrawer(searchImmediately: Bool = false) {
        drawerFilter = "all"
        withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.90)) {
            drawerOpen = true
        }
        if searchImmediately {
            DispatchQueue.main.async { searchFocused = true }
        }
    }

    private func closeDrawer() {
        searchFocused = false
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.21)) {
            drawerOpen = false
        }
    }

    private func reload() {
        savedWorkspaces = persistence.string(forKey: "BloomBoxNovaWorkspaceV1") ?? "{}"
        let restored = BloomBoxNovaLayout.load(profile: profileID, from: savedWorkspaces)
        workspace = restored
        workspace.reconcile(available: keys)
        page = min(page, max(0, workspace.pages.count - 1))
        let wallpaperURL = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LiveBoard", isDirectory: true)
            .appendingPathComponent("wallpaper.jpg")
        wallpaper = UIImage(contentsOfFile: wallpaperURL.path)
        customWallpaper = UIImage(contentsOfFile: customWallpaperURL.path)
    }

    private var customWallpaperURL: URL {
        let safeProfile = String(profileID.filter {
            $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-")
        }.prefix(72))
        return FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BloomBox/NovaWallpapers", isDirectory: true)
            .appendingPathComponent((safeProfile.isEmpty ? "primary" : safeProfile) + ".jpg")
    }

    private func saveCustomWallpaper(_ image: UIImage) {
        let longest = max(image.size.width, image.size.height, 1)
        let factor = min(1.0, 1600.0 / longest)
        let size = CGSize(width: max(1, image.size.width * factor),
                          height: max(1, image.size.height * factor))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let data = UIGraphicsImageRenderer(size: size, format: format)
            .jpegData(withCompressionQuality: 0.83) { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
        do {
            try FileManager.default.createDirectory(
                at: customWallpaperURL.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            try data.write(to: customWallpaperURL, options: .atomic)
            customWallpaper = UIImage(data: data)
            workspace.useCustomWallpaper = true
        } catch {
            NSLog("[BloomBox Nova] Wallpaper save failed: %@", error.localizedDescription)
        }
    }

    private func deleteCustomWallpaper() {
        try? FileManager.default.removeItem(at: customWallpaperURL)
        customWallpaper = nil
        workspace.useCustomWallpaper = false
    }

    private func acceptDrop(_ providers: [NSItemProvider],
                            perform: @escaping (String) -> Void) -> Bool {
        guard let provider = providers.first(where: {
            $0.canLoadObject(ofClass: NSString.self)
        }) else { return false }
        _ = provider.loadObject(ofClass: NSString.self) { item, _ in
            guard let key = item as? String else { return }
            DispatchQueue.main.async {
                guard keys.contains(key) || workspace.folders.contains(where: { $0.id == key })
                else { return }
                perform(key)
                UISelectionFeedbackGenerator().selectionChanged()
            }
        }
        return true
    }
}
