import SwiftUI
import GameController
import UIKit

/// Reset only when the iOS process is relaunched, not when it resumes from
/// Files, the app switcher or SpringBoard.
private enum BloomBoxWelcomeLaunchSession {
    static var hasShownInitialGreeting = false
}

/// BloomBox's own mode host. LiveContainer stays mounted for guest/JIT/signing.
struct BloomBoxLauncherRootView: View {
    @EnvironmentObject private var sharedModel: SharedModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var introProfile: BloomBoxUserProfile?
    @State private var introSequence = 0
    @State private var lastIntroAt = Date.distantPast
    @AppStorage("LiveBoardMode", store: LCUtils.appGroupUserDefault) private var mode = "ios"
    @AppStorage(BloomBoxProfileStore.activeKey, store: LCUtils.appGroupUserDefault)
    private var activeProfileID = BloomBoxUserProfile.primaryID
    private var preferredExperience: String {
        BloomBoxLaunchPreferences.preferredMode(
            defaults: LCUtils.appGroupUserDefault, profileID: activeProfileID)
    }
    @AppStorage("BloomBoxPreferredLanguage", store: LCUtils.appGroupUserDefault) private var language = "system"
    @State private var ready = false
    @State private var showModeSheet = false
    @State private var showDestination = false
    @State private var showDiagnostics = false
    @State private var showRecoveryNotice = false
    @State private var showFirstRunWizard = false
    @AppStorage("BloomBoxWizardInitialCompletedV1", store: LCUtils.appGroupUserDefault)
    private var wizardCompleted = false
    @AppStorage("BloomBoxAutoGameBoxOnController", store: LCUtils.appGroupUserDefault)
    private var autoGameBoxOnController = true
    // Ask iOS to prioritize BloomBox's bottom-edge gestures. iOS controls
    // whether a second swipe is needed; never trap the user in the launcher.
    @AppStorage("BloomBoxDeferBottomSystemGestures", store: LCUtils.appGroupUserDefault)
    private var protectBottomGestures = true
    @AppStorage(BloomBoxLaunchPreferences.shortcutKey, store: LCUtils.appGroupUserDefault)
    private var showGameBoxShortcut = true

    private var locale: Locale {
        Locale(identifier: language == "system" ? (Locale.preferredLanguages.first ?? "en") : language)
    }

    var body: some View {
        if #available(iOS 16.0, *) {
            launcherContent
                .defersSystemGestures(on: protectBottomGestures ? .bottom : [])
        } else {
            launcherContent
        }
    }

    private var launcherContent: some View {
        Group {
            if ready {
                LCAppListView(openInterface: { showModeSheet = true })
                    .preferredColorScheme(.dark)
            } else {
                Color.black.ignoresSafeArea()
            }
        }
        .environment(\.locale, locale)
        .overlay(alignment: .top) {
            if let introProfile, wizardCompleted, !showFirstRunWizard {
                BloomBoxActiveProfileIntro(profile: introProfile) {
                    self.introProfile = nil
                }
                .id(introSequence)
                .padding(.top, 24)
                .zIndex(200)
                .allowsHitTesting(false)
                .transition(.opacity)
            }
        }
        .fullScreenCover(isPresented: $showFirstRunWizard) {
            BloomBoxWizardFlowView(isPreview: false) {
                wizardCompleted = true
                showFirstRunWizard = false
                mode = BloomBoxLaunchPreferences.runtimeMode(for: preferredExperience)
                showRecoveryNotice = BloomBoxCrashJournal.shared.previousInterrupted
                showProfileIntro()
            }
            .preferredColorScheme(BloomBoxWizardSystemAppearance.current)
        }
        .sheet(isPresented: $showModeSheet) {
            NavigationView {
                ScrollView {
                    VStack(spacing: 16) {
                        launcherOption(
                            title: BloomBoxL10n.isEnglish ? "Hybrid · Recommended" : "Híbrido · Recomendado",
                            detail: BloomBoxL10n.isEnglish ? "iOS Home; compatible games enter GameBox automatically." : "Escritorio iOS; los juegos compatibles entran automáticamente en GameBox.",
                            icon: "square.on.square", value: "hybrid")
                        launcherOption(title: "iOS Home", detail: BloomBoxL10n.t("Escritorio, apps y widgets."),
                                       icon: "square.grid.3x3.fill", value: "ios")
                        if #available(iOS 16.0, *) {
                            launcherOption(title: "GameBox v2", detail: BloomBoxL10n.t("Interfaz de consola con carátulas, fondos y cristal."),
                                           icon: "gamecontroller.fill", value: "gamebox")
                        }
                        NavigationLink(destination: BloomBoxDiagnosticsView()) {
                            Label("Diagnósticos y recuperación", systemImage: "waveform.path.ecg")
                                .font(.headline)
                                .padding(20)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 20))
                        }
                        .buttonStyle(.plain)
                        Toggle(isOn: $showGameBoxShortcut) {
                            Label(BloomBoxL10n.isEnglish ? "Show GameBox button on Home" : "Mostrar botón GameBox en el escritorio",
                                  systemImage: "gamecontroller.fill")
                        }
                        .tint(.cyan)
                        .padding(16)
                        .background(Color.white.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 16))
                        Toggle(isOn: $protectBottomGestures) {
                            Label(BloomBoxL10n.isEnglish ? "Protect bottom-edge gestures" : "Proteger gestos del borde inferior",
                                  systemImage: "hand.draw.fill")
                        }
                        .tint(.cyan)
                        .padding(16)
                        .background(Color.white.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 16))
                        Text(BloomBoxL10n.isEnglish
                             ? "Reduces accidental exits while using BloomBox. iOS may require a second swipe to go Home. You can turn this off anytime."
                             : "Evita salidas accidentales del launcher. iOS puede pedir un segundo deslizamiento para ir al inicio. Puedes desactivarlo cuando quieras.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Toggle(isOn: $autoGameBoxOnController) {
                            Label(BloomBoxL10n.t("Abrir GameBox al conectar un control"), systemImage: "gamecontroller.fill")
                        }
                        .tint(.cyan)
                        .padding(16)
                        .background(Color.white.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 16))
                        Text(BloomBoxL10n.t("La detección funciona al usar BloomBox. iOS no permite abrirla desde cero cuando está cerrada o suspendida."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(BloomBoxL10n.isEnglish ? "Your choice is saved per profile. Existing profiles keep their iOS Home setting until you change it." : "Tu selección se guarda por perfil. Los perfiles existentes conservan su inicio iOS hasta que lo cambies.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }
                .navigationTitle(BloomBoxL10n.isEnglish ? "Interface" : "Interfaz")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(BloomBoxL10n.isEnglish ? "Done" : "Listo") { showModeSheet = false }
                    }
                }
            }
            .navigationViewStyle(.stack)
            .environment(\.locale, locale)
        }
        .sheet(isPresented: $showDestination, onDismiss: {
            sharedModel.selectedTab = .apps
        }) {
            VStack(spacing: 0) {
                HStack { Spacer(); Button(BloomBoxL10n.isEnglish ? "Done" : "Listo") { showDestination = false }.padding() }
                destinationContent
            }
        }
        .sheet(isPresented: $showDiagnostics) {
            NavigationView {
                BloomBoxDiagnosticsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(BloomBoxL10n.t("Listo")) { showDiagnostics = false }
                        }
                    }
            }
            .navigationViewStyle(.stack)
        }
        .alert(BloomBoxL10n.t("GameBox recuperado"), isPresented: $showRecoveryNotice) {
            Button(BloomBoxL10n.t("Ver registro")) { showDiagnostics = true }
            Button(BloomBoxL10n.t("Seguir en inicio"), role: .cancel) { }
        } message: {
            Text(BloomBoxL10n.t("La sesión anterior terminó mientras GameBox estaba abierto. BloomBox inició en el escritorio para evitar un ciclo de cierres. Guardamos los últimos pasos para investigar."))
        }
        .onChange(of: sharedModel.selectedTab) { tab in
            if tab == .apps {
                showDestination = false
            } else {
                showDestination = true
            }
        }
        .onAppear {
            if !BloomBoxLauncherSession.restored {
                mode = BloomBoxLaunchPreferences.resetForNewProcess(
                    defaults: LCUtils.appGroupUserDefault, profileID: activeProfileID)
                BloomBoxLauncherSession.restored = true
            }
            ready = true
            if !wizardCompleted {
                showFirstRunWizard = true
            } else {
                showRecoveryNotice = BloomBoxCrashJournal.shared.previousInterrupted
                routeConnectedControllerIfAllowed()
                showProfileIntro()
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                // Covers cold launches where onAppear ran before activation.
                // The process guard prevents repeats after minimizing.
                showProfileIntro()
            } else if phase == .background {
                introProfile = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: BloomBoxProfileStore.didActivate)) { note in
            // Resolve the ID from the notification itself. AppStorage can
            // re-render one frame later, especially when switching in GameBox.
            let id = (note.object as? String) ?? BloomBoxProfileStore.active.id
            let selection = BloomBoxLaunchPreferences.preferredMode(
                defaults: LCUtils.appGroupUserDefault, profileID: id)
            mode = BloomBoxLaunchPreferences.runtimeMode(for: selection)
            showProfileIntro(force: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .GCControllerDidConnect)) { _ in
            routeConnectedControllerIfAllowed()
        }
    }

    private func showProfileIntro(force: Bool = false) {
        guard ready, wizardCompleted, !showFirstRunWizard, !showRecoveryNotice,
              !showDestination, !showModeSheet,
              UIApplication.shared.applicationState == .active else { return }
        // Once per real process launch. Profile switches explicitly force their
        // own greeting; reopening the existing process never does.
        if !force {
            guard !BloomBoxWelcomeLaunchSession.hasShownInitialGreeting else { return }
            BloomBoxWelcomeLaunchSession.hasShownInitialGreeting = true
        }
        lastIntroAt = Date()
        introSequence += 1
        introProfile = BloomBoxProfileStore.active
    }

    private func routeConnectedControllerIfAllowed() {
        // Do not relaunch an interrupted GameBox session or steal focus from a guest.
        guard autoGameBoxOnController, ready, wizardCompleted,
              !showFirstRunWizard, !showRecoveryNotice,
              !showDestination, !showModeSheet, mode != "gamebox",
              UIApplication.shared.applicationState == .active,
              !GCController.controllers().isEmpty else { return }
        mode = "gamebox"
        BloomBoxCrashJournal.shared.record("gamebox.controller.auto_enter")
    }

    @ViewBuilder private var destinationContent: some View {
        switch sharedModel.selectedTab {
        case .apps: EmptyView()
        case .settings: LCSettingsView()
        case .sources: LCSourcesView()
        case .tweaks: LCTweaksView()
        }
    }

    private func launcherOption(title: String, detail: String, icon: String, value: String) -> some View {
        Button {
            BloomBoxLaunchPreferences.setPreferredMode(
                value, profileID: activeProfileID,
                defaults: LCUtils.appGroupUserDefault)
            mode = BloomBoxLaunchPreferences.runtimeMode(for: value)
            showModeSheet = false
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon).font(.title).frame(width: 48)
                VStack(alignment: .leading, spacing: 6) {
                    Text(BloomBoxGameBoxL10n.t(title)).font(.headline)
                    Text(BloomBoxGameBoxL10n.t(detail)).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: preferredExperience == value ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(.blue)
            }
            .padding(20)
            .background(Color.white.opacity(preferredExperience == value ? 0.12 : 0.05),
                        in: RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(preferredExperience == value ? .isSelected : [])
    }
}

@MainActor private enum BloomBoxLauncherSession {
    static var restored = false
}

// Source compatibility for the existing LiveContainer host.
typealias LiveBoardRootView = BloomBoxLauncherRootView


// MARK: - BloomBox Media (LiveContainer2-derived independent instance)
//
// This edition is emitted by LiveContainer's existing clone packager; the
// primary BloomBox build remains completely unchanged. Guest storage is
// inherited from the same signed App Group as the primary instance.
enum BloomBoxMediaBuild {
    static var isEnabled: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "BloomBoxMediaEdition") as? Bool) == true
    }
}

/// Strict recognition: only known media apps are shown in the Media edition.
/// A generic installed game must never surface here or be launched as media.
enum BloomBoxMediaCatalog {
    enum Kind: String, CaseIterable, Identifiable {
        case video
        case music

        var id: String { rawValue }
        var symbol: String { self == .video ? "play.rectangle.fill" : "music.note" }
    }

    static func kind(for app: LCAppModel) -> Kind? {
        guard app.uiIsShared else { return nil }
        let bundle = app.bundleIdentifier.lowercased()
        let name = app.displayName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let musicIDs: Set<String> = [
            "com.google.ios.youtubemusic", "com.spotify.client",
            "com.amazon.mp3", "com.soundcloud.touchapp", "com.deezer.deezer",
            "com.tidal", "com.apple.music"
        ]
        let videoIDs: Set<String> = [
            "com.google.ios.youtube", "com.netflix.netflix",
            "com.amazon.aiv", "com.twitch.twitch", "tv.twitch",
            "org.videolan.vlc-ios", "com.plexapp.plex",
            "com.firecore.infuse", "com.disney.disneyplus"
        ]
        if musicIDs.contains(bundle) { return .music }
        if videoIDs.contains(bundle) { return .video }

        let musicNames: Set<String> = [
            "youtube music", "spotify", "apple music", "amazon music",
            "soundcloud", "deezer", "tidal"
        ]
        let videoNames: Set<String> = [
            "youtube", "netflix", "prime video", "twitch", "vlc",
            "plex", "infuse", "disney+", "disney plus"
        ]
        if musicNames.contains(name) { return .music }
        if videoNames.contains(name) { return .video }
        return nil
    }
}

struct BloomBoxMediaHome: View {
    let apps: [LCAppModel]
    let launch: (LCAppModel) -> Void

    @AppStorage("BloomBoxPreferredLanguage", store: LCUtils.appGroupUserDefault)
    private var preferredLanguage = "system"
    @State private var searchText = ""

    private var english: Bool {
        preferredLanguage == "en" ||
        (preferredLanguage == "system" &&
         !(Locale.preferredLanguages.first ?? "es").lowercased().hasPrefix("es"))
    }

    private var visibleApps: [LCAppModel] {
        apps.filter { BloomBoxMediaCatalog.kind(for: $0) != nil }
            .filter {
                searchText.isEmpty ||
                $0.displayName.localizedCaseInsensitiveContains(searchText)
            }
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    var body: some View {
        ZStack {
            Color(red: 0.055, green: 0.06, blue: 0.10).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 14) {
                        Image(systemName: "play.rectangle.on.rectangle.fill")
                            .font(.system(size: 29, weight: .semibold))
                            .foregroundStyle(.purple)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("BloomBox Media")
                                .font(.system(size: 29, weight: .bold))
                            Text(english ? "Your media, all in one place" : "Tu contenido, en un solo lugar")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 20)

                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField(english ? "Search media apps" : "Buscar apps multimedia", text: $searchText)
                            .autocorrectionDisabled()
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.07),
                                in: RoundedRectangle(cornerRadius: 16))

                    if visibleApps.isEmpty {
                        VStack(spacing: 14) {
                            Image(systemName: "rectangle.stack.badge.play")
                                .font(.system(size: 46))
                                .foregroundStyle(.purple)
                            Text(english ? "No shared media apps yet" : "Aún no hay apps multimedia compartidas")
                                .font(.headline)
                                .multilineTextAlignment(.center)
                            Text(english
                                ? "In BloomBox, open YouTube or YouTube Music settings and select Convert to Shared App. Then reopen BloomBox Media."
                                : "En BloomBox, entra a los ajustes de YouTube o YouTube Music y elige Convertir en app compartida. Después vuelve a abrir BloomBox Media.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(25)
                        .background(Color.white.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 20))
                    }

                    ForEach(BloomBoxMediaCatalog.Kind.allCases) { kind in
                        let matching = visibleApps.filter { BloomBoxMediaCatalog.kind(for: $0) == kind }
                        if !matching.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Label(kind == .music
                                      ? (english ? "Music" : "Música")
                                      : (english ? "Video" : "Video"),
                                      systemImage: kind.symbol)
                                    .font(.headline)
                                ForEach(matching, id: \.self) { app in
                                    Button { launch(app) } label: {
                                        HStack(spacing: 14) {
                                            Image(systemName: kind.symbol)
                                                .font(.title2)
                                                .frame(width: 44, height: 44)
                                                .background(Color.purple.opacity(0.20),
                                                            in: RoundedRectangle(cornerRadius: 13))
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(app.displayName)
                                                    .font(.headline)
                                                Text(english ? "Shared app" : "App compartida")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Image(systemName: "play.fill").foregroundStyle(.secondary)
                                        }
                                        .padding(14)
                                        .background(Color.white.opacity(0.065),
                                                    in: RoundedRectangle(cornerRadius: 18))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    Text(english
                         ? "BloomBox Media shows compatible shared media apps only. Games are never listed here."
                         : "BloomBox Media solo muestra apps multimedia compartidas compatibles. Los juegos no aparecen aquí.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 20)
                }
                .padding(.horizontal, 20)
            }
        }
        .foregroundStyle(.white)
    }
}
