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
    @AppStorage("BloomBoxTourStepV1", store: LCUtils.appGroupUserDefault) private var tourStep = 0
    @AppStorage("BloomBoxTourCompletedV1", store: LCUtils.appGroupUserDefault) private var tourCompleted = false
    @State private var tourVisible = false
    @State private var tourCenter = false
    @State private var tourResume = false
    @State private var tourAfterWizard = false
    @State private var tourProfiles = false
    @AppStorage("BloomBoxTourSeenTopicsV1", store: LCUtils.appGroupUserDefault) private var tourSeenTopics = ""
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
                    .environment(\.bloomBoxTourCollect, tourVisible && !tourCenter)
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
        .overlayPreferenceValue(BloomBoxTourAnchors.self) { anchors in
            tourLayer(anchors)
        }
        .fullScreenCover(isPresented: $showFirstRunWizard, onDismiss: {
            if tourAfterWizard && !showRecoveryNotice && !tourCompleted { tourVisible = true }
            tourAfterWizard = false
        }) {
            BloomBoxWizardFlowView(isPreview: false) {
                wizardCompleted = true
                tourAfterWizard = true
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
                        launcherOption(title: "Nova Launcher",
                                       detail: BloomBoxL10n.isEnglish ? "Android-style Home and app drawer with opaque surfaces." : "Escritorio Android y cajón de apps con superficies sólidas.",
                                       icon: "circle.grid.3x3.fill", value: "nova")
                        if #available(iOS 16.0, *) {
                            launcherOption(title: "GameBox v2", detail: BloomBoxL10n.t("Interfaz de consola con carátulas, fondos y cristal."),
                                           icon: "gamecontroller.fill", value: "gamebox")
                        }
                        Button {
                            tourCenter = true; tourVisible = true; tourResume = false; showModeSheet = false
                        } label: {
                            Label(BloomBoxL10n.isEnglish ? "Learning center" : "Centro de aprendizaje", systemImage: "graduationcap.fill")
                                .font(.headline).padding(20).frame(maxWidth: .infinity, alignment: .leading)
                                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 20))
                        }.buttonStyle(.plain)
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
        .sheet(isPresented: $tourProfiles) {
            NavigationView {
                BloomBoxProfileManagementView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(BloomBoxL10n.isEnglish ? "Done" : "Listo") { tourProfiles = false }
                        }
                    }
            }.navigationViewStyle(.stack)
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
                // Deliver the installer seed before the bundled SideStore starts.
                // No seed means a normal installation: no preferences are touched.
                let pairingStorage = BloomBoxJITPairingStorage(documentsDirectory: LCPath.docPath)
                let handoff = pairingStorage.handOffInstallerPairing()
                UserDefaults.standard.set(handoff.rawValue, forKey: "BloomBoxInstallerPairingHandoffStatus")
                if handoff == .delivered || handoff == .alreadyDelivered {
                    let anisette = pairingStorage.configureInstallerAnisette()
                    UserDefaults.standard.set(anisette.rawValue, forKey: "BloomBoxInstallerAnisetteStatus")
                }
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
            LCUtils.appGroupUserDefault.set(selection, forKey: BloomBoxLaunchPreferences.primaryKey)
            mode = BloomBoxLaunchPreferences.runtimeMode(for: selection)
            showProfileIntro(force: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: BloomBoxTourEvents.center)) { _ in
            guard wizardCompleted, !showRecoveryNotice else { return }
            tourCenter = true; tourVisible = true; tourResume = false
            showDestination = false; sharedModel.selectedTab = .apps
        }
        .onReceive(NotificationCenter.default.publisher(for: .GCControllerDidConnect)) { _ in
            routeConnectedControllerIfAllowed()
        }
    }

    private var currentTourTopic: BloomBoxTourTopic {
        let topics = BloomBoxTourTopic.all
        return topics[min(max(0, tourStep), topics.count - 1)]
    }

    private var canExploreTour: Bool {
        guard let destination = currentTourTopic.destination else { return false }
        return mode == "ios" || ["interface", "settings", "diagnostics", "profiles", "home"].contains(destination)
    }

    @ViewBuilder private func tourLayer(_ anchors: [String: [Anchor<CGRect>]]) -> some View {
        if ready && wizardCompleted && !showFirstRunWizard && !showRecoveryNotice &&
            !showDestination && !showModeSheet && !showDiagnostics && !tourProfiles {
            if tourVisible {
                BloomBoxTourOverlay(anchors: anchors, index: tourStep, center: tourCenter,
                    canExplore: canExploreTour, seenTopics: Set(tourSeenTopics.split(separator: ",").map(String.init)),
                    onSelect: { index in tourStep = index; tourCenter = false; tourCompleted = false },
                    onBack: { tourStep = max(0, tourStep - 1) },
                    onNext: {
                        rememberTourTopic(currentTourTopic.id)
                        UISelectionFeedbackGenerator().selectionChanged()
                        if tourStep >= BloomBoxTourTopic.all.count - 1 {
                            tourCompleted = true; tourVisible = false; tourResume = false
                        } else { tourStep = max(0, tourStep + 1) }
                    },
                    onPause: { tourVisible = false; tourResume = false },
                    onSkip: {
                        tourSeenTopics = BloomBoxTourTopic.all.map(\.id).joined(separator: ",")
                        tourCompleted = true; tourVisible = false; tourResume = false
                    },
                    onCenter: { tourCenter = true },
                    onExplore: exploreTour)
            } else if tourResume {
                VStack {
                    HStack(spacing: 8) {
                        Button {
                            tourVisible = true; tourCenter = false; tourResume = false
                        } label: {
                            Label(BloomBoxL10n.isEnglish ? "Continue guide" : "Continuar guía", systemImage: "graduationcap")
                                .font(.caption.weight(.semibold))
                        }
                        Button { tourResume = false } label: {
                            Image(systemName: "xmark.circle.fill").font(.subheadline)
                        }.accessibilityLabel(BloomBoxL10n.isEnglish ? "Hide guide" : "Ocultar guía")
                    }.buttonStyle(.plain).padding(11)
                        .background(.regularMaterial, in: Capsule())
                    Spacer()
                }.padding(.top, 8).frame(maxWidth: .infinity)
            }
        }
    }

    private func rememberTourTopic(_ id: String) {
        var seen = Set(tourSeenTopics.split(separator: ",").map(String.init))
        seen.insert(id)
        tourSeenTopics = seen.sorted().joined(separator: ",")
    }

    private func exploreTour() {
        guard canExploreTour, let destination = currentTourTopic.destination else { return }
        tourVisible = false; tourResume = true
        switch destination {
        case "interface": showModeSheet = true
        case "settings": sharedModel.selectedTab = .settings
        case "diagnostics": showDiagnostics = true
        case "gamebox": mode = "gamebox"
        case "home": mode = "ios"
        case "profiles": tourProfiles = true
        default:
            NotificationCenter.default.post(name: BloomBoxTourEvents.explore, object: destination)
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
              !showDestination, !showModeSheet, !tourVisible, mode != "gamebox",
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
