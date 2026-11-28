// SPDX-License-Identifier: AGPL-3.0-only
import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass
import UniformTypeIdentifiers

// Nova owns only presentation and a profile-scoped workspace. All application
// lifecycle operations remain in BloomBox's existing Home adapter.
struct BloomBoxNovaWorkspace: Codable, Equatable {
    struct Folder: Codable, Equatable {
        var name: String
        var apps: [String]
    }

    struct SearchBar: Codable, Equatable {
        // All colors are RGB only: the bar always has an opaque fill.
        var fillRGB: UInt32 = 0x003B60
        var iconRGB: UInt32 = 0xFFFFFF
        var automaticInk = false
        var shape = 0
        var compact = false
        var leadingIcon = 0
        var trailingApp: String?
        var trailingSymbol = 0
        var useAppArtwork = true

        mutating func normalize() {
            fillRGB &= 0xFFFFFF
            iconRGB &= 0xFFFFFF
            shape = min(2, max(0, shape))
            leadingIcon = min(2, max(0, leadingIcon))
            trailingSymbol = min(3, max(0, trailingSymbol))
        }
    }

    struct DrawerAppearance: Codable, Equatable {
        var backgroundRGB: UInt32 = 0x111D2B
        var transparency = 0.0
        var columns = 5
        var showRecent = true
        var recent: [String] = []
        var labelStyle = 0

        mutating func normalize() {
            backgroundRGB &= 0xFFFFFF
            transparency = transparency.isFinite ? min(1, max(0, transparency)) : 0
            columns = min(6, max(4, columns))
            labelStyle = min(2, max(0, labelStyle))
            var seen = Set<String>()
            recent = Array(recent.filter { seen.insert($0).inserted }.prefix(5))
        }
    }

    static let capacity = 20
    static let dockCapacity = 5
    static func emptyPage() -> [String?] { Array(repeating: nil, count: capacity) }
    var pages: [[String?]] = [Self.emptyPage()]
    var dock: [String?] = Array(repeating: nil, count: Self.dockCapacity)
    var known: [String] = []
    var folders: [String: Folder] = [:]
    var columns = 4
    var labels = true
    var iconShape = 0
    var wallpaper = 0
    // Optional for compatibility with workspaces saved before the search bar.
    var searchBar: SearchBar?
    var drawerAppearance: DrawerAppearance?
    var widgets: [Int: [BloomBoxPlacedWidget]]?
    // Nova-only, optional for older workspaces. 0 = invisible background.
    var widgetOpacity: [String: Double]?

    func opacity(for id: String) -> Double {
        let value = widgetOpacity?[id] ?? 1
        return value.isFinite ? min(1, max(0, value)) : 1
    }

    mutating func setOpacity(_ value: Double, id: String) {
        var values = widgetOpacity ?? [:]
        values[id] = value.isFinite ? min(1, max(0, value)) : 1
        widgetOpacity = values
    }

    func canPlaceWidget(_ widget: BloomBoxPlacedWidget, on page: Int) -> Bool {
        guard pages.indices.contains(page), widget.columns > 0, widget.rows > 0,
              widget.slot >= 0, widget.slot < Self.capacity,
              widget.columns <= columns, widget.rows <= Self.capacity / columns else { return false }
        let area = widgetCells(widget)
        guard area.count == widget.columns * widget.rows else { return false }
        return (widgets?[page] ?? []).allSatisfy {
            $0.id == widget.id || area.isDisjoint(with: widgetCells($0))
        }
    }

    @discardableResult
    mutating func changeWidget(_ id: String, page: Int, slot: Int? = nil,
                               width: Int? = nil, height: Int? = nil) -> Bool {
        guard let index = widgets?[page]?.firstIndex(where: { $0.id == id }),
              var widget = widgets?[page]?[index] else { return false }
        widget.slot = slot ?? widget.slot
        widget.columns = width ?? widget.columns
        widget.rows = height ?? widget.rows
        guard canPlaceWidget(widget, on: page) else { return false }
        widgets?[page]?[index] = widget
        return true
    }

    func widgetCells(_ widget: BloomBoxPlacedWidget) -> Set<Int> {
        let x = widget.slot % columns, y = widget.slot / columns
        guard widget.slot >= 0, widget.columns > 0, widget.rows > 0,
              x + widget.columns <= columns, (y + widget.rows) * columns <= Self.capacity else { return [] }
        return Set((0..<widget.rows).flatMap { row in
            (0..<widget.columns).map { widget.slot + row * columns + $0 }
        })
    }

    func occupiedByWidgets(_ page: Int) -> Set<Int> {
        (widgets?[page] ?? []).reduce(into: Set<Int>()) { $0.formUnion(widgetCells($1)) }
    }

    func freeAppSlot(_ page: Int) -> Int? {
        guard pages.indices.contains(page) else { return nil }
        let occupied = occupiedByWidgets(page)
        return pages[page].indices.first { pages[page][$0] == nil && !occupied.contains($0) }
            ?? pages[page].indices.first { pages[page][$0] == nil }
    }

    mutating func insertWidget(_ kind: String, style: String?, preferred: Int) -> Int {
        let candidates = [preferred] + pages.indices.filter { $0 != preferred }
        for index in candidates where pages.indices.contains(index) {
            let occupied = occupiedByWidgets(index)
            for slot in pages[index].indices {
                var widget = BloomBoxPlacedWidget(kind: kind, slot: slot, columns: 2, rows: 2)
                widget.glass = false
                widget.clockStyle = style
                let cells = widgetCells(widget)
                guard cells.count == 4, cells.isDisjoint(with: occupied) else { continue }
                var next = widgets ?? [:]
                next[index, default: []].append(widget)
                widgets = next
                return index
            }
        }
        pages.append(Self.emptyPage())
        return insertWidget(kind, style: style, preferred: pages.count - 1)
    }

    mutating func removeWidget(_ id: String, page: Int) {
        widgets?[page]?.removeAll { $0.id == id }
        widgetOpacity?.removeValue(forKey: id)
    }

    mutating func updateWidgetMedia(_ id: String, name: String) {
        for page in Array(widgets?.keys ?? Dictionary<Int, [BloomBoxPlacedWidget]>().keys) {
            guard let index = widgets?[page]?.firstIndex(where: { $0.id == id }) else { continue }
            widgets?[page]?[index].mediaName = name
        }
    }

    mutating func putInFolder(_ key: String, id: String) {
        guard key != id, folders[key] == nil, var destination = folders[id] else { return }
        if destination.apps.contains(key) { return }
        remove(key)
        destination.apps.append(key)
        folders[id] = destination
    }

    mutating func reconcile(_ installed: [String]) {
        // Keep unavailable guests in their saved slots during registry reloads.
        let valid = Set(installed).union(known)
        columns = columns == 5 ? 5 : 4
        iconShape = min(2, max(0, iconShape))
        wallpaper = min(3, max(0, wallpaper))
        for id in Array(folders.keys) {
            folders[id]?.apps.removeAll { !valid.contains($0) }
            if folders[id]?.apps.isEmpty != false { folders.removeValue(forKey: id) }
        }
        let allowed = valid.union(folders.keys)
        pages = pages.map { page in
            var result = Array(page.prefix(Self.capacity))
            result += Array(repeating: nil, count: Self.capacity - result.count)
            return result.map { key in key.flatMap { allowed.contains($0) ? $0 : nil } }
        }
        if pages.isEmpty { pages = [Self.emptyPage()] }
        let overflow = dock.dropFirst(Self.dockCapacity).compactMap { $0 }
        dock = Array(dock.prefix(Self.dockCapacity))
        dock += Array(repeating: nil, count: Self.dockCapacity - dock.count)
        for key in overflow where allowed.contains(key) && !contains(key) { add(key, preferred: 0) }
        searchBar?.normalize()
        drawerAppearance?.normalize()
        drawerAppearance?.recent.removeAll { !valid.contains($0) }
        dock = dock.map { key in key.flatMap { allowed.contains($0) ? $0 : nil } }
        // Deduplicate damaged or old workspace state without deleting guest data.
        var seen = Set<String>()
        for i in dock.indices {
            if let key = dock[i], !seen.insert(key).inserted { dock[i] = nil }
        }
        for i in pages.indices {
            for j in pages[i].indices {
                if let key = pages[i][j], !seen.insert(key).inserted { pages[i][j] = nil }
            }
        }
        for id in folders.keys.sorted() {
            let uniqueApps = (folders[id]?.apps ?? []).filter { seen.insert($0).inserted }
            folders[id]?.apps = uniqueApps
            if folders[id]?.apps.isEmpty != false {
                folders.removeValue(forKey: id)
                remove(id)
            }
        }
        let previous = Set(known)
        for key in installed where !previous.contains(key) && !seen.contains(key) {
            add(key, preferred: 0)
            seen.insert(key)
        }
        known = Array(Set(known).union(installed)).sorted()
    }

    func contains(_ key: String) -> Bool {
        dock.contains(key) || pages.contains { $0.contains(key) } ||
        folders.values.contains { $0.apps.contains(key) }
    }

    mutating func remove(_ key: String) {
        for i in pages.indices {
            for j in pages[i].indices where pages[i][j] == key { pages[i][j] = nil }
        }
        for i in dock.indices where dock[i] == key { dock[i] = nil }
        for id in Array(folders.keys) {
            folders[id]?.apps.removeAll { $0 == key }
            if folders[id]?.apps.isEmpty == true {
                folders.removeValue(forKey: id)
                for i in pages.indices {
                    for j in pages[i].indices where pages[i][j] == id { pages[i][j] = nil }
                }
                for i in dock.indices where dock[i] == id { dock[i] = nil }
            }
        }
    }

    mutating func add(_ key: String, preferred: Int) {
        remove(key)
        if pages.indices.contains(preferred), let slot = freeAppSlot(preferred) {
            pages[preferred][slot] = key
        } else if let i = pages.indices.first(where: { freeAppSlot($0) != nil }),
                  let slot = freeAppSlot(i) {
            pages[i][slot] = key
        } else {
            pages.append(Self.emptyPage())
            pages[pages.count - 1][0] = key
        }
    }

    mutating func place(_ key: String, page: Int, slot: Int) {
        guard pages.indices.contains(page), pages[page].indices.contains(slot),
              pages[page][slot] != key else { return }
        let displaced = pages[page][slot]
        // Swap in-place when moving within a workspace or dock.
        let sourcePage = pages.firstIndex { $0.contains(key) }
        let sourceSlot = sourcePage.flatMap { pages[$0].firstIndex(of: key) }
        let sourceDock = dock.firstIndex(of: key)
        remove(key)
        pages[page][slot] = key
        if let displaced {
            if let sourcePage, let sourceSlot { pages[sourcePage][sourceSlot] = displaced }
            else if let sourceDock { dock[sourceDock] = displaced }
            else { add(displaced, preferred: page) }
        }
    }

    mutating func placeInDock(_ key: String, slot: Int, page: Int) {
        guard dock.indices.contains(slot), dock[slot] != key else { return }
        let displaced = dock[slot]
        let sourcePage = pages.firstIndex { $0.contains(key) }
        let sourceSlot = sourcePage.flatMap { pages[$0].firstIndex(of: key) }
        let sourceDock = dock.firstIndex(of: key)
        remove(key)
        dock[slot] = key
        if let displaced {
            if let sourcePage, let sourceSlot { pages[sourcePage][sourceSlot] = displaced }
            else if let sourceDock { dock[sourceDock] = displaced }
            else { add(displaced, preferred: page) }
        }
    }

    mutating func createFolder(_ first: String, _ second: String, name: String, page: Int) {
        guard first != second, folders[first] == nil, folders[second] == nil else { return }
        remove(first)
        remove(second)
        let id = "nova-folder:" + UUID().uuidString
        folders[id] = Folder(name: name, apps: [first, second])
        add(id, preferred: page)
    }

    mutating func dissolve(_ id: String, page: Int) {
        guard let folder = folders.removeValue(forKey: id) else { return }
        remove(id)
        for key in folder.apps { add(key, preferred: page) }
    }

    mutating func removePage(_ index: Int) {
        guard pages.count > 1, pages.indices.contains(index) else { return }
        let removed = pages.remove(at: index).compactMap { $0 }
        // Page removal must not silently discard widgets. Retain them on a
        // dedicated replacement page if the page contains any.
        if let retained = widgets?[index], !retained.isEmpty {
            var next = widgets ?? [:]
            next.removeValue(forKey: index)
            widgets = Dictionary(uniqueKeysWithValues: next.map { ($0.key > index ? $0.key - 1 : $0.key, $0.value) })
            pages.append(Self.emptyPage())
            widgets?[pages.count - 1] = retained
        } else if let old = widgets {
            widgets = Dictionary(uniqueKeysWithValues: old.filter { $0.key != index }.map { ($0.key > index ? $0.key - 1 : $0.key, $0.value) })
        }
        for key in removed { add(key, preferred: min(index, pages.count - 1)) }
    }
}

// All Nova surfaces are deliberately opaque, with plain controls. System
// pickers, guest settings and installer actions are owned by their existing hosts.
@MainActor private final class BloomBoxNovaPointer: ObservableObject {
    struct Position: Equatable {
        let location: CGPoint
        let highlight: CGRect?
    }
    @Published private(set) var position: Position?
    func move(to point: CGPoint, highlight: CGRect?) {
        let next = Position(location: point, highlight: highlight)
        if position != next { position = next }
    }
    func reset() { position = nil }
}

// Only this small view observes touch coordinates. The desktop and drawer
// update when a drag begins or ends, not for each pointer sample.
private struct BloomBoxNovaDragOverlay: View {
    @ObservedObject var pointer: BloomBoxNovaPointer
    let image: AnyView
    let origin: CGPoint
    var body: some View {
        ZStack(alignment: .topLeading) {
            if let position = pointer.position {
                image.position(x: position.location.x - origin.x, y: position.location.y - origin.y)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// A single native recognizer owns the original touch and the menu deadline.
private final class BloomBoxNovaContact: UIGestureRecognizer {
    enum Event { case none, tap, hold, drag, finish, cancel }
    var permitsDrag = true
    var dragAfterHold = false
    var holdDuration: TimeInterval = 3
    private(set) var event: Event = .none
    private(set) var point = CGPoint.zero
    private(set) var delta = CGSize.zero
    private(set) var anchor = CGRect.zero
    private var first = CGPoint.zero
    private var started: TimeInterval = 0
    private var finger: UITouch?
    private var timer: DispatchWorkItem?
    private var dragging = false
    private var held = false

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard finger == nil, touches.count == 1, let touch = touches.first,
              let view, let window = view.window else { cancelContact(); return }
        finger = touch
        first = touch.location(in: window)
        point = first
        anchor = view.convert(view.bounds, to: window)
        started = touch.timestamp
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.state == .possible, self.finger != nil,
                  !self.dragging, !self.held else { return }
            self.held = true
            if self.dragAfterHold {
                self.first = self.point
                self.delta = .zero
            }
            self.event = .hold
            self.state = .began
        }
        timer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration, execute: work)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let finger, touches.contains(finger), let window = view?.window,
              !held || (dragAfterHold && permitsDrag) else { return }
        point = finger.location(in: window)
        delta = CGSize(width: point.x - first.x, height: point.y - first.y)
        if dragging {
            self.event = .drag
            state = .changed
            return
        }
        guard hypot(delta.width, delta.height) >= 10 else { return }
        timer?.cancel()
        let canStartDrag = dragAfterHold ? held : finger.timestamp - started >= 0.30
        guard permitsDrag, canStartDrag else {
            state = .failed
            return
        }
        dragging = true
        self.event = .drag
        state = held ? .changed : .began
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let finger, touches.contains(finger) else { return }
        timer?.cancel()
        if let window = view?.window {
            point = finger.location(in: window)
            delta = CGSize(width: point.x - first.x, height: point.y - first.y)
        }
        if dragging {
            self.event = .finish
            state = .ended
        } else if held {
            self.event = .none
            state = .ended
        } else if finger.timestamp - started < 0.30 && hypot(delta.width, delta.height) < 10 {
            self.event = .tap
            state = .recognized
        } else { state = .failed }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) { cancelContact() }

    func cancelContact() {
        timer?.cancel()
        if state == .began || state == .changed {
            event = .cancel
            state = .cancelled
        } else if state == .possible { state = .failed }
    }

    override func reset() {
        super.reset()
        timer?.cancel()
        timer = nil
        finger = nil
        dragging = false
        held = false
        event = .none
        delta = .zero
    }

    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
        if finger != nil && (dragging || held || hypot(delta.width, delta.height) < 10) { return false }
        return super.canBePrevented(by: preventingGestureRecognizer)
    }
}

private struct BloomBoxNovaTouchSurface: UIViewRepresentable {
    var permitsDrag = true
    var dragAfterHold = false
    var holdDuration: TimeInterval = 3
    let tap: () -> Void
    let hold: (CGRect) -> Void
    let armed: (Bool) -> Void
    let move: (CGPoint, CGSize) -> Void
    let finish: (CGPoint, CGSize) -> Void
    let cancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isAccessibilityElement = false
        let contact = BloomBoxNovaContact(target: context.coordinator, action: #selector(Coordinator.contact(_:)))
        contact.permitsDrag = permitsDrag
        contact.dragAfterHold = dragAfterHold
        contact.holdDuration = holdDuration
        contact.cancelsTouchesInView = true
        view.addGestureRecognizer(contact)
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
        if let contact = uiView.gestureRecognizers?.first as? BloomBoxNovaContact {
            contact.permitsDrag = permitsDrag
            contact.dragAfterHold = dragAfterHold
            contact.holdDuration = holdDuration
        }
    }
    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        if let contact = uiView.gestureRecognizers?.first as? BloomBoxNovaContact {
            contact.removeTarget(coordinator, action: nil)
            contact.cancelContact()
        }
    }

    final class Coordinator: NSObject {
        var parent: BloomBoxNovaTouchSurface
        private var moving = false
        init(_ parent: BloomBoxNovaTouchSurface) { self.parent = parent }
        @objc func contact(_ recognizer: BloomBoxNovaContact) {
            switch recognizer.event {
            case .tap: parent.tap()
            case .hold:
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                parent.hold(recognizer.anchor)
            case .drag:
                if !moving { moving = true; parent.armed(true) }
                parent.move(recognizer.point, recognizer.delta)
            case .finish:
                parent.finish(recognizer.point, recognizer.delta)
                releaseDrag()
            case .cancel:
                if moving { parent.cancel(); releaseDrag() }
            case .none: break
            }
        }
        private func releaseDrag() {
            moving = false
            let release = parent.armed
            DispatchQueue.main.async { release(false) }
        }
    }
}

private struct BloomBoxNovaStableContent<Signature: Equatable, Content: View>: View, Equatable {
    let signature: Signature
    let content: () -> Content
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.signature == rhs.signature }
    var body: some View { content() }
}

private struct BloomBoxNovaDropTarget: Hashable {
    let page: Int
    let slot: Int
    let dock: Bool
}

private struct BloomBoxNovaDropFrames: PreferenceKey {
    static var defaultValue: [BloomBoxNovaDropTarget: CGRect] { [:] }
    static func reduce(value: inout [BloomBoxNovaDropTarget: CGRect], nextValue: () -> [BloomBoxNovaDropTarget: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct BloomBoxNovaV2View: View {
    let profileID: String
    let keys: [String]
    let names: [String: String]
    let orderedKeys: [String]
    let iconRevision: String
    private func name(_ key: String) -> String { names[key] ?? key }
    let icon: (String, CGFloat) -> AnyView
    let isGuest: (String) -> Bool
    let hasGift: (String) -> Bool
    let canJIT: (String) -> Bool
    let jitEnabled: (String) -> Bool
    let setJIT: (String, Bool) -> Void
    let rename: (String) -> Void
    let changeIcon: (String) -> Void
    let toggleFavorite: (String) -> Void
    let favorite: (String) -> Bool
    let toggleNetwork: (String) -> Void
    let networkBlocked: (String) -> Bool
    let addTweak: (String) -> Void
    let toggleAudio: (String) -> Void
    let audioEnabled: (String) -> Bool
    let isAndroid: (String) -> Bool
    let launch: (String) -> Void
    let launchJIT: (String) -> Void
    let manage: (String) -> Void
    let uninstall: (String) -> Void
    let orientation: (String, String) -> Void
    let openInstall: () -> Void
    let openInterface: () -> Void
    let openManagement: () -> Void
    let openGameBox: () -> Void
    let openSettings: () -> Void
    let newsPage: () -> AnyView

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("BloomBoxPreferredLanguage", store: LiveContainerPreferencesAdapter.defaults)
    private var language = "system"
    @State private var workspace = BloomBoxNovaWorkspace()
    @State private var loaded = false
    @State private var interactionEpoch = 0
    @State private var wasBackgrounded = false
    @State private var persistenceFailed = false
    @State private var page = 0
    // The gesture state resets even if UIKit cancels the touch (app switch,
    // system gesture, another recognizer). No half-open drawer can be stranded.
    private enum DrawerSwipe: Equatable {
        case idle
        case rejected
        case tracking(CGFloat)

        var delta: CGFloat {
            if case let .tracking(value) = self { return value }
            return 0
        }
    }
    @GestureState(resetTransaction: Transaction(animation: .spring(response: 0.34, dampingFraction: 0.88)))
    private var drawerSwipe: DrawerSwipe = .idle
    @State private var drawer = false
    private struct HomeDrag: Equatable {
        let key: String
        let size: CGFloat
        let moving: Bool
    }
    private struct WidgetDrag: Equatable {
        let widget: BloomBoxPlacedWidget
        let page: Int
        let width: CGFloat
        let height: CGFloat
    }
    @State private var homeDrag: HomeDrag?
    @State private var widgetDrag: WidgetDrag?
    @State private var widgetSelection: String?
    @State private var selectionAnchor: CGRect?
    @State private var pointer = BloomBoxNovaPointer()
    @State private var dropFrames: [BloomBoxNovaDropTarget: CGRect] = [:]
    @State private var suppressDrawerForIcon = false
    @State private var editing = false
    @State private var widgetsExpanded = false
    @State private var widgetQuery = ""
    @State private var expandedWidgetProvider = true
    @State private var widgetMediaID: String?
    @State private var widgetMediaImport = false
    @State private var widgetMediaError = false
    @State private var noteEditor = false
    @AppStorage("ManzanaNote", store: LiveContainerPreferencesAdapter.defaults) private var widgetNote = ""
    @State private var settings = false
    @State private var searchSettings = false
    @State private var drawerSettings = false
    @State private var shortcutPicker = false
    @State private var shortcutQuery = ""
    @State private var focusDrawerOnAppear = false
    @State private var query = ""
    @State private var selected: String?
    @State private var folder: String?
    @State private var folderSource: String?
    @State private var importWallpaper = false
    @State private var photo: UIImage?
    @State private var wallpaperError = false
    @FocusState private var searching: Bool

    private let panel = Color(red: 0.11, green: 0.13, blue: 0.15)
    private let raised = Color(red: 0.18, green: 0.21, blue: 0.23)
    private let accent = Color(red: 0.54, green: 0.87, blue: 0.64)
    private var english: Bool {
        language == "en" || (language == "system" &&
            (Locale.preferredLanguages.first ?? "en").lowercased().hasPrefix("en"))
    }
    private func t(_ en: String, _ es: String) -> String { english ? en : es }
    private var defaults: UserDefaults { LiveContainerPreferencesAdapter.defaults }
    private var storageKey: String { "BloomBoxNovaWorkspaceV2/" + profileID }
    private var workspaceURL: URL {
        wallpaperURL.deletingLastPathComponent()
            .appendingPathComponent(wallpaperURL.deletingPathExtension().lastPathComponent + ".workspace.json")
    }
    private var distinctKeys: [String] {
        var seen = Set<String>()
        return keys.filter { seen.insert($0).inserted }
    }
    private var visibleKeys: [String] {
        query.isEmpty ? orderedKeys : orderedKeys.filter { name($0).localizedCaseInsensitiveContains(query) }
    }
    private struct HomeSignature: Equatable {
        let workspace: BloomBoxNovaWorkspace
        let names: [String: String]
        let iconRevision: String
        let gifts: Set<String>
        let page: Int
        let editing: Bool
        let drag: HomeDrag?
        let widgetDrag: WidgetDrag?
        let language: String
        let travel: CGFloat
        let drawer: Bool
        let showHomeSearchBar: Bool
    }

    private struct DrawerSignature: Equatable {
        let style: BloomBoxNovaWorkspace.DrawerAppearance
        let names: [String: String]
        let iconRevision: String
        let gifts: Set<String>
        let query: String
        let editing: Bool
        let language: String
        let shape: Int
        let drawer: Bool
    }

    private var giftKeys: Set<String> { Set(keys.filter(hasGift)) }

    private func stableHome(travel: CGFloat, showHomeSearchBar: Bool) -> some View {
        BloomBoxNovaStableContent(signature: HomeSignature(
            workspace: workspace, names: names, iconRevision: iconRevision,
            gifts: giftKeys, page: page, editing: editing, drag: homeDrag, widgetDrag: widgetDrag,
            language: language, travel: travel, drawer: drawer, showHomeSearchBar: showHomeSearchBar
        )) { homeView(travel: travel, showHomeSearchBar: showHomeSearchBar) }.equatable()
    }

    private var stableDrawer: some View {
        BloomBoxNovaStableContent(signature: DrawerSignature(
            style: drawerStyle, names: names, iconRevision: iconRevision,
            gifts: giftKeys, query: query, editing: editing, language: language,
            shape: workspace.iconShape, drawer: drawer
        )) { drawerView() }.equatable()
    }

    private var grid: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 5), count: workspace.columns)
    }
    private var wallpaperURL: URL {
        let safe = profileID.filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BloomBoxNovaV2", isDirectory: true)
            .appendingPathComponent(safe + ".jpg")
    }
    private func displayName(_ key: String) -> String { workspace.folders[key]?.name ?? name(key) }
    private func valid(_ key: String) -> Bool { distinctKeys.contains(key) || workspace.folders[key] != nil }
    private func animate(_ action: () -> Void) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.20), action)
    }

    var body: some View {
        ZStack {
            wallpaperView
            GeometryReader { geometry in
                // Keep both views mounted throughout the swipe. Switching the
                // hierarchy at a threshold would cancel the Dock recognizer.
                let height = max(1, geometry.size.height)
                let closedBarY = max(32, height - 28)
                let openBarY: CGFloat = 32
                let travel = max(1, closedBarY - openBarY)
                let progress = drawerProgress(travel: travel)
                let barY = closedBarY - progress * travel
                let showMovingSearchBar = drawer || progress > 0
                ZStack(alignment: .top) {
                    // Move the Home icons out of the way, leaving only the
                    // wallpaper behind the customizable drawer background.
                    stableHome(travel: travel, showHomeSearchBar: !showMovingSearchBar)
                        .id(interactionEpoch)
                        .frame(width: geometry.size.width,
                               height: editing ? max(120, height - collapsedWidgetPanelHeight(height) - 150) : height,
                               alignment: .top)
                        .scaleEffect(editing ? 0.94 : 1, anchor: .top)
                        .offset(y: -progress * (height + geometry.safeAreaInsets.bottom))
                        .allowsHitTesting(!drawer && !(editing && widgetsExpanded))
                        .accessibilityHidden(drawer || (editing && widgetsExpanded))
                    // Separate, full-bleed background outside the safe-area
                    // content frame. The search and app grid stay inset.
                    rgbColor(drawerStyle.backgroundRGB)
                        .opacity(1 - drawerStyle.transparency)
                        .frame(width: geometry.size.width,
                               height: height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom)
                        .position(x: geometry.size.width / 2,
                                  y: (height + geometry.safeAreaInsets.bottom - geometry.safeAreaInsets.top) / 2)
                        .offset(y: (1 - progress) * (height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom))
                        .allowsHitTesting(false)
                        .zIndex(0.5)
                    stableDrawer
                        .frame(width: geometry.size.width, height: height)
                        .offset(y: (1 - progress) * height)
                        .allowsHitTesting(drawer && page >= 0)
                        .accessibilityHidden(!drawer || page < 0)
                        .zIndex(1)
                    // During a vertical transition the search bar travels
                    // between the desktop footer and the drawer header.
                    searchBarView(preview: false, inDrawer: drawer, showHint: progress > 0.08)
                        .frame(width: geometry.size.width, height: 44)
                        .position(x: geometry.size.width / 2, y: barY)
                        .simultaneousGesture(drawerGesture(travel: travel, opening: !drawer))
                        .opacity(showMovingSearchBar && !editing && page >= 0 ? 1 : 0)
                        .allowsHitTesting(drawer && page >= 0)
                        .accessibilityHidden(!drawer || page < 0)
                        .zIndex(2)
                    if editing {
                        editPanel(height: height).zIndex(2.2)
                    }
                    let origin = geometry.frame(in: .global).origin
                    if let drag = homeDrag, drag.moving {
                        BloomBoxNovaDragOverlay(pointer: pointer,
                            image: AnyView(tileImage(drag.key, size: drag.size * 1.12)), origin: origin)
                            .zIndex(2.5)
                    } else if let drag = widgetDrag {
                        BloomBoxNovaDragOverlay(pointer: pointer,
                            image: AnyView(widgetArtwork(drag.widget, width: drag.width, height: drag.height, active: false)), origin: origin)
                            .zIndex(2.5)
                    }
                }
                .frame(width: geometry.size.width, height: height)
            }
            if settings { settingsView.zIndex(3) }
            if let folder { folderView(folder).zIndex(4) }
            if let selected {
                GeometryReader { geo in
                    contextPanel(selected, width: geo.size.width, height: geo.size.height, origin: geo.frame(in: .global).origin)
                }.zIndex(5)
            }
            if let id = widgetSelection,
               let widget = workspace.widgets?[page]?.first(where: { $0.id == id }) {
                widgetOptions(widget).zIndex(6)
            }
            if noteEditor {
                modal(t("Edit note", "Editar nota"), close: { noteEditor = false }) {
                    TextEditor(text: $widgetNote).frame(minHeight: 150)
                    actionRow(t("Done", "Listo"), "checkmark") { noteEditor = false }
                }.zIndex(10)
            }
            if let folderSource { folderPicker(folderSource).zIndex(6) }
            if searchSettings { searchSettingsView.zIndex(7) }
            if shortcutPicker { shortcutPickerView.zIndex(8) }
            if drawerSettings { drawerSettingsView.zIndex(9) }
        }
        .foregroundStyle(Color.white)
        .background(panel.ignoresSafeArea())
        .onReceive(NotificationCenter.default.publisher(for: BloomBoxTourEvents.explore)) { note in
            guard let destination = note.object as? String else { return }
            switch destination {
            case "library": openDrawer(focus: false)
            case "news": animate { page = -1 }
            case "desktop": animate { settings = true }
            case "widgets": animate { editing = true; widgetsExpanded = true; widgetQuery = "" }
            default: break
            }
        }
        .onAppear {
            guard !loaded else { return }
            restoreWorkspace()
            workspace.reconcile(distinctKeys)
            photo = UIImage(contentsOfFile: wallpaperURL.path)
            loaded = true
            save()
        }
        .onChange(of: distinctKeys) { new in
            guard loaded else { return }
            workspace.reconcile(new)
            page = min(page, workspace.pages.count - 1)
            if let selected, !valid(selected) { self.selected = nil }
            if let folder, workspace.folders[folder] == nil { self.folder = nil }
        }
        .onPreferenceChange(BloomBoxNovaDropFrames.self) { frames in
            if dropFrames != frames { dropFrames = frames }
        }
        .onChange(of: workspace) { _ in if loaded { save() } }
        .onChange(of: scenePhase) { phase in
            if phase == .background {
                if loaded { save() }
                wasBackgrounded = true
                resetTransientInteraction()
            } else if phase == .active && wasBackgrounded {
                wasBackgrounded = false
                resetTransientInteraction()
                interactionEpoch &+= 1
                if loaded { workspace.reconcile(distinctKeys) }
            }
        }
        .onDisappear {
            if loaded { save() }
            resetTransientInteraction()
        }
        .onChange(of: page) { _ in
            selected = nil
            widgetSelection = nil
            selectionAnchor = nil
            clearDrag()
            suppressDrawerForIcon = false
            if page < 0 {
                editing = false
                widgetsExpanded = false
                searching = false
                drawer = false
            }
        }
        .onChange(of: drawer) { opened in
            if !opened {
                searching = false
                focusDrawerOnAppear = false
            } else if focusDrawerOnAppear {
                focusDrawerOnAppear = false
                DispatchQueue.main.async { if drawer { searching = true } }
            }
        }
        .fileImporter(isPresented: $importWallpaper, allowedContentTypes: [.image]) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                guard data.count <= 15_000_000, let image = UIImage(data: data),
                      let jpeg = image.jpegData(compressionQuality: 0.86) else {
                    wallpaperError = true
                    return
                }
                try FileManager.default.createDirectory(at: wallpaperURL.deletingLastPathComponent(),
                                                        withIntermediateDirectories: true)
                try jpeg.write(to: wallpaperURL, options: .atomic)
                photo = image
                workspace.wallpaper = 3
            } catch { wallpaperError = true }
        }
        .fileImporter(isPresented: $widgetMediaImport, allowedContentTypes: [.image]) { result in
            defer { widgetMediaID = nil }
            guard let id = widgetMediaID else { return }
            do {
                let file = try BloomBoxWidgetMedia.importFile(result.get())
                workspace.updateWidgetMedia(id, name: file)
            } catch { widgetMediaError = true }
        }
        .alert(t("Widget image could not be loaded", "No se pudo cargar la imagen del widget"), isPresented: $widgetMediaError) {
            Button("OK", role: .cancel) {}
        }
        .alert(t("Wallpaper could not be loaded", "No se pudo cargar el fondo"), isPresented: $wallpaperError) {
            Button("OK", role: .cancel) {}
        }
        .accessibilityIdentifier("bloombox.nova.v2")
    }

    private func restoreWorkspace() {
        let fileExists = FileManager.default.fileExists(atPath: workspaceURL.path)
        let disk = try? Data(contentsOf: workspaceURL)
        let legacy = defaults.data(forKey: storageKey)
        for candidate in [disk, legacy].compactMap({ $0 }) {
            if let saved = try? JSONDecoder().decode(BloomBoxNovaWorkspace.self, from: candidate) {
                workspace = saved
                persistenceFailed = false
                return
            }
        }
        persistenceFailed = fileExists || legacy != nil
    }

    private func save() {
        guard loaded, !persistenceFailed else { return }
        do {
            let data = try JSONEncoder().encode(workspace)
            try FileManager.default.createDirectory(at: workspaceURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try data.write(to: workspaceURL, options: .atomic)
            defaults.set(data, forKey: storageKey)
        } catch {
            if let data = try? JSONEncoder().encode(workspace) { defaults.set(data, forKey: storageKey) }
            NSLog("BloomBox Nova workspace save failed: %@", error.localizedDescription)
        }
    }

    private func resetTransientInteraction() {
        clearDrag()
        suppressDrawerForIcon = false
        selected = nil
        widgetSelection = nil
        selectionAnchor = nil
        folder = nil
        folderSource = nil
        searching = false
        focusDrawerOnAppear = false
        drawer = false
        editing = false
        widgetsExpanded = false
    }

    private var wallpaperView: some View {
        ZStack {
            switch workspace.wallpaper {
            case 1: Color(red: 0.07, green: 0.20, blue: 0.16)
            case 2: Color(red: 0.12, green: 0.15, blue: 0.30)
            case 3:
                if let photo {
                    GeometryReader { geometry in
                        Image(uiImage: photo).resizable().scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    }
                } else { panel }
            default: Color(red: 0.07, green: 0.09, blue: 0.11)
            }
        }.ignoresSafeArea()
    }

    private func homeView(travel: CGFloat, showHomeSearchBar: Bool) -> some View {
        TabView(selection: $page) {
            VStack(spacing: 4) {
                newsPage()
                pageControl(currentPage: -1).frame(height: 22)
            }
            .tag(-1)

            ForEach(workspace.pages.indices, id: \.self) { index in
                VStack(spacing: 4) {
                    desktopGrid(index)
                    desktopFooter(index, showSearchBar: showHomeSearchBar)
                }
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .simultaneousGesture(drawerGesture(travel: travel, opening: true))
    }

    private func desktopGrid(_ index: Int) -> some View {
        GeometryReader { geo in
            let columns = workspace.columns
            let rows = (BloomBoxNovaWorkspace.capacity + columns - 1) / columns
            let rowHeight = max(1, (geo.size.height - 6) / CGFloat(rows))
            let cellWidth = max(1, (geo.size.width - 20) / CGFloat(columns))
            let labelSpace: CGFloat = workspace.labels ? 18 : 4
            let size = min(58, max(16, min(cellWidth - 12, rowHeight - labelSpace - 4)))
            // Fit every slot on the actual page, from top to bottom.
            // No vertical ScrollView clipping the last row.
            ZStack(alignment: .topLeading) {
                ForEach(workspace.widgets?[index] ?? []) { widget in
                    let w = max(1, CGFloat(widget.columns) * cellWidth - 8)
                    let h = max(1, CGFloat(widget.rows) * rowHeight - 8)
                    novaWidget(widget, pageIndex: index, width: w, height: h, cellWidth: cellWidth, rowHeight: rowHeight)
                        .position(x: 10 + CGFloat(widget.slot % columns) * cellWidth + CGFloat(widget.columns) * cellWidth / 2,
                                  y: 3 + CGFloat(widget.slot / columns) * rowHeight + CGFloat(widget.rows) * rowHeight / 2)
                }
                let occupied = workspace.occupiedByWidgets(index)
                VStack(spacing: 0) {
                    ForEach(0..<rows, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<columns, id: \.self) { column in
                                let slot = row * columns + column
                                if workspace.pages[index].indices.contains(slot) {
                                    let key = workspace.pages[index][slot]
                                    slotView(key, size: size, dockSlot: nil, pageIndex: index,
                                             slot: slot, overWidget: occupied.contains(slot))
                                        .frame(width: cellWidth, height: rowHeight)
                                } else {
                                    Color.clear.frame(width: cellWidth, height: rowHeight)
                                        .allowsHitTesting(false)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 3)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            }
        }
    }

    private func desktopFooter(_ index: Int, showSearchBar: Bool) -> some View {
        VStack(spacing: 3) {
            ZStack {
                pageControl(currentPage: index)
                if !editing {
                    HStack {
                        Spacer()
                        Button { openDrawer(focus: false) } label: {
                            Image(systemName: "chevron.up").font(.caption.weight(.semibold))
                                .frame(width: 32, height: 22)
                        }
                        .buttonStyle(.plain)
                        .bloomBoxTourAnchor("library")
                        .accessibilityLabel(t("Open app drawer", "Abrir cajón de apps"))
                    }.padding(.horizontal, 12)
                }
            }.frame(height: 22)
            if !editing {
                dockView(pageIndex: index)
                searchBarView(preview: false)
                    .frame(height: 50, alignment: .top)
                    .opacity(showSearchBar ? 1 : 0)
                    .accessibilityHidden(!showSearchBar)
            }
        }
        .contentShape(Rectangle())
    }

    private func drawerProgress(travel: CGFloat) -> CGFloat {
        let base: CGFloat = drawer ? 1 : 0
        return min(1, max(0, base + drawerSwipe.delta / max(1, travel)))
    }

    private var drawerGestureBlocked: Bool {
        page < 0 || editing || suppressDrawerForIcon || homeDrag != nil || widgetDrag != nil || widgetSelection != nil || settings || searchSettings || drawerSettings || shortcutPicker ||
        selected != nil || folder != nil || folderSource != nil || searching
    }

    private func drawerGesture(travel: CGFloat, opening: Bool) -> some Gesture {
        // Global coordinates prevent feedback when the dragged Dock/header
        // itself moves underneath the finger.
        DragGesture(minimumDistance: 12, coordinateSpace: .global)
            .updating($drawerSwipe) { value, state, transaction in
                transaction.animation = nil
                guard !drawerGestureBlocked, drawer != opening else {
                    state = .rejected
                    return
                }
                let vertical = value.translation.height
                let horizontal = value.translation.width
                if case .idle = state {
                    let directionIsValid = opening ? vertical < 0 : vertical > 0
                    guard directionIsValid, abs(vertical) > abs(horizontal) * 1.35 else {
                        state = .rejected
                        return
                    }
                }
                guard state != .rejected else { return }
                // No threshold animation while held: one point of finger
                // movement equals one point of drawer movement.
                let delta = -vertical
                state = .tracking(opening ? min(travel, max(0, delta)) : max(-travel, min(0, delta)))
            }
            .onEnded { value in
                guard !drawerGestureBlocked, drawer != opening else { return }
                // GestureState can already have reset when onEnded arrives.
                // Validate the final direction rather than requiring tracking.
                if case .rejected = drawerSwipe { return }
                let direction: CGFloat = opening ? -1 : 1
                let vertical = direction * value.translation.height
                guard vertical > 0, vertical > abs(value.translation.width) * 1.35 else { return }
                let distance = vertical
                let projected = direction * value.predictedEndTranslation.height
                // The search bar travels from height - 28 to 32, so add
                // those 60 points to measure a quarter of the actual viewport.
                // A quick upward flick may open it even before that threshold.
                let threshold = opening ? (travel + 60) * 0.25 : travel * 0.36
                let farEnough = distance >= threshold
                let fastFlick = opening
                    ? distance >= 12 && projected - distance >= 45
                    : distance >= 20 && projected - distance >= 85
                guard farEnough || fastFlick else { return }
                settleDrawer(open: opening)
            }
    }

    private func settleDrawer(open: Bool) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.88)) {
            if open {
                query = ""
                editing = false
            } else {
                searching = false
                focusDrawerOnAppear = false
            }
            drawer = open
        }
    }

    private var editorBar: some View {
        HStack {
            Button { workspace.pages.append(BloomBoxNovaWorkspace.emptyPage()); page = workspace.pages.count - 1 } label: {
                Label(t("New page", "Nueva página"), systemImage: "plus")
            }
            Spacer()
            Button {
                workspace.removePage(page)
                page = min(page, workspace.pages.count - 1)
            } label: { Label(t("Remove page", "Quitar página"), systemImage: "minus") }
                .disabled(workspace.pages.count <= 1)
        }.font(.caption.weight(.semibold)).buttonStyle(.plain)
            .padding(12).background(raised).padding(.horizontal, 12)
    }

    private func pageControl(currentPage: Int) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Button { animate { page = -1 } } label: {
                    Image(systemName: "newspaper.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(currentPage == -1 ? accent : Color.gray)
                        .frame(minWidth: 22, minHeight: 22)
                }.buttonStyle(.plain).bloomBoxTourAnchor("news").accessibilityLabel(t("News", "Noticias"))
                ForEach(workspace.pages.indices, id: \.self) { index in
                    Button { animate { page = index } } label: {
                        Capsule().fill(currentPage == index ? accent : Color.gray)
                            .frame(width: currentPage == index ? 18 : 6, height: 6)
                            .frame(minWidth: 22, minHeight: 22)
                    }.buttonStyle(.plain)
                        .accessibilityLabel(t("Page", "Página") + " \(index + 1)")
                }
            }
        }.fixedSize(horizontal: workspace.pages.count < 10, vertical: true)
    }

    // Five user-controlled app slots, without an extra drawer button or backing
    // panel. The wallpaper shows directly between icons, as on Android.
    private func dockView(pageIndex: Int) -> some View {
        GeometryReader { geometry in
            let size = min(56, max(32, (geometry.size.width - 32) / CGFloat(BloomBoxNovaWorkspace.dockCapacity) - 8))
            HStack(spacing: 8) {
                ForEach(workspace.dock.indices, id: \.self) { index in
                    slotView(workspace.dock[index], size: size, dockSlot: index,
                             pageIndex: pageIndex, slot: index, hideLabel: true)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 66)
        .bloomBoxTourAnchor("dock")
        .accessibilityIdentifier("bloombox.nova.dock")
    }

    private var bar: BloomBoxNovaWorkspace.SearchBar {
        workspace.searchBar ?? BloomBoxNovaWorkspace.SearchBar()
    }

    private func updateBar(_ change: (inout BloomBoxNovaWorkspace.SearchBar) -> Void) {
        var value = bar
        change(&value)
        value.normalize()
        workspace.searchBar = value
    }

    private func rgbColor(_ value: UInt32) -> Color {
        Color(red: Double((value >> 16) & 255) / 255,
              green: Double((value >> 8) & 255) / 255,
              blue: Double(value & 255) / 255)
    }

    private func rgbValue(_ color: Color) -> UInt32? {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        guard UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        func byte(_ channel: CGFloat) -> UInt32 {
            UInt32((max(0, min(1, channel)) * 255).rounded())
        }
        return (byte(r) << 16) | (byte(g) << 8) | byte(b)
    }

    private var barInk: Color {
        guard bar.automaticInk else { return rgbColor(bar.iconRGB) }
        let rgb = bar.fillRGB
        func linear(_ byte: UInt32) -> Double {
            let v = Double(byte) / 255
            return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * linear((rgb >> 16) & 255)
            + 0.7152 * linear((rgb >> 8) & 255) + 0.0722 * linear(rgb & 255)
        return luminance > 0.179 ? .black : .white
    }

    private var leadingSymbol: String {
        ["circle.grid.3x3.fill", "magnifyingglass", "square.grid.3x3.fill"][bar.leadingIcon]
    }

    private var trailingSymbol: String {
        ["sparkles", "bolt.fill", "star.fill", "gearshape.fill"][bar.trailingSymbol]
    }

    private var shortcutApp: String? {
        guard let key = bar.trailingApp, distinctKeys.contains(key) else { return nil }
        return key
    }

    private func openDrawer(focus: Bool) {
        focusDrawerOnAppear = focus
        if !focus { searching = false }
        if drawer && focus {
            searching = true
            focusDrawerOnAppear = false
        } else {
            settleDrawer(open: true)
        }
    }

    private func searchBarView(preview: Bool, inDrawer: Bool = false, showHint: Bool = false) -> some View {
        let height: CGFloat = 44
        let radius: CGFloat = bar.shape == 0 ? height / 2 : (bar.shape == 1 ? 12 : 3)
        return HStack(spacing: 0) {
            if inDrawer && !preview {
                HStack(spacing: 9) {
                    Image(systemName: leadingSymbol).font(.system(size: 19, weight: .semibold))
                    TextField("", text: $query,
                              prompt: Text(t("Search apps", "Buscar apps")).foregroundColor(barInk.opacity(0.76)))
                        .textFieldStyle(.plain)
                        .foregroundStyle(barInk)
                        .focused($searching)
                        .autocorrectionDisabled(true)
                        .submitLabel(.search)
                        .accessibilityLabel(t("Search installed apps", "Buscar apps instaladas"))
                }
                .padding(.leading, 14)
                .frame(maxWidth: .infinity, minHeight: height)
                Button {
                    if query.isEmpty {
                        settleDrawer(open: false)
                    } else {
                        query = ""
                    }
                } label: {
                    Image(systemName: query.isEmpty ? "chevron.down" : "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 44, height: height)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(query.isEmpty ? t("Close app drawer", "Cerrar cajón") : t("Clear search", "Borrar búsqueda"))
            } else {
                Button {
                    if !preview { openDrawer(focus: true) }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: leadingSymbol).font(.system(size: 19, weight: .semibold))
                        if bar.leadingIcon != 1 {
                            Image(systemName: "magnifyingglass").font(.system(size: 12, weight: .semibold))
                        }
                        if showHint {
                            Text(t("Search apps", "Buscar apps")).font(.subheadline).lineLimit(1)
                                .padding(.leading, 6)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, 14)
                    .frame(maxWidth: .infinity, minHeight: height)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(t("Search installed apps", "Buscar apps instaladas"))
                .accessibilityIdentifier("bloombox.nova.searchBar.search")
                Button {
                    guard !preview else { return }
                    if let key = shortcutApp { activate(key) }
                    else { shortcutQuery = ""; shortcutPicker = true }
                } label: {
                    Group {
                        if let key = shortcutApp, bar.useAppArtwork {
                            icon(key, 27).frame(width: 27, height: 27)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        } else {
                            Image(systemName: trailingSymbol).font(.system(size: 20, weight: .semibold))
                        }
                    }
                    .frame(width: 52, height: height)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(shortcutApp.map { name($0) } ?? t("Choose shortcut app", "Elegir app de acceso rápido"))
                .accessibilityIdentifier("bloombox.nova.searchBar.shortcut")
            }
        }
        .foregroundStyle(barInk)
        .background(rgbColor(bar.fillRGB), in: RoundedRectangle(cornerRadius: radius))
        .frame(maxWidth: bar.compact ? 268 : .infinity)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .disabled(preview)
        .accessibilityHidden(preview)
    }

    private var searchSettingsView: some View {
        modal(t("Search bar", "Barra de búsqueda"), close: { searchSettings = false }) {
            searchBarView(preview: true).padding(.vertical, 8)
            Text(t("Appearance", "Apariencia")).font(.headline).foregroundStyle(accent)
            actionRow(t("Shape", "Forma") + ": " +
                      [t("Pill", "Cápsula"), t("Rounded", "Redondeada"), t("Square", "Rectangular")][bar.shape], "rectangle") {
                updateBar { $0.shape = ($0.shape + 1) % 3 }
            }
            actionRow(t("Width", "Ancho") + ": " + (bar.compact ? t("Compact", "Compacta") : t("Full", "Completa")), "arrow.left.and.right") {
                updateBar { $0.compact.toggle() }
            }
            ColorPicker(t("Bar color", "Color de la barra"), selection: Binding(
                get: { rgbColor(bar.fillRGB) },
                set: { color in if let rgb = rgbValue(color) { updateBar { $0.fillRGB = rgb } } }
            ), supportsOpacity: false)
                .padding(12).background(raised, in: RoundedRectangle(cornerRadius: 8))
            actionRow(t("Automatic icon color", "Color automático de iconos"),
                      bar.automaticInk ? "checkmark.square" : "square") {
                updateBar { $0.automaticInk.toggle() }
            }
            if !bar.automaticInk {
                ColorPicker(t("Icon color", "Color de iconos"), selection: Binding(
                    get: { rgbColor(bar.iconRGB) },
                    set: { color in if let rgb = rgbValue(color) { updateBar { $0.iconRGB = rgb } } }
                ), supportsOpacity: false)
                    .padding(12).background(raised, in: RoundedRectangle(cornerRadius: 8))
            }
            actionRow(t("Search icon", "Icono de búsqueda"), leadingSymbol) {
                updateBar { $0.leadingIcon = ($0.leadingIcon + 1) % 3 }
            }
            Text(t("App shortcut", "Acceso rápido a una app")).font(.headline).foregroundStyle(accent).padding(.top, 8)
            actionRow(shortcutApp.map { name($0) } ?? t("Choose app", "Elegir app"), "app.badge") {
                shortcutQuery = ""; shortcutPicker = true
            }
            if bar.trailingApp != nil {
                actionRow(t("Remove shortcut", "Quitar acceso"), "minus.circle") {
                    updateBar { $0.trailingApp = nil }
                }
            }
            actionRow(t("Use app artwork", "Usar icono de la app"),
                      bar.useAppArtwork ? "checkmark.square" : "square") {
                updateBar { $0.useAppArtwork.toggle() }
            }
            actionRow(t("Shortcut symbol", "Símbolo del acceso"), trailingSymbol) {
                updateBar { $0.trailingSymbol = ($0.trailingSymbol + 1) % 4 }
            }
            actionRow(t("Restore defaults", "Restablecer diseño"), "arrow.counterclockwise") {
                workspace.searchBar = BloomBoxNovaWorkspace.SearchBar()
            }
        }
        .accessibilityIdentifier("bloombox.nova.searchBar.settings")
    }

    private var shortcutPickerView: some View {
        modal(t("Choose shortcut app", "Elegir app de acceso rápido"), close: { shortcutPicker = false }) {
            TextField(t("Search apps", "Buscar aplicaciones"), text: $shortcutQuery)
                .textFieldStyle(.plain).autocorrectionDisabled(true)
                .padding(12).background(raised, in: RoundedRectangle(cornerRadius: 8))
            let matches = distinctKeys.filter {
                shortcutQuery.isEmpty || name($0).localizedCaseInsensitiveContains(shortcutQuery)
            }.sorted { name($0).localizedStandardCompare(name($1)) == .orderedAscending }
            if matches.isEmpty {
                Text(t("No matching apps", "No hay aplicaciones")).foregroundStyle(Color.gray).padding(12)
            }
            ForEach(matches, id: \.self) { key in
                Button {
                    updateBar { $0.trailingApp = key }
                    shortcutPicker = false
                } label: {
                    HStack(spacing: 12) {
                        icon(key, 36).frame(width: 36, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Text(name(key)).lineLimit(1)
                        Spacer(minLength: 4)
                        if shortcutApp == key { Image(systemName: "checkmark").foregroundStyle(accent) }
                    }
                    .padding(10).background(raised, in: RoundedRectangle(cornerRadius: 8))
                }.buttonStyle(.plain)
            }
        }
    }

    private var drawerStyle: BloomBoxNovaWorkspace.DrawerAppearance {
        workspace.drawerAppearance ?? BloomBoxNovaWorkspace.DrawerAppearance()
    }

    private func updateDrawer(_ change: (inout BloomBoxNovaWorkspace.DrawerAppearance) -> Void) {
        var value = drawerStyle
        change(&value)
        value.normalize()
        workspace.drawerAppearance = value
    }

    private var drawerInk: Color {
        if drawerStyle.labelStyle == 1 { return .white }
        if drawerStyle.labelStyle == 2 { return .black }
        if drawerStyle.transparency > 0.45 { return .white }
        let rgb = drawerStyle.backgroundRGB
        let luminance = (0.299 * Double((rgb >> 16) & 255)
                         + 0.587 * Double((rgb >> 8) & 255)
                         + 0.114 * Double(rgb & 255)) / 255
        return luminance > 0.60 ? .black : .white
    }

    private var drawerGrid: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 4), count: drawerStyle.columns)
    }

    private var recentDrawerKeys: [String] {
        guard drawerStyle.showRecent, query.isEmpty else { return [] }
        return Array(drawerStyle.recent.filter { distinctKeys.contains($0) }.prefix(drawerStyle.columns))
    }

    private func recordDrawerLaunch(_ key: String) {
        guard distinctKeys.contains(key) else { return }
        updateDrawer {
            $0.recent.removeAll { $0 == key }
            $0.recent.insert(key, at: 0)
        }
    }

    private func drawerView() -> some View {
        GeometryReader { geometry in
            let size = min(54, max(30, (geometry.size.width - 24) / CGFloat(drawerStyle.columns) - 15))
            VStack(spacing: 0) {
                // Space for the shared search bar; the same view remains above
                // this scrolling grid throughout the interactive transition.
                Color.clear.frame(height: 62).allowsHitTesting(false)
                HStack(spacing: 8) {
                    Button(action: openInstall) {
                        Label(t("Install app", "Instalar app"), systemImage: "plus")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 11).padding(.vertical, 8)
                            .foregroundStyle(Color.white)
                            .background(raised, in: Capsule())
                    }.buttonStyle(.plain)
                    Button { drawerSettings = true } label: {
                        Label(t("Drawer settings", "Ajustes del cajón"), systemImage: "gearshape")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 11).padding(.vertical, 8)
                            .foregroundStyle(Color.white)
                            .background(raised, in: Capsule())
                    }.buttonStyle(.plain)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .contentShape(Rectangle())
                .simultaneousGesture(drawerGesture(travel: max(1, geometry.size.height - 60), opening: false))
                ScrollView {
                    VStack(spacing: 18) {
                        if !recentDrawerKeys.isEmpty {
                            LazyVGrid(columns: drawerGrid, spacing: 18) {
                                ForEach(recentDrawerKeys, id: \.self) { key in
                                    tile(key, size: size, alwaysLabel: true)
                                }
                            }
                            Capsule().fill(drawerInk.opacity(0.28))
                                .frame(width: 116, height: 2).padding(.vertical, 10)
                        }
                        if visibleKeys.isEmpty {
                            Text(t("No matching apps", "No hay aplicaciones")).padding(35)
                        } else {
                            // The drawer is a flat alphabetical list of the
                            // installed registry. Home folders never enter it.
                            LazyVGrid(columns: drawerGrid, spacing: 28) {
                                ForEach(visibleKeys, id: \.self) { key in
                                    tile(key, size: size, alwaysLabel: true)
                                        .frame(minHeight: size + 30, alignment: .top)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(drawerInk)
            .background(Color.clear)
        }
        .accessibilityIdentifier("bloombox.nova.drawer")
    }

    private var drawerSettingsView: some View {
        modal(t("App drawer", "Cajón de aplicaciones"), close: { drawerSettings = false }) {
            ColorPicker(t("Background color", "Color de fondo"), selection: Binding(
                get: { rgbColor(drawerStyle.backgroundRGB) },
                set: { color in if let rgb = rgbValue(color) { updateDrawer { $0.backgroundRGB = rgb } } }
            ), supportsOpacity: false)
                .padding(12).background(raised, in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(t("Background transparency", "Transparencia del fondo"))
                    Spacer()
                    Text("\(Int((drawerStyle.transparency * 100).rounded()))%").monospacedDigit()
                }
                Slider(value: Binding(
                    get: { drawerStyle.transparency },
                    set: { value in updateDrawer { $0.transparency = value } }
                ), in: 0...1, step: 0.01)
                    .tint(accent)
                HStack {
                    Text(t("Solid", "Sólido"))
                    Spacer()
                    Text(t("Transparent", "Transparente"))
                }.font(.caption)
                ZStack {
                    Color(red: 0.45, green: 0.24, blue: 0.12)
                    rgbColor(drawerStyle.backgroundRGB).opacity(1 - drawerStyle.transparency)
                    Text(t("Preview", "Vista previa")).foregroundStyle(drawerInk)
                }.frame(height: 56).clipShape(RoundedRectangle(cornerRadius: 8))
            }.padding(12).background(raised, in: RoundedRectangle(cornerRadius: 8))
            actionRow(t("Columns", "Columnas") + ": \(drawerStyle.columns)", "square.grid.3x3") {
                updateDrawer { $0.columns = $0.columns >= 6 ? 4 : $0.columns + 1 }
            }
            actionRow(t("Show recent apps", "Mostrar apps recientes"),
                      drawerStyle.showRecent ? "checkmark.square" : "square") {
                updateDrawer { $0.showRecent.toggle() }
            }
            actionRow(t("App label color", "Color de nombres") + ": " +
                      [t("Automatic", "Automático"), t("White", "Blanco"), t("Black", "Negro")][drawerStyle.labelStyle],
                      "textformat") {
                updateDrawer { $0.labelStyle = ($0.labelStyle + 1) % 3 }
            }
            actionRow(t("Restore defaults", "Restablecer diseño"), "arrow.counterclockwise") {
                let recent = drawerStyle.recent
                workspace.drawerAppearance = BloomBoxNovaWorkspace.DrawerAppearance()
                workspace.drawerAppearance?.recent = recent
            }
        }
    }

    private func target(at location: CGPoint) -> BloomBoxNovaDropTarget? {
        var best: BloomBoxNovaDropTarget?
        for (candidate, rect) in dropFrames where
            candidate.page == page && rect.contains(location) {
            if let current = best {
                if candidate.dock == current.dock {
                    if candidate.slot < current.slot { best = candidate }
                } else if candidate.dock { best = candidate }
            } else { best = candidate }
        }
        return best
    }

    private func finishHomeDrag(_ key: String, at location: CGPoint) {
        guard valid(key), let destination = target(at: location) else { return }
        animate {
            if destination.dock {
                workspace.placeInDock(key, slot: destination.slot, page: page)
            } else {
                workspace.place(key, page: destination.page, slot: destination.slot)
            }
        }
        save()
    }

    private func clearDrag() {
        homeDrag = nil
        widgetDrag = nil
        pointer.reset()
    }

    private func showAppMenu(_ key: String, anchor: CGRect) {
        clearDrag()
        searching = false
        selectionAnchor = anchor
        animate { selected = key }
    }

    private func appTouch(_ key: String, size: CGFloat, permitsDrag: Bool) -> some View {
        BloomBoxNovaTouchSurface(permitsDrag: permitsDrag, dragAfterHold: true, holdDuration: 0.6,
            tap: { if !editing { activate(key) } else { selected = key } },
            hold: { showAppMenu(key, anchor: $0) },
            armed: { suppressDrawerForIcon = $0 },
            move: { point, _ in
                guard permitsDrag else { return }
                if homeDrag == nil {
                    selected = nil
                    selectionAnchor = nil
                    homeDrag = HomeDrag(key: key, size: size, moving: true)
                }
                pointer.move(to: point, highlight: nil)
            },
            finish: { point, _ in
                if homeDrag?.key == key { finishHomeDrag(key, at: point) }
                clearDrag()
            },
            cancel: { clearDrag() })
    }

    private func slotView(_ key: String?, size: CGFloat, dockSlot: Int?, pageIndex: Int, slot: Int, hideLabel: Bool = false, overWidget: Bool = false) -> some View {
        let destination = BloomBoxNovaDropTarget(page: pageIndex,
                                                 slot: dockSlot ?? slot, dock: dockSlot != nil)
        return ZStack {
            if let key, valid(key) {
                VStack(spacing: 3) {
                    tileImage(key, size: size)
                    if !hideLabel && workspace.labels {
                        Text(displayName(key)).font(.system(size: 11, weight: .medium))
                            .lineLimit(1).truncationMode(.tail)
                    }
                }
                .frame(width: size + 6)
                .opacity(homeDrag?.key == key && homeDrag?.moving == true ? 0 : 1)
                .contentShape(Rectangle())
                .overlay { appTouch(key, size: size, permitsDrag: !editing) }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(displayName(key))
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { if editing { selected = key } else { activate(key) } }
                .accessibilityAction(named: Text(t("App options", "Opciones de app"))) { selectionAnchor = nil; selected = key }
            } else if !overWidget {
                Color.clear.contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: 0.40, maximumDistance: 12) {
                        if dockSlot == nil && !editing && !drawer {
                            animate { editing = true; widgetsExpanded = false; widgetQuery = "" }
                        }
                    }
            } else {
                Color.clear.allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GeometryReader { geometry in
            Color.clear.allowsHitTesting(false).preference(key: BloomBoxNovaDropFrames.self,
                                   value: [destination: geometry.frame(in: .global)])
        })
    }

    @ViewBuilder private func tile(_ key: String, size: CGFloat, alwaysLabel: Bool, hideLabel: Bool = false) -> some View {
        let content = VStack(spacing: 4) {
            tileImage(key, size: size)
            if !hideLabel && (workspace.labels || alwaysLabel) {
                Text(displayName(key)).font(.system(size: 11, weight: .medium))
                    .lineLimit(1).truncationMode(.tail)
            }
        }
        .frame(maxWidth: .infinity, minHeight: hideLabel ? size + 4 : size + 20)
        .contentShape(Rectangle())
        .overlay { appTouch(key, size: size, permitsDrag: false) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(displayName(key))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { if editing { selected = key } else { activate(key) } }
        .accessibilityAction(named: Text(t("App options", "Opciones de app"))) { selectionAnchor = nil; selected = key }
        content
    }

    private func tileImage(_ key: String, size: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            if let item = workspace.folders[key] {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 2), spacing: 2) {
                    ForEach(Array(item.apps.prefix(4)), id: \.self) { child in
                        icon(child, size * 0.32).frame(width: size * 0.32, height: size * 0.32).clipped()
                    }
                }.padding(5).frame(width: size, height: size).background(raised)
            } else {
                icon(key, size).frame(width: size, height: size)
                if hasGift(key) {
                    Image(systemName: "gift.fill").font(.caption).foregroundStyle(panel)
                        .padding(4).background(accent, in: Circle())
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: workspace.iconShape == 0 ? size * 0.20 : workspace.iconShape == 1 ? size / 2 : 2))
        .bloomBoxTourAnchor(key)
    }

    private func activate(_ key: String) {
        guard valid(key) else { return }
        if workspace.folders[key] != nil { animate { folder = key }; return }
        searching = false
        if !hasGift(key) {
            recordDrawerLaunch(key)
            settleDrawer(open: false)
            folder = nil
            query = ""
        }
        launch(key)
    }

    private func control(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 17, weight: .semibold))
                .frame(width: 42, height: 42).background(raised, in: RoundedRectangle(cornerRadius: 9))
        }.buttonStyle(.plain).accessibilityLabel(label)
    }

    private func actionRow(_ label: String, _ symbol: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol).frame(width: 22)
                Text(label).frame(maxWidth: .infinity, alignment: .leading)
            }.font(.subheadline.weight(.medium)).padding(12)
                .foregroundStyle(destructive ? Color.red : Color.white)
                .background(raised, in: RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain)
    }

    private func modal<Content: View>(_ title: String, close: @escaping () -> Void, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text(title).font(.title3.bold()).lineLimit(1)
                Spacer()
                control("xmark", t("Close", "Cerrar"), action: close)
            }
            ScrollView { VStack(alignment: .leading, spacing: 8, content: content) }
        }.padding(16).frame(maxWidth: 440)
            .background(panel, in: RoundedRectangle(cornerRadius: 20))
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.07, green: 0.09, blue: 0.11).ignoresSafeArea().onTapGesture(perform: close))
    }

    private func bubbleRow(_ label: String, _ symbol: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol).frame(width: 22)
                Text(label).frame(maxWidth: .infinity, alignment: .leading)
            }.font(.subheadline.weight(.medium))
                .foregroundStyle(destructive ? Color.red : Color.black)
                .padding(.horizontal, 12).padding(.vertical, 10)
        }.buttonStyle(.plain)
    }

    private func contextPanel(_ key: String, width: CGFloat, height: CGFloat, origin: CGPoint) -> some View {
        let stored = selectionAnchor ?? dropFrames.first { destination, _ in
            if destination.dock { return destination.page == page && workspace.dock.indices.contains(destination.slot) && workspace.dock[destination.slot] == key }
            return destination.page == page && workspace.pages.indices.contains(page) &&
                workspace.pages[page].indices.contains(destination.slot) && workspace.pages[page][destination.slot] == key
        }?.value
        let anchor = stored?.offsetBy(dx: -origin.x, dy: -origin.y)
        let bubbleWidth = min(294, max(180, width - 24))
        let gap: CGFloat = 28
        let topRoom = max(0, (anchor?.minY ?? height / 2) - gap - 10)
        let bottomRoom = max(0, height - (anchor?.maxY ?? height / 2) - gap - 10)
        let above = topRoom >= bottomRoom
        let bubbleHeight = min(440, max(90, max(topRoom, bottomRoom)))
        let x = min(width - bubbleWidth / 2 - 12, max(bubbleWidth / 2 + 12, anchor?.midX ?? width / 2))
        let y = above ? (anchor?.minY ?? height / 2) - gap - bubbleHeight / 2
                      : (anchor?.maxY ?? height / 2) + gap + bubbleHeight / 2
        let tailX = min(x + bubbleWidth / 2 - 14, max(x - bubbleWidth / 2 + 14, anchor?.midX ?? x))
        return ZStack(alignment: .topLeading) {
            Color.clear.contentShape(Rectangle()).onTapGesture { selected = nil }
            VStack(spacing: 0) {
                HStack {
                    tileImage(key, size: 30)
                    Text(displayName(key)).font(.headline).lineLimit(1)
                    Spacer()
                    Button { selected = nil } label: { Image(systemName: "xmark").padding(8) }.buttonStyle(.plain)
                }.padding(12)
                Divider()
                ScrollView {
                    VStack(spacing: 0) {
                        if workspace.folders[key] != nil {
                            bubbleRow(t("Open folder", "Abrir carpeta"), "folder") { selected = nil; folder = key }
                            bubbleRow(t("Dissolve folder", "Deshacer carpeta"), "folder.badge.minus") {
                                workspace.dissolve(key, page: page); selected = nil
                            }
                        } else {
                            bubbleRow(t("Open", "Abrir"), "play.fill") { selected = nil; activate(key) }
                            if workspace.contains(key) {
                                bubbleRow(t("Remove from Home Screen", "Quitar del escritorio"), "minus.circle", destructive: true) {
                                    workspace.remove(key); selected = nil
                                }
                            } else {
                                bubbleRow(t("Add to Home", "Añadir al escritorio"), "house") {
                                    workspace.add(key, preferred: page); selected = nil; settleDrawer(open: false)
                                }
                            }
                            bubbleRow(t("Add to folder", "Añadir a carpeta"), "folder.badge.plus") { selected = nil; folderSource = key }
                            if canJIT(key) {
                                bubbleRow(jitEnabled(key) ? t("Disable JIT", "Deshabilitar JIT") : t("Enable JIT", "Habilitar JIT"), "bolt.fill") {
                                    setJIT(key, !jitEnabled(key)); selected = nil
                                }
                                bubbleRow(t("Launch with JIT", "Abrir con JIT"), "bolt") {
                                    selected = nil; recordDrawerLaunch(key); settleDrawer(open: false); folder = nil; launchJIT(key)
                                }
                                bubbleRow(t("Rename", "Renombrar"), "pencil") { selected = nil; rename(key) }
                                bubbleRow(t("Change icon", "Cambiar icono"), "photo") { selected = nil; changeIcon(key) }
                                bubbleRow(favorite(key) ? t("Unfavorite", "Quitar favorito") : t("Favorite", "Favorito"), "star") { selected = nil; toggleFavorite(key) }
                                bubbleRow(networkBlocked(key) ? t("Allow Internet", "Permitir Internet") : t("Block Internet", "Bloquear Internet"), "wifi") { selected = nil; toggleNetwork(key) }
                                bubbleRow(audioEnabled(key) ? t("Disable simultaneous audio", "Desactivar audio simultáneo") : t("Allow simultaneous audio", "Permitir audio simultáneo"), "speaker.wave.2") { selected = nil; toggleAudio(key) }
                                bubbleRow(t("Add tweak", "Añadir tweak"), "square.and.arrow.down.on.square") { selected = nil; addTweak(key) }
                                bubbleRow(t("App settings", "Ajustes de app"), "gearshape") { selected = nil; manage(key) }
                            }
                            if isAndroid(key) {
                                bubbleRow(t("Portrait", "Vertical"), "iphone") { selected = nil; orientation(key, "portrait") }
                                bubbleRow(t("Landscape", "Horizontal"), "iphone.landscape") { selected = nil; orientation(key, "landscape") }
                                bubbleRow(t("Ask every launch", "Preguntar al abrir"), "arrow.triangle.2.circlepath") { selected = nil; orientation(key, "hybrid") }
                            }
                            if isGuest(key) {
                                bubbleRow(t("Uninstall", "Desinstalar"), "trash", destructive: true) { selected = nil; uninstall(key) }
                            }
                        }
                        bubbleRow(t("Pin to dock", "Fijar en Dock"), "rectangle.bottomthird.inset.filled") {
                            workspace.placeInDock(key, slot: workspace.dock.firstIndex(of: nil) ?? (BloomBoxNovaWorkspace.dockCapacity - 1), page: page)
                            selected = nil; settleDrawer(open: false)
                        }
                        ForEach(workspace.pages.indices, id: \.self) { index in
                            bubbleRow(t("Move to page", "Mover a página") + " \(index + 1)", "rectangle.on.rectangle") {
                                workspace.add(key, preferred: index); page = index; selected = nil; settleDrawer(open: false)
                            }
                        }
                    }
                }
            }
            .foregroundStyle(Color.black)
            .frame(width: bubbleWidth, height: bubbleHeight)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 22))
            .shadow(color: .black.opacity(0.2), radius: 12, y: 3)
            .position(x: x, y: y)
            if anchor != nil {
                Circle().fill(Color.white).frame(width: 13, height: 13)
                    .position(x: tailX, y: y + (above ? 1 : -1) * (bubbleHeight / 2 + 7))
                Circle().fill(Color.white).frame(width: 7, height: 7)
                    .position(x: tailX, y: y + (above ? 1 : -1) * (bubbleHeight / 2 + 19))
            }
        }
        .accessibilityIdentifier("bloombox.nova.contextBubble")
    }

    private func folderPicker(_ first: String) -> some View {
        modal(t("Choose another app", "Elige otra app"), close: { folderSource = nil }) {
            ForEach(workspace.folders.keys.sorted(), id: \.self) { id in
                actionRow(workspace.folders[id]?.name ?? t("Folder", "Carpeta"), "folder") {
                    workspace.putInFolder(first, id: id)
                    folderSource = nil; settleDrawer(open: false)
                }
            }
            Text(t("Create new folder with", "Crear carpeta nueva con")).font(.headline)
            ForEach(distinctKeys.filter { $0 != first }, id: \.self) { second in
                actionRow(name(second), "plus") {
                    workspace.createFolder(first, second, name: t("Folder", "Carpeta"), page: page)
                    folderSource = nil; folder = nil; settleDrawer(open: false)
                }
            }
        }
    }

    private func folderView(_ id: String) -> some View {
        modal(workspace.folders[id]?.name ?? t("Folder", "Carpeta"), close: { folder = nil }) {
            TextField(t("Folder name", "Nombre de carpeta"), text: Binding(
                get: { workspace.folders[id]?.name ?? "" },
                set: { workspace.folders[id]?.name = String($0.prefix(40)) }
            )).textFieldStyle(.plain).padding(12).background(raised, in: RoundedRectangle(cornerRadius: 8))
            LazyVGrid(columns: grid, spacing: 14) {
                ForEach(workspace.folders[id]?.apps ?? [], id: \.self) { key in tile(key, size: 46, alwaysLabel: true) }
            }
        }
    }

    private func widgetArtwork(_ widget: BloomBoxPlacedWidget, width: CGFloat, height: CGFloat, active: Bool) -> some View {
        var plain = widget
        plain.glass = false
        return BloomBoxGridWidgetView(widget: plain, width: width, height: height,
                                     active: active, clockAccentColor: accent)
            .background(raised.opacity(workspace.opacity(for: widget.id)), in: RoundedRectangle(cornerRadius: 16))
    }

    private func novaWidget(_ widget: BloomBoxPlacedWidget, pageIndex: Int, width: CGFloat, height: CGFloat,
                            cellWidth: CGFloat, rowHeight: CGFloat) -> some View {
        widgetArtwork(widget, width: width, height: height, active: page == pageIndex && !drawer)
            .opacity(widgetDrag?.widget.id == widget.id ? 0 : 1)
            .overlay {
                BloomBoxNovaTouchSurface(permitsDrag: !editing,
                    tap: {
                        if editing { widgetSelection = widget.id }
                        else if widget.kind == "notes" { noteEditor = true }
                        else if widget.kind == "media" { widgetMediaID = widget.id; widgetMediaImport = true }
                    },
                    hold: { _ in clearDrag(); widgetSelection = widget.id },
                    armed: { suppressDrawerForIcon = $0 },
                    move: { point, _ in
                        guard !editing, widgetSelection == nil else { return }
                        if widgetDrag == nil {
                            widgetDrag = WidgetDrag(widget: widget, page: pageIndex, width: width, height: height)
                        }
                        pointer.move(to: point, highlight: nil)
                    },
                    finish: { _, delta in
                        if widgetDrag?.widget.id == widget.id {
                            let col = min(workspace.columns - widget.columns, max(0,
                                widget.slot % workspace.columns + Int((delta.width / cellWidth).rounded())))
                            let row = min(BloomBoxNovaWorkspace.capacity / workspace.columns - widget.rows, max(0,
                                widget.slot / workspace.columns + Int((delta.height / rowHeight).rounded())))
                            if workspace.changeWidget(widget.id, page: pageIndex, slot: row * workspace.columns + col) {
                                save()
                            } else {
                                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                            }
                        }
                        clearDrag()
                    },
                    cancel: { clearDrag() })
            }
            .overlay(alignment: .topTrailing) {
                if editing {
                    Button { widgetSelection = widget.id } label: {
                        Image(systemName: "ellipsis.circle.fill").font(.title3).foregroundStyle(Color.white)
                    }.buttonStyle(.plain)
                }
            }
            .accessibilityLabel(t("Widget", "Widget"))
            .accessibilityAction(named: Text(t("Widget options", "Opciones del widget"))) { widgetSelection = widget.id }
    }

    private func widgetOptions(_ widget: BloomBoxPlacedWidget) -> some View {
        modal(t("Widget options", "Opciones del widget"), close: { widgetSelection = nil }) {
            Text(t("Background transparency", "Transparencia del fondo")).font(.headline)
            HStack {
                Slider(value: Binding(
                    get: { 1 - workspace.opacity(for: widget.id) },
                    set: { workspace.setOpacity(1 - $0, id: widget.id) }
                ), in: 0...1)
                Text("\(Int(((1 - workspace.opacity(for: widget.id)) * 100).rounded()))%")
                    .monospacedDigit().frame(width: 48)
            }
            actionRow(t("No background", "Sin fondo"), "square.dashed") {
                workspace.setOpacity(0, id: widget.id)
            }
            Text(t("Size", "Tamaño")).font(.headline)
            HStack {
                Text(t("Width", "Ancho"))
                Spacer()
                control("minus", t("Narrower", "Reducir ancho")) { resizeWidget(widget, width: max(1, widget.columns - 1), height: widget.rows) }
                Text("\(widget.columns)")
                control("plus", t("Wider", "Ampliar ancho")) { resizeWidget(widget, width: min(workspace.columns, widget.columns + 1), height: widget.rows) }
            }
            HStack {
                Text(t("Height", "Alto"))
                Spacer()
                control("minus", t("Shorter", "Reducir alto")) { resizeWidget(widget, width: widget.columns, height: max(1, widget.rows - 1)) }
                Text("\(widget.rows)")
                control("plus", t("Taller", "Ampliar alto")) { resizeWidget(widget, width: widget.columns, height: min(BloomBoxNovaWorkspace.capacity / workspace.columns, widget.rows + 1)) }
            }
            if widget.kind == "media" {
                actionRow(t("Change image or GIF", "Cambiar imagen o GIF"), "photo") {
                    widgetSelection = nil; widgetMediaID = widget.id; widgetMediaImport = true
                }
            }
            if widget.kind == "notes" {
                actionRow(t("Edit note", "Editar nota"), "pencil") { widgetSelection = nil; noteEditor = true }
            }
            actionRow(t("Remove widget", "Eliminar widget"), "trash", destructive: true) {
                workspace.removeWidget(widget.id, page: page); widgetSelection = nil
            }
            actionRow(t("Done", "Listo"), "checkmark") { widgetSelection = nil }
        }
    }

    private func resizeWidget(_ widget: BloomBoxPlacedWidget, width: Int, height: Int) {
        let col = min(widget.slot % workspace.columns, workspace.columns - width)
        let row = min(widget.slot / workspace.columns, BloomBoxNovaWorkspace.capacity / workspace.columns - height)
        let slot = row * workspace.columns + col
        if !workspace.changeWidget(widget.id, page: page, slot: slot, width: width, height: height) {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }

    private func addNovaWidget(_ kind: String, style: String? = nil) {
        page = workspace.insertWidget(kind, style: style, preferred: page)
        widgetsExpanded = false
        editing = false
    }

    private func widgetOption(_ title: String, kind: String, style: String? = nil) -> some View {
        var preview = BloomBoxPlacedWidget(kind: kind, slot: 0, columns: 2, rows: 2)
        preview.glass = false
        preview.clockStyle = style
        return VStack(spacing: 6) {
            BloomBoxGridWidgetView(widget: preview, width: 128, height: 104, active: false, clockAccentColor: accent)
                .background(raised, in: RoundedRectangle(cornerRadius: 16))
                .allowsHitTesting(false)
            Text(title).font(.caption).foregroundStyle(.white)
        }
        .contentShape(Rectangle())
        .onTapGesture { addNovaWidget(kind, style: style) }
        .onLongPressGesture(minimumDuration: 0.4) { addNovaWidget(kind, style: style) }
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { addNovaWidget(kind, style: style) }
    }

    private func collapsedWidgetPanelHeight(_ height: CGFloat) -> CGFloat {
        min(180, height * 0.30)
    }

    private func editorAction(_ symbol: String, _ label: String, primary: Bool = false,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: primary ? 42 : 35, weight: .medium))
                    .frame(height: 46)
                Text(label)
                    .font(.system(size: primary ? 16 : 14, weight: .semibold))
                    .lineLimit(1)
            }
            .frame(minWidth: 70, minHeight: 76)
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private func editPanel(height: CGFloat) -> some View {
        VStack(spacing: 12) {
            if !widgetsExpanded {
                HStack(spacing: 0) {
                    editorAction("photo.on.rectangle", t("Wallpapers", "Fondos")) { importWallpaper = true }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    editorAction("checkmark.circle.fill", t("Done", "Listo"), primary: true) {
                        animate { editing = false }
                    }.frame(maxWidth: .infinity, alignment: .center)
                    editorAction("gearshape", t("Settings", "Ajustes")) { settings = true }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }.padding(.horizontal, 22).frame(height: 78)
                editorBar
            }
            VStack(alignment: .leading, spacing: 12) {
                Capsule().fill(Color.gray).frame(width: 38, height: 4)
                    .frame(maxWidth: .infinity).padding(.top, 4)
                    .onTapGesture { animate { widgetsExpanded.toggle() } }
                HStack {
                    Image(systemName: "square.grid.2x2")
                    Text(t("Widgets", "Widgets")).font(.headline)
                    Spacer()
                    Button { animate { widgetsExpanded.toggle() } } label: {
                        Image(systemName: widgetsExpanded ? "chevron.down" : "chevron.up")
                    }.buttonStyle(.plain)
                }
                if widgetsExpanded {
                    TextField(t("Search widgets", "Buscar widgets"), text: $widgetQuery)
                        .textFieldStyle(.plain).padding(12)
                        .background(raised, in: Capsule())
                }
                ScrollView {
                    if widgetQuery.isEmpty || "BloomBox clock reloj notas notes foto gif media".localizedCaseInsensitiveContains(widgetQuery) {
                        Button { expandedWidgetProvider.toggle() } label: {
                            HStack {
                                Image(systemName: "square.grid.2x2.fill").font(.title2).frame(width: 42, height: 42)
                                VStack(alignment: .leading) {
                                    Text("BloomBox").font(.headline)
                                    Text(t("6 widgets", "6 widgets")).font(.caption).foregroundStyle(.gray)
                                }
                                Spacer()
                                Image(systemName: expandedWidgetProvider ? "chevron.up" : "chevron.down")
                            }.padding(12).background(raised, in: RoundedRectangle(cornerRadius: 16))
                        }.buttonStyle(.plain)
                        if expandedWidgetProvider && widgetsExpanded {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 8)], spacing: 16) {
                                widgetOption(t("Minimal clock", "Reloj minimalista"), kind: "clock", style: "minimal")
                                widgetOption(t("Flip clock", "Reloj flip"), kind: "clock", style: "flip")
                                widgetOption(t("Analog clock", "Reloj analógico"), kind: "clock", style: "analog")
                                widgetOption(t("Pixel clock", "Reloj pixel"), kind: "clock", style: "pixel")
                                widgetOption(t("Notes", "Notas"), kind: "notes")
                                widgetOption(t("Photo or GIF", "Foto o GIF"), kind: "media")
                            }.padding(.vertical, 8)
                        }
                    }
                }
            }
            .padding(16)
            .frame(height: widgetsExpanded ? max(180, height - 20) : collapsedWidgetPanelHeight(height))
            .background(panel, in: RoundedRectangle(cornerRadius: 24))
            .gesture(DragGesture(minimumDistance: 20).onEnded { value in
                if value.translation.height < -30 { animate { widgetsExpanded = true } }
                if value.translation.height > 30 { animate { widgetsExpanded = false } }
            })
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private var settingsView: some View {
        modal(t("Nova settings", "Ajustes de Nova"), close: { settings = false }) {
            Text(t("Home layout", "Diseño del inicio")).font(.headline).foregroundStyle(accent)
            actionRow(t("Columns", "Columnas") + ": \(workspace.columns)", "square.grid.3x3") {
                if workspace.widgets?.values.allSatisfy({ $0.isEmpty }) != false { workspace.columns = workspace.columns == 4 ? 5 : 4 }
            }
            actionRow(t("Icon labels", "Nombres de apps"), workspace.labels ? "checkmark.square" : "square") {
                workspace.labels.toggle()
            }
            actionRow(t("Icon shape", "Forma del icono") + ": " +
                      [t("Rounded", "Redondeado"), t("Circle", "Círculo"), t("Square", "Cuadrado")][workspace.iconShape], "app") {
                workspace.iconShape = (workspace.iconShape + 1) % 3
            }
            Text(t("Search bar", "Barra de búsqueda")).font(.headline).foregroundStyle(accent).padding(.top, 8)
            actionRow(t("Customize search bar", "Personalizar barra de búsqueda"), "magnifyingglass") {
                searchSettings = true
            }
            Text(t("App drawer", "Cajón de aplicaciones")).font(.headline).foregroundStyle(accent).padding(.top, 8)
            actionRow(t("Customize app drawer", "Personalizar cajón de aplicaciones"), "square.grid.3x3") {
                drawerSettings = true
            }
            Text(t("Wallpaper", "Fondo de pantalla")).font(.headline).foregroundStyle(accent).padding(.top, 8)
            actionRow(t("Solid color", "Color sólido"), "paintpalette") { workspace.wallpaper = (workspace.wallpaper + 1) % 3 }
            actionRow(t("Choose image", "Elegir imagen"), "photo") { importWallpaper = true }
            Text(t("BloomBox", "BloomBox")).font(.headline).foregroundStyle(accent).padding(.top, 8)
            actionRow(t("Install app", "Instalar app"), "plus") { settings = false; openInstall() }
            actionRow(t("Manage apps", "Administrar apps"), "square.grid.2x2") { settings = false; openManagement() }
            actionRow("GameBox", "gamecontroller") { settings = false; openGameBox() }
            actionRow(t("Change launcher", "Cambiar launcher"), "arrow.left.arrow.right") { settings = false; openInterface() }
            actionRow(t("BloomBox settings", "Ajustes de BloomBox"), "gearshape") { settings = false; openSettings() }
        }
    }
}
