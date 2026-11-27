import SwiftUI
import UIKit

private typealias ProbeLog = @convention(c) (UnsafePointer<CChar>?) -> Void
private func record(_ text: String, _ logger: ProbeLog) {
    text.withCString { logger($0) }
}

// This deliberately has no SwiftUI.App, app delegate, shared preferences,
// launcher singleton or nested LiveContainer dependency.
private struct ProbeDesktop: View {
    let logger: ProbeLog
    @State private var selected: String? = nil
    @State private var compact = false
    @State private var count = 0
    private let tiles: [(String, String, Color)] = [
        ("Archivos", "folder.fill", .blue),
        ("Ajustes", "gearshape.fill", .gray),
        ("Apps", "square.grid.2x2.fill", .purple),
        ("Noticias", "newspaper.fill", .orange),
        ("Temas", "paintpalette.fill", .pink),
        ("Diagnóstico", "waveform.path.ecg", .mint)
    ]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("BloomBox Dev").font(.largeTitle.bold())
                Text("Prueba de renderizado · V4").font(.subheadline).foregroundStyle(.secondary)
                Label("SwiftUI activo", systemImage: "checkmark.circle.fill").foregroundStyle(.mint)
                Toggle("Cuadrícula compacta", isOn: $compact).tint(.purple)
                    .onChange(of: compact) { _ in record("13 SwiftUI grid layout changed", logger) }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: compact ? 3 : 2), spacing: 16) {
                    ForEach(tiles.indices, id: \.self) { index in
                        let tile = tiles[index]
                        Button {
                            selected = tile.0
                            count += 1
                            record("13 SwiftUI tile interaction", logger)
                        } label: {
                            VStack(spacing: 10) {
                                Image(systemName: tile.1).font(.system(size: 26, weight: .medium))
                                    .frame(width: 58, height: 58)
                                    .background(tile.2.gradient, in: RoundedRectangle(cornerRadius: 17))
                                Text(tile.0).font(.caption).lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(tile.0)
                    }
                }
                Text(selected.map { "Último icono: " + $0 } ?? "Toca cualquier icono")
                Text("Toques: \(count)").monospacedDigit()
                Text("Los iconos son de prueba; no ejecutan aplicaciones ni modifican el BloomBox principal.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient(colors: [Color(red: 0.19, green: 0.11, blue: 0.31), .black], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear { record("12 SwiftUI view appeared", logger) }
    }
}

@_cdecl("BBDevMakeSwiftUIV4")
public func BBDevMakeSwiftUIV4(_ logger: @convention(c) (UnsafePointer<CChar>?) -> Void) -> UnsafeMutableRawPointer? {
    guard Thread.isMainThread else { return nil }
    record("09 Swift factory entered", logger)
    let controller = UIHostingController(rootView: ProbeDesktop(logger: logger))
    return Unmanaged.passRetained(controller).toOpaque()
}
