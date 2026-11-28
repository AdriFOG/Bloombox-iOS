// SPDX-License-Identifier: AGPL-3.0-only
import SwiftUI
import Foundation
import UIKit

struct BloomBoxInspectorApp: Identifiable {
    let id: String
    let name: String
    let bundle: URL
    let jit: Bool
    let shared: Bool

    func analyze() -> String {
        let fm = FileManager.default
        let info = NSDictionary(contentsOf: bundle.appendingPathComponent("Info.plist")) as? [String: Any] ?? [:]
        let executable = info["CFBundleExecutable"] as? String ?? ""
        var lines = ["App: " + name, "Bundle ID: " + (info["CFBundleIdentifier"] as? String ?? "?"),
                     "Version: " + (info["CFBundleShortVersionString"] as? String ?? "?"),
                     "Minimum iOS: " + (info["MinimumOSVersion"] as? String ?? "?"),
                     "JIT configured: " + String(jit), "Shared guest: " + String(shared)]
        if !executable.isEmpty, executable == URL(fileURLWithPath: executable).lastPathComponent {
            let url = bundle.appendingPathComponent(executable)
            if let handle = try? FileHandle(forReadingFrom: url) {
                defer { try? handle.close() }
                let data = (try? handle.read(upToCount: 65536)) ?? Data()
                lines += Self.machO(data)
            } else { lines.append("Executable unreadable") }
        } else { lines.append("Executable name missing or invalid") }
        let frameworks = bundle.appendingPathComponent("Frameworks")
        let children = (try? fm.contentsOfDirectory(at: frameworks, includingPropertiesForKeys: nil)) ?? []
        lines.append("Embedded libraries/frameworks: " + String(children.count))
        lines += children.map(\.lastPathComponent).sorted().prefix(100).map { "  " + $0 }
        let usage = info.keys.filter { $0.hasPrefix("NS") && $0.hasSuffix("UsageDescription") }.sorted()
        lines.append("Declared privacy usage keys (not granted permissions):")
        lines += usage.prefix(80).map { "  " + $0 }
        return lines.joined(separator: "\n")
    }

    private static func machO(_ d: Data) -> [String] {
        func word(_ o: Int, big: Bool = false) -> UInt32? {
            guard o >= 0, o <= d.count - 4 else { return nil }
            let a = UInt32(d[o]), b = UInt32(d[o+1]), c = UInt32(d[o+2]), e = UInt32(d[o+3])
            return big ? (a << 24 | b << 16 | c << 8 | e) : (a | b << 8 | c << 16 | e << 24)
        }
        guard let magic = word(0) else { return ["Mach-O: truncated"] }
        func cpu(_ n: UInt32) -> String {
            switch n { case 12: return "ARM32"; case 0x0100000c: return "ARM64"
            case 7: return "x86"; case 0x01000007: return "x86_64"; default: return String(n) }
        }
        if [UInt32(0xbebafeca), 0xbfbafeca, 0xcafebabe, 0xcafebabf].contains(magic) {
            let big = magic == 0xbebafeca || magic == 0xbfbafeca
            let stride = magic == 0xbfbafeca || magic == 0xcafebabf ? 32 : 20
            let count = min(Int(word(4, big: big) ?? 0), 32)
            let arch = (0..<count).compactMap { word(8 + $0 * stride, big: big).map(cpu) }
            return ["Mach-O universal: " + arch.joined(separator: ", ")]
        }
        guard magic == 0xfeedface || magic == 0xfeedfacf else { return ["Mach-O: unsupported header"] }
        var lines = ["Mach-O: " + cpu(word(4) ?? 0)]
        let count = min(Int(word(16) ?? 0), 1024)
        var offset = magic == 0xfeedfacf ? 32 : 28
        for _ in 0..<count {
            guard let cmd = word(offset), let size = word(offset + 4), size >= 8,
                  Int(size) <= d.count - offset else { break }
            let kind = cmd & 0x7fffffff
            if [UInt32(0xc), 0x18, 0x1f, 0x20, 0x23].contains(kind),
               let nameOffset = word(offset + 8), nameOffset >= 12, nameOffset < size {
                let start = offset + Int(nameOffset), end = offset + Int(size)
                let bytes = d[start..<end].prefix { $0 != 0 }
                let name = String(decoding: bytes.prefix(512), as: UTF8.self)
                lines.append("Dependency: " + URL(fileURLWithPath: name).lastPathComponent)
            }
            offset += Int(size)
        }
        return lines
    }
}

enum BloomBoxInspectorStore {
    struct Session: Codable, Identifiable {
        let id: String
        let key: String
        let name: String
        let date: Date
    }
    private static let lock = NSLock()
    private static let fm = FileManager.default
    private static let enabledKey = "BloomBoxInspectorEnabledAppsV1"
    private static let pendingKey = "BloomBoxInspectorPendingV1"
    private static var directory: URL {
        fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BloomBoxInspector", isDirectory: true)
    }
    private static var index: URL { directory.appendingPathComponent("sessions.json") }
    private static func local(_ id: String) -> URL { directory.appendingPathComponent(id + ".log") }
    private static func remote(_ id: String) -> URL? {
        LiveContainerDiagnosticsAdapter.inspectorSharedDirectory?.appendingPathComponent(id + ".log")
    }
    private static func valid(_ id: String) -> Bool { UUID(uuidString: id) != nil && id.count == 36 }
    static func enabled(_ key: String) -> Bool {
        (UserDefaults.standard.stringArray(forKey: enabledKey) ?? []).contains(key)
    }
    static func setEnabled(_ key: String, _ value: Bool) {
        lock.lock(); defer { lock.unlock() }
        var keys = Set(UserDefaults.standard.stringArray(forKey: enabledKey) ?? [])
        if value { keys.insert(key) } else { keys.remove(key) }
        UserDefaults.standard.set(Array(keys).sorted(), forKey: enabledKey)
    }
    private static func load() -> [Session] {
        guard let data = try? Data(contentsOf: index), data.count < 512 * 1024,
              let sessions = try? JSONDecoder().decode([Session].self, from: data) else { return [] }
        return sessions.filter { valid($0.id) }
    }
    static func sessions() -> [Session] {
        lock.lock(); defer { lock.unlock() }
        return load()
    }
    static func begin(key: String, name: String) -> String? {
        guard !key.isEmpty, enabled(key) else { return nil }
        lock.lock(); defer { lock.unlock() }
        let session = Session(id: UUID().uuidString, key: key, name: String(name.prefix(200)), date: Date())
        do {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data("BloomBox Inspector | app: \(session.name) | \(session.date)\n".utf8)
                .write(to: local(session.id), options: .atomic)
            var all = load()
            all.insert(session, at: 0)
            let old = Array(all.dropFirst(40))
            all = Array(all.prefix(40))
            try JSONEncoder().encode(all).write(to: index, options: .atomic)
            for item in old {
                try? fm.removeItem(at: local(item.id))
                if let url = remote(item.id) { try? fm.removeItem(at: url) }
                try? fm.removeItem(at: fm.temporaryDirectory.appendingPathComponent("BloomBox-Inspector-" + item.id + ".log"))
            }
            return session.id
        } catch { return nil }
    }
    static func arm(_ id: String?, selected: String?, useShared: Bool) {
        guard let id, valid(id), let selected, !selected.isEmpty else { return }
        lock.lock(); defer { lock.unlock() }
        if useShared {
            guard let url = remote(id) else { append(id, "host.inspector.shared_unavailable"); return }
            do {
                try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data().write(to: url, options: .atomic)
            } catch { append(id, "host.inspector.shared_unavailable"); return }
        }
        UserDefaults.standard.set(["id": id, "selected": selected, "shared": useShared,
                                   "time": Date().timeIntervalSince1970], forKey: pendingKey)
        UserDefaults.standard.synchronize()
        append(id, "host.inspector.native_armed")
    }
    static func record(_ id: String?, _ stage: String) {
        guard let id, valid(id) else { return }
        lock.lock(); defer { lock.unlock() }
        append(id, stage)
    }
    private static func append(_ id: String, _ stage: String) {
        let clean = stage.prefix(100).filter { $0.isASCII && ($0.isLetter || $0.isNumber || "._-".contains($0)) }
        let url = local(id)
        guard let h = try? FileHandle(forWritingTo: url) else { return }
        defer { try? h.close() }
        guard let size = try? h.seekToEnd(), size < 128 * 1024 else { return }
        try? h.write(contentsOf: Data("\(Int(Date().timeIntervalSince1970)) \(clean)\n".utf8))
    }
    static func report(_ id: String) -> String {
        guard valid(id) else { return "" }
        var pieces: [String] = []
        for url in [Optional(local(id)), remote(id)].compactMap({ $0 }) {
            guard let h = try? FileHandle(forReadingFrom: url) else { continue }
            defer { try? h.close() }
            if let data = try? h.read(upToCount: 144 * 1024) {
                pieces.append(String(decoding: data, as: UTF8.self))
            }
        }
        return pieces.joined(separator: "\n--- Native / LiveProcess ---\n")
    }
    static func export(_ id: String) -> URL? {
        guard valid(id) else { return nil }
        let url = fm.temporaryDirectory.appendingPathComponent("BloomBox-Inspector-" + id + ".log")
        do { try report(id).write(to: url, atomically: true, encoding: .utf8); return url }
        catch { return nil }
    }
}

struct BloomBoxInspectorView: View {
    let apps: [BloomBoxInspectorApp]
    @State private var chosen = ""
    @State private var analysis = ""
    @State private var sessions: [BloomBoxInspectorStore.Session] = []
    @State private var revision = 0
    private var en: Bool { BloomBoxL10n.isEnglish }
    private var app: BloomBoxInspectorApp? { apps.first { $0.id == chosen } }
    var body: some View {
        Form {
            Section {
                Text(en ? "Inspect installed apps and record the next launch. Logs are local; an interruption alone does not prove a crash." : "Examina las apps instaladas y registra el próximo arranque. Los logs son locales; una interrupción no confirma un crash.")
                if apps.isEmpty {
                    Text(en ? "No installed guest apps." : "No hay apps invitadas instaladas.")
                } else {
                    Picker(en ? "Application" : "Aplicación", selection: $chosen) {
                        ForEach(apps) { Text($0.name).tag($0.id) }
                    }
                    Toggle(en ? "Detailed launch recording" : "Registrar arranque detallado", isOn: Binding(
                        get: { BloomBoxInspectorStore.enabled(chosen) },
                        set: { BloomBoxInspectorStore.setEnabled(chosen, $0); revision += 1 }))
                        .id(chosen + String(revision))
                    Button(en ? "Examine installed package" : "Examinar paquete instalado") {
                        if let app { analysis = app.analyze() }
                    }
                    if !analysis.isEmpty {
                        Text(analysis).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                        Button(en ? "Copy analysis" : "Copiar análisis") { UIPasteboard.general.string = analysis }
                    }
                }
            } header: { Text(en ? "App inspector" : "Examinar app") }
            Section {
                Button(en ? "Refresh history" : "Actualizar historial") { sessions = BloomBoxInspectorStore.sessions() }
                if sessions.isEmpty { Text(en ? "No recordings yet." : "Todavía no hay registros.") }
                ForEach(sessions) { item in
                    NavigationLink {
                        BloomBoxInspectorSessionView(session: item)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(item.name).font(.headline)
                            Text(item.date, style: .date).font(.caption)
                            Text(item.date, style: .time).font(.caption2)
                        }
                    }
                }
            } header: { Text(en ? "Launch history" : "Historial de arranques") }
            Section {
                NavigationLink { BloomBoxDiagnosticsView() } label: {
                    Label(en ? "System diagnostics and MetricKit" : "Diagnósticos del sistema y MetricKit", systemImage: "waveform.path.ecg")
                }
                NavigationLink { BloomBoxJITLogHistoryView(appName: nil) } label: {
                    Label(en ? "JIT history" : "Historial de JIT", systemImage: "bolt")
                }
            }
        }
        .navigationTitle("BloomBox Inspector")
        .onAppear {
            if chosen.isEmpty { chosen = apps.first?.id ?? "" }
            sessions = BloomBoxInspectorStore.sessions()
        }
        .onChange(of: chosen) { _ in analysis = "" }
    }
}

private struct BloomBoxInspectorSessionView: View {
    let session: BloomBoxInspectorStore.Session
    @State private var report = ""
    @State private var exportURL: URL?
    private var en: Bool { BloomBoxL10n.isEnglish }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(session.name).font(.headline)
                Text(en ? "The last event is a clue, not a confirmed cause. Memory samples show process footprint." : "El último evento es una pista, no una causa confirmada. Las muestras muestran la memoria del proceso.").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button(en ? "Refresh" : "Actualizar", action: refresh)
                    Button(en ? "Copy" : "Copiar") { UIPasteboard.general.string = report }
                    if #available(iOS 16.0, *), let exportURL {
                        ShareLink(item: exportURL) { Label(en ? "Export log" : "Exportar log", systemImage: "square.and.arrow.up") }
                    }
                }
                Text(report).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.padding()
        }.navigationTitle(en ? "Launch log" : "Registro de arranque")
            .onAppear(perform: refresh)
    }
    private func refresh() {
        report = BloomBoxInspectorStore.report(session.id)
        exportURL = BloomBoxInspectorStore.export(session.id)
    }
}
