import SwiftUI
import UIKit

// Stable topic IDs also act as navigation intents. No guest launch, download,
// installation, permission change or deletion is performed by the guide itself.
struct BloomBoxTourTopic: Identifiable {
    let id: String
    let icon: String
    let es: String
    let en: String
    let detailES: String
    let detailEN: String
    let target: String?
    let destination: String?

    var title: String { BloomBoxL10n.isEnglish ? en : es }
    var detail: String { BloomBoxL10n.isEnglish ? detailEN : detailES }

    init(_ id: String, _ icon: String, _ es: String, _ en: String,
         _ detailES: String, _ detailEN: String, target: String? = nil, destination: String? = nil) {
        self.id = id; self.icon = icon; self.es = es; self.en = en
        self.detailES = detailES; self.detailEN = detailEN
        self.target = target; self.destination = destination
    }

    static let all: [Self] = [
        .init("welcome", "sparkles", "Descubre BloomBox", "Discover BloomBox",
              "Tu escritorio, aplicaciones y herramientas en un solo lugar. Explora a tu ritmo; nada se instala ni se activa automáticamente.",
              "Your Home, apps and tools in one place. Explore at your own pace; nothing is installed or enabled automatically."),
        .init("library", "square.grid.2x2", "Tus aplicaciones", "Your apps",
              "Abre la biblioteca de apps o, en Nova, desliza hacia arriba para abrir el cajón. Desde ahí encuentras las apps instaladas y las herramientas de BloomBox.",
              "Open the App Library or swipe up in Nova to open the drawer. Find installed apps and BloomBox tools there.", target: "library", destination: "library"),
        .init("install", "square.and.arrow.down", "Instalar IPA", "Install IPA",
              "Usa Instalar app para elegir un IPA o TIPA de Archivos. También puedes abrir un archivo compatible desde Archivos y elegir BloomBox.",
              "Use Install app to select an IPA or TIPA from Files. You can also open a compatible file in Files and choose BloomBox.", target: "manzana:install", destination: "install"),
        .init("sidestore", "square.stack.3d.up", "SideStore y firmas", "SideStore and signing",
              "Si tu edición incluye SideStore, puedes usarlo para instalar o renovar apps firmadas en iOS. La cuenta Apple y la renovación se administran aparte.",
              "If your edition includes SideStore, use it to install or refresh signed iOS apps. Apple Account and signing are managed separately.", target: "manzana:sidestore"),
        .init("appstore", "bag", "App Store de BloomBox", "BloomBox App Store",
              "Consulta el catálogo de apps y ports para iOS. Revisa la procedencia y compatibilidad antes de descargar.",
              "Browse the iOS app and port catalog. Check the source and compatibility before downloading.", target: "manzana:appstore", destination: "appstore"),
        .init("apkstore", "gamecontroller", "ApkStore y Husk", "ApkStore and Husk",
              "Explora los ports Android. Husk es necesario para ejecutar APK compatibles; no todas las apps Android funcionan y algunos títulos requieren JIT.",
              "Explore Android ports. Husk is needed to run compatible APKs; not all Android apps work and some titles require JIT.", target: "manzana:portstore", destination: "apkstore"),
        .init("files", "folder", "Archivos iOS y Android", "iOS and Android Files",
              "Abre Archivos para elegir iOS o Android y administrar los datos disponibles de tus aplicaciones. Ten cuidado al borrar archivos.",
              "Open Files to choose iOS or Android and manage available app data. Be careful when deleting files.", target: "manzana:androidfiles", destination: "files"),
        .init("modules", "square.stack.3d.up", "Módulos y RAM+", "Modules and RAM+",
              "Consulta los módulos, sus requisitos y el estado de RAM+. Solicitar una función no garantiza que iOS conceda el permiso.",
              "Review modules, requirements and RAM+ status. Requesting a feature does not guarantee that iOS grants permission.", target: "manzana:modules", destination: "modules"),
        .init("jit", "bolt.fill", "Activar JIT", "JIT setup",
              "Algunas apps, emuladores y juegos lo necesitan. Configura el proveedor y revisa el estado de conexión antes de iniciar un título compatible.",
              "Some apps, emulators and games need it. Configure the provider and review connection status before launching a compatible title.", target: "manzana:modules", destination: "jit"),
        .init("tweaks", "puzzlepiece.extension", "Tweak Store", "Tweak Store",
              "Descubre extensiones compatibles. Revisa qué cambia cada tweak antes de añadirlo a una app; pueden causar incompatibilidades.",
              "Discover compatible extensions. Review what each tweak changes before adding it to an app; incompatibilities are possible.", target: "manzana:tweakstore", destination: "tweaks"),
        .init("profiles", "person.crop.circle", "Perfiles y contenedores", "Profiles and containers",
              "Los perfiles conservan su configuración y las apps pueden usar contenedores de datos separados. Consulta los ajustes de la app antes de cambiar de contenedor.",
              "Profiles retain their settings and apps can use separate data containers. Review app settings before switching containers.", target: "profiles", destination: "profiles"),
        .init("context", "hand.tap", "Menú de una app", "App options",
              "Mantén presionado un icono para abrir sus opciones. Puedes gestionar sus datos, icono, JIT y otras opciones según la app, o moverla después.",
              "Press and hold an icon to open its options. Manage data, artwork, JIT and other options when available, or move the app afterward."),
        .init("appdata", "externaldrive", "Datos, copias y contenedores", "App data and backups",
              "Desde las opciones de una app consulta sus contenedores, almacenamiento y copias de seguridad disponibles. No borres datos sin confirmar que tienes una copia.",
              "From an app’s options, review available containers, storage and backups. Do not delete data without checking that you have a backup."),
        .init("audio", "waveform", "Audio y acceso a red", "Audio and network access",
              "En las opciones de una app compatible puedes revisar el audio simultáneo, acceso a red y otras preferencias individuales.",
              "In a compatible app’s options, review simultaneous audio, network access and other per-app preferences."),
        .init("desktop", "slider.horizontal.3", "Personaliza el escritorio", "Customize Home",
              "Mantén presionado un espacio vacío para editar el escritorio. Cambia el fondo, iconos, páginas y otras opciones disponibles en tu launcher.",
              "Press and hold an empty area to edit Home. Change wallpaper, icons, pages and other options available in your launcher.", destination: "desktop"),
        .init("themes", "paintpalette", "Temas", "Themes",
              "Explora los temas de BloomBox, aplica uno o guarda tu diseño. Revisa qué elementos incluye antes de aplicarlo.",
              "Explore BloomBox themes, apply one or save your design. Review what a theme includes before applying it.", target: "manzana:themes", destination: "themes"),
        .init("widgets", "square.grid.2x2.fill", "Widgets", "Widgets",
              "En modo edición puedes añadir, colocar o modificar widgets. Nova y el escritorio iOS tienen sus propios controles.",
              "In edit mode you can add, place or modify widgets. Nova and iOS Home have their own controls.", destination: "widgets"),
        .init("dock", "rectangle.bottomthird.inset.filled", "Dock y carpetas", "Dock and folders",
              "Organiza tus accesos favoritos en el Dock. Agrupa apps en carpetas desde el escritorio según las opciones del launcher.",
              "Keep favorite shortcuts in the Dock. Group apps into folders using your launcher's Home controls.", target: "dock"),
        .init("news", "newspaper", "Noticias y actualizaciones", "News and updates",
              "Desliza hasta la página de noticias para consultar novedades, accesos rápidos y actualizaciones de BloomBox.",
              "Swipe to the News page for announcements, shortcuts and BloomBox updates.", target: "news", destination: "news"),
        .init("launchers", "circle.grid.3x3", "iOS, Nova e híbrido", "iOS, Nova and hybrid",
              "Desde Interfaz puedes elegir el escritorio que prefieras. La elección se conserva por perfil y no elimina tus apps.",
              "Choose your preferred launcher from Interface. Your choice is saved per profile and does not delete apps.", destination: "interface"),
        .init("home", "house", "Volver al escritorio", "Return to Home",
              "Puedes regresar de GameBox al escritorio sin cambiar tu launcher preferido ni tus aplicaciones.",
              "Return from GameBox to Home without changing your preferred launcher or installed apps.", destination: "home"),
        .init("gamebox", "gamecontroller.fill", "GameBox", "GameBox",
              "GameBox es la interfaz de consola de BloomBox, con carátulas, fondos y controles para juegos compatibles.",
              "GameBox is BloomBox's console interface, with artwork, backgrounds and controls for compatible games.", target: "gamebox", destination: "gamebox"),
        .init("controller", "gamecontroller", "Controles de juego", "Game controllers",
              "GameBox puede abrirse al conectar un mando compatible si activaste esa opción. Ajusta la preferencia desde Interfaz.",
              "GameBox can open when a compatible controller connects if you enabled that option. Adjust it from Interface.", destination: "interface"),
        .init("media", "music.note", "MediaBloom", "MediaBloom",
              "MediaBloom es una app independiente para música y video. Consulta sus funciones e integración por separado; no se instala con este recorrido.",
              "MediaBloom is a separate app for music and video. Explore its features and integration separately; this tour does not install it."),
        .init("settings", "gearshape", "Ajustes y seguridad", "Settings and safety",
              "Consulta la cuenta Apple, firmas, JIT y ajustes disponibles. Instala únicamente archivos de confianza; BloomBox no garantiza que sean seguros.",
              "Review Apple Account, signing, JIT and available settings. Only install files you trust; BloomBox cannot guarantee their safety.", destination: "settings"),
        .init("account", "person.crop.circle.badge.checkmark", "Cuenta Apple y renovación", "Apple Account and renewal",
              "Si SideStore está integrado, puedes consultar tu cuenta Apple en Ajustes y revisar las fechas de caducidad. El recorrido no solicita contraseñas.",
              "If SideStore is integrated, review your Apple Account in Settings and check expiry dates. The tour never asks for passwords.", destination: "settings"),
        .init("diagnostics", "waveform.path.ecg", "Diagnóstico y recuperación", "Diagnostics and recovery",
              "En Interfaz encontrarás Diagnósticos y recuperación. Si una sesión falla, consulta el registro antes de volver a intentar.",
              "Find Diagnostics and recovery in Interface. If a session fails, review the log before trying again.", destination: "diagnostics")
    ]
}

enum BloomBoxTourEvents {
    static let center = Notification.Name("BloomBoxTourCenterV1")
    static let explore = Notification.Name("BloomBoxTourExploreV1")
}

private struct BloomBoxTourCollectKey: EnvironmentKey {
    static let defaultValue = false
}
extension EnvironmentValues {
    var bloomBoxTourCollect: Bool {
        get { self[BloomBoxTourCollectKey.self] }
        set { self[BloomBoxTourCollectKey.self] = newValue }
    }
}
struct BloomBoxTourAnchors: PreferenceKey {
    static var defaultValue: [String: [Anchor<CGRect>]] { [:] }
    static func reduce(value: inout [String: [Anchor<CGRect>]], nextValue: () -> [String: [Anchor<CGRect>]]) {
        value.merge(nextValue(), uniquingKeysWith: +)
    }
}
private struct BloomBoxTourAnchorModifier: ViewModifier {
    @Environment(\.bloomBoxTourCollect) private var collect
    let key: String
    @ViewBuilder func body(content: Content) -> some View {
        if collect {
            content.anchorPreference(key: BloomBoxTourAnchors.self, value: .bounds) { [key: [$0]] }
        } else { content }
    }
}
extension View {
    func bloomBoxTourAnchor(_ key: String) -> some View {
        modifier(BloomBoxTourAnchorModifier(key: key))
    }
}

private struct BloomBoxTourShade: Shape {
    let hole: CGRect?
    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        if let hole { path.addRoundedRect(in: hole, cornerSize: CGSize(width: 15, height: 15)) }
        return path
    }
}

struct BloomBoxTourOverlay: View {
    let anchors: [String: [Anchor<CGRect>]]
    let index: Int
    let center: Bool
    let canExplore: Bool
    let seenTopics: Set<String>
    let onSelect: (Int) -> Void
    let onBack: () -> Void
    let onNext: () -> Void
    let onPause: () -> Void
    let onSkip: () -> Void
    let onCenter: () -> Void
    let onExplore: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme

    private var en: Bool { BloomBoxL10n.isEnglish }
    private var topics: [BloomBoxTourTopic] { BloomBoxTourTopic.all }
    private var safeIndex: Int { min(max(index, 0), topics.count - 1) }
    private var topic: BloomBoxTourTopic { topics[safeIndex] }
    private var accent: Color { BloomBoxWizardPalette.color(BloomBoxProfileStore.active.accentHex) }

    private func highlight(in geo: GeometryProxy) -> CGRect? {
        guard !center, let key = topic.target else { return nil }
        let bounds = CGRect(origin: CGPoint.zero, size: geo.size)
        let candidates: [Anchor<CGRect>] = anchors[key] ?? []
        var best: CGRect?
        var bestArea = CGFloat.greatestFiniteMagnitude
        for candidate in candidates {
            let rect: CGRect = geo[candidate]
            let width = rect.width
            let height = rect.height
            guard width.isFinite, height.isFinite, width > 8, height > 8 else { continue }
            let midpoint = CGPoint(x: rect.midX, y: rect.midY)
            guard bounds.contains(midpoint) else { continue }
            let visible = rect.intersection(bounds)
            let minimumWidth: CGFloat = width * 0.8
            let minimumHeight: CGFloat = height * 0.8
            guard !visible.isNull, visible.width >= minimumWidth,
                  visible.height >= minimumHeight else { continue }
            let area: CGFloat = width * height
            if area < bestArea {
                best = rect
                bestArea = area
            }
        }
        guard let best else { return nil }
        let expanded = best.insetBy(dx: -5, dy: -5)
        return expanded.intersection(bounds)
    }

    var body: some View {
        GeometryReader { geo in
            let hole = highlight(in: geo)
            ZStack {
                // Use exactly the same geometry for the shade and its spotlight.
                BloomBoxTourShade(hole: hole)
                    .fill(Color.black.opacity(0.57), style: FillStyle(eoFill: true))
                    .allowsHitTesting(false)
                Rectangle().fill(Color.clear).contentShape(Rectangle())
                    .onTapGesture {}.accessibilityHidden(true)
                if let hole {
                    RoundedRectangle(cornerRadius: 15)
                        .strokeBorder(accent, lineWidth: 2)
                        .frame(width: hole.width, height: hole.height)
                        .position(x: hole.midX, y: hole.midY)
                        .allowsHitTesting(false).accessibilityHidden(true)
                    if canExplore {
                        Button(action: onExplore) {
                            Color.clear.contentShape(Rectangle())
                        }.buttonStyle(.plain)
                            .frame(width: hole.width, height: hole.height)
                            .position(x: hole.midX, y: hole.midY)
                            .accessibilityLabel(en ? "Explore " + topic.title : "Explorar " + topic.title)
                    }
                }
                VStack(spacing: 0) {
                    if hole == nil || (hole?.midY ?? 0) < geo.size.height / 2 { Spacer(minLength: 0) }
                    if center { centerPanel } else { topicPanel }
                    if let hole, hole.midY >= geo.size.height / 2 { Spacer(minLength: 0) }
                }
                .frame(maxWidth: 480)
                .padding(.horizontal, 14).padding(.vertical, 10)
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: safeIndex)
        }
        .accessibilityIdentifier("bloombox.tour.overlay")
    }

    private var topicPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(en ? "BLOOMBOX GUIDE" : "GUÍA DE BLOOMBOX").font(.caption2.bold()).foregroundStyle(.secondary)
                Spacer()
                Text("\(safeIndex + 1) / \(topics.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            ProgressView(value: Double(safeIndex + 1), total: Double(topics.count)).tint(accent)
            ScrollView {
                explanation
            }.frame(maxHeight: 132)
            if canExplore {
                Button(action: onExplore) {
                    Label(en ? "Explore feature" : "Explorar función", systemImage: "arrow.up.right")
                        .frame(maxWidth: .infinity)
                }.buttonStyle(.bordered).tint(accent)
            }
            HStack {
                Button(en ? "Topics" : "Temas", action: onCenter)
                Spacer()
                Button(en ? "Pause" : "Pausar", action: onPause)
                Button(en ? "Skip tour" : "Omitir", action: onSkip)
            }.font(.caption.weight(.semibold))
            HStack {
                Button(action: onBack) { Image(systemName: "chevron.left").frame(minWidth: 44, minHeight: 36) }
                    .disabled(safeIndex == 0).accessibilityLabel(en ? "Back" : "Atrás")
                Spacer()
                Button(action: onNext) {
                    Text(safeIndex == topics.count - 1 ? (en ? "Finish" : "Finalizar") : (en ? "Next" : "Siguiente"))
                        .fontWeight(.semibold).frame(minWidth: 100, minHeight: 30)
                }.buttonStyle(.borderedProminent).tint(accent)
            }
        }
        .padding(17).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    private var explanation: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(topic.title, systemImage: topic.icon).font(.headline)
            Text(topic.detail).font(.subheadline).fixedSize(horizontal: false, vertical: true)
            if topic.destination != nil && !canExplore {
                Text(en ? "Return to Home to explore this feature." : "Regresa al escritorio para explorar esta función.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var centerPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(en ? "Learning center" : "Centro de aprendizaje", systemImage: "graduationcap.fill").font(.headline)
                Spacer()
                Button(action: onPause) { Image(systemName: "xmark.circle.fill").font(.title3) }
                    .accessibilityLabel(en ? "Close" : "Cerrar")
            }
            Button { onSelect(safeIndex) } label: {
                Label(en ? "Continue tour" : "Continuar recorrido", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }.buttonStyle(.borderedProminent).tint(accent)
            Button { onSelect(0) } label: {
                Label(en ? "Start from the beginning" : "Empezar desde el principio", systemImage: "arrow.counterclockwise")
            }.font(.subheadline)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(topics.enumerated()), id: \.element.id) { item in
                        Button { onSelect(item.offset) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: item.element.icon).frame(width: 28).foregroundStyle(accent)
                                Text(item.element.title).font(.subheadline)
                                Spacer()
                                if !seenTopics.isEmpty && !seenTopics.contains(item.element.id) {
                                    Text(en ? "New" : "Nuevo").font(.caption2.weight(.semibold)).foregroundStyle(accent)
                                }
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                            }.padding(.vertical, 12).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        Divider()
                    }
                }
            }.frame(maxHeight: 360)
        }.padding(18).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
    }
}
