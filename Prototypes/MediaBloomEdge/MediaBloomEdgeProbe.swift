import SwiftUI
import UIKit
import MediaPlayer

// MediaBloom Edge: a self-contained IPA to test inside BloomBox.
// This preview does NOT hook into YouTube Music or manipulate other guests.
// Four sample media shortcuts let us polish spacing and interaction first.
@main
struct MediaBloomEdgeProbeApp: App {
    var body: some Scene {
        WindowGroup {
            EdgePreview()
                .preferredColorScheme(.dark)
        }
    }
}

private enum EdgeTone {
    static let purple = Color(red: 0.60, green: 0.43, blue: 0.93)
    static let bg = Color(red: 0.075, green: 0.055, blue: 0.095)
    static let surface = Color(red: 0.14, green: 0.115, blue: 0.17)
}

// The same contour lives on screen throughout both states. Only its geometry
// changes, so the gel grows from the edge instead of sliding a rigid panel in.
private struct EdgeContour: Shape {
    var right: Bool
    var expansion: CGFloat

    var animatableData: CGFloat {
        get { expansion }
        set { expansion = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let t = max(0, min(1.12, expansion))
        let stretch = min(t, 1)
        let w = min(rect.width, 12 + (rect.width - 15) * t)
        // Height blooms early; the inward bulge catches up a fraction later.
        let h = min(rect.height, 80 + (rect.height - 80) * (1 - pow(1 - stretch, 1.35)))
        let y = (rect.height - h) / 2
        func pt(_ x: CGFloat, _ v: CGFloat) -> CGPoint {
            CGPoint(x: right ? rect.maxX - x * w : rect.minX + x * w,
                    y: rect.minY + y + v * h)
        }
        var p = Path()
        p.move(to: pt(0, 0))
        // A shallow, almost flat rail with soft shoulders at the screen edge.
        p.addCurve(to: pt(0.97, 0.16),
                   control1: pt(0, 0.075), control2: pt(0.97, 0.09))
        p.addCurve(to: pt(1, 0.50),
                   control1: pt(1, 0.24), control2: pt(1, 0.39))
        p.addCurve(to: pt(0.97, 0.84),
                   control1: pt(1, 0.61), control2: pt(1, 0.76))
        p.addCurve(to: pt(0, 1),
                   control1: pt(0.97, 0.91), control2: pt(0, 0.925))
        p.closeSubpath()
        return p
    }
}

private struct MediaShortcut: Identifiable {
    var id: Int
    var title: String
    var symbol: String
    var tint: Color
}

private struct EdgeDrawer: View {
    var right: Bool
    var opened: Bool
    var opacity: Double
    var onToggle: () -> Void
    var onSync: () -> Void
    var onApp: (MediaShortcut) -> Void

    private let apps: [MediaShortcut] = [
        .init(id: 0, title: "YouTube Music", symbol: "play.fill",
              tint: Color(red: 0.91, green: 0.13, blue: 0.18)),
        .init(id: 1, title: "Spotify", symbol: "music.note",
              tint: Color(red: 0.12, green: 0.67, blue: 0.36)),
        .init(id: 2, title: "VLC", symbol: "play.rectangle.fill",
              tint: Color(red: 0.99, green: 0.51, blue: 0.19)),
        .init(id: 3, title: "Apple Music", symbol: "music.quarternote.3",
              tint: Color(red: 0.91, green: 0.35, blue: 0.49))
    ]

    var body: some View {
        let anchor: Alignment = right ? .trailing : .leading
        let contour = EdgeContour(right: right, expansion: opened ? 1 : 0)
        ZStack(alignment: anchor) {
            contour
                .fill(Color.black.opacity(opacity))
                .contentShape(contour)
                .onTapGesture(perform: onToggle)

            // A generous touch target for the small closed tab.
            if !opened {
                Button(action: onToggle) {
                    Capsule()
                        .fill(EdgeTone.purple.opacity(0.7))
                        .frame(width: 2, height: 25)
                        .frame(width: 30, height: 88, alignment: right ? .trailing : .leading)
                        .padding(right ? .trailing : .leading, 5)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Abrir menú lateral")
                .transition(.opacity)
            }

            VStack(spacing: 10) {
                edgeButton("arrow.triangle.2.circlepath", fill: EdgeTone.purple,
                           label: "Resincronizar") { onSync() }
                // The unified volume control is rendered above this reserved slot.
                Color.clear
                    .frame(width: 45, height: 45)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                Rectangle()
                    .fill(Color.white.opacity(0.17))
                    .frame(width: 30, height: 1)
                    .padding(.vertical, 2)
                ForEach(apps) { app in
                    edgeButton(app.symbol, fill: app.tint, label: app.title) {
                        onApp(app)
                    }
                }
            }
            .frame(width: 66)
            .padding(right ? .trailing : .leading, 5)
            .scaleEffect(opened ? 1 : 0.55, anchor: right ? .trailing : .leading)
            .offset(x: opened ? 0 : (right ? 28 : -28))
            .opacity(opened ? 1 : 0)
            .animation(opened ? .easeOut(duration: 0.23).delay(0.12) : .easeOut(duration: 0.10),
                       value: opened)
            .allowsHitTesting(opened)
            .accessibilityHidden(!opened)
        }
        .accessibilityElement(children: .contain)
    }

    private func edgeButton(_ symbol: String, fill: Color,
                            label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
                .frame(width: 45, height: 45)
                .background(Circle().fill(fill))
                .overlay(Circle().stroke(Color.white.opacity(0.19), lineWidth: 0.9))
                .shadow(color: .black.opacity(0.26), radius: 3, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

private struct SystemVolumeSlider: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView()
        view.showsRouteButton = false
        view.showsVolumeSlider = true
        view.tintColor = UIColor.systemPurple
        return view
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}

// One capsule for both states; its outer edge and speaker stay fixed.
private struct JellyVolumeControl: View {
    var right: Bool
    var expanded: Bool
    var maximumWidth: CGFloat
    var onToggle: () -> Void

    private let diameter: CGFloat = 45

    var body: some View {
        HStack(spacing: 0) {
            if right { slider }
            speaker
            if !right { slider }
        }
        .frame(width: expanded ? maximumWidth : diameter, height: diameter,
               alignment: right ? .trailing : .leading)
        .background {
            Capsule()
                .fill(Color(red: 0.18, green: 0.18, blue: 0.20).opacity(0.98))
                .overlay(Capsule().stroke(Color.white.opacity(0.13), lineWidth: 0.9))
        }
        .clipShape(Capsule())
        .contentShape(Capsule())
    }

    private var speaker: some View {
        Button(action: onToggle) {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 19, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
                .frame(width: diameter, height: diameter)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(expanded ? "Cerrar volumen" : "Abrir volumen")
    }

    private var slider: some View {
        SystemVolumeSlider()
            .frame(width: max(1, maximumWidth - diameter - 16), height: 30)
            .padding(right ? .leading : .trailing, 12)
            .padding(right ? .trailing : .leading, 4)
            .frame(width: expanded ? max(0, maximumWidth - diameter) : 0,
                   alignment: right ? .trailing : .leading)
            .clipped()
            .opacity(expanded ? 1 : 0)
            .allowsHitTesting(expanded)
            .accessibilityHidden(!expanded)
            .accessibilityLabel("Volumen de iOS")
    }
}

private struct EdgePreview: View {
    @AppStorage("MBEdgeProbeRightV1") private var onRight = false
    @AppStorage("MBEdgeProbeHeightV1") private var relativeY = 0.54
    @AppStorage("MediaBloomEdgeOpacityV1") private var edgeOpacity = 1.0
    @State private var showEdgeSettings = false
    @State private var opened = false
    @State private var volumeOpen = false
    @State private var synchronizing = false
    @State private var headline = "MediaBloom Edge"
    @State private var subtitle = "Prueba de HotSwap dentro de BloomBox"
    @State private var currentSong = "Tu música, sin salir del reproductor"
    @State private var showNotice = false
    @State private var playing = true
    @State private var progress = 0.35

    private let menuHeight: CGFloat = 426
    private let menuWidth: CGFloat = 82
    // The column is 335 pt tall (six 45 pt buttons, six 10 pt gaps,
    // and a 5 pt separator). Its second button is 90 pt above center.
    private let volumeButtonY: CGFloat = -90
    private let volumeButtonInset: CGFloat = 38
    private let jellySpring = Animation.spring(response: 0.52, dampingFraction: 0.67, blendDuration: 0.12)

    var body: some View {
        GeometryReader { geo in
            let panelHeight = min(menuHeight, max(1, geo.size.height - 16))
            let panelScale = panelHeight / menuHeight
            let panelY = clampedY(in: geo, height: panelHeight)
            let volumeStart = volumeButtonInset - 22.5
            let volumeWidth = min(215, max(45, geo.size.width - volumeStart - 16))
            let volumeX = onRight ? geo.size.width - volumeStart - volumeWidth / 2 : volumeStart + volumeWidth / 2
            ZStack {
                background
                demoPlayer(in: geo)
                if opened {
                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(jellySpring) {
                                opened = false
                                volumeOpen = false
                            }
                        }
                }
                EdgeDrawer(
                    right: onRight,
                    opened: opened,
                    opacity: edgeOpacity,
                    onToggle: toggleDrawer,
                    onSync: syncPreview,
                    onApp: selectApp
                )
                .frame(width: menuWidth, height: menuHeight)
                .scaleEffect(x: 1, y: panelScale)
                .position(x: onRight ? geo.size.width - menuWidth / 2 : menuWidth / 2,
                          y: panelY)
                .zIndex(3)
                .simultaneousGesture(DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        guard abs(value.translation.height) > abs(value.translation.width) else { return }
                        withAnimation(jellySpring) {
                            relativeY = Double(max(0.20, min(0.80,
                                CGFloat(relativeY) +
                                value.translation.height / max(geo.size.height, 1))))
                        }
                    })
                if opened {
                    JellyVolumeControl(right: onRight, expanded: volumeOpen,
                                       maximumWidth: volumeWidth) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(jellySpring) {
                            volumeOpen.toggle()
                        }
                    }
                    .frame(width: volumeWidth, height: 45,
                           alignment: onRight ? .trailing : .leading)
                    .scaleEffect(x: 1, y: panelScale)
                    .position(x: volumeX, y: panelY + volumeButtonY * panelScale)
                    .transition(.opacity)
                    .zIndex(4)
                }
                if showNotice {
                    VStack {
                        Spacer()
                        Text(subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 17)
                            .padding(.vertical, 11)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(.bottom, 105)
                    }
                    .transition(.opacity)
                    .allowsHitTesting(false)
                    .zIndex(5)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .animation(jellySpring, value: opened)
            .sheet(isPresented: $showEdgeSettings) {
                NavigationView {
                    Form {
                        Section(header: Text("MediaBloom Edge")) {
                            Text("Opacidad: \(Int((edgeOpacity * 100).rounded()))%")
                            Slider(value: $edgeOpacity, in: 0...1, step: 0.01)
                            Button("Negro puro") { edgeOpacity = 1 }
                        }
                    }
                    .navigationTitle("Ajustes")
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Listo") { showEdgeSettings = false } } }
                }
            }
        }
    }

    private func clampedY(in geometry: GeometryProxy, height: CGFloat) -> CGFloat {
        let half = height / 2
        return min(max(geometry.size.height * relativeY, half + 8),
                   max(half + 8, geometry.size.height - half - 8))
    }

    private func toggleDrawer() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(jellySpring) {
            opened.toggle()
            if !opened { volumeOpen = false }
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.22, green: 0.09, blue: 0.20),
                EdgeTone.bg,
                Color(red: 0.07, green: 0.05, blue: 0.11)
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private func demoPlayer(in geo: GeometryProxy) -> some View {
        let width = min(geo.size.width - 76, 360.0)
        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "music.note")
                    .foregroundStyle(EdgeTone.purple)
                Text("MEDIABLOOM EDGE")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(2.0)
                Spacer()
                Button { showEdgeSettings = true } label: {
                    Image(systemName: "gearshape").font(.system(size: 17)).frame(width: 38, height: 38)
                }
                .accessibilityLabel("Ajustes del borde")
                Button {
                    withAnimation { onRight.toggle() }
                    notice("Borde: \(onRight ? "derecho" : "izquierdo")")
                } label: {
                    Image(systemName: "arrow.left.and.right")
                        .font(.system(size: 17, weight: .medium))
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .accessibilityLabel("Cambiar de borde")
            }
            .padding(.horizontal, 25)
            .padding(.top, 22)

            Spacer(minLength: 35)

            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [EdgeTone.purple.opacity(0.86),
                                     Color(red: 0.19, green: 0.16, blue: 0.35),
                                     Color(red: 0.44, green: 0.23, blue: 0.41)],
                            startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 30)
                    .frame(width: width * 0.67, height: width * 0.67)
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 2)
                    .frame(width: width * 0.38, height: width * 0.38)
                Image(systemName: "headphones")
                    .font(.system(size: width * 0.34, weight: .ultraLight))
                    .foregroundStyle(.white.opacity(0.95))
                VStack {
                    Spacer()
                    Text("UI PROBE  ·  NO STREAMING")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.65))
                        .padding(.bottom, 18)
                }
            }
            .frame(width: width, height: width)
            .shadow(color: EdgeTone.purple.opacity(0.18), radius: 24, y: 10)

            VStack(alignment: .leading, spacing: 5) {
                Text(headline)
                    .font(.system(size: 24, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(currentSong)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.57))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 38)
            .padding(.top, 24)

            Spacer(minLength: 14)

            VStack(spacing: 10) {
                Slider(value: $progress, in: 0...1)
                    .tint(.white)
                HStack {
                    Text("1:28")
                    Spacer()
                    Text("4:13")
                }
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.52))
            }
            .padding(.horizontal, 36)

            HStack(spacing: 53) {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 23))
                Button {
                    playing.toggle()
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                } label: {
                    Image(systemName: playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 66, height: 66)
                        .background(.white, in: Circle())
                }
                .accessibilityLabel(playing ? "Pausar demostración" : "Reanudar demostración")
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 23))
            }
            .padding(.top, 25)

            Spacer(minLength: 28)

            VStack(spacing: 7) {
                Text("Toca la pestañita del borde para abrir el panel")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.79))
                Text("Botones de apps y sincronización: demostración")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.43))
            }
            .multilineTextAlignment(.center)
            .padding(.bottom, 24)
        }
        .foregroundStyle(.white)
    }

    private func syncPreview() {
        guard !synchronizing else { return }
        synchronizing = true
        volumeOpen = false
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        notice("Resincronizando · demostración visual")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            synchronizing = false
            notice("Listo · la conexión real será en MediaBloom")
        }
    }

    private func selectApp(_ app: MediaShortcut) {
        headline = app.title
        currentSong = "Acceso rápido de muestra • HotSwap pendiente"
        withAnimation(jellySpring) {
            opened = false
            volumeOpen = false
        }
        UISelectionFeedbackGenerator().selectionChanged()
        notice("\(app.title) seleccionado · demo")
    }

    private func notice(_ message: String) {
        subtitle = message
        withAnimation(.easeInOut(duration: 0.18)) { showNotice = true }
        let value = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            if subtitle == value {
                withAnimation(.easeOut(duration: 0.2)) {
                    showNotice = false
                }
            }
        }
    }
}
