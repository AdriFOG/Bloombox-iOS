import SwiftUI
import CryptoKit

/// BloomBox's native News desktop. No guest execution or installer state lives
/// on this page. The old Manzana widget-page entry point is retained as an alias.
struct BloomBoxNewsPage: View {
    let openSettings: () -> Void
    var openGameBox: () -> Void = {}
    var gameNames: [String: String] = [:]
    var singleWidget: String? = nil

    @AppStorage("BloomBoxPreferredLanguage", store: LCUtils.appGroupUserDefault)
    private var preferredLanguage = "system"
    private var locale: Locale {
        Locale(identifier: preferredLanguage == "system"
               ? (Locale.preferredLanguages.first ?? "en") : preferredLanguage)
    }
    private var english: Bool { locale.languageCode == "en" }

    var openInstall: () -> Void = {}
    var openShortcut: (BloomBoxNewsShortcut) -> Void = { _ in }

    @AppStorage("BloomBoxNewsInstallerUsedV1", store: LCUtils.appGroupUserDefault)
    private var hasUsedNewsInstaller = false
    @State private var installTipDismissedForVisit = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("BloomBox")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        Text(english ? "News and desktop" : "Novedades y escritorio")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    VStack(alignment: .trailing, spacing: 0) {
                        HStack(spacing: 8) {
                            Button {
                                // Remember actual usage, not mere presentation of the tip.
                                hasUsedNewsInstaller = true
                                installTipDismissedForVisit = true
                                openInstall()
                            } label: {
                                Image(systemName: "square.and.arrow.down.fill")
                                    .font(.system(size: 18, weight: .medium))
                                    .frame(width: 44, height: 44)
                                    .background(.thinMaterial, in: Circle())
                            }
                            .accessibilityLabel(english ? "Install IPA, TIPA or APK" : "Instalar IPA, TIPA o APK")
                            .accessibilityIdentifier("bloombox.news.install")
                            Button(action: openSettings) {
                                Image(systemName: "paintbrush.pointed.fill")
                                    .font(.system(size: 18, weight: .medium))
                                    .frame(width: 44, height: 44)
                                    .background(.thinMaterial, in: Circle())
                            }
                            .accessibilityLabel(english ? "Customize Home" : "Personalizar escritorio")
                            .accessibilityIdentifier("bloombox.news.settings")
                        }
                        if !hasUsedNewsInstaller && !installTipDismissedForVisit {
                            VStack(alignment: .trailing, spacing: 0) {
                                Image(systemName: "triangle.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color(red: 0.20, green: 0.18, blue: 0.30))
                                    .padding(.trailing, 68)
                                HStack(spacing: 7) {
                                    Image(systemName: "bubble.left.fill")
                                        .font(.caption2)
                                    Text(english ? "Install apps here!" : "¡Instala apps aquí!")
                                        .font(.caption.weight(.semibold))
                                        .fixedSize(horizontal: true, vertical: false)
                                    Button {
                                        // Dismiss only for this visit; it returns until used.
                                        installTipDismissedForVisit = true
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .frame(width: 24, height: 24)
                                    }
                                    .accessibilityLabel(english ? "Dismiss tip" : "Cerrar consejo")
                                }
                                .foregroundStyle(.white)
                                .padding(.leading, 12)
                                .padding(.trailing, 5)
                                .padding(.vertical, 4)
                                .background(Color(red: 0.20, green: 0.18, blue: 0.30),
                                            in: Capsule())
                            }
                            .padding(.top, 1)
                            .accessibilityIdentifier("bloombox.news.install.tip")
                        }
                    }
                }
                BloomBoxProfileSwitcherWidget()
                BloomBoxNewsQuickAccess(onOpen: openShortcut)
                BloomBoxGameBoxNewsWidget(onOpen: openGameBox, gameNames: gameNames)
                BloomBoxRemoteNewsSection()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .accessibilityIdentifier("bloombox.news.home")
    }
}

// Temporary source-compatibility shim only; all new calls use BloomBoxNewsPage.
typealias ManzanaDesktopView = BloomBoxNewsPage

/// Stable IDs are used for saved order/visibility, independent of translated labels.
enum BloomBoxNewsShortcut: String, CaseIterable, Identifiable {
    case apkStore, appStore, themes, modules, sideStore, files, ramPlus, settings

    var id: String { rawValue }

    func title(english: Bool) -> String {
        switch self {
        case .apkStore: return "APK Store"
        case .appStore: return "App Store"
        case .themes: return english ? "Themes" : "Temas"
        case .modules: return english ? "Modules" : "Módulos"
        case .sideStore: return "SideStore"
        case .files: return english ? "Files" : "Archivos"
        case .ramPlus: return "RAM+"
        case .settings: return english ? "Settings" : "Ajustes"
        }
    }

    var symbol: String {
        switch self {
        case .apkStore: return "cube"
        case .appStore: return "a"
        case .themes: return "paintpalette"
        case .modules: return "puzzlepiece"
        case .sideStore: return "square.and.arrow.down"
        case .files: return "folder"
        case .ramPlus: return "cpu"
        case .settings: return "gearshape"
        }
    }

    var tint: Color {
        switch self {
        case .apkStore: return Color(red: 0.51, green: 0.30, blue: 0.81)
        case .appStore: return Color(red: 0.19, green: 0.42, blue: 0.87)
        case .themes: return Color(red: 0.62, green: 0.26, blue: 0.88)
        case .modules: return Color(red: 0.91, green: 0.60, blue: 0.25)
        case .sideStore: return Color(red: 0.12, green: 0.66, blue: 0.82)
        case .files: return Color(red: 0.25, green: 0.67, blue: 0.45)
        case .ramPlus: return Color(red: 0.85, green: 0.29, blue: 0.48)
        case .settings: return Color(red: 0.39, green: 0.43, blue: 0.59)
        }
    }
}

/// News-page shortcuts never launch guests or touch JIT; the Home host
/// receives a typed destination and uses its existing navigation actions.
private struct BloomBoxNewsQuickAccess: View {
    let onOpen: (BloomBoxNewsShortcut) -> Void
    @AppStorage("BloomBoxNewsQuickAccessOrderV1", store: LCUtils.appGroupUserDefault)
    private var orderJSON = ""
    @AppStorage("BloomBoxNewsQuickAccessHiddenV1", store: LCUtils.appGroupUserDefault)
    private var hiddenJSON = "[]"
    @AppStorage("BloomBoxPreferredLanguage", store: LCUtils.appGroupUserDefault)
    private var language = "system"
    @State private var showCustomize = false

    private var english: Bool {
        (language == "system" ? Locale.preferredLanguages.first ?? "en" : language)
            .lowercased().hasPrefix("en")
    }
    private var ordered: [BloomBoxNewsShortcut] {
        let stored = (try? JSONDecoder().decode([String].self, from: Data(orderJSON.utf8))) ?? []
        var result: [BloomBoxNewsShortcut] = []
        for key in stored {
            if let item = BloomBoxNewsShortcut(rawValue: key), !result.contains(item) {
                result.append(item)
            }
        }
        for item in BloomBoxNewsShortcut.allCases where !result.contains(item) {
            result.append(item)
        }
        return result
    }
    private var hidden: Set<String> {
        Set((try? JSONDecoder().decode([String].self, from: Data(hiddenJSON.utf8))) ?? [])
    }
    private var visible: [BloomBoxNewsShortcut] {
        ordered.filter { !hidden.contains($0.rawValue) }
    }
    private func persistOrder(_ items: [BloomBoxNewsShortcut]) {
        guard let data = try? JSONEncoder().encode(items.map(\.rawValue)),
              let value = String(data: data, encoding: .utf8) else { return }
        orderJSON = value
    }
    private func setVisible(_ item: BloomBoxNewsShortcut, _ enabled: Bool) {
        var updated = hidden
        if enabled { updated.remove(item.rawValue) }
        else { updated.insert(item.rawValue) }
        guard let data = try? JSONEncoder().encode(updated.sorted()),
              let value = String(data: data, encoding: .utf8) else { return }
        hiddenJSON = value
    }
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 0), spacing: 9), count: 4)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                Image(systemName: "square.on.square")
                Text(english ? "BloomBox Apps" : "Aplicaciones de BloomBox")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                Button { showCustomize = true } label: {
                    HStack(spacing: 4) {
                        Text(english ? "Customize" : "Personalizar")
                        Image(systemName: "chevron.right").font(.caption2.weight(.semibold))
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.purple)
                }
                .accessibilityIdentifier("bloombox.news.shortcuts.customize")
            }
            if !visible.isEmpty {
                LazyVGrid(columns: columns, spacing: 11) {
                    ForEach(visible) { item in
                        Button { onOpen(item) } label: {
                            VStack(spacing: 5) {
                                BloomBoxNewsAppIcon(shortcut: item)
                                    .frame(width: 60, height: 60)
                                Text(item.title(english: english))
                                    .font(.system(size: 11, weight: .medium))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                                    .foregroundStyle(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("bloombox.news.shortcut." + item.id)
                        .accessibilityLabel(item.title(english: english))
                    }
                }
                .padding(11)
                .background(.ultraThinMaterial,
                            in: RoundedRectangle(cornerRadius: 23, style: .continuous))
            }
        }
        .sheet(isPresented: $showCustomize) {
            NavigationView {
                List {
                    Section {
                        ForEach(ordered) { item in
                            Toggle(isOn: Binding(
                                get: { !hidden.contains(item.rawValue) },
                                set: { setVisible(item, $0) }
                            )) {
                                Label(item.title(english: english), systemImage: item.symbol)
                            }
                        }
                        .onMove { from, to in
                            var items = ordered
                            items.move(fromOffsets: from, toOffset: to)
                            persistOrder(items)
                        }
                    } header: {
                        Text(english ? "Shortcuts · drag to reorder" : "Accesos · arrastra para ordenar")
                    } footer: {
                        Text(english ? "Changes only affect the News desktop." :
                             "Los cambios solo afectan al inicio de novedades.")
                    }
                    Section {
                        Button(english ? "Restore defaults" : "Restablecer accesos") {
                            orderJSON = ""
                            hiddenJSON = "[]"
                        }
                    }
                }
                .environment(\.editMode, .constant(.active))
                .navigationTitle(english ? "Quick Access" : "Accesos rápidos")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(english ? "Done" : "Listo") { showCustomize = false }
                    }
                }
            }
            .navigationViewStyle(.stack)
        }
    }
}

/// Store brand artwork is bundled locally for offline display.
/// SideStore is loaded from its actual embedded app bundle, not a guessed logo.
private struct BloomBoxNewsAppIcon: View {
    let shortcut: BloomBoxNewsShortcut
    private let radius: CGFloat = 15

    var body: some View {
        Group {
            switch shortcut {
            case .apkStore:
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.white)
                    .overlay {
                        if let icon = BloomBoxNewsBrandIcons.googlePlay {
                            Image(uiImage: icon)
                                .resizable()
                                .scaledToFit()
                                .padding(8)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.system(size: 29))
                                .foregroundStyle(.green)
                        }
                    }
            case .appStore:
                if let icon = BloomBoxNewsBrandIcons.appleAppStore {
                    Image(uiImage: icon)
                        .resizable()
                        .scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(shortcut.tint)
                        .overlay {
                            Image(systemName: "a")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                }
            case .sideStore:
                if let icon = LiveContainerHomeAdapter.builtInSignerIcon(dark: false) {
                    Image(uiImage: icon)
                        .resizable()
                        .scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(shortcut.tint)
                        .overlay {
                            Image(systemName: "square.stack.3d.up.fill")
                                .font(.system(size: 26, weight: .regular))
                                .foregroundStyle(.white)
                        }
                }
            default:
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(shortcut.tint)
                    .overlay {
                        Image(systemName: shortcut.symbol)
                            .font(.system(size: 27, weight: .regular))
                            .foregroundStyle(.white)
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .shadow(color: .black.opacity(0.11), radius: 2, x: 0, y: 1)
        .accessibilityHidden(true)
    }
}

/// News shortcut stays on iOS Home and makes GameBox visible even when
/// the optional floating control has been hidden. Only reads saved titles.
private struct BloomBoxGameBoxNewsWidget: View {
    let onOpen: () -> Void
    let gameNames: [String: String]

    @AppStorage(BloomBoxProfileStore.activeKey,
                store: LiveContainerPreferencesAdapter.defaults)
    private var activeProfileID = BloomBoxUserProfile.primaryID
    @AppStorage(BloomBoxProfileStore.profilesKey,
                store: LiveContainerPreferencesAdapter.defaults)
    private var profiles = Data()
    @AppStorage("BloomBoxPreferredLanguage",
                store: LiveContainerPreferencesAdapter.defaults)
    private var language = "system"
    @AppStorage("BloomBoxGameBoxV2Favorites",
                store: LiveContainerPreferencesAdapter.defaults)
    private var favoritesJSON = "[]"
    @AppStorage("BloomBoxGameBoxRecentRevisionV1",
                store: LiveContainerPreferencesAdapter.defaults)
    private var recentRevision = ""

    private var english: Bool {
        language == "en" || (language == "system" &&
            (Locale.preferredLanguages.first ?? "en").lowercased().hasPrefix("en"))
    }
    private var tint: Color {
        BloomBoxProfileTheme.color(activeID: activeProfileID, profilesData: profiles)
    }
    private var favorites: [String] {
        BloomBoxHomeAppPolicy.favorites(from: favoritesJSON)
            .compactMap { gameNames[$0] }
    }
    private var recentlyPlayed: [String] {
        _ = recentRevision // refresh when the game list changes
        return BloomBoxLaunchPreferences.recentGames(
            profileID: activeProfileID, defaults: LiveContainerPreferencesAdapter.defaults)
    }

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 21, weight: .medium))
                        .foregroundStyle(tint)
                        .frame(width: 42, height: 42)
                        .background(tint.opacity(0.13),
                                    in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("GameBox").font(.headline)
                        Text(english ? "Your games, one tap away" : "Tus juegos, a un toque")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(tint)
                }
                if recentlyPlayed.first != nil || !favorites.isEmpty {
                    HStack(spacing: 12) {
                        if let last = recentlyPlayed.first {
                            Label(last, systemImage: "clock.arrow.circlepath")
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityLabel((english ? "Recently played: " : "Último juego: ") + last)
                        }
                        if let first = favorites.first {
                            Label(first, systemImage: "star.fill")
                                .lineLimit(1)
                                .foregroundStyle(tint)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityLabel((english ? "Favorite: " : "Favorito: ") + first)
                        }
                    }
                    .font(.caption2)
                }
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: 23, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 23, style: .continuous)
                    .strokeBorder(tint.opacity(0.24), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("bloombox.news.gamebox")
        .accessibilityLabel(english ? "Open GameBox" : "Abrir GameBox")
    }
}

// MARK: - Read-only remote news. No HTML, scripts, or execution paths.
private struct BloomBoxNewsFeed: Decodable {
    let posts: [BloomBoxNewsPost]
}
private struct BloomBoxNewsPost: Decodable, Identifiable {
    let id: String
    let title: String
    let text: String
    let media: String?
}

private struct BloomBoxRemoteNewsSection: View {
    @AppStorage("BloomBoxNewsFeedURL", store: LCUtils.appGroupUserDefault)
    private var feedAddress = ""
    @AppStorage("BloomBoxPreferredLanguage", store: LCUtils.appGroupUserDefault)
    private var preferredLanguage = "system"
    private var english: Bool { (preferredLanguage == "system" ? (Locale.preferredLanguages.first ?? "en") : preferredLanguage).lowercased().hasPrefix("en") }
    private var defaultFeed: String { "https://raw.githubusercontent.com/AdriFOG/Bloombox-Remote-Systems/main/news/\(english ? "en" : "es").json" }
    // Earlier builds persisted the old built-in feed URL. Treat that legacy
    // default as automatic so upgrades use the AdriFOG remote catalog and its locale feeds.
    // Preserve any genuinely custom HTTPS news source selected by the user.
    private var activeFeed: String {
        let saved = feedAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let oldCatalogDefault = "https://raw.githubusercontent.com/adri23rep-stack/BloomBox-Catalog/main/news/"
        if saved.isEmpty || saved == "https://raw.githubusercontent.com/adri23rep-stack/BloomBox/feature/bloombox-2-ui-foundation-20261031/remote/news.json" || saved == "https://raw.githubusercontent.com/adri23rep-stack/BloomBox/main/remote/news.json" || saved == oldCatalogDefault + "es.json" || saved == oldCatalogDefault + "en.json" {
            return defaultFeed
        }
        return saved
    }
    @State private var posts: [BloomBoxNewsPost] = []
    @State private var loading = false
    @State private var error: String?
    @State private var editingFeed = false
    @State private var feedDraft = ""

    @State private var currentPostIndex = 0
    @State private var expandedPost: BloomBoxNewsPost?

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Label(english ? "BloomBox News" : "Novedades de BloomBox",
                      systemImage: "newspaper.fill")
                    .font(.headline)
                Spacer(minLength: 4)
                if posts.count > 1 {
                    Button {
                        currentPostIndex = (currentPostIndex + posts.count - 1) % posts.count
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .accessibilityLabel(english ? "Previous news" : "Noticia anterior")
                    Button {
                        currentPostIndex = (currentPostIndex + 1) % posts.count
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .accessibilityLabel(english ? "Next news" : "Siguiente noticia")
                }
                Button { Task { await refresh() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(loading)
                .accessibilityLabel(english ? "Refresh news" : "Actualizar novedades")
                Button { feedDraft = activeFeed; editingFeed = true } label: {
                    Image(systemName: "link")
                }
                .accessibilityLabel(english ? "Change news source" : "Cambiar fuente de noticias")
            }
            if loading && posts.isEmpty { ProgressView(english ? "Loading news…" : "Cargando novedades…") }
            if let error, posts.isEmpty {
                Text(error).font(.caption).foregroundStyle(.secondary)
            }
            if !posts.isEmpty {
                let post = posts[min(currentPostIndex, posts.count - 1)]
                Button { expandedPost = post } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(post.title)
                            .font(.headline)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(post.text)
                            .font(.subheadline)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let media = post.media, let url = URL(string: media),
                           url.scheme?.lowercased() == "https" {
                            BloomBoxRemoteNewsImage(url: url)
                                .frame(height: 118)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 13))
                        }
                        if posts.count > 1 {
                            HStack(spacing: 5) {
                                ForEach(0..<min(posts.count, 8), id: \.self) { index in
                                    Capsule()
                                        .fill(index == currentPostIndex ? Color.purple : Color.white.opacity(0.20))
                                        .frame(width: index == currentPostIndex ? 17 : 8, height: 4)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel(english
                                ? "News \(currentPostIndex + 1) of \(posts.count)"
                                : "Noticia \(currentPostIndex + 1) de \(posts.count)")
                        }
                    }
                    .padding(13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial,
                                in: RoundedRectangle(cornerRadius: 23, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("bloombox.news.article.preview")
                .accessibilityHint(english ? "Open full article" : "Abrir noticia completa")
            }
        }
        .task(id: activeFeed) { await refresh() }
        .sheet(item: $expandedPost) { post in
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(post.title).font(.title2.bold())
                        Text(post.text).font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let media = post.media, let url = URL(string: media),
                           url.scheme?.lowercased() == "https" {
                            BloomBoxRemoteNewsImage(url: url)
                                .frame(height: 260)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 15))
                        }
                    }
                    .padding()
                }
                .navigationTitle(english ? "News" : "Novedades")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(english ? "Done" : "Listo") { expandedPost = nil }
                    }
                }
            }
            .navigationViewStyle(.stack)
        }
        .alert("Fuente de novedades", isPresented: $editingFeed) {
            TextField("Enlace HTTPS a JSON", text: $feedDraft)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Guardar") {
                let input = feedDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let url = URL(string: input),
                      url.scheme?.lowercased() == "https" else {
                    error = "Usa un enlace HTTPS válido."
                    return
                }
                feedAddress = url.absoluteString
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Puedes modificar las noticias desde cualquier archivo JSON remoto, sin reinstalar BloomBox.")
        }
        .accessibilityIdentifier("bloombox.news.remote")
    }

    @MainActor private func refresh() async {
        guard let url = URL(string: activeFeed), url.scheme?.lowercased() == "https" else {
            error = "La fuente debe ser HTTPS."; return
        }
        loading = true
        defer { loading = false }
        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 15
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  data.count <= 256_000 else { throw BloomBoxMotionMedia.failure("La lista de noticias no está disponible.") }
            let decoded = try JSONDecoder().decode(BloomBoxNewsFeed.self, from: data)
            posts = Array(decoded.posts.prefix(12))
            currentPostIndex = min(currentPostIndex, max(0, posts.count - 1))
            error = nil
        } catch {
            self.error = english ? "Could not load news. Tap refresh to try again." : "No se pudieron cargar las noticias. Desliza o toca actualizar para intentar otra vez."
        }
    }
}

private struct BloomBoxRemoteNewsImage: View {
    let url: URL
    @State private var gifFile: URL?
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        Group {
            if url.pathExtension.lowercased() == "gif" {
                if let gifFile {
                    BloomBoxAnimatedWallpaper(url: gifFile, fit: false,
                                             paused: scenePhase != .active,
                                             clearBackground: true)
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .task(id: url) {
            gifFile = nil
            guard url.pathExtension.lowercased() == "gif",
                  BloomBoxNewsCachePolicy.isHTTPS(url) else { return }
            let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("BloomBoxNewsGIF", isDirectory: true)
            let filename = SHA256.hash(data: Data(url.absoluteString.utf8))
                .map { String(format: "%02x", $0) }.joined() + ".gif"
            let target = directory.appendingPathComponent(filename)
            var staging: URL?
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                if FileManager.default.fileExists(atPath: target.path) {
                    if (try? BloomBoxMotionMedia.gifFrames(target)) != nil {
                        gifFile = target
                    } else {
                        try? FileManager.default.removeItem(at: target)
                    }
                }
                let (data, response) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled, let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode),
                      data.count > 0, data.count <= 10 * 1_024 * 1_024 else { return }
                let temp = directory.appendingPathComponent(UUID().uuidString + ".gif")
                staging = temp
                try data.write(to: temp, options: .atomic)
                _ = try BloomBoxMotionMedia.gifFrames(temp)
                guard !Task.isCancelled else { try? FileManager.default.removeItem(at: temp); return }
                if FileManager.default.fileExists(atPath: target.path) {
                    try FileManager.default.removeItem(at: target)
                }
                try FileManager.default.moveItem(at: temp, to: target)
                staging = nil
                gifFile = target
                _ = try? BloomBoxNewsCachePolicy.prune(in: directory, keeping: target)
            } catch {
                if let staging { try? FileManager.default.removeItem(at: staging) }
                // A previously downloaded valid image remains visible offline.
            }
        }
    }
}

