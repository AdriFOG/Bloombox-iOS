import SwiftUI
import Foundation

// OpenPortsGames iOS discovery inside BloomBox App Store.
// This view never treats an upstream source check as BloomBox compatibility,
// and it never bypasses the reviewed SHA-256 guest IPA installation policy.
struct BloomBoxIOSPortsSection: View {
    let search: String
    @ObservedObject private var catalog = BloomBoxPortCatalog.shared
    @State private var ipaOnly = false

    private var english: Bool { BloomBoxL10n.isEnglish }

    private var matching: [BloomBoxCatalogPort] {
        let needle = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return catalog.iosPorts.filter { port in
            if ipaOnly && !port.downloads.orEmpty.contains(where: { $0.safeURL?.pathExtension.lowercased() == "ipa" }) {
                return false
            }
            if needle.isEmpty { return true }
            return ([port.title, port.game ?? "", port.genre ?? ""] +
                    (port.developers ?? []) + (port.originalSystems ?? []))
                .contains { $0.localizedStandardContains(needle) }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Label(english ? "iPhone ports" : "Ports para iPhone",
                          systemImage: "iphone.gen3")
                        .font(.title3.bold())
                    Text(english ? "\(matching.count) of \(catalog.iosPorts.count) iOS projects" :
                            "\(matching.count) de \(catalog.iosPorts.count) proyectos iOS")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle(english ? "IPA only" : "Solo IPA", isOn: $ipaOnly)
                    .font(.caption)
                    .fixedSize()
                    .tint(.cyan)
            }
            Text(english ?
                 "Only entries tagged iOS by OpenPortsGames are shown. An iOS listing does not guarantee support for your iPhone or BloomBox." :
                 "Solo aparecen proyectos marcados para iOS por OpenPortsGames. Esto no garantiza compatibilidad con tu iPhone ni con BloomBox.")
                .font(.caption).foregroundStyle(.secondary)

            if catalog.loading && catalog.iosPorts.isEmpty {
                ProgressView(english ? "Loading iOS ports…" : "Cargando ports de iPhone…")
                    .frame(maxWidth: .infinity).padding(26)
            }
            if let message = catalog.errorMessage {
                Label(message, systemImage: "wifi.exclamationmark")
                    .font(.caption).foregroundStyle(.orange)
            }
            if matching.isEmpty && !catalog.loading {
                Label(english ? "No ports match this search." : "No hay ports con estos filtros.",
                      systemImage: "gamecontroller")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            }
            LazyVStack(spacing: 10) {
                ForEach(matching) { port in
                    NavigationLink(destination: BloomBoxIOSPortDetails(port: port)) {
                        BloomBoxIOSPortRow(port: port)
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Link(destination: URL(string: "https://openportsgames.com/es/")!) {
                    Label(english ? "Source: OpenPortsGames" : "Fuente: OpenPortsGames",
                          systemImage: "arrow.up.right.square")
                }
                .font(.footnote)
                Text(english ?
                     "OpenPortsGames catalog data: CC BY 4.0 for original entries; some imported entries have separate source terms. Credit and downloads belong to their original authors." :
                     "Datos originales del catálogo: CC BY 4.0; algunos registros importados tienen condiciones propias. Se respetan las fuentes, créditos y descargas de cada autor.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(english ?
                     "No direct IPA installation without a reviewed release and SHA-256. Use original publisher links." :
                     "La instalación directa de IPA exige una versión revisada y SHA-256. Por ahora se abren los enlaces originales.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
        .task { await catalog.refresh() }
    }
}

private extension Optional where Wrapped: Collection {
    var orEmpty: Wrapped {
        self ?? .init()
    }
}

private struct BloomBoxIOSPortRow: View {
    let port: BloomBoxCatalogPort
    private var english: Bool { BloomBoxL10n.isEnglish }
    private var hasIPA: Bool {
        port.downloads?.contains(where: { $0.safeURL?.pathExtension.lowercased() == "ipa" }) == true
    }

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            artwork
            VStack(alignment: .leading, spacing: 6) {
                Text(port.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
                Text(port.originalSystems?.first ?? "iOS")
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Label("iOS", systemImage: "iphone.gen3")
                    if hasIPA {
                        Label("IPA", systemImage: "arrow.down.circle")
                    }
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(.cyan)
                Label(english ? "Not tested in BloomBox" : "Sin probar en BloomBox",
                      systemImage: "questionmark.circle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let version = port.version {
                    Text(english ? "Version \(version)" : "Versión \(version)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
                .padding(.top, 31)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .contentShape(RoundedRectangle(cornerRadius: 18))
    }

    private var artwork: some View {
        AsyncImage(url: port.coverURL) { phase in
            if case .success(let image) = phase {
                image.resizable()
                    .scaledToFill()
                    .frame(width: 82, height: 106)
                    .clipped()
            } else {
                ZStack {
                    Color.indigo.opacity(0.45)
                    Image(systemName: "gamecontroller.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
                .frame(width: 82, height: 106)
            }
        }
        .frame(width: 82, height: 106)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct BloomBoxIOSPortDetails: View {
    let port: BloomBoxCatalogPort
    private var english: Bool { BloomBoxL10n.isEnglish }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                BloomBoxIOSPortRow(port: port)
                Text(port.description(english: english))
                    .font(.body)
                if !port.details(english: english).isEmpty {
                    Text(port.details(english: english))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Label(english ?
                      "This project is indexed for iOS. iPhone, iOS-version, signing and BloomBox compatibility have not been independently tested." :
                      "Este proyecto aparece para iOS. No hemos comprobado compatibilidad con iPhone, versiones de iOS, firma ni BloomBox.",
                      systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if port.noOriginalGameRequired != true {
                    Label(english ?
                          "You may need original game files that you own." :
                          "Podrías necesitar archivos originales de un juego que te pertenezca.",
                          systemImage: "externaldrive")
                        .font(.caption)
                }
                if port.wip == true {
                    Label(english ? "Work in progress" : "En desarrollo",
                          systemImage: "hammer")
                        .font(.caption)
                }
                if let original = port.sourceURL {
                    Link(destination: original) {
                        Label(english ? "Open original repository" : "Abrir repositorio original",
                              systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    .font(.subheadline.bold())
                }
                Text(english ? "Publisher downloads" : "Descargas del autor")
                    .font(.headline)
                let downloads = port.downloads ?? []
                if downloads.isEmpty {
                    Text(english ? "No downloadable build listed yet." : "Todavía no hay una compilación descargable.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(downloads) { item in
                    if let link = item.safeURL {
                        VStack(alignment: .leading, spacing: 6) {
                            Link(destination: link) {
                                Label(
                                    item.safeURL?.pathExtension.lowercased() == "ipa"
                                    ? (english ? "Open original IPA download" : "Abrir descarga IPA original")
                                    : item.label,
                                    systemImage: "arrow.up.right.square"
                                )
                            }
                            .font(.subheadline.weight(.semibold))
                            if let size = item.size {
                                Text(size).font(.caption).foregroundStyle(.secondary)
                            }
                            if let note = item.note {
                                Text(note).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                Link(destination: URL(string: "https://openportsgames.com/es/ports/" + port.id)!) {
                    Label("OpenPortsGames", systemImage: "arrow.up.right.square")
                }
                .font(.footnote)
            }
            .padding(17)
        }
        .navigationTitle(port.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
