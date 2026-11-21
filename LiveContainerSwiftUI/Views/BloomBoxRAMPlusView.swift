import SwiftUI
import CryptoKit
import UniformTypeIdentifiers

@MainActor
final class BloomBoxRAMPlus: ObservableObject {
    static let shared = BloomBoxRAMPlus()
    private let defaults = LCUtils.appGroupUserDefault
    private let key = "BloomBoxRAMPlusRequested"
    @Published private(set) var requested = false
    @Published private(set) var validation = BloomBoxRAMValidation.inspect(runtime: nil, profile: nil, applicationIdentifier: nil)
    @Published private(set) var extensionSigned: Bool?
    @Published private(set) var available: UInt64 = 0
    @Published private(set) var checkedAt: Date?
    @Published private(set) var applicationIdentifier = ""
    @Published private(set) var activationStatus = ""
    @Published private(set) var activationMessage = ""
    private let reinstallKey = "BloomBoxRAMReinstall"
    private let experimentalControlsKey = "BloomBoxRAMPlusExperimentalControls"
    private var experimentalControlsEnabled: Bool { defaults.bool(forKey: experimentalControlsKey) }
    private var experimentalReinstall: Bool {
        experimentalControlsEnabled &&
        (defaults.dictionary(forKey: reinstallKey)?["experimental"] as? Bool == true)
    }
    @Published private(set) var reinstallStage = ""
    @Published private(set) var reinstallMessage = ""
    @Published private(set) var preparedIPA: URL?
    @Published private(set) var reinstallBusy = false
    var activationPending: Bool { ["awaitingSession", "checking", "requesting"].contains(activationStatus) }

    func requestActivation() throws {
        guard !activationPending else { return }
        guard let signature = Self.signature(Bundle.main.executablePath),
              let team = signature["com.apple.developer.team-identifier"] as? String, !team.isEmpty,
              let appIdentifier = signature["application-identifier"] as? String,
              let bundle = Bundle.main.bundleIdentifier,
              appIdentifier.hasSuffix("." + bundle),
              Bundle.main.privateFrameworksURL.map({ FileManager.default.fileExists(atPath: $0.appendingPathComponent("SideStoreApp.framework").path) }) == true else {
            throw NSError(domain: "BloomBoxRAM", code: 1, userInfo: [NSLocalizedDescriptionKey: "No se pudo identificar la cuenta de firma o falta el SideStore integrado. Reinstala la edición con SideStore."])
        }
        var bundles = [bundle]
        if let url = Bundle.main.builtInPlugInsURL?.appendingPathComponent("LiveProcess.appex"),
           let extensionBundle = Bundle(url: url), let extensionID = extensionBundle.bundleIdentifier,
           extensionID != bundle, extensionID.hasPrefix(bundle + "."),
           let extensionSignature = Self.signature(extensionBundle.executablePath),
           extensionSignature["com.apple.developer.team-identifier"] as? String == team {
            bundles.append(extensionID)
        }
        let id = UUID().uuidString
        defaults.set(true, forKey: key)
        defaults.set(["id": id, "team": team, "bundles": bundles, "expires": Date().addingTimeInterval(300)], forKey: "BloomBoxRAMPlusRequest")
        defaults.set(["id": id, "status": "awaitingSession", "message": "Abre Mis apps en SideStore. Se usará su sesión para solicitar RAM+; si te pide iniciar sesión, hazlo allí.", "date": Date()], forKey: "BloomBoxRAMPlusResult")
        defaults.removeObject(forKey: reinstallKey)
        defaults.synchronize()
        refresh()
    }

    func cancelActivation() {
        defaults.removeObject(forKey: "BloomBoxRAMPlusRequest")
        defaults.set(["status": "cancelled", "message": "Solicitud cancelada. Si ya se envió a Apple, el permiso podría haberse aplicado; vuelve a comprobar antes de repetirla.", "date": Date()], forKey: "BloomBoxRAMPlusResult")
        defaults.synchronize()
        refresh()
    }

    var needsAttention: Bool { requested && !validation.confirmed }
    var status: String {
        if validation.confirmed { return "RAM+ confirmado en la instalación actual" }
        if validation.profileGranted == true && validation.runtimeGranted != true {
            return "El perfil tiene RAM+, pero la firma instalada no lo confirma"
        }
        if validation.runtimeGranted == true { return "Firma con RAM+; perfil sin confirmar" }
        if activationStatus == "approved" { return "Apple aprobó RAM+; falta reinstalar BloomBox" }
        if activationPending { return "Esperando confirmación de Apple" }
        return requested ? "RAM+ solicitado, aún sin confirmar" : "Permiso no confirmado"
    }

    func setRequested(_ enabled: Bool) {
        defaults.set(enabled, forKey: key)
        if !enabled && activationPending { cancelActivation() }
        refresh()
    }

    func refresh() {
        requested = defaults.bool(forKey: key)
        if let plan = defaults.dictionary(forKey: "BloomBoxRAMPlusRequest"),
           let expiry = plan["expires"] as? Date, expiry <= Date(),
           let result = defaults.dictionary(forKey: "BloomBoxRAMPlusResult"),
           let status = result["status"] as? String, ["awaitingSession", "checking", "requesting"].contains(status) {
            defaults.removeObject(forKey: "BloomBoxRAMPlusRequest")
            defaults.set(["status": "expired", "message": "La solicitud venció. Si llegó a enviarse a Apple, su resultado no está confirmado. Puedes iniciar una nueva comprobación.", "date": Date()], forKey: "BloomBoxRAMPlusResult")
        }
        let result = defaults.dictionary(forKey: "BloomBoxRAMPlusResult")
        activationStatus = result?["status"] as? String ?? ""
        activationMessage = result?["message"] as? String ?? ""
        let saved = defaults.dictionary(forKey: reinstallKey) ?? [:]
        reinstallStage = saved["stage"] as? String ?? ""
        reinstallMessage = saved["message"] as? String ?? ""
        if let path = saved["path"] as? String, FileManager.default.fileExists(atPath: path) {
            preparedIPA = URL(fileURLWithPath: path)
        } else { preparedIPA = nil }
        let signed = Self.signature(Bundle.main.executablePath)
        applicationIdentifier = signed?["application-identifier"] as? String ?? ""
        let profileURL = Bundle.main.bundleURL.appendingPathComponent("embedded.mobileprovision")
        let profile = (try? Data(contentsOf: profileURL)).flatMap(BloomBoxRAMValidation.profile)
        validation = .inspect(runtime: LCUtils.bloomBoxMemoryEntitlement()?.boolValue,
                              profile: profile,
                              applicationIdentifier: applicationIdentifier.isEmpty ? nil : applicationIdentifier)
        let extensionPath = Bundle.main.builtInPlugInsURL?.appendingPathComponent("LiveProcess.appex")
        let extensionBundle = extensionPath.flatMap { Bundle(url: $0) }
        extensionSigned = BloomBoxRAMValidation.boolean(Self.signature(extensionBundle?.executablePath)?[BloomBoxRAMValidation.entitlement])
        available = LCUtils.bloomBoxAvailableMemory()
        checkedAt = Date()
        if validation.confirmed && reinstallStage != "confirmed" && !experimentalReinstall {
            saveReinstall("confirmed", "RAM+ está activa en esta instalación.")
        } else if reinstallStage == "installing" {
            saveReinstall("verifying", "SideStore recibió la solicitud. Cuando termine, vuelve a abrir BloomBox para comprobar la firma.")
        }
    }

    private func saveReinstall(_ stage: String, _ message: String, path: URL? = nil) {
        var value = defaults.dictionary(forKey: reinstallKey) ?? [:]
        value["stage"] = stage
        value["message"] = message
        value["date"] = Date()
        if let path { value["path"] = path.path }
        else if ["checking", "review", "chooseIPA"].contains(stage) {
            value.removeValue(forKey: "path")
        }
        defaults.set(value, forKey: reinstallKey)
        reinstallStage = stage
        reinstallMessage = message
        preparedIPA = (value["path"] as? String).map { URL(fileURLWithPath: $0) }
    }


    private func prepareIPA(_ source: URL, digest: String?) throws -> URL {
        let fm = FileManager.default
        let dir = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BloomBoxRAMPlus", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let temporary = dir.appendingPathComponent(UUID().uuidString + ".ipa")
        try fm.copyItem(at: source, to: temporary)
        defer { try? fm.removeItem(at: temporary) }
        let handle = try FileHandle(forReadingFrom: temporary)
        defer { try? handle.close() }
        var hash = SHA256()
        while true {
            let data = handle.readData(ofLength: 1024 * 1024)
            if data.isEmpty { break }
            hash.update(data: data)
        }
        let sha = hash.finalize().map { String(format: "%02x", $0) }.joined()
        if let digest, sha.lowercased() != digest.lowercased() {
            throw NSError(domain: "BloomBoxRAM", code: 1, userInfo: [NSLocalizedDescriptionKey: "El SHA-256 descargado no coincide con el publicado."])
        }
        let ipa = try BloomBoxArchive.inspectIPA(temporary)
        guard let bundle = ipa["bundle"] as? String,
              let version = ipa["version"] as? String,
              let build = ipa["build"] as? String else {
            throw NSError(domain: "BloomBoxRAM", code: 2, userInfo: [NSLocalizedDescriptionKey: "No se pudo verificar la estructura de la IPA."])
        }
        let installedID = Bundle.main.bundleIdentifier ?? ""
        let installedExtensions = Set(((try? fm.contentsOfDirectory(atPath: Bundle.main.builtInPlugInsURL?.path ?? "")) ?? []).filter { $0.hasSuffix(".appex") })
        let ipaExtensions = Set(ipa["extensions"] as? [String] ?? [])
        // The published release may have a different version/build/commit.
        // The app's internal version is inherited from LiveContainer (3.8.10)
        // and does NOT match BloomBox's public tag (v1.3.0).
        // SideStore reassigns Apple App Groups during signing; exact equality
        // with the *unsigned* IPA is not meaningful and previously blocked updates.
        guard BloomBoxRAMRelease.compatibleIdentity(installed: installedID, sourceBundle: bundle),
              !version.isEmpty, !build.isEmpty,
              BloomBoxRAMRelease.preservesExtensions(installed: installedExtensions, candidate: ipaExtensions) else {
            throw NSError(domain: "BloomBoxRAM", code: 3, userInfo: [NSLocalizedDescriptionKey: "La IPA no conserva la identidad o las extensiones instaladas. No se instalará."])
        }
        let destination = dir.appendingPathComponent("BloomBox-validada.ipa")
        if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
        try fm.moveItem(at: temporary, to: destination)
        var state = defaults.dictionary(forKey: reinstallKey) ?? [:]
        state["sha256"] = sha
        state["version"] = version
        state["build"] = build
        defaults.set(state, forKey: reinstallKey)
        return destination
    }


    /// Uses the newest PUBLIC stable BloomBox release, never an Actions artifact
    /// or a release selected using upstream LiveContainer's internal version.
    /// A different commit needs an explicit second confirmation before downloading.
    func resumeAfterAppleApproval(confirmDifferentBuild: Bool = false) async {
        let testing = validation.confirmed && experimentalReinstall
        guard !reinstallBusy, (!validation.confirmed || testing), (requested || testing),
              (activationStatus == "approved" || testing),
              (reinstallStage.isEmpty || ["approved", "review", "chooseIPA"].contains(reinstallStage)) else { return }
        reinstallBusy = true
        defer { reinstallBusy = false }
        saveReinstall("checking", "Buscando la release estable más reciente de BloomBox…")
        do {
            var req = URLRequest(url: BloomBoxRAMRelease.latestAPI)
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            req.timeoutInterval = 25
            let (body, response) = try await URLSession.shared.data(for: req)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw NSError(domain: "BloomBoxRAM", code: 5, userInfo: [NSLocalizedDescriptionKey: "No se pudo consultar la última release oficial de GitHub. Revisa Internet y reintenta."])
            }
            let asset = try BloomBoxRAMRelease.select(json: body)
            let installedCommit = Bundle.main.object(forInfoDictionaryKey: "BloomBoxBuildCommit") as? String ?? ""
            // Comparing to the release commit is only informational here:
            // downloaded IPA contents are independently checked against GitHub's SHA.
            let releaseCommit = asset.commitish ?? ""
            if !confirmDifferentBuild && (releaseCommit.isEmpty || installedCommit != releaseCommit) {
                var state = defaults.dictionary(forKey: reinstallKey) ?? [:]
                state["reviewTag"] = asset.tag
                state["reviewDigest"] = asset.digest
                defaults.set(state, forKey: reinstallKey)
                saveReinstall("review", "Última versión oficial: \(asset.tag). Tu instalación tiene otra compilación (posiblemente JIT experimental). Instalar esta release podría reemplazar funciones experimentales. Revisa y confirma si quieres continuar.")
                return
            }
            if confirmDifferentBuild {
                let confirmed = defaults.dictionary(forKey: reinstallKey) ?? [:]
                guard confirmed["reviewTag"] as? String == asset.tag,
                      confirmed["reviewDigest"] as? String == asset.digest else {
                    saveReinstall("review", "La release más reciente cambió desde tu confirmación. Vuelve a revisar antes de instalar.")
                    var state = defaults.dictionary(forKey: reinstallKey) ?? [:]
                    state["reviewTag"] = asset.tag
                    state["reviewDigest"] = asset.digest
                    defaults.set(state, forKey: reinstallKey)
                    return
                }
            }
            saveReinstall("downloading", "Descargando BloomBox \(asset.tag) desde GitHub…")
            let (download, result) = try await URLSession.shared.download(from: asset.url)
            guard (result as? HTTPURLResponse)?.statusCode == 200 else {
                throw NSError(domain: "BloomBoxRAM", code: 6, userInfo: [NSLocalizedDescriptionKey: "No se pudo descargar la última IPA desde GitHub."])
            }
            let fileSize = (try FileManager.default.attributesOfItem(atPath: download.path)[.size] as? NSNumber)?.int64Value ?? -1
            guard fileSize == asset.size else {
                throw NSError(domain: "BloomBoxRAM", code: 6, userInfo: [NSLocalizedDescriptionKey: "El tamaño descargado no coincide con la release oficial. No se instalará."])
            }
            saveReinstall("preparing", "Verificando SHA-256, identidad y extensiones de BloomBox \(asset.tag)…")
            // The published v1.3.0 IPA has no stable BloomBoxBuildCommit.
            // The official release-asset SHA-256 is the integrity check.
            let local = try prepareIPA(download, digest: asset.digest)
            var saved = defaults.dictionary(forKey: reinstallKey) ?? [:]
            saved["releaseTag"] = asset.tag
            defaults.set(saved, forKey: reinstallKey)
            saveReinstall("preparing", "BloomBox \(asset.tag) validada. Preparando la actualización con SideStore…", path: local)
            // SideStore's documented remote URL scheme will fetch the official asset
            // again. Its final signed entitlement is always checked after install.
            var link = URLComponents()
            link.scheme = "sidestore"
            link.host = "install"
            link.queryItems = [URLQueryItem(name: "url", value: asset.url.absoluteString)]
            guard let deeplink = link.url else {
                throw NSError(domain: "BloomBoxRAM", code: 7, userInfo: [NSLocalizedDescriptionKey: "No se pudo preparar el enlace de SideStore."])
            }
            saveReinstall("installing", "SideStore instalará BloomBox \(asset.tag) encima de esta app. Conserva extensiones y datos. RAM+ se comprobará después de firmar.")
            UIApplication.shared.open(deeplink, options: [:]) { opened in
                if !opened {
                    Task { @MainActor in
                        self.saveReinstall("failed", "SideStore no pudo abrir la instalación. Comparte la IPA validada o reintenta.")
                    }
                }
            }
        } catch {
            saveReinstall("failed", error.localizedDescription + " No se reemplazó BloomBox.")
        }
    }

    func importIPA(_ source: URL) async {
        let testing = validation.confirmed && experimentalReinstall
        guard !reinstallBusy, (activationStatus == "approved" && !validation.confirmed) || testing else { return }
        reinstallBusy = true
        defer { reinstallBusy = false }
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        do {
            guard source.pathExtension.lowercased() == "ipa" else {
                throw NSError(domain: "BloomBoxRAM", code: 4, userInfo: [NSLocalizedDescriptionKey: "Elige un archivo .ipa."])
            }
            saveReinstall("checking", "Comprobando la IPA seleccionada…")
            let checked = try prepareIPA(source, digest: nil)
            saveReinstall("manualReady", "IPA compatible. El origen del archivo no está autenticado: compártelo con SideStore, instala encima sin borrar la app y conserva las extensiones.", path: checked)
        } catch { saveReinstall("chooseIPA", error.localizedDescription) }
    }

    func retryReinstall() {
        let testing = validation.confirmed && experimentalReinstall
        guard !reinstallBusy, (activationStatus == "approved" && !validation.confirmed) || testing else { return }
        saveReinstall("approved", "Buscando de nuevo la última release estable de BloomBox.")
    }

    /// Reopens the existing reinstall controls only. No Apple request, signing,
    /// SideStore launch or file change occurs until the user chooses an action.
    func startExperimentalReinstall() {
        guard validation.confirmed, experimentalControlsEnabled, !reinstallBusy else { return }
        var state = defaults.dictionary(forKey: reinstallKey) ?? [:]
        state["experimental"] = true
        defaults.set(state, forKey: reinstallKey)
        saveReinstall("approved", "Prueba experimental: RAM+ ya está activa. Se comprobará la última release estable, sin repetir la solicitud a Apple.")
    }

    private static func signature(_ path: String?) -> [String: Any]? {
        guard let path, let xml = getExecutableEntitlementXML(path), let data = xml.data(using: .utf8) else { return nil }
        return (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any]
    }
}

struct BloomBoxRAMPlusView: View {
    let openSideStore: () -> Void
    @ObservedObject private var ram = BloomBoxRAMPlus.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var activationError: String?
    @State private var chooseOriginalIPA = false
    @State private var externalInstallLogs: [String] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("BloomBoxRAMPlusExperimentalControls", store: LCUtils.appGroupUserDefault)
    private var experimentalControlsEnabled = false
    private let statusTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Memoria ampliada", systemImage: "cpu")
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                    Text("Elige un método para solicitar RAM+. El permiso se aplica al volver a firmar e instalar BloomBox.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 10)

                ramActionTile(
                    title: ram.validation.confirmed ? "RAM+ activa" : "Activar RAM+",
                    subtitle: "Método BloomBox recomendado",
                    symbol: ram.validation.confirmed ? "checkmark.seal.fill" : "bolt.fill",
                    tint: Color(red: 0.10, green: 0.80, blue: 0.31),
                    secondary: Color(red: 0.02, green: 0.36, blue: 0.16)
                ) {
                    if ram.validation.confirmed {
                        ram.refresh()
                    } else if ram.activationStatus == "approved" {
                        ram.retryReinstall()
                        Task { await ram.resumeAfterAppleApproval() }
                    } else if ram.activationPending {
                        openSideStore()
                    } else {
                        activate()
                    }
                }
                .accessibilityIdentifier("bloombox.ram.primaryActivate")

                ramActionTile(
                    title: "Método 2",
                    subtitle: "Descargar, instalar y abrir GetMoreRam",
                    symbol: "arrow.down.app.fill",
                    tint: Color(red: 0.94, green: 0.17, blue: 0.23),
                    secondary: Color(red: 0.38, green: 0.04, blue: 0.12)
                ) {
                    // Testing GetMoreRam must remain independent of the installed
                    // RAM+ entitlement. Never short-circuit when confirmed.
                    externalInstallLogs = ram.validation.confirmed
                        ? ["[TEST] RAM+ ya está activa; ejecutando Método 2 completo de todos modos."]
                        : ["[INFO] Solicitando GetMoreRam desde su repositorio oficial…"]
                    NotificationCenter.default.post(name: Notification.Name("BloomBoxRAMInstallGetMoreRam"), object: nil)
                }
                .accessibilityIdentifier("bloombox.ram.alternativeInstall")

                ramConsole
                ramCurrentStatus

                DisclosureGroup("Validaciones de esta instalación") {
                    VStack(alignment: .leading, spacing: 12) {
                        check("Permiso del proceso BloomBox", ram.validation.runtimeGranted)
                        check("Permiso incluido en el perfil", ram.validation.profileGranted)
                        check("Perfil vigente", ram.validation.profileCurrent)
                        check("Perfil corresponde a esta app", ram.validation.profileMatches)
                        check("Firma de LiveProcess", ram.extensionSigned)
                        Text("LiveProcess se comprueba por separado en su firma; esto no confirma su proceso en ejecución ni el permiso de cada app invitada.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.top, 12)
                }
                .font(.subheadline)
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .accessibilityIdentifier("bloombox.ram.validations")

                GroupBox("Activar con la sesión de SideStore") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("BloomBox solicitará Increased Memory Limit para su App ID y para LiveProcess si tiene uno separado. Se conservarán los demás permisos.")
                        Text("SideStore hace el inicio de sesión. BloomBox no guarda tu contraseña ni la sesión de Apple.")
                            .font(.footnote).foregroundStyle(.secondary)
                        if !ram.activationMessage.isEmpty {
                            Label(ram.activationMessage.loc, systemImage: ram.activationStatus == "approved" ? "checkmark.circle" : "info.circle")
                                .font(.callout)
                        }
                        if ram.activationStatus == "awaitingSession" {
                            Text("Esperando una consulta de SideStore a Apple. Abre Mis apps con la misma cuenta que firmó BloomBox. Si la sesión venció, SideStore puede pedir iniciar sesión.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        if ram.activationStatus == "approved" && !ram.validation.confirmed {
                            Text("Apple aprobó RAM+, pero falta firmar e instalar BloomBox con el permiso. Se buscará la release oficial más reciente. Si usas una compilación experimental, confirma antes de reemplazarla.")
                                .font(.footnote).foregroundStyle(.orange)
                        }
                        if !ram.reinstallStage.isEmpty {
                            Label(ram.reinstallMessage.loc, systemImage: ram.reinstallStage == "confirmed" ? "checkmark.seal.fill" : "arrow.triangle.2.circlepath")
                                .font(.footnote)
                            Text("Etapa: " + ([
                                "checking": "Comprobando",
                                "downloading": "Descargando",
                                "preparing": "Preparando instalación",
                                "installing": "Instalando",
                                "verifying": "Verificando",
                                "chooseIPA": "IPA oficial no disponible",
                                "manualReady": "Preparada para SideStore",
                                "review": "Confirma el cambio de versión",
                                "failed": "Reintento disponible",
                                "confirmed": "Verificada"
                            ][ram.reinstallStage] ?? ram.reinstallStage))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if ram.reinstallBusy { ProgressView("Preparando reinstalación…") }
                        if ram.activationStatus == "approved" && !ram.validation.confirmed {
                            if !ram.reinstallBusy && (ram.reinstallStage.isEmpty || ["approved", "failed", "verifying", "chooseIPA"].contains(ram.reinstallStage)) {
                                Button("Buscar última release e instalar") {
                                    ram.retryReinstall()
                                    Task { await ram.resumeAfterAppleApproval() }
                                }.buttonStyle(.borderedProminent)
                            }
                            Button("Elegir IPA manualmente") { chooseOriginalIPA = true }
                            if #available(iOS 16.0, *), let file = ram.preparedIPA {
                                ShareLink(item: file) {
                                    Label("Compartir IPA con SideStore", systemImage: "square.and.arrow.up")
                                }
                            }
                            Text("Si SideStore no acepta la entrega automática, guarda la IPA en Archivos, abre SideStore y selecciónala con +. Instálala encima de BloomBox, con todas sus extensiones.")
                                .font(.footnote).foregroundStyle(.secondary)
                            Button("Abrir SideStore", action: openSideStore)
                        }
                        if ram.reinstallStage == "review" && !ram.reinstallBusy {
                            Button("Confirmar actualización a la última release") {
                                Task { await ram.resumeAfterAppleApproval(confirmDifferentBuild: true) }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                            .accessibilityIdentifier("bloombox.ram.confirmLatestRelease")
                            Text("Advertencia: la última release pública puede reemplazar funciones de compilaciones experimentales, incluido JIT. No se borrarán los datos intencionalmente, pero haz un respaldo antes de actualizar.")
                                .font(.footnote).foregroundStyle(.orange)
                        }
                        if ram.validation.confirmed && experimentalControlsEnabled {
                            Divider()
                            Label("Controles RAM+ habilitados para pruebas", systemImage: "flask.fill")
                                .font(.subheadline.bold())
                            Text("RAM+ ya está activa. Estos controles prueban la descarga de la última release estable SIN volver a solicitar el permiso a Apple. Reinstalar puede reemplazar JIT experimental o perder RAM+ si SideStore no conserva el permiso.")
                                .font(.footnote).foregroundStyle(.orange)
                            Button("Probar actualización RAM+ (experimental)") {
                                ram.startExperimentalReinstall()
                                Task { await ram.resumeAfterAppleApproval() }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(ram.reinstallBusy)
                            .accessibilityIdentifier("bloombox.experiments.ramRetryInstall")
                            Button("Elegir IPA manualmente") {
                                ram.startExperimentalReinstall()
                                chooseOriginalIPA = true
                            }
                            .disabled(ram.reinstallBusy)
                            if #available(iOS 16.0, *), let file = ram.preparedIPA {
                                ShareLink(item: file) {
                                    Label("Compartir IPA con SideStore", systemImage: "square.and.arrow.up")
                                }
                            }
                            Button("Abrir SideStore", action: openSideStore)
                        }
                        if ram.activationStatus == "uncertain" {
                            Text("No se pudo confirmar la respuesta de Apple después de enviar la solicitud. Comprueba el App ID antes de repetirla para evitar modificaciones duplicadas.")
                                .font(.footnote).foregroundStyle(.orange)
                        }
                        if ram.activationPending {
                            ProgressView("Solicitud en curso…")
                            Button("Volver a SideStore", action: openSideStore)
                            Button("Cancelar solicitud", role: .cancel) { ram.cancelActivation() }
                        } else if ram.activationStatus != "approved" && !ram.validation.confirmed {
                            Button("Activar y reinstalar") { activate() }
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("bloombox.ram.requestPermission")
                        }
                        Text("La confirmación de Apple y el permiso de esta instalación se validan por separado. Nunca borres BloomBox para aplicar RAM+.")
                        if ram.activationStatus != "approved" {
                            Button("Abrir SideStore", action: openSideStore)
                        }
                        if let activationError { Text(activationError).foregroundStyle(.orange) }
                    }.font(.callout).padding(.vertical, 6)
                }
                DisclosureGroup("Alternativa manual con GetMoreRam") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Si la integración experimental no funciona, usa la misma cuenta Apple en GetMoreRam, selecciona este App ID y pulsa Add Increased Memory Limit. Después reinstala desde SideStore.")
                        Text(Bundle.main.bundleIdentifier ?? "Identificador no disponible")
                            .font(.caption.monospaced()).textSelection(.enabled)
                        Button("Copiar identificador") { UIPasteboard.general.string = Bundle.main.bundleIdentifier }
                        Link("GetMoreRam · instrucciones e instalación", destination: URL(string: "https://github.com/hugeBlack/GetMoreRam")!)
                    }.font(.footnote).padding(.top, 10)
                }
                Button("Comprobar de nuevo") { ram.refresh() }
                    .buttonStyle(.bordered)
                if let date = ram.checkedAt {
                    Text("Última comprobación: \(date.formatted(date: .omitted, time: .standard))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text("Memoria disponible para el proceso ahora: \(ByteCountFormatter.string(fromByteCount: Int64(clamping: ram.available), countStyle: .memory)). Cambia con el uso; no demuestra por sí sola que RAM+ esté activa ni añade RAM física.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .background {
            ZStack {
                Color(red: 0.055, green: 0.058, blue: 0.078)
                RadialGradient(
                    colors: [BloomBoxWizardPalette.color(BloomBoxProfileStore.active.accentHex).opacity(0.20), .clear],
                    center: .topTrailing, startRadius: 8, endRadius: 470
                )
                // Reuse the exact ambient artwork from onboarding, not a copy.
                BloomBoxWizardAmbientSymbols(
                    isDark: true, accentHex: BloomBoxProfileStore.active.accentHex
                )
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .navigationTitle("RAM+")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            ram.refresh()
            // Never silently replace a working experimental build on view appear.
        }
        .onChange(of: scenePhase) {
            if $0 == .active {
                ram.refresh()
            }
        }
        .onReceive(statusTimer) { _ in if scenePhase == .active && ram.activationPending { ram.refresh() } }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("BloomBoxRAMExternalInstallLog"))) { notification in
            guard let message = notification.userInfo?["message"] as? String else { return }
            externalInstallLogs.append(message)
            if externalInstallLogs.count > 30 { externalInstallLogs.removeFirst(externalInstallLogs.count - 30) }
            if (notification.userInfo?["refreshRAM"] as? Bool) == true { ram.refresh() }
        }
        .fileImporter(isPresented: $chooseOriginalIPA, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let files):
                if let file = files.first { Task { await ram.importIPA(file) } }
            case .failure(let error):
                activationError = error.localizedDescription
            }
        }
    }

    private var ramCurrentStatus: some View {
        let active = ram.validation.confirmed
        let processing = ram.activationPending || ram.reinstallBusy
        return HStack(spacing: 14) {
            Image(systemName: active ? "checkmark.circle.fill" :
                  (processing ? "hourglass.circle.fill" : "circle.dotted.circle.fill"))
                .font(.system(size: 32))
                .foregroundStyle(active ? Color.green : (processing ? Color.orange : Color.gray))
            VStack(alignment: .leading, spacing: 5) {
                Text(active ? "Estado actual: RAM+ verificada" :
                     (processing ? "Estado actual: en proceso" : "Estado actual: listo para activar"))
                    .font(.subheadline.bold())
                Text(BloomBoxL10n.t(ram.status))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(active ? "La firma y el perfil de esta instalación confirman RAM+." :
                     "RAM+ no aumenta la RAM física; iOS comprueba el permiso después de firmar e instalar.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(15)
        .background(Color.green.opacity(active ? 0.11 : 0.055),
                    in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18)
            .strokeBorder(Color.green.opacity(active ? 0.35 : 0.14), lineWidth: 1))
    }

    private var consoleLines: [String] {
        var lines = ["[BloomBox] Diagnóstico RAM+ (datos reales)"]
        func validationLine(_ title: String, _ state: Bool?) -> String {
            "[\(state == true ? "OK" : (state == false ? "WARN" : "INFO"))] \(title): " +
            (state == true ? "sí" : (state == false ? "no" : "sin confirmar"))
        }
        lines.append(validationLine("Permiso de BloomBox", ram.validation.runtimeGranted))
        lines.append(validationLine("Perfil con RAM+", ram.validation.profileGranted))
        lines.append(validationLine("Perfil vigente", ram.validation.profileCurrent))
        lines.append(validationLine("Identidad de la app", ram.validation.profileMatches))
        lines.append(validationLine("Firma de LiveProcess", ram.extensionSigned))
        if !ram.activationStatus.isEmpty {
            lines.append("[INFO] Solicitud Apple: \(ram.activationStatus)")
        }
        if !ram.activationMessage.isEmpty {
            lines.append("[INFO] \(ram.activationMessage)")
        }
        if !ram.reinstallStage.isEmpty {
            lines.append("[INFO] Reinstalación: \(ram.reinstallStage)")
            if !ram.reinstallMessage.isEmpty {
                lines.append("[INFO] \(ram.reinstallMessage)")
            }
        }
        lines.append(contentsOf: externalInstallLogs)
        lines.append(ram.validation.confirmed
            ? "[OK] RAM+ verificada en esta instalación"
            : "[INFO] RAM+ aún no confirmada en esta instalación")
        return lines
    }

    private var ramConsole: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Circle().fill(Color.red).frame(width: 10, height: 10)
                Circle().fill(Color.yellow).frame(width: 10, height: 10)
                Circle().fill(Color.green).frame(width: 10, height: 10)
                Text("Consola de proceso RAM+")
                    .font(.subheadline.bold())
                    .padding(.leading, 7)
                Spacer()
                Image(systemName: "terminal")
                    .foregroundStyle(.secondary)
            }
            .padding(14)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(consoleLines.enumerated()), id: \.offset) { entry in
                            let index = entry.offset
                            let line = entry.element
                            Text(line)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(line.hasPrefix("[OK]") ? Color.green :
                                                 (line.hasPrefix("[WARN]") || line.hasPrefix("[ERROR]") ? Color.orange :
                                                  Color.white.opacity(0.79)))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(index)
                        }
                    }
                    .padding(14)
                }
                .onChange(of: consoleLines.count) { count in
                    guard count > 0 else { return }
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) {
                        proxy.scrollTo(count - 1, anchor: .bottom)
                    }
                }
            }
            .frame(height: 225)
            .background(Color.black.opacity(0.93),
                        in: RoundedRectangle(cornerRadius: 15))
            .padding([.horizontal, .bottom], 7)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 19))
        .overlay(RoundedRectangle(cornerRadius: 19).strokeBorder(.white.opacity(0.10)))
        .accessibilityIdentifier("bloombox.ram.console")
    }

    private func ramActionTile(
        title: String, subtitle: String, symbol: String,
        tint: Color, secondary: Color, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: 31, weight: .semibold))
                    .frame(width: 43)
                Rectangle().fill(Color.white.opacity(0.55))
                    .frame(width: 1, height: 54)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 23, weight: .heavy, design: .rounded))
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .opacity(0.88)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 113)
            .background(
                LinearGradient(colors: [secondary, tint, secondary.opacity(0.87)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 25, style: .continuous)
            )
            .overlay(RoundedRectangle(cornerRadius: 25).strokeBorder(tint.opacity(0.80), lineWidth: 1.6))
            .overlay {
                BloomBoxRAMButtonParticles(tint: tint)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .shadow(color: tint.opacity(0.36), radius: 13)
        }
        .buttonStyle(.plain)
    }

    private func activate() {
        do {
            activationError = nil
            try ram.requestActivation()
            openSideStore()
        } catch {
            activationError = error.localizedDescription
        }
    }

    private func check(_ title: String, _ value: Bool?) -> some View {
        HStack {
            Image(systemName: value == true ? "checkmark.circle.fill" : (value == false ? "xmark.circle" : "questionmark.circle"))
                .foregroundStyle(value == true ? Color.green : Color.orange)
            Text(title)
            Spacer()
            Text(value.map { $0 ? "Sí" : "No" } ?? "Sin confirmar").font(.caption)
        }.font(.footnote)
    }
}


/// Lightweight particles around the action tiles. The screen background itself
/// uses BloomBoxWizardAmbientSymbols from onboarding.
private struct BloomBoxRAMButtonParticles: View {
    let tint: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: reduceMotion)) { timeline in
            Canvas(opaque: false) { context, size in
                let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                for index in 0..<15 {
                    let phase = Double(index) * 2.21
                    let x = CGFloat((Double(index * 37 % 101) / 101 + sin(time * 0.31 + phase) * 0.018)) * size.width
                    let y = CGFloat((Double(index * 41 % 99) / 99 + cos(time * 0.38 + phase) * 0.05)) * size.height
                    let diameter: CGFloat = index.isMultiple(of: 4) ? 4.8 : 2.5
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: diameter, height: diameter)),
                                 with: .color(tint.opacity(0.85)))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 25))
    }
}
