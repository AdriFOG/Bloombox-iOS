//
//  LiveContainerSwiftUIApp.swift
//  LiveContainer
//
//  Created by s s on 2025/5/16.
//
import SwiftUI
import UIKit

@main
struct LiveContainerSwiftUIApp : SwiftUI.App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("BloomBoxPreferredLanguage", store: LCUtils.appGroupUserDefault)
    private var preferredLanguage = "system"

    // Apply the selected language across the entire app, including sheets,
    // the widget gallery, modules, settings and accessibility labels.
    private var bloomBoxLocale: Locale {
        switch preferredLanguage {
        case "en": return Locale(identifier: "en")
        case "es": return Locale(identifier: "es_MX")
        default: return Locale(identifier: Locale.preferredLanguages.first ?? "en")
        }
    }
    
    init() {
        let fm = FileManager()
        var tempAppDataFolderNames : [String] = []
        var tempTweakFolderNames : [String] = []
        
        var tempApps: [LCAppModel] = []
        var tempArm32EmuApps: [LCAppModel] = []
        var tempHiddenApps: [LCAppModel] = []
        var tempURLSchemes: Set<String>? = DataManager.shared.model.multiLCStatus != 2 ? Set() : nil

        do {
            // load apps
            try fm.createDirectory(at: LCPath.bundlePath, withIntermediateDirectories: true)
            let appDirs = try fm.contentsOfDirectory(atPath: LCPath.bundlePath.path)
            for appDir in appDirs {
                if !appDir.hasSuffix(".app") {
                    continue
                }
                guard let newApp = LCAppInfo(bundlePath: "\(LCPath.bundlePath.path)/\(appDir)") else {
                    // Leave incomplete bundles untouched so they can be
                    // recovered; one bad IPA must never crash the launcher.
                    NSLog("[BloomBox] Skipping unreadable private guest bundle: %@", appDir)
                    continue
                }
                newApp.relativeBundlePath = appDir
                newApp.isShared = false
                let model = LCAppModel(appInfo: newApp)
                if newApp.isHidden {
                    tempHiddenApps.append(model)
                } else {
                    tempApps.append(model)
                    tempURLSchemes?.formUnion((newApp.urlSchemes() as? [String]) ?? [])
                }
                if newApp.is32bitEmulator {
                    tempArm32EmuApps.append(model)
                }
            }
            if LCPath.lcGroupDocPath != LCPath.docPath {
                try fm.createDirectory(at: LCPath.lcGroupBundlePath, withIntermediateDirectories: true)
                let appDirsShared = try fm.contentsOfDirectory(atPath: LCPath.lcGroupBundlePath.path)
                for appDir in appDirsShared {
                    if !appDir.hasSuffix(".app") {
                        continue
                    }
                    guard let newApp = LCAppInfo(bundlePath: "\(LCPath.lcGroupBundlePath.path)/\(appDir)") else {
                        NSLog("[BloomBox] Skipping unreadable shared guest bundle: %@", appDir)
                        continue
                    }
                    newApp.relativeBundlePath = appDir
                    newApp.isShared = true
                    let model = LCAppModel(appInfo: newApp)
                    if newApp.isHidden {
                        tempHiddenApps.append(model)
                    } else {
                        tempApps.append(model)
                        tempURLSchemes?.formUnion((newApp.urlSchemes() as? [String]) ?? [])
                    }
                    if newApp.is32bitEmulator {
                        tempArm32EmuApps.append(model)
                    }
                }
            }
            // load document folders
            try fm.createDirectory(at: LCPath.dataPath, withIntermediateDirectories: true)
            let dataDirs = try fm.contentsOfDirectory(atPath: LCPath.dataPath.path)
            for dataDir in dataDirs {
                let dataDirUrl = LCPath.dataPath.appendingPathComponent(dataDir)
                if !dataDirUrl.hasDirectoryPath {
                    continue
                }
                tempAppDataFolderNames.append(dataDir)
            }
            
            // load tweak folders
            try fm.createDirectory(at: LCPath.tweakPath, withIntermediateDirectories: true)
            let tweakDirs = try fm.contentsOfDirectory(atPath: LCPath.tweakPath.path)
            for tweakDir in tweakDirs {
                let tweakDirUrl = LCPath.tweakPath.appendingPathComponent(tweakDir)
                if !tweakDirUrl.hasDirectoryPath {
                    continue
                }
                let folderName = tweakDir.hasSuffix(".disabled") ? String(tweakDir.dropLast(".disabled".count)) : tweakDir
                tempTweakFolderNames.append(folderName)
            }
        } catch {
            NSLog("[LC] error:\(error)")
        }
        
        DataManager.shared.model.apps = tempApps
        DataManager.shared.model.arm32EmuApps = tempArm32EmuApps
        DataManager.shared.model.hiddenApps = tempHiddenApps
        DataManager.shared.model.appDataFolderNames = tempAppDataFolderNames
        DataManager.shared.model.tweakFolderNames = tempTweakFolderNames
        if let tempURLSchemes {
            UserDefaults.lcShared().set(Array(tempURLSchemes), forKey: "LCGuestURLSchemes")
        }
    }
    
    var body: some Scene {
        WindowGroup(id: "Main") {
            LCTabView()
                .environment(\.locale, bloomBoxLocale)
                .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
                .environmentObject(DataManager.shared.model)
                .environmentObject(LCAppSortManager.shared)
        }
        
        if UIApplication.shared.supportsMultipleScenes, #available(iOS 16.1, *) {
            WindowGroup(id: "appView", for: String.self) { $id in
                if let id {
                    MultitaskAppWindow(id: id)
                        .environment(\.locale, bloomBoxLocale)
                }
            }

        }
    }
    
}


// Only the separately packaged nested probe enters this diagnostic app.
// Do not initialize the production AppDelegate, model, shared defaults or account.
private enum BloomBoxNestedProbeSessionV2 {
    static var root: URL?
    static func record(_ phase: String, at root: URL) {
        let log = root.appendingPathComponent("boot.log")
        let old = (try? String(contentsOf: log, encoding: .utf8)) ?? ""
        try? (String(old.suffix(4096)) + phase + "\n").write(to: log, atomically: true, encoding: .utf8)
        NSLog("[BloomBoxDev/v2] %@", phase)
    }
}

@_cdecl("BloomBoxNestedProbeUIV2")
@MainActor public func BloomBoxNestedProbeUIV2(_ root: UnsafePointer<CChar>) -> Int32 {
    guard Thread.isMainThread else { return 77 }
    let url = URL(fileURLWithPath: String(cString: root), isDirectory: true)
    BloomBoxNestedProbeSessionV2.root = url
    BloomBoxNestedProbeSessionV2.record("04 SwiftUI entry reached", at: url)
    BloomBoxNestedProbeAppV2.main()
    return 0
}

private struct BloomBoxNestedProbeAppV2: SwiftUI.App {
    var body: some Scene {
        WindowGroup {
            if let root = BloomBoxNestedProbeSessionV2.root {
                BloomBoxNestedProbeViewV2(root: root)
            } else {
                Text("BloomBox Dev: storage unavailable")
            }
        }
    }
}

private struct BloomBoxNestedProbeViewV2: View {
    let root: URL
    @State private var count = 0
    @State private var status = "Sin comprobar"
    @State private var didAppear = false
    private var counterFile: URL { root.appendingPathComponent("counter.txt") }
    private var logFile: URL { root.appendingPathComponent("boot.log") }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.17, green: 0.10, blue: 0.31), .black],
                           startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 42, weight: .semibold)).foregroundStyle(.mint)
                    Text("BloomBox Dev").font(.largeTitle.bold())
                    Text("Nested Probe 02 · SwiftUI").font(.subheadline).foregroundStyle(.secondary)
                    Label("Interfaz iniciada", systemImage: "checkmark.circle.fill").foregroundStyle(.mint)
                    Label("Almacenamiento: " + status, systemImage: "folder.fill")
                    Text("Contador guardado: \(count)").font(.title2.monospacedDigit())
                    Button("Guardar prueba (+1)") { save() }
                        .buttonStyle(.borderedProminent).tint(.purple)
                    Button("Copiar log de arranque") {
                        UIPasteboard.general.string = (try? String(contentsOf: logFile, encoding: .utf8)) ?? "Log no disponible"
                    }.buttonStyle(.bordered)
                    Text("Prueba de interfaz y archivos privados. No solicita credenciales ni abre otras apps.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .frame(maxWidth: 440, alignment: .leading)
                .padding(28)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
                .padding(24)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            guard !didAppear else { return }
            didAppear = true
            let stored = try? String(contentsOf: counterFile, encoding: .utf8)
            count = stored.flatMap { Int($0) } ?? 0
            do {
                try String(count).write(to: counterFile, atomically: true, encoding: .utf8)
                guard try String(contentsOf: counterFile, encoding: .utf8) == String(count) else {
                    status = "error de verificación"
                    return
                }
                status = "lectura y escritura correctas"
                BloomBoxNestedProbeSessionV2.record("05 view appeared; private storage roundtrip OK", at: root)
            } catch {
                status = "error"
                BloomBoxNestedProbeSessionV2.record("05 view appeared; private storage failed", at: root)
            }
        }
    }

    private func save() {
        guard count < Int.max else { return }
        do {
            let next = count + 1
            try String(next).write(to: counterFile, atomically: true, encoding: .utf8)
            guard try String(contentsOf: counterFile, encoding: .utf8) == String(next) else {
                status = "error de verificación"
                return
            }
            count = next
            status = "guardado correcto"
            BloomBoxNestedProbeSessionV2.record("06 counter persisted", at: root)
        } catch {
            status = "error de escritura"
        }
    }
}
