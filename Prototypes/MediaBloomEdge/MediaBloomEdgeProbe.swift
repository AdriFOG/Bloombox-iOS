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
        let w = min(rect.width, 13 + (rect.width - 20) * t)
        // Height blooms early; the inward bulge catches up a fraction later.
        let h = min(rect.height, 80 + (rect.height - 80) * (1 - pow(1 - stretch, 1.35)))
        let y = (rect.height - h) / 2
        func pt(_ x: CGFloat, _ v: CGFloat) -> CGPoint {
            CGPoint(x: right ? rect.maxX - x * w : rect.minX + x * w,
                    y: rect.minY + y + v * h)
        }
        var p = Path()
        p.move(to: pt(0, 0))
        p.addCurve(to: pt(0.80, 0.21),
                   control1: pt(0, 0.09), control2: pt(0.69, 0.10))
        p.addCurve(to: pt(1, 0.50),
                   control1: pt(0.96, 0.37), control2: pt(1, 0.40))
        p.addCurve(to: pt(0.80, 0.79),
                   control1: pt(1, 0.60), control2: pt(0.96, 0.63))
        p.addCurve(to: pt(0, 1),
                   control1: pt(0.69, 0.90), control2: pt(0, 0.91))
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
    var onToggle: () -> Void
    var onSync: () -> Void
    var onVolume: () -> Void
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
                .fill(LinearGradient(
                    colors: [Color.black.opacity(0.96),
                             Color(red: 0.13, green: 0.11, blue: 0.16).opacity(0.86)],
                    startPoint: right ? .trailing : .leading,
                    endPoint: right ? .leading : .trailing))
                .overlay {
                    contour.stroke(Color.white.opacity(0.10), lineWidth: 0.8)
                }
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
                edgeButton("speaker.wave.2.fill", fill: Color.white.opacity(0.19),
                           label: "Volumen") { onVolume() }
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

private struct EdgePreview: View {
    @AppStorage("MBEdgeProbeRightV1") private var onRight = false
    @AppStorage("MBEdgeProbeHeightV1") private var relativeY = 0.54
    @State private var opened = false
    @State private var volumeOpen = false
    @State private var synchronizing = false
    @State private var headline = "MediaBloom Edge"
    @State private var subtitle = "Prueba de HotSwap dentro de BloomBox"
    @State private var currentSong = "Tu música, sin salir del reproductor"
    @State private var showNotice = false
    @State private var playing = true
    @State private var progress = 0.35

    private let menuHeight: CGFloat = 462
    private let menuWidth: CGFloat = 120
    private let jellySpring = Animation.spring(response: 0.52, dampingFraction: 0.67, blendDuration: 0.12)

    var body: some View {
        GeometryReader { geo in
            let panelHeight = min(menuHeight, max(1, geo.size.height - 16))
            let volumeWidth = min(226, max(100, geo.size.width - menuWidth - 20))
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
                if volumeOpen && opened {
                    volumePopup
                        .frame(width: volumeWidth)
                        .position(x: onRight ? geo.size.width - menuWidth - 8 - volumeWidth / 2 : menuWidth + 8 + volumeWidth / 2,
                                  y: max(165, min(geo.size.height - 150,
                                                geo.size.height * relativeY - 120)))
                        .transition(.opacity.combined(with: .scale(scale: 0.94)))
                        .zIndex(2)
                }
                EdgeDrawer(
                    right: onRight,
                    opened: opened,
                    onToggle: toggleDrawer,
                    onSync: syncPreview,
                    onVolume: {
                        withAnimation(.easeOut(duration: 0.18)) {
                            volumeOpen.toggle()
                        }
                    },
                    onApp: selectApp
                )
                .frame(width: menuWidth, height: menuHeight)
                .scaleEffect(x: 1, y: panelHeight / menuHeight)
                .position(x: onRight ? geo.size.width - menuWidth / 2 : menuWidth / 2,
                          y: clampedY(in: geo, height: panelHeight))
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
                    .zIndex(4)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .animation(jellySpring, value: opened)
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

    private var volumePopup: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 7) {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(EdgeTone.purple)
                Text("Volumen de iOS")
                    .font(.system(size: 13, weight: .semibold))
            }
            SystemVolumeSlider()
                .frame(height: 32)
            Text("Control real del volumen del sistema")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(17)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 19))
        .overlay(RoundedRectangle(cornerRadius: 19)
            .stroke(.white.opacity(0.08), lineWidth: 1))
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
