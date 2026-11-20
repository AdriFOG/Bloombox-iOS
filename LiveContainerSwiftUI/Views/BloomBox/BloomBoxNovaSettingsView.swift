// SPDX-License-Identifier: AGPL-3.0-only
import SwiftUI

/// Native Nova-style launcher controls. All values are saved with the active
/// BloomBox profile; the iOS Home and GameBox preferences are untouched.
struct BloomBoxNovaSettingsView: View {
    @Binding var layout: BloomBoxNovaLayout
    let availableKeys: [String]
    let english: Bool
    let chooseWallpaper: (UIImage) -> Void
    let removeWallpaper: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var resetConfirmation = false
    @State private var wallpaperPicker = false
    private func t(_ spanish: String, _ en: String) -> String {
        english ? en : spanish
    }


    private var desktopSection: some View {
        Section {
            Stepper(value: $layout.columns, in: 4...6) {
                HStack {
                    Label(t("Columnas", "Columns"), systemImage: "square.grid.4x3.fill")
                    Spacer()
                    Text("\(layout.columns)").foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(t("Tamaño de iconos", "Icon size"), systemImage: "app.fill")
                    Spacer()
                    Text("\(Int(layout.iconScale * 100))%").foregroundStyle(.secondary)
                }
                Slider(value: $layout.iconScale, in: 0.75...1.20, step: 0.05)
            }
            Toggle(isOn: $layout.roundIcons) {
                Label(t("Iconos redondos", "Round icons"), systemImage: "circle.grid.3x3.fill")
            }
            Toggle(isOn: $layout.showLabels) {
                Label(t("Mostrar nombres", "Show app labels"), systemImage: "textformat")
            }
        } header: {
            Text(t("Escritorio", "Desktop"))
        } footer: {
            Text(t("Puedes mover iconos y crear carpetas desde el menú al dejar presionado.",
                   "Long-press icons to move them or create folders."))
        }
    }

    private var drawerSection: some View {
        Section(t("Cajón de aplicaciones", "App drawer")) {
            Toggle(isOn: $layout.drawerList) {
                Label(t("Vista de lista", "List view"), systemImage: "list.bullet")
            }
            Picker(t("Ordenar", "Sort"), selection: $layout.drawerSort) {
                Text(t("Alfabéticamente", "Alphabetical")).tag("alphabetical")
                Text(t("Uso reciente", "Recently used")).tag("recent")
            }
            Toggle(isOn: $layout.showSearch) {
                Label(t("Búsqueda en escritorio", "Home search bar"), systemImage: "magnifyingglass")
            }
        }
    }

    private var motionSection: some View {
        Section(t("Movimiento", "Motion")) {
            Picker(t("Animación al abrir", "Launch animation"), selection: $layout.animation) {
                Text("Zoom").tag("zoom")
                Text(t("Deslizamiento", "Slide")).tag("slide")
                Text(t("Desvanecer", "Fade")).tag("fade")
                Text(t("Sin animación", "None")).tag("none")
            }
            Text(t("Se respeta la opción de reducir movimiento de iOS.",
                   "Respects iOS Reduce Motion accessibility settings."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var wallpaperSection: some View {
        Section(t("Fondo y elementos", "Wallpaper & elements")) {
            Button {
                wallpaperPicker = true
            } label: {
                Label(t("Elegir fondo de Fotos", "Choose photo wallpaper"),
                      systemImage: "photo.on.rectangle.angled")
            }
            if layout.useCustomWallpaper {
                Button(role: .destructive) {
                    removeWallpaper()
                    layout.useCustomWallpaper = false
                } label: {
                    Label(t("Eliminar fondo personalizado", "Remove custom wallpaper"),
                          systemImage: "trash")
                }
            }
            Toggle(isOn: $layout.useHomeWallpaper) {
                Label(t("Usar fondo del launcher iOS", "Use iOS Home wallpaper"),
                      systemImage: "photo")
            }
            .disabled(layout.useCustomWallpaper)
            Toggle(isOn: $layout.showClock) {
                Label(t("Mostrar reloj", "Show clock"), systemImage: "clock")
            }
            Text(t("El color principal sigue el perfil activo de BloomBox.",
                   "Accent colors follow your active BloomBox profile."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                resetConfirmation = true
            } label: {
                Label(t("Restablecer escritorio Android", "Reset Android Home"),
                      systemImage: "arrow.counterclockwise")
            }
        } footer: {
            Text(t("Solo restablece el launcher Android de este perfil. No borra apps, contenedores, datos ni el escritorio iOS.",
                   "Resets only this profile's Android launcher. Apps, containers, data and iOS Home remain untouched."))
        }
    }

    var body: some View {
        NavigationView {
            Form {
                desktopSection
                drawerSection
                motionSection
                wallpaperSection
                resetSection
            }
            .tint(.cyan)
            .navigationTitle(t("Personalizar launcher", "Customize launcher"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(t("Listo", "Done")) { dismiss() }
                }
            }
            .sheet(isPresented: $wallpaperPicker) {
                BloomBoxNovaWallpaperPicker { image in
                    chooseWallpaper(image)
                    layout.useCustomWallpaper = true
                    wallpaperPicker = false
                }
            }
            .confirmationDialog(t("¿Restablecer el escritorio Android?", "Reset Android Home?"),
                                isPresented: $resetConfirmation) {
                Button(t("Restablecer", "Reset"), role: .destructive) {
                    var fresh = BloomBoxNovaLayout()
                    fresh.reconcile(available: availableKeys)
                    layout = fresh
                }
                Button(t("Cancelar", "Cancel"), role: .cancel) {}
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
    }
}
