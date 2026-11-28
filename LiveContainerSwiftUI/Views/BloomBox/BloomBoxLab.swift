import Foundation
import SwiftUI

// Never erase an App Group, a keychain, an executable or a signing identity.
// All reset requests are stored in the current app's private defaults and
// applied on a new host process before guest models are initialized.
enum BloomBoxLabReset {
    enum Scope: String, CaseIterable, Identifiable {
        case welcome, preferences, factory
        var id: String { rawValue }
        var title: String {
            switch self {
            case .welcome: return BloomBoxL10n.isEnglish ? "Restart welcome" : "Reiniciar bienvenida"
            case .preferences: return BloomBoxL10n.isEnglish ? "Reset local preferences" : "Restablecer preferencias locales"
            case .factory: return BloomBoxL10n.isEnglish ? "Simulate first installation" : "Simular primera instalación"
            }
        }
        var icon: String {
            switch self {
            case .welcome: return "arrow.counterclockwise"
            case .preferences: return "slider.horizontal.3"
            case .factory: return "exclamationmark.triangle.fill"
            }
        }
        var detail: String {
            let en = BloomBoxL10n.isEnglish
            switch self {
            case .welcome: return en ? "Repeat the wizard and required guide. Keep apps and files." : "Repite el wizard y la guía obligatoria. Conserva apps y archivos."
            case .preferences: return en ? "Reset private BloomBox appearance and preferences; keep installed apps." : "Restablece preferencias y apariencia privadas; conserva las apps instaladas."
            case .factory: return en ? "Delete private installed apps, guest data, tweaks and BloomBox files, then start the wizard." : "Borra las apps privadas, datos, tweaks y archivos de BloomBox; vuelve al wizard."
            }
        }
    }

    static let pendingKey = "BloomBoxLabPendingResetV1"
    static let statusKey = "BloomBoxLabResetStatusV1"
    private static let migratedKey = "BloomBoxLabLocalOnboardingMigratedV1"
    static let onboardingKeys = [
        "BloomBoxWizardInitialCompletedV1", "BloomBoxBasicGuideStateV2", "BloomBoxBasicGuideStepV2",
        "BloomBoxTourStepV1", "BloomBoxTourCompletedV1", "BloomBoxTourSeenTopicsV1"
    ]
    private static let privateDocumentNames = ["Applications", "Data", "Tweaks", "BloomBox Files", "Manzana Files"]
    private static let privateSupportNames = ["LiveBoard", "BloomBoxNovaV2", "Manzana"]

    static var sharedStoragePresent: Bool {
        LiveContainerPreferencesAdapter.hasSharedStorage
    }

    static func schedule(_ scope: Scope) {
        UserDefaults.standard.set(scope.rawValue, forKey: pendingKey)
        UserDefaults.standard.removeObject(forKey: statusKey)
        UserDefaults.standard.synchronize()
    }

    static func cancel() {
        UserDefaults.standard.removeObject(forKey: pendingKey)
    }

    static func prepareForHostStart() {
        let defaults = UserDefaults.standard
        // Read legacy values once. Never write onboarding flags back into a
        // shared suite, or a reset in one copy could restart another copy.
        if !defaults.bool(forKey: migratedKey) {
            for key in onboardingKeys where defaults.object(forKey: key) == nil {
                if let value = LiveContainerPreferencesAdapter.defaults.object(forKey: key) {
                    defaults.set(value, forKey: key)
                }
            }
            defaults.set(true, forKey: migratedKey)
        }
        guard let raw = defaults.string(forKey: pendingKey),
              let scope = Scope(rawValue: raw) else { return }
        // Consume before doing IO: a failed reset cannot create a wipe loop.
        defaults.removeObject(forKey: pendingKey)
        defaults.synchronize()
        do {
            if scope == .factory {
                let fm = FileManager.default
                let docs = LiveContainerPreferencesAdapter.privateDocuments
                // Check and delete only explicitly owned paths beneath HOME.
                try removePrivateChildren(privateDocumentNames, root: docs)
                if let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                    try removePrivateChildren(privateSupportNames, root: support)
                }
            }
            if scope != .welcome {
                if let bundleID = Bundle.main.bundleIdentifier {
                    clearPreferences(defaults, domain: bundleID)
                }
                // "Unknown" is the private fallback suite used when no group
                // is available. Never clear a real or ambiguous group suite.
                if let privateDefaults = LiveContainerPreferencesAdapter.privateFallbackDefaults {
                    clearPreferences(privateDefaults, domain: "Unknown")
                }
                if scope == .preferences,
                   let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                    try removePrivateChildren(privateSupportNames, root: support)
                }
            }
            for key in onboardingKeys { defaults.removeObject(forKey: key) }
            defaults.set(false, forKey: "BloomBoxWizardInitialCompletedV1")
            defaults.set(0, forKey: "BloomBoxBasicGuideStateV2")
            defaults.set(0, forKey: "BloomBoxBasicGuideStepV2")
            defaults.set(true, forKey: migratedKey)
            defaults.set("ok:" + scope.rawValue, forKey: statusKey)
        } catch {
            defaults.set("error:" + error.localizedDescription, forKey: statusKey)
            NSLog("[BloomBoxLab] Private reset stopped: %@", error.localizedDescription)
        }
    }

    private static func clearPreferences(_ defaults: UserDefaults, domain: String) {
        let keys = defaults.persistentDomain(forName: domain)?.keys.map { $0 } ?? []
        for key in keys where isResettablePreference(key) {
            defaults.removeObject(forKey: key)
        }
    }

    private static func isResettablePreference(_ key: String) -> Bool {
        // Reset only BloomBox-owned presentation and guest preferences;
        // preserve signing, account, pairing, installer and lab metadata.
        let low = key.lowercased()
        let owned = ["bloombox", "liveboard", "manzana", "husk"].contains { low.hasPrefix($0) } || low == "darkmodeicon"
        let protected = ["certificate", "pairing", "account", "anisette", "sign", "token",
                         "credential", "password", "team", "installer", "keychain", "device", "bloomboxlab"]
        return owned && !protected.contains { low.contains($0) }
    }

    private static func removePrivateChildren(_ names: [String], root: URL) throws {
        let fm = FileManager.default
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .standardizedFileURL.resolvingSymlinksInPath()
        let directory = root.standardizedFileURL.resolvingSymlinksInPath()
        guard directory.path.hasPrefix(home.path + "/"),
              directory.path == home.appendingPathComponent("Documents").path ||
                directory.path == home.appendingPathComponent("Library/Application Support").path else {
            throw CocoaError(.fileWriteNoPermission)
        }
        // Preflight all targets; reject aliases to data outside our sandbox.
        var targets: [URL] = []
        for name in names {
            let target = directory.appendingPathComponent(name, isDirectory: true)
            guard fm.fileExists(atPath: target.path) else { continue }
            let resolved = target.standardizedFileURL.resolvingSymlinksInPath()
            guard resolved.path == target.standardizedFileURL.path,
                  resolved.deletingLastPathComponent().path == directory.path else {
                throw CocoaError(.fileWriteNoPermission)
            }
            targets.append(target)
        }
        for target in targets { try fm.removeItem(at: target) }
    }
}

struct BloomBoxLabView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(BloomBoxLabReset.pendingKey) private var pending = ""
    @AppStorage(BloomBoxLabReset.statusKey) private var status = ""
    @State private var selected: BloomBoxLabReset.Scope?
    @State private var confirmation = ""
    private var en: Bool { BloomBoxL10n.isEnglish }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Label(en ? "Experimental tools" : "Herramientas experimentales", systemImage: "flask.fill")
                        .font(.headline).foregroundStyle(.purple)
                    Text(en ? "Only this installation's private storage is eligible for deletion. Signing and shared storage are preserved." :
                            "Solo se puede borrar el almacenamiento privado de esta instalación. Se conservan la firma y los datos compartidos.")
                        .font(.footnote)
                    if BloomBoxLabReset.sharedStoragePresent {
                        Label(en ? "Shared storage detected. Shared apps and preferences will remain." :
                                "Almacenamiento compartido detectado. Las apps y preferencias compartidas permanecerán.", systemImage: "exclamationmark.shield")
                            .font(.footnote).foregroundStyle(.orange)
                    }
                }
                if let scope = BloomBoxLabReset.Scope(rawValue: pending) {
                    Section {
                        Label(scope.title, systemImage: "clock.arrow.circlepath")
                        Text(en ? "Close BloomBox completely from the app switcher and reopen it to apply the reset." :
                                "Cierra BloomBox por completo desde el selector de apps y vuelve a abrirlo para aplicar el reinicio.")
                        Button(en ? "Cancel pending reset" : "Cancelar reinicio pendiente", role: .cancel) {
                            BloomBoxLabReset.cancel()
                        }
                    } header: { Text(en ? "Reset scheduled" : "Reinicio preparado") }
                } else {
                    Section {
                        ForEach(BloomBoxLabReset.Scope.allCases) { scope in
                            Button {
                                selected = scope
                                confirmation = ""
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Label(scope.title, systemImage: scope.icon)
                                        .foregroundStyle(scope == .factory ? Color.red : Color.primary)
                                    Text(scope.detail).font(.caption).foregroundStyle(.secondary)
                                }
                            }.buttonStyle(.plain)
                        }
                    }
                    if let selected {
                        Section {
                            Text(selected.detail)
                            if selected == .factory {
                                Text(en ? "Private data cannot be recovered after deletion. Type RESET to confirm." :
                                        "Los datos privados no se pueden recuperar después del borrado. Escribe RESET para confirmar.")
                                    .foregroundStyle(.red)
                                TextField("RESET", text: $confirmation)
                                    .textInputAutocapitalization(.characters).autocorrectionDisabled()
                            }
                            Button(role: selected == .factory ? .destructive : nil) {
                                BloomBoxLabReset.schedule(selected)
                                self.selected = nil
                                confirmation = ""
                            } label: {
                                Text(en ? "Prepare reset" : "Preparar reinicio")
                            }
                            .disabled(selected == .factory && confirmation != "RESET")
                            Button(en ? "Cancel" : "Cancelar", role: .cancel) {
                                self.selected = nil; confirmation = ""
                            }
                        } header: { Text(selected.title) }
                    }
                }
                if status.hasPrefix("ok:") {
                    Section { Label(en ? "Last reset applied" : "Último reinicio aplicado", systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
                } else if status.hasPrefix("error:") {
                    Section {
                        Label(en ? "Reset stopped; some private data may already be deleted." : "Reinicio interrumpido; algunos datos privados podrían haberse borrado.", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text(String(status.dropFirst(6))).font(.caption)
                    }
                }
            }
            .navigationTitle("BloomBox Lab")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(en ? "Done" : "Listo") { dismiss() }
                }
            }
        }.navigationViewStyle(.stack)
    }
}
