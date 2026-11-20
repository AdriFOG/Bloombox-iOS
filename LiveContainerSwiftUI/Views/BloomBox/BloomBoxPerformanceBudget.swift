import Foundation
import SwiftUI

/// Shared, hysteresis-based performance budget for Home, widgets and GameBox.
/// Recovery is delayed so transient thermal changes never flash the interface.
@MainActor
final class BloomBoxPerformanceBudget: ObservableObject {
    enum Level: Int, Comparable {
        case nominal = 0, fair, serious, critical
        static func < (lhs: Level, rhs: Level) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    static let shared = BloomBoxPerformanceBudget()
    @Published private(set) var level: Level = .nominal
    @Published var guestActive = false

    var allowsVideo: Bool { level == .nominal && !guestActive }
    var allowsLivingWidgets: Bool { level == .nominal && !guestActive }
    var allowsDecorations: Bool { level < .serious && !guestActive }
    var allowsGlass: Bool { level < .serious }
    var maximumAnimationFPS: Int? { level >= .serious ? 30 : nil }
    var useDarkWallpaper: Bool { level == .critical }

    private var recovery: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []

    private init() {
        let center = NotificationCenter.default
        for name in [ProcessInfo.thermalStateDidChangeNotification,
                     Notification.Name.NSProcessInfoPowerStateDidChange] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) {
                [weak self] _ in
                Task { @MainActor [weak self] in self?.refresh() }
            })
        }
        refresh()
    }

    private func measuredLevel() -> Level {
        let info = ProcessInfo.processInfo
        let thermal: Level
        switch info.thermalState {
        case .nominal: thermal = .nominal
        case .fair: thermal = .fair
        case .serious: thermal = .serious
        case .critical: thermal = .critical
        @unknown default: thermal = .critical
        }
        return max(thermal, info.isLowPowerModeEnabled ? .serious : .nominal)
    }

    func refresh() {
        let target = measuredLevel()
        recovery?.cancel()
        recovery = nil
        if target >= level {
            level = target
            return
        }
        // Only recover after a continuously stable 45 seconds.
        recovery = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 45_000_000_000) }
            catch { return }
            guard let self, !Task.isCancelled else { return }
            let current = self.measuredLevel()
            if current <= target { self.level = current }
            else { self.refresh() }
        }
    }
}
