import Foundation

struct NovaLayoutTests {
    static func main() {
        let apps = (1...14).map { "guest:\($0)" } + BloomBoxNovaLayout.builtIns
        var first = BloomBoxNovaLayout()
        first.reconcile(available: apps)
        assert(first.initialized)
        assert(first.dock.count == BloomBoxNovaLayout.dockCapacity)
        assert(first.pages.flatMap { $0 }.count == apps.count - first.dock.count)

        let firstApp = "guest:1"
        let secondApp = "guest:2"
        let thirdApp = "guest:3"
        first.moveToPage(firstApp, page: 1)
        assert(first.pages[1].contains(firstApp))
        assert(!first.dock.contains(firstApp))
        assert(first.moveToDock(firstApp))
        assert(first.dock.contains(firstApp))
        first.removeFromDock(firstApp)
        assert(first.pages.flatMap { $0 }.contains(firstApp))

        let folderID = first.createFolder(with: firstApp, and: secondApp)
        assert(folderID != nil)
        assert(first.folders.count == 1)
        assert(first.folders[0].apps == [secondApp, firstApp])
        first.move(thirdApp, into: folderID!)
        assert(first.folders[0].apps.contains(thirdApp))
        first.remove(thirdApp, from: folderID!)
        assert(first.pages.flatMap { $0 }.contains(thirdApp))
        first.folders[0].name = "My games"

        first.toggleFavorite(firstApp)
        first.recordLaunch(firstApp)
        first.aliases[firstApp] = "Custom"
        first.columns = 6
        first.iconScale = 1.15
        let saved = BloomBoxNovaLayout.save(first, profile: "primary", into: "{}")
        let restored = BloomBoxNovaLayout.load(profile: "primary", from: saved)
        assert(restored == first)
        assert(BloomBoxNovaLayout.load(profile: "guest", from: saved) == BloomBoxNovaLayout())

        var second = BloomBoxNovaLayout()
        second.reconcile(available: apps)
        let both = BloomBoxNovaLayout.save(second, profile: "guest", into: saved)
        assert(BloomBoxNovaLayout.load(profile: "primary", from: both) == first)
        assert(BloomBoxNovaLayout.load(profile: "guest", from: both) == second)

        // Removal of an app never erases the remaining workspace or a profile.
        first.reconcile(available: apps.filter { $0 != thirdApp })
        assert(!first.allPlaced.contains(thirdApp))
        assert(first.aliases[firstApp] == "Custom")
        assert(first.folders.first?.name == "My games")
        first.removeFromHome(secondApp)
        assert(first.hiddenFromHome.contains(secondApp))
        first.addToHome(secondApp)
        assert(!first.hiddenFromHome.contains(secondApp))
        first.reconcile(available: apps)
        assert(first.allPlaced.contains(thirdApp))
        print("Nova layout profile isolation, folder, dock, drawer and reconciliation tests passed")
    }
}

NovaLayoutTests.main()
