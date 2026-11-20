import SwiftUI
import CryptoKit
import PhotosUI
import UniformTypeIdentifiers

struct BloomBoxThemeShareSheet: UIViewControllerRepresentable {
    let fileURL: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}


func liveBoardAppKey(_ app: LCAppModel) -> String {
    if app.appInfo is BuiltInSideStoreAppInfo { return "builtin:sidestore" }
    return "\(app.uiIsShared ? "shared" : "local"):\(app.appInfo.relativeBundlePath ?? app.bundleIdentifier)"
}

// BloomBox Alive: view-only motion, no launcher state or guest app data changes.
struct BloomBoxAliveIconFrames: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

struct BloomBoxAliveEntrance: ViewModifier {
    let entranceEnabled: Bool
    let revealed: Bool
    let delay: Double
    let playfulStyle: Int?
    let playfulActive: Bool

    func body(content: Content) -> some View {
        content
            .opacity(!entranceEnabled || revealed ? 1 : 0)
            .scaleEffect(!entranceEnabled || revealed ? 1 : 0.46, anchor: .bottom)
            .offset(y: entranceEnabled && !revealed ? 22 : 0)
            .offset(y: playfulActive && playfulStyle == 0 ? -11 : 0)
            .offset(x: playfulActive && playfulStyle == 1 ? 4 : 0)
            .rotationEffect(.degrees(playfulActive && playfulStyle == 2 ? 9 : 0))
            .animation(.spring(response: 0.39, dampingFraction: 0.59).delay(entranceEnabled ? delay : 0),
                       value: revealed)
            .animation(.spring(response: 0.21, dampingFraction: 0.35), value: playfulActive)
    }
}

// Keep multiple photo/file sheets out of the huge Home ViewBuilder expression.
struct BloomBoxWidgetMediaPresentation: ViewModifier {
    @Binding var sourcePresented: Bool
    @Binding var photoPresented: Bool
    @Binding var filePresented: Bool
    @Binding var importing: Bool
    let openPhotos: () -> Void
    let openFiles: () -> Void
    let cancel: () -> Void
    let photoResult: (Data?, Bool) -> Void
    let fileResult: (Result<URL, Error>) -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog("Foto o GIF para el widget",
                                isPresented: $sourcePresented,
                                titleVisibility: .visible) {
                Button(BloomBoxL10n.t("Elegir de Fotos"), action: openPhotos)
                Button(BloomBoxL10n.t("Importar de Archivos"), action: openFiles)
                Button("Cancelar", role: .cancel, action: cancel)
            }
            .sheet(isPresented: $photoPresented) {
                BloomBoxMediaPhotosPicker(completion: photoResult)
            }
            .fileImporter(isPresented: $filePresented,
                          allowedContentTypes: [.image, .gif],
                          onCompletion: fileResult)
            .overlay {
                if importing {
                    ProgressView("Importando imagen o GIF…")
                        .padding(22)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                }
            }
    }
}

/// Keep a stable tile identity throughout editing. A local drag on an explicit
/// handle avoids UIKit lifting/hiding the animated media view for drag-and-drop.
struct BloomBoxWidgetInteraction<MenuContent: View>: ViewModifier {
    let editing: Bool
    let select: () -> Void
    let move: (CGSize) -> Void
    let menu: () -> MenuContent
    @GestureState(resetTransaction: Transaction(animation: nil)) private var translation = CGSize.zero

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .contextMenu {
                // Editing has its own options button; do not let a long-press
                // menu recognizer compete with the movement handle.
                if !editing { menu() }
            }
            .overlay(alignment: .bottomLeading) {
                if editing {
                    Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.72), in: Circle())
                        .contentShape(Rectangle())
                        .padding(4)
                        .highPriorityGesture(
                            // The page sits inside TabView's UIKit host. Use the fixed
                            // screen coordinate space, never the moving tile/page space.
                            DragGesture(minimumDistance: 2, coordinateSpace: .global)
                                .updating($translation) { value, state, transaction in
                                    transaction.animation = nil
                                    transaction.disablesAnimations = true
                                    state = value.translation
                                }
                                .onChanged { _ in select() }
                                .onEnded { value in move(value.translation) }
                        )
                        .accessibilityLabel(BloomBoxL10n.t("Arrastrar widget"))
                        .accessibilityHint("Usa Opciones para moverlo a otra página")
                }
            }
            .offset(translation)
            // Finger tracking must be immediate, including gesture reset and
            // the grid-position commit. Never interpolate successive samples.
            .transaction { transaction in
                // Live drag never lerps behind the finger; normal widgets
                // must still receive the BloomBox Alive entrance spring.
                if editing {
                    transaction.animation = nil
                    transaction.disablesAnimations = true
                }
            }
    }
}

// Living widgets move using repeatForever animations committed to Core Animation,
// not a 30 FPS TimelineView that re-evaluates SwiftUI body on every frame.
struct BloomBoxLivingMotion: ViewModifier {
    let mode: String
    let speed: Double
    let travel: Double
    let enabled: Bool
    @State private var xForward = false
    @State private var yForward = false

    @ViewBuilder func body(content: Content) -> some View {
        if enabled && mode != "none" {
            let distance = CGFloat(max(0, min(100, travel))) * 0.65
            let duration = 0.5 / (0.15 + max(0, min(100, speed)) / 100 * 0.75)
            let xDistance = (mode == "horizontal" || mode == "wander") ? distance : 0
            let yDistance = mode == "float" ? distance * 0.45 :
                mode == "wander" ? distance * 0.35 : 0
            content
                .offset(x: xForward ? xDistance : -xDistance)
                .animation(.easeInOut(duration: duration * (mode == "wander" ? 1.59 : 1))
                    .repeatForever(autoreverses: true), value: xForward)
                .offset(y: yForward ? yDistance : -yDistance)
                .animation(.easeInOut(duration: duration * (mode == "wander" ? 1.27 : 1))
                    .repeatForever(autoreverses: true), value: yForward)
                .onAppear { xForward = true; yForward = true }
                .onDisappear { xForward = false; yForward = false }
        } else {
            content
        }
    }
}

