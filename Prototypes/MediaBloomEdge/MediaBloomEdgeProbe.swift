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

private struct EdgeContour: Shape {
    var right: Bool

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: w * 0.52, y: 0))
        p.addCurve(to: CGPoint(x: w * 0.65, y: h * 0.14),
                   control1: CGPoint(x: w * 0.58, y: 0),
                   control2: CGPoint(x: w * 0.64, y: h * 0.08))
        p.addCurve(to: CGPoint(x: w * 0.96, y: h * 0.36),
                   control1: CGPoint(x: w * 0.80, y: h * 0.24),
                   control2: CGPoint(x: w * 0.96, y: h * 0.29))
        p.addCurve(to: CGPoint(x: w * 0.96, y: h * 0.64),
                   control1: CGPoint(x: w * 1.02, y: h * 0.45),
                   control2: CGPoint(x: w * 1.02, y: h * 0.55))
        p.addCurve(to: CGPoint(x: w * 0.65, y: h * 0.86),
                   control1: CGPoint(x: w * 0.96, y: h * 0.73),
                   control2: CGPoint(x: w * 0.80, y: h * 0.76))
        p.addCurve(to: CGPoint(x: w * 0.52, y: h),
                   control1: CGPoint(x: w * 0.64, y: h * 0.92),
                   control2: CGPoint(x: w * 0.58, y: h))
        p.addLine(to: CGPoint(x: 0, y: h))
        p.closeSubpath()
        if right {
            return p.applying(CGAffineTransform(translationX: w, y: 0)
                .scaledBy(x: -1, y: 1))
        }
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
        ZStack(alignment: right ? .trailing : .leading) {
            EdgeContour(right: right)
                .fill(Color.black.opacity(0.96))
                .overlay {
                    EdgeContour(right: right)
                        .stroke(Color.white.opacity(0.10), lineWidth: 0.7)
                }
            VStack(spacing: 13) {
                edgeButton("arrow.triangle.2.circlepath", fill: EdgeTone.purple,
                           label: "Resincronizar") { onSync() }
                edgeButton("speaker.wave.2.fill", fill: Color.white.opacity(0.19),
                           label: "Volumen") { onVolume() }
                Rectangle()
                    .fill(Color.white.opacity(0.17))
                    .frame(width: 33, height: 1)
                    .padding(.vertical, 2)
                ForEach(apps) { app in
                    edgeButton(app.symbol, fill: app.tint, label: app.title) {
                        onApp(app)
                    }
                }
            }
            .frame(width: 74)
            .padding(.leading, right ? 0 : 8)
            .padding(.trailing, right ? 8 : 0)
            .padding(.vertical, 12)
        }
        .frame(width: 138, height: 414)
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

    private let menuHeight: CGFloat = 414
    private let menuWidth: CGFloat = 138

    var body: some View {
        GeometryReader { geo in
            ZStack {
                background
                demoPlayer(in: geo)
                if opened {
                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.33,
                                                  dampingFraction: 0.86)) {
                                opened = false
                                volumeOpen = false
                            }
                        }
                }
                if volumeOpen && opened {
                    volumePopup
                        .frame(width: 226)
                        .position(x: onRight ? geo.size.width - 168 : 168,
                                  y: max(165, min(geo.size.height - 150,
                                                geo.size.height * relativeY - 120)))
                        .transition(.opacity.combined(with: .scale(scale: 0.94)))
                        .zIndex(2)
                }
                if opened {
                    EdgeDrawer(
                        right: onRight,
                        onSync: syncPreview,
                        onVolume: {
                            withAnimation(.easeOut(duration: 0.18)) {
                                volumeOpen.toggle()
                            }
                        },
                        onApp: selectApp
                    )
                    .position(x: onRight ? geo.size.width - menuWidth / 2 : menuWidth / 2,
                              y: clampedY(in: geo))
                    .transition(.move(edge: onRight ? .trailing : .leading)
                        .combined(with: .opacity))
                    .zIndex(3)
                    .gesture(DragGesture(minimumDistance: 20)
                        .onEnded { value in
                            relativeY = Double(max(0.28, min(0.72,
                                CGFloat(relativeY) +
                                value.translation.height / max(geo.size.height, 1))))
                        })
                } else {
                    Capsule()
                        .fill(Color.black)
                        .frame(width: 12, height: 80)
                        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                        .overlay {
                            Capsule()
                                .fill(EdgeTone.purple.opacity(0.7))
                                .frame(width: 2, height: 27)
                        }
                        .position(x: onRight ? geo.size.width - 6 : 6,
                                  y: clampedY(in: geo))
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35,
                                                  dampingFraction: 0.83)) {
                                opened = true
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        .transition(.opacity)
                        .zIndex(3)
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
                    .zIndex(4)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .animation(.spring(response: 0.35, dampingFraction: 0.86),
                       value: opened)
        }
    }

    private func clampedY(in geometry: GeometryProxy) -> CGFloat {
        let half = menuHeight / 2
        return min(max(geometry.size.height * relativeY, half + 32),
                   max(half + 32, geometry.size.height - half - 32))
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
        withAnimation(.spring(response: 0.33, dampingFraction: 0.85)) {
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
