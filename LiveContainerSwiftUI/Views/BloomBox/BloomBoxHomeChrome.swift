import SwiftUI
import UIKit
import ImageIO

// The original 3DS-style celebration sits on top of the real launcher.
// It reports actual installation progress; a short hold is done by the host.
struct BloomBoxHomeInstallationNotice: View {
    let progress: Double
    let completed: Bool
    let reduceMotion: Bool
    let accentColor: Color
    @State private var hop = false

    private var amount: Double {
        progress.isFinite ? min(completed ? 1 : 0.98, max(0, progress)) : 0
    }

    var body: some View {
        GeometryReader { bounds in
            ZStack {
                Color.black.opacity(0.48).ignoresSafeArea()

                VStack(spacing: 13) {
                    HStack(alignment: .bottom, spacing: 0) {
                        ForEach(Array(BloomBoxL10n.t(completed ? "¡Instalada!" : "Instalando...").enumerated()), id: \.offset) { index, character in
                            Text(String(character))
                                .font(.system(size: min(43, bounds.size.width / 9.7),
                                              weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .shadow(color: accentColor.opacity(0.85), radius: 3, y: 4)
                                .shadow(color: .black.opacity(0.35), radius: 9, y: 3)
                                .offset(y: reduceMotion || completed ? 0 :
                                    (hop == (index.isMultiple(of: 2)) ? -7 : 3))
                                .animation(reduceMotion ? nil :
                                    .easeInOut(duration: 0.46).repeatForever(autoreverses: true)
                                        .delay(Double(index) * 0.055), value: hop)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(BloomBoxL10n.t(completed ? "¡Instalada!" : "Instalando..."))

                    GeometryReader { bar in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.96))
                                .shadow(color: accentColor.opacity(0.55), radius: 16)
                            Capsule().fill(accentColor.opacity(0.20))
                                .padding(8)
                            Capsule()
                                .fill(LinearGradient(colors: [
                                    accentColor.opacity(0.55),
                                    accentColor
                                ], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: max(0, (bar.size.width - 16) * amount))
                                .overlay(alignment: .leading) {
                                    Capsule().stroke(.white.opacity(0.55), lineWidth: 1)
                                }
                                .padding(8)
                                .animation(.easeOut(duration: 0.26), value: amount)
                            Text("\(Int(amount * 100))%")
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(Color.black.opacity(0.78))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .padding(.trailing, 19)
                        }
                    }
                    .frame(height: 71)
                    .padding(.horizontal, 22)

                    ZStack {
                        Ellipse().fill(accentColor.opacity(0.25))
                            .frame(width: 230, height: 30)
                            .blur(radius: 13)
                            .offset(y: 70)
                        if reduceMotion {
                            BloomBoxSleepingKirbyPlayer(animated: false)
                        } else {
                            BloomBoxSleepingKirbyPlayer(animated: true)
                        }
                    }
                    .frame(width: min(bounds.size.width - 80, 270), height: 176)
                    .padding(.top, 5)

                    Text(BloomBoxL10n.t(completed
                        ? "¡Tu regalo ya está en el escritorio!"
                        : "Preparando tu nueva app..."))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.88))
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .position(x: bounds.size.width / 2, y: bounds.size.height * 0.51)
            }
            .onAppear { hop = true }
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(BloomBoxL10n.t(completed ? "¡Instalada!" : "Instalando..."))
        .accessibilityValue("\(Int(amount * 100)) %")
        .accessibilityAddTraits(.updatesFrequently)
    }
}

// A downscaled nearest-neighbor copy of the six-frame GIF supplied for
// BloomBox. The official iOS bundle picks it up from the packaged IPA.
private struct BloomBoxSleepingKirbyPlayer: UIViewRepresentable {
    let animated: Bool

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.backgroundColor = .clear
        view.layer.magnificationFilter = .nearest
        guard let url = Bundle.main.url(forResource: "BloomBoxSleepingKirby", withExtension: "gif"),
              let data = try? Data(contentsOf: url),
              let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return view
        }
        var images: [UIImage] = []
        var duration = 0.0
        for index in 0..<CGImageSourceGetCount(source) {
            guard let cg = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            images.append(UIImage(cgImage: cg))
            let dict = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [String: Any]
            let gif = dict?[kCGImagePropertyGIFDictionary as String] as? [String: Any]
            duration += (gif?[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double)
                ?? (gif?[kCGImagePropertyGIFDelayTime as String] as? Double) ?? 0.2
        }
        if let first = images.first {
            view.image = first
            if animated && images.count > 1 {
                view.animationImages = images
                view.animationDuration = max(0.1, duration)
                view.animationRepeatCount = 0
                view.startAnimating()
            }
        }
        return view
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        if animated && !uiView.isAnimating { uiView.startAnimating() }
        if !animated && uiView.isAnimating { uiView.stopAnimating() }
    }
}

// A one-tap Nintendo 3DS-inspired present; a second tap on the revealed
// real app icon runs the guest through the usual signing/JIT route.
struct BloomBoxHomeGiftIcon: View {
    let name: String
    let size: CGFloat
    let showLabel: Bool
    let reduceMotion: Bool
    let reveal: () -> Void
    @State private var opening = false
    @State private var rattling = false

    var body: some View {
        Button {
            guard !opening else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            if reduceMotion {
                reveal()
            } else {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.55)) {
                    opening = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) {
                    reveal()
                }
            }
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.23)
                        .fill(LinearGradient(colors: [
                            Color(red: 1, green: 0.88, blue: 0.72),
                            Color(red: 1, green: 0.55, blue: 0.67)
                        ], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay {
                            RoundedRectangle(cornerRadius: size * 0.23)
                                .strokeBorder(.white.opacity(0.8), lineWidth: 2)
                        }
                        .shadow(color: Color.pink.opacity(0.65), radius: 12, y: 4)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(red: 0.95, green: 0.18, blue: 0.50))
                        .frame(width: size * 0.20, height: size * 0.72)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(red: 0.95, green: 0.18, blue: 0.50))
                        .frame(width: size * 0.74, height: size * 0.17)
                    Image(systemName: "gift.fill")
                        .font(.system(size: size * 0.45, weight: .bold))
                        .foregroundStyle(.white.opacity(0.92))
                        .shadow(color: .pink, radius: 4)
                        .offset(y: -size * 0.18)
                    Image(systemName: "sparkle")
                        .font(.system(size: size * 0.23, weight: .bold))
                        .foregroundStyle(.yellow)
                        .offset(x: size * 0.34, y: -size * 0.35)
                }
                .frame(width: size, height: size)
                .scaleEffect(opening ? 1.45 : 1)
                .rotationEffect(.degrees(opening ? -12 : (rattling ? 6 : 0)))
                .offset(x: opening ? 0 : (rattling ? 2 : 0))
                .animation(reduceMotion ? nil :
                    .easeInOut(duration: 0.095).repeatCount(6, autoreverses: true),
                    value: rattling)
                .opacity(opening ? 0 : 1)
                if showLabel {
                    Text(name)
                        .font(.system(size: 11))
                        .lineLimit(1)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.72), radius: 3, y: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .task(id: reduceMotion) {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 2_700_000_000) }
                catch { break }
                guard !opening else { break }
                rattling = true
                do { try await Task.sleep(nanoseconds: 700_000_000) }
                catch { break }
                rattling = false
            }
        }
        .accessibilityLabel(BloomBoxL10n.isEnglish
            ? "Open gift to reveal \(name)"
            : "Abrir regalo para descubrir \(name)")
        .accessibilityIdentifier("bloombox.home.gift")
    }
}

/// Only overlays the existing wallpaper; does not start a duplicate video/GIF
/// player or intercept icon taps while the Home entrance animation plays.
struct BloomBoxHomeWelcome: View {
    let message: String
    let visible: Bool
    var body: some View {
        ZStack {
            Rectangle().fill(.regularMaterial)
            Color.black.opacity(0.22)
            VStack(spacing: 12) {
                Text("BloomBox")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .tracking(-2)
                    .shadow(color: .white.opacity(0.25), radius: 23)
                Text(BloomBoxL10n.t(message))
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(red: 1, green: 0.87, blue: 0.38))
                    .shadow(color: .black.opacity(0.5), radius: 8, y: 3)
                    .rotationEffect(.degrees(-5))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 28)
            }
            .scaleEffect(visible ? 1 : 1.05)
        }
        .ignoresSafeArea()
        .opacity(visible ? 1 : 0)
        .animation(.easeInOut(duration: 0.27), value: visible)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Keep Edit/Done buttons inside a shallow top toolbar, never a full-screen
/// overlay that steals touches from pages, folders and animated widgets.
struct BloomBoxHomeEditorToolbar: View {
    @Binding var exportURL: URL?
    let addWidget: () -> Void
    let customize: () -> Void
    let exportTheme: () -> Void
    let addPage: () -> Void
    let managePages: () -> Void
    let openLibrary: () -> Void
    let finish: () -> Void

    var body: some View {
        HStack {
            Menu {
                Button("Añadir widget", systemImage: "square.grid.2x2.badge.plus",
                       action: addWidget)
                Button("Personalizar", systemImage: "paintbrush", action: customize)
                Button("Exportar tema", systemImage: "square.and.arrow.up",
                       action: exportTheme)
                Button("Añadir página", systemImage: "plus", action: addPage)
                Button("Gestionar páginas", systemImage: "square.grid.2x2",
                       action: managePages)
                Button("Biblioteca de apps", systemImage: "square.grid.2x2",
                       action: openLibrary)
            } label: {
                Text(BloomBoxL10n.t("Editar"))
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 18)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .liveBoardGlass(radius: 18, interactive: false)
            .accessibilityIdentifier("bloombox.home.edit")
            Spacer(minLength: 12)
            Button(action: finish) {
                Text(BloomBoxL10n.t("Listo"))
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 18)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .liveBoardGlass(radius: 18, interactive: false)
            .accessibilityIdentifier("bloombox.home.done")
        }
        .padding(.horizontal, 22)
        .sheet(isPresented: Binding(
            get: { exportURL != nil },
            set: { if !$0 { exportURL = nil } }
        )) {
            if let url = exportURL { BloomBoxThemeShareSheet(fileURL: url) }
        }
    }
}
