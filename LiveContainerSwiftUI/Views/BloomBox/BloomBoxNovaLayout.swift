// SPDX-License-Identifier: AGPL-3.0-only
import Foundation

/// Nova-inspired BloomBox workspace data. It never moves, deletes or rewrites
/// a LiveContainer guest. Layout is separate from the existing iOS Home.
struct BloomBoxNovaLayout: Codable, Equatable {
    struct Folder: Codable, Equatable, Identifiable {
        var id: String
        var name: String
        var apps: [String]
    }

    static let builtIns = [
        "nova:install", "nova:gamebox", "nova:management",
        "nova:settings", "nova:interface"
    ]
    static let pageCapacity = 30
    static let dockCapacity = 5

    var initialized = false
    var pages: [[String]] = [[]]
    var dock: [String] = []
    var folders: [Folder] = []
    var hiddenFromHome: [String] = []
    var aliases: [String: String] = [:]
    var favorites: [String] = []
    var recents: [String] = []
    var columns = 4
    var iconScale = 1.0
    var showLabels = true
    var showClock = true
    var showSearch = true
    var useHomeWallpaper = true
    var useCustomWallpaper = false
    var roundIcons = false
    var drawerList = false
    var drawerSort = "alphabetical"
    var launchAnimation = "zoom"

    static func load(profile: String, from json: String) -> Self {
        guard let data = json.data(using: .utf8),
              let all = try? JSONDecoder().decode([String: Self].self, from: data)
        else { return Self() }
        return all[profile] ?? Self()
    }

    static func save(_ layout: Self, profile: String, into json: String) -> String {
        var all = (json.data(using: .utf8)
            .flatMap { try? JSONDecoder().decode([String: Self].self, from: $0) }) ?? [:]
        all[profile] = layout
        return (try? JSONEncoder().encode(all))
            .flatMap { String(data: $0, encoding: .utf8) } ?? json
    }

    var allPlaced: Set<String> {
        Set(dock + hiddenFromHome + folders.flatMap(\.apps) +
            pages.flatMap { $0.filter { !$0.hasPrefix("folder:") } })
    }

    mutating func reconcile(available: [String]) {
        var unique = Set<String>()
        let keys = available.filter { unique.insert($0).inserted }
        let valid = Set(keys)
        columns = min(max(columns, 4), 6)
        iconScale = min(max(iconScale, 0.75), 1.20)
        if !["zoom", "slide", "fade", "none"].contains(launchAnimation) { launchAnimation = "zoom" }
        if !["alphabetical", "recent"].contains(drawerSort) { drawerSort = "alphabetical" }
        if pages.isEmpty { pages = [[]] }
        var occupied = Set<String>()
        hiddenFromHome = hiddenFromHome.filter {
            valid.contains($0) && occupied.insert($0).inserted
        }
        dock = Array(dock.filter {
            valid.contains($0) && occupied.insert($0).inserted
        }.prefix(Self.dockCapacity))
        var folderIDs = Set<String>()
        folders = folders.filter {
            $0.id.hasPrefix("folder:") && folderIDs.insert($0.id).inserted
        }
        for index in folders.indices {
            folders[index].apps = folders[index].apps.filter {
                valid.contains($0) && occupied.insert($0).inserted
            }
        }
        folders.removeAll { $0.apps.isEmpty }
        let validFolders = Set(folders.map(\.id))
        var visibleFolderIDs = Set<String>()
        for index in pages.indices {
            pages[index] = Array(pages[index].filter { key in
                if key.hasPrefix("folder:") {
                    return validFolders.contains(key) && visibleFolderIDs.insert(key).inserted
                }
                return valid.contains(key) && occupied.insert(key).inserted
            }.prefix(Self.pageCapacity))
        }
        if !initialized {
            let initialDock = Array(keys.filter { !occupied.contains($0) }
                .prefix(Self.dockCapacity))
            dock += initialDock
            occupied.formUnion(initialDock)
            initialized = true
        }
        // Newly installed apps are available in the drawer and placed on Home.
        for key in keys where !occupied.contains(key) {
            appendToPage(key, page: max(0, pages.count - 1))
            occupied.insert(key)
        }
        for folder in folders where !visibleFolderIDs.contains(folder.id) {
            appendToPage(folder.id, page: 0)
        }
        aliases = aliases.filter { valid.contains($0.key) }
        favorites = favorites.filter { valid.contains($0) }
        recents = Array(recents.filter { valid.contains($0) }.prefix(16))
    }

    mutating func appendToPage(_ key: String, page: Int) {
        var destination = max(0, page)
        while pages.count <= destination { pages.append([]) }
        while pages[destination].count >= Self.pageCapacity {
            destination += 1
            if pages.count <= destination { pages.append([]) }
        }
        pages[destination].append(key)
    }

    mutating func removePlacement(_ key: String) {
        for i in pages.indices { pages[i].removeAll { $0 == key } }
        dock.removeAll { $0 == key }
        hiddenFromHome.removeAll { $0 == key }
        for i in folders.indices { folders[i].apps.removeAll { $0 == key } }
    }

    mutating func moveToPage(_ key: String, page: Int, before target: String? = nil) {
        let isFolder = key.hasPrefix("folder:")
        guard !isFolder || folders.contains(where: { $0.id == key }) else { return }
        removePlacement(key)
        let destination = min(max(page, 0), max(pages.count, 1))
        while pages.count <= destination { pages.append([]) }
        if let target, let position = pages[destination].firstIndex(of: target),
           pages[destination].count < Self.pageCapacity {
            pages[destination].insert(key, at: position)
        } else {
            appendToPage(key, page: destination)
        }
    }

    @discardableResult
    mutating func moveToDock(_ key: String) -> Bool {
        guard !key.hasPrefix("folder:"), !dock.contains(key),
              dock.count < Self.dockCapacity else { return false }
        removePlacement(key)
        dock.append(key)
        return true
    }

    mutating func removeFromDock(_ key: String) {
        guard dock.contains(key) else { return }
        moveToPage(key, page: 0)
    }

    mutating func removeFromHome(_ key: String) {
        guard !key.hasPrefix("folder:") else { return }
        removePlacement(key)
        hiddenFromHome.append(key)
    }

    mutating func addToHome(_ key: String, page: Int = 0) {
        moveToPage(key, page: page)
    }

    @discardableResult
    mutating func createFolder(with first: String, and second: String) -> String? {
        guard first != second, !first.hasPrefix("folder:"),
              !second.hasPrefix("folder:") else { return nil }
        let page = pages.firstIndex(where: { $0.contains(second) }) ?? 0
        removePlacement(first)
        removePlacement(second)
        let id = "folder:" + UUID().uuidString
        folders.append(Folder(id: id, name: "Folder", apps: [second, first]))
        appendToPage(id, page: page)
        return id
    }

    mutating func move(_ key: String, into folderID: String) {
        guard !key.hasPrefix("folder:"), let index = folders.firstIndex(where: { $0.id == folderID }),
              !folders[index].apps.contains(key) else { return }
        removePlacement(key)
        folders[index].apps.append(key)
    }

    mutating func remove(_ key: String, from folderID: String) {
        guard let index = folders.firstIndex(where: { $0.id == folderID }),
              folders[index].apps.contains(key) else { return }
        folders[index].apps.removeAll { $0 == key }
        appendToPage(key, page: 0)
        if folders[index].apps.isEmpty { dissolve(folderID) }
    }

    mutating func dissolve(_ folderID: String) {
        guard let index = folders.firstIndex(where: { $0.id == folderID }) else { return }
        let contents = folders.remove(at: index).apps
        for i in pages.indices { pages[i].removeAll { $0 == folderID } }
        for key in contents { appendToPage(key, page: 0) }
    }

    mutating func recordLaunch(_ key: String) {
        recents.removeAll { $0 == key }
        recents.insert(key, at: 0)
        recents = Array(recents.prefix(16))
    }

    mutating func toggleFavorite(_ key: String) {
        if favorites.contains(key) { favorites.removeAll { $0 == key } }
        else { favorites.append(key) }
    }
}
