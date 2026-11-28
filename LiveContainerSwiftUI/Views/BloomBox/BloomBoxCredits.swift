// SPDX-License-Identifier: AGPL-3.0-only
import SwiftUI

/// Local, offline acknowledgments. The catalog distinguishes bundled code,
/// external tools and historical references; no ownership is reassigned.
struct BloomBoxCreditsView: View {
    private var en: Bool { BloomBoxL10n.isEnglish }

    private struct Credit: Identifiable {
        let id: String
        let author: String
        let es: String
        let en: String
        let address: String
        init(_ id: String, _ author: String, _ es: String, _ en: String, _ address: String) {
            self.id = id; self.author = author; self.es = es; self.en = en; self.address = address
        }
    }
    private struct GroupData: Identifiable {
        let es: String
        let en: String
        let items: [Credit]
        var id: String { en }
    }
    private static let groups: [GroupData] = [
        GroupData(es: "Equipo BloomBox", en: "BloomBox team", items: [
            Credit("BloomBox", "AdriFOG / adri23rep-stack", "Desarrollo y mantenimiento del proyecto, diseño, launcher y herramientas propias.", "Project development and maintenance, design, launcher and original tools.", "https://github.com/AdriFOG/Bloombox-iOS"),
            Credit("Manzana", "adri23rep-stack", "Proyecto anterior y origen histórico de BloomBox.", "Earlier project and historical origin of BloomBox.", "https://github.com/AdriFOG/Bloombox-iOS/blob/main/BLOOMBOX_MIGRATION.md"),
            Credit("MediaBloom", "AdriFOG", "Proyecto hermano de multimedia.", "Companion multimedia project.", "https://github.com/AdriFOG/MediaBloom-iOS"),
            Credit("Takopi / NikaView", "adri23rep-stack", "Referencia de administración de archivos.", "File management reference.", "https://github.com/adri23rep-stack/NikaView"),
            Credit("BloomBox Installer", "AdriFOG", "Asistente web de instalación sin PC.", "No-computer web installation assistant.", "https://github.com/AdriFOG/Bloombox-iOS-Installer")
        ]),
        GroupData(es: "Componentes principales", en: "Core components", items: [
            Credit("LiveContainer", "Duy Tran (khanhduytran0), hugeBlack y colaboradores", "Base de ejecución de apps invitadas; AGPL-3.0.", "Guest application runtime foundation; AGPL-3.0.", "https://github.com/LiveContainer/LiveContainer"),
            Credit("SideStore", "SideStore team", "Firma, autenticación e instalación; licencia upstream.", "Signing, authentication and installation; upstream license.", "https://github.com/SideStore/SideStore"),
            Credit("StikJIT", "StikDebug team", "Integración JIT adaptada; MPL-2.0.", "Adapted JIT integration; MPL-2.0.", "https://github.com/StikDebug/StikJIT"),
            Credit("Husk", "Leviidev y colaboradores", "Emparejamiento adaptado (GPL-2.0-or-later); compatibilidad Android mediante la app externa.", "Adapted pairing (GPL-2.0-or-later); Android compatibility through the external app.", "https://github.com/Leviidev/Husk"),
            Credit("idevice", "jkcoxson y colaboradores", "Comunicación con el dispositivo y componentes FFI. Consultar licencias correspondientes.", "Device communication and FFI components. See applicable licenses.", "https://github.com/jkcoxson/idevice"),
            Credit("LiveExec32", "LiveContainer team", "Runtime de 32 bits; Apache-2.0.", "32-bit runtime; Apache-2.0.", "https://github.com/LiveContainer/LiveExec32"),
            Credit("dylibify", "LiveContainer team", "Herramienta de preparación de ejecutables durante la compilación.", "Executable preparation tool used during builds.", "https://github.com/LiveContainer/dylibify"),
            Credit("ZSign / Feather", "zhlynn / khcrysalis", "Firma de código; versión modificada por Feather usada por LiveContainer.", "Code signing; Feather's modified version used by LiveContainer.", "https://github.com/zhlynn/zsign"),
            Credit("Feather", "khcrysalis", "Fuente de la versión modificada de ZSign.", "Source of the modified ZSign version.", "https://github.com/khcrysalis/Feather"),
            Credit("fishhook", "Autores de fishhook y colaboradores de LiveContainer", "Submódulo de interposición de funciones.", "Function rebinding submodule.", "https://github.com/LiveContainer/fishhook"),
            Credit("litehook", "opa334 y colaboradores", "Submódulo de hooks; MIT.", "Hooking submodule; MIT.", "https://github.com/opa334/litehook"),
            Credit("OpenSSL", "OpenSSL contributors / krzyzanowskim", "Submódulo de bibliotecas criptográficas.", "Cryptographic library submodule.", "https://github.com/krzyzanowskim/OpenSSL"),
            Credit("ElleKit / CydiaSubstrate.framework", "Évelyne Bélanger", "Aviso de copyright de 2022 conservado en el framework incluido.", "2022 copyright notice retained in the bundled framework.", "https://github.com/AdriFOG/Bloombox-iOS/blob/main/Resources/Frameworks/CydiaSubstrate.framework/LICENSE")
        ]),
        GroupData(es: "Referencias y antecedentes", en: "References and history", items: [
            Credit("Strata", "huzaifahshahid71-ops", "Antecedente histórico del launcher. La procedencia y avisos se conservan; no implica autoría exclusiva de todos los componentes heredados.", "Historical launcher predecessor. Provenance and notices are preserved; this does not establish exclusive authorship of all inherited components.", "https://github.com/huzaifahshahid71-ops/Strata"),
            Credit("GetMoreRam", "hugeBlack", "Referencia para solicitar Increased Memory Limit en RAM+; no se incluye su código de autenticación.", "Reference for requesting Increased Memory Limit in RAM+; its authentication code is not bundled.", "https://github.com/hugeBlack/GetMoreRam"),
            Credit("StosSign", "stossy11", "Referencia de Developer Services para RAM+; no se incluye su código de autenticación.", "Developer Services reference for RAM+; its authentication code is not bundled.", "https://github.com/stossy11/StosSign"),
            Credit("SideSign", "SideStore team", "Referencia de App ID y firma.", "App ID and signing reference.", "https://github.com/SideStore/SideSign"),
            Credit("MeloNX", "stossy11 y colaboradores", "Script original de JIT del perfil experimental 2.6; GPL-3.0.", "Original JIT script for the experimental 2.6 profile; GPL-3.0.", "https://starforgejo.dev/projects/MeloNX/src/tag/2.6/src/MeloNX/MeloNX/Common/JIT/EnableJIT.swift"),
            Credit("Playnite", "Playnite team", "Formato y documentación de temas de consola.", "Console theme format and documentation.", "https://api.playnite.link/docs/tutorials/themes/manifestFile.html"),
            Credit("Nintendo Switch-ish", "David Griggs", "Tema original de Playnite para la adaptación de GameBox; MIT.", "Original Playnite theme for the GameBox adaptation; MIT.", "https://github.com/davidkgriggs/Nintendo-Switch-ish"),
            Credit("OpenPortsGames", "Kymie131 y colaboradores", "Catálogo de ports; datos propios CC BY 4.0 y créditos individuales por entrada.", "Ports catalog; original data CC BY 4.0 and individual entry attribution.", "https://github.com/Kymie131/openportsgames"),
            Credit("Dashboard Icons", "Homarr Labs y colaboradores", "Iconos de tiendas; colección Apache-2.0. Las marcas pertenecen a sus titulares.", "Store icons; Apache-2.0 collection. Trademarks belong to their owners.", "https://github.com/homarr-labs/dashboard-icons"),
            Credit("FrontBoardAppLauncher", "khanhduytran0", "Antecedente técnico reconocido por LiveContainer.", "Technical predecessor acknowledged by LiveContainer.", "https://github.com/khanhduytran0/FrontBoardAppLauncher"),
            Credit("Restoring Dyld Memory Loading", "xpn", "Referencia técnica reconocida por LiveContainer.", "Technical reference acknowledged by LiveContainer.", "https://blog.xpnsec.com/restoring-dyld-memory-loading"),
            Credit("CFastFind", "LinusHenze", "Código de PatchfinderUtils reconocido por LiveContainer; MIT.", "PatchfinderUtils code acknowledged by LiveContainer; MIT.", "https://github.com/pinauten/PatchfinderUtils/blob/master/Sources/CFastFind/CFastFind.c")
        ]),
        GroupData(es: "Instalación sin PC", en: "No-computer installation", items: [
            Credit("siboot", "FrizzleM", "Herramienta externa utilizada por el instalador web.", "External tool used by the web installer.", "https://github.com/FrizzleM/siboot"),
            Credit("SideInstaller", "FrizzleM", "Método externo de instalación; no se redistribuye su código ni binarios.", "External installation method; its code and binaries are not redistributed.", "https://github.com/FrizzleM/SideInstaller"),
            Credit("Open Minis", "OpenMinis team", "Terminal externa que ejecuta el comando confirmado por el usuario.", "External terminal that runs the user-confirmed command.", "https://github.com/OpenMinis/OpenMinis"),
            Credit("LocalDevVPN", "Equipo de LocalDevVPN", "VPN externa para comunicación local con el dispositivo.", "External VPN for local device communication.", "https://apps.apple.com/app/id6755608044")
        ]),
        GroupData(es: "Colaboradores de LiveContainer", en: "LiveContainer contributors", items: [
            Credit("khanhduytran0", "Duy Tran", "Proyecto base y desarrollo upstream.", "Base project and upstream development.", "https://github.com/khanhduytran0"),
            Credit("hugeBlack", "Huge_Black", "Contribuciones SwiftUI.", "SwiftUI contributions.", "https://github.com/hugeBlack"),
            Credit("haxi0", "haxi0", "Icono original de LiveContainer.", "Original LiveContainer icon.", "https://github.com/haxi0"),
            Credit("m1337v", "m1337v", "Icono original de LiveContainer.", "Original LiveContainer icon.", "https://github.com/m1337v"),
            Credit("Vishram1123", "Vishram1123", "Implementación inicial de accesos directos y scripts JIT para iOS 26+.", "Initial shortcut implementation and iOS 26+ JIT script support.", "https://github.com/Vishram1123"),
            Credit("Staubgeborener", "Staubgeborener", "Actualizador automático de fuentes.", "Automatic source updater.", "https://github.com/Staubgeborener"),
            Credit("fkunn1326", "fkunn1326", "Mejoras para ocultar aplicaciones.", "Improved app hiding.", "https://github.com/fkunn1326"),
            Credit("slds1", "slds1", "Colores dinámicos.", "Dynamic colors.", "https://github.com/slds1"),
            Credit("StephenDev0", "StephenDev0", "Compatibilidad con fuentes AltStore.", "AltStore source support.", "https://github.com/StephenDev0")
        ])
    ]

    var body: some View {
        List {
            Section {
                VStack(spacing: 9) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(.purple)
                        .accessibilityHidden(true)
                    Text("BloomBox").font(.title.bold())
                    Text(en ? "Built with the community" : "Hecho con la comunidad")
                        .font(.headline)
                    Text(en ? "Thank you to everyone who develops, tests, translates and shares open-source software." : "Gracias a quienes desarrollan, prueban, traducen y comparten software libre.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
            ForEach(Self.groups) { group in
                Section {
                    ForEach(group.items) { credit in
                        creditRow(credit)
                    }
                } header: {
                    Text(en ? group.en : group.es)
                }
            }
            Section {
                Link(en ? "BloomBox contributors" : "Colaboradores de BloomBox",
                     destination: URL(string: "https://github.com/AdriFOG/Bloombox-iOS/graphs/contributors")!)
                Link(en ? "Historical contributors and provenance" : "Colaboradores históricos y procedencia",
                     destination: URL(string: "https://github.com/AdriFOG/Bloombox-iOS/blob/main/docs/STRATA-CONTRIBUTOR-HISTORY-PREVIEW.md")!)
                Link(en ? "LiveContainer contributors and translators" : "Colaboradores y traductores de LiveContainer",
                     destination: URL(string: "https://github.com/LiveContainer/LiveContainer/graphs/contributors")!)
                Link(en ? "Original LiveContainer credits" : "Créditos originales de LiveContainer",
                     destination: URL(string: "https://github.com/AdriFOG/Bloombox-iOS/blob/main/docs/LiveContainer-Upstream.md#credits")!)
                Link("Crowdin – LiveContainer", destination: URL(string: "https://crowdin.com/project/livecontainer")!)
                Link("Duy Tran · X / Twitter", destination: URL(string: "https://twitter.com/khanhduytran0")!)
                Text(en ? "And everyone who reports bugs, tests on real devices, creates themes or contributes translations. Individual app and theme authors are credited in their respective catalogs." : "Y a todas las personas que reportan errores, prueban en sus dispositivos, crean temas o traducen. Los autores de apps y temas individuales aparecen en sus respectivos catálogos.")
                    .font(.footnote).foregroundStyle(.secondary)
            } header: { Text(en ? "Community" : "Comunidad") }
            Section {
                Text("Original BloomBox contributions (c) 2026 adri23rep-stack")
                    .font(.subheadline).textSelection(.enabled)
                Link("https://github.com/adri23rep-stack/BloomBox",
                     destination: URL(string: "https://github.com/adri23rep-stack/BloomBox")!)
                Text(en ? "The additional AGPL section 7(b) term applies only to expressly marked original BloomBox material. All third-party copyright and licensing notices remain in effect." : "El término adicional de la sección 7(b) de AGPL solo se aplica al material original de BloomBox expresamente marcado. Se conservan los derechos y avisos de licencia de terceros.")
                    .font(.footnote)
                Link("GNU AGPL-3.0", destination: URL(string: "https://github.com/AdriFOG/Bloombox-iOS/blob/main/LICENSE")!)
                Link(en ? "Original-work attribution" : "Atribución del trabajo original", destination: URL(string: "https://github.com/AdriFOG/Bloombox-iOS/blob/main/LICENSE-ADDITIONAL-TERMS.md")!)
                Link(en ? "Third-party notices and licenses" : "Avisos y licencias de terceros", destination: URL(string: "https://github.com/AdriFOG/Bloombox-iOS/blob/main/THIRD_PARTY_NOTICES.md")!)
                Link(en ? "Source provenance audit" : "Auditoría de procedencia", destination: URL(string: "https://github.com/AdriFOG/Bloombox-iOS/blob/main/docs/STRATA-PROVENANCE-AUDIT.md")!)
                Text(en ? "Credits do not imply endorsement or affiliation with the named projects. Apple, Nintendo and other trademarks belong to their respective owners." : "Los créditos no implican afiliación ni respaldo de los proyectos mencionados. Apple, Nintendo y las demás marcas pertenecen a sus respectivos titulares.")
                    .font(.footnote).foregroundStyle(.secondary)
            } header: { Text(en ? "Licenses and attribution" : "Licencias y atribución") }
        }
        .navigationTitle(en ? "Credits" : "Créditos")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private func creditRow(_ credit: Credit) -> some View {
        if let url = URL(string: credit.address) {
            Link(destination: url) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(credit.id).font(.headline).foregroundStyle(.primary)
                        Text(credit.author).font(.subheadline).foregroundStyle(.secondary)
                        Text(en ? credit.en : credit.es)
                            .font(.footnote).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 5)
                    Image(systemName: "arrow.up.right").font(.caption.weight(.semibold))
                        .foregroundStyle(.purple)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 5)
                .contentShape(Rectangle())
            }
        }
    }
}
