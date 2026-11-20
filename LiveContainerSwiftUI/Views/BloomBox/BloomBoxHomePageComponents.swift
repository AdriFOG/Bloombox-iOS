import SwiftUI

/// Small view state: only the current page binding; Home owns navigation policy.
struct BloomBoxHomePageControl: View {
    @Binding var page: Int
    let visiblePages: [Int]
    let libraryPageIndex: Int
    let editing: Bool
    let englishUI: Bool
    let reduceMotion: Bool
    let onSearch: () -> Void
    let onManage: () -> Void
    let onAddPage: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            Button { page = 1 } label: {
                Image(systemName: "house.fill").frame(width: 32, height: 32)
            }
            .accessibilityLabel(englishUI ? "Home Screen" : "Pantalla de inicio")
            Button(action: onSearch) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 32)
            }
            .accessibilityLabel(englishUI ? "Search" : "Buscar")
            Rectangle().fill(.white.opacity(0.22))
                .frame(width: 0.5, height: 12).padding(.trailing, 3)
            ForEach([0] + visiblePages.map { $0 + 1 }, id: \.self) { index in
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        page = index
                    }
                } label: {
                    Circle().fill(.white.opacity(page == index ? 1 : 0.35))
                        .frame(width: 6, height: 6)
                        .frame(width: 27, height: 40)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(index == 0 ? "Widgets" :
                    (englishUI ? "Page \(index)" : "Página \(index)"))
            }
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.4)) {
                    page = libraryPageIndex
                }
            } label: {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(page == libraryPageIndex ? 1 : 0.55))
                    .frame(width: 21, height: 32)
            }
            .accessibilityLabel(BloomBoxL10n.t("Biblioteca de apps"))
            if editing {
                Button(action: onManage) {
                    Image(systemName: "rectangle.stack")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 24, height: 32)
                }.accessibilityLabel("Gestionar páginas")
                Button(action: onAddPage) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 24, height: 32)
                }.accessibilityLabel("Añadir página")
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .frame(height: 40)
        .liveBoardGlass(radius: 16, interactive: false)
        .accessibilityIdentifier("home.pages")
    }
}

/// Isolated render boundary for one Home page, without owning layout state.
struct BloomBoxHomePageCanvas<Icons: View, Tiles: View>: View {
    let icons: Icons
    let tiles: Tiles

    var body: some View {
        icons.overlay(alignment: .topLeading) {
            tiles.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
