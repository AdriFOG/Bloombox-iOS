import SwiftUI

struct BloomBoxAppleAccountView: View {
    let accentHex: String
    let isPreview: Bool
    let onBack: (() -> Void)?
    let onNext: (() -> Void)?
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("BloomBoxPreferredLanguage", store: LiveContainerPreferencesAdapter.defaults) private var language = "system"
    @State private var state: BloomBoxAccountPolicy.State = .unknown
    @State private var busy = false
    @State private var failure: String?
    private var es: Bool { language == "es" || (language == "system" && (Locale.preferredLanguages.first ?? "en").hasPrefix("es")) }
    private func t(_ spanish: String, _ english: String) -> String { es ? spanish : english }
    private var tint: Color { BloomBoxWizardPalette.color(accentHex) }
    private var headline: String {
        switch state {
        case .saved: return t("Cuenta guardada", "Saved account")
        case .unavailable: return t("SideStore no incluido", "SideStore not included")
        case .incomplete: return t("Configuración pendiente", "Setup incomplete")
        case .unknown: return t("No se pudo comprobar la cuenta", "Account status unavailable")
        case .notLinked: return t("Sin cuenta vinculada", "No linked account")
        }
    }
    private var detail: String {
        switch state {
        case .saved: return t("SideStore conserva una sesión local. Se comprobará con Apple al usarla.", "SideStore has a saved local session. Apple will validate it when used.")
        case .unavailable: return t("Esta edición no incluye el motor de firma. Puedes seguir usando BloomBox.", "This edition has no bundled signing engine. You can continue using BloomBox.")
        case .incomplete: return t("Hay datos de cuenta, pero falta una sesión completa.", "Some account data exists, but the session is incomplete.")
        case .unknown: return t("Desbloquea el iPhone o abre SideStore para revisar la cuenta.", "Unlock your iPhone or open SideStore to check your account.")
        case .notLinked: return t("Inicia sesión para firmar aplicaciones, renovar firmas y solicitar RAM+.", "Sign in to install apps, refresh signatures and request RAM+.")
        }
    }

    var body: some View {
        ZStack {
            (scheme == .dark ? Color(red: 0.042, green: 0.045, blue: 0.063) : Color(red: 0.977, green: 0.973, blue: 0.985)).ignoresSafeArea()
            RadialGradient(colors: [tint.opacity(0.17), .clear], center: .topLeading, startRadius: 0, endRadius: 470)
                .ignoresSafeArea().allowsHitTesting(false)
            BloomBoxWizardAmbientSymbols(isDark: scheme == .dark, accentHex: accentHex)
                .ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
            ScrollView {
                VStack(spacing: 20) {
                    if onNext != nil {
                        HStack {
                            Label("BloomBox", systemImage: "sparkle").font(.headline)
                            Spacer()
                            Text("03 / 06").font(.caption.monospacedDigit())
                        }.foregroundStyle(.secondary)
                    }
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 74, weight: .light))
                        .foregroundStyle(tint)
                        .padding(.top, 24)
                    Text(t("Vincula tu cuenta Apple", "Link your Apple Account"))
                        .font(.system(size: 29, weight: .heavy, design: .rounded))
                        .multilineTextAlignment(.center)
                    Text(t("Una cuenta para las firmas de BloomBox y SideStore.", "One account for BloomBox and SideStore signing."))
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    VStack(alignment: .leading, spacing: 10) {
                        Label(headline, systemImage: state == .saved ? "checkmark.circle.fill" : "info.circle")
                            .font(.headline).foregroundStyle(state == .saved ? Color.green : tint)
                        Text(detail).font(.footnote).foregroundStyle(.secondary)
                    }
                    .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                    if state != .unavailable {
                        Button {
                            launch(mode: state == .saved || state == .unknown ? "manage" : "signin")
                        } label: {
                            Label(state == .saved || state == .unknown ? t("Administrar cuenta", "Manage account") : t("Iniciar sesión con Apple", "Sign in with Apple"), systemImage: "person.crop.circle")
                                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent).tint(tint).disabled(busy || isPreview)
                        .accessibilityIdentifier("bloombox.account.signin")
                        if state == .notLinked || state == .incomplete {
                            Button { launch(mode: "signin") } label: {
                                Label(t("Abrir login y reparar conexión", "Open login and repair connection"), systemImage: "arrow.clockwise")
                                    .font(.subheadline.weight(.medium))
                            }
                            .disabled(busy || isPreview)
                            .accessibilityIdentifier("bloombox.account.repair")
                        }
                        if busy { ProgressView(t("Abriendo autenticación de SideStore…", "Opening SideStore authentication…")) }
                        Text(t("El login original de SideStore conserva la verificación de dos pasos. BloomBox no solicita ni copia tu contraseña.", "SideStore’s original sign-in preserves two-factor authentication. BloomBox does not request or copy your password."))
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        Button(t("Comprobar cuenta", "Check account")) { reload() }
                            .font(.footnote).disabled(busy || isPreview)
                    }
                    if let failure { Text(failure).font(.footnote).foregroundStyle(.orange) }
                    if let onNext {
                        Button(action: onNext) {
                            Text(state == .saved || state == .unavailable ? t("Continuar", "Continue") : t("Configurar más tarde", "Set up later"))
                                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 9)
                        }.buttonStyle(.bordered).disabled(busy)
                        .accessibilityIdentifier("bloombox.wizard.account.continue")
                    }
                    if let onBack { Button(t("Atrás", "Back"), action: onBack).disabled(busy) }
                }.padding(25)
            }
        }
        .onAppear { reload() }
        .onChange(of: scenePhase) { phase in if phase == .active { reload() } }
    }
    @MainActor private func reload() {
        guard !isPreview else { state = .notLinked; return }
        state = BloomBoxAppleAccount.state()
    }
    @MainActor private func launch(mode: String) {
        guard !busy, !isPreview else { return }
        busy = true
        failure = nil
        Task { @MainActor in
            defer { busy = false; reload() }
            do { try await BloomBoxAppleAccount.open(mode: mode) }
            catch { failure = t("No se pudo abrir SideStore. Reintenta desde Ajustes.", "Could not open SideStore. Retry from Settings.") }
        }
    }
}
