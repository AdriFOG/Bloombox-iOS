import Foundation

// The new BloomBox layout engine must handle older serialized layouts.
var model = BloomBoxHomeLayout()
model.initialized = true
model.pages = [
    ["A", "A", "Missing"] + Array(repeating: nil, count: 21),
    ["B"] + Array(repeating: nil, count: 23)
]
model.dock = ["A", "A", "manzana:sidestore"]
model.folders = [
    .init(id: "folder:test", name: "Tools", apps: ["B", "B", "C"])
]
model.reconcile(["A", "B", "C", "manzana:sidestore"], favorites: [])
assert(model.dock == ["A", "manzana:sidestore"])
assert(model.folders.first?.apps == ["B", "C"])
assert(model.pages.flatMap { $0.compactMap { $0 } }.contains("folder:test"))
assert(!model.pages.flatMap { $0.compactMap { $0 } }.contains("Missing"))
assert(model.encoded.contains("\"initialized\":true"))
assert(BloomBoxHomeLayout.decode(model.encoded) == model)

// A new folder should replace the app in the original cell, not jump to page 1.
var positions = BloomBoxHomeLayout()
positions.initialized = true
positions.pages = [
    ["A"] + Array(repeating: nil, count: 23),
    ["B", "C"] + Array(repeating: nil, count: 22)
]
positions.createFolder(name: "Work", app: "B")
let folder = positions.folders[0].id
assert(positions.pages[1][0] == folder)
assert(!positions.pages.flatMap { $0.compactMap { $0 } }.contains("B"))
positions.dissolveFolder(folder)
assert(positions.pages[1][0] == "B")
assert(positions.folders.isEmpty)

// A corrupt or future-incompatible layout must fall back safely.
assert(BloomBoxHomeLayout.decode("not JSON").pages.count == 1)
assert(BloomBoxHomeLayout.decode("").dock.isEmpty)
print("BloomBox native Home layout: migration, de-duplication, folder position and recovery passed.")

// The built-in BloomBox shortcuts may be removed from Home and brought back
// from the App Library without losing their stable identity or being reinserted.
let optionalShortcuts = [
    "manzana:sidestore", "manzana:install", "manzana:tweakstore",
    "manzana:appstore", "manzana:portstore", "manzana:modules",
    "manzana:themes"
]
var optionalLayout = BloomBoxHomeLayout()
optionalLayout.reconcile(optionalShortcuts + ["Guest"], favorites: [])
for key in optionalShortcuts { optionalLayout.hide(key) }
optionalLayout.reconcile(optionalShortcuts + ["Guest"], favorites: [])
assert(Set(optionalLayout.hidden) == Set(optionalShortcuts), "All built-in icons can stay hidden")
let savedOptionalLayout = BloomBoxHomeLayout.decode(optionalLayout.encoded)
assert(Set(savedOptionalLayout.hidden) == Set(optionalShortcuts),
       "Built-in icon removal must survive restart")
assert(!savedOptionalLayout.pages.flatMap { $0 }.contains("manzana:sidestore"),
       "Hidden SideStore must not be re-added automatically")
optionalLayout.place("manzana:sidestore", on: 0)
optionalLayout.reconcile(optionalShortcuts + ["Guest"], favorites: [])
assert(!optionalLayout.hidden.contains("manzana:sidestore") &&
       optionalLayout.pages[0].contains("manzana:sidestore"),
       "Hidden SideStore can be restored from App Library")
print("Optional BloomBox built-in shortcuts: removal, persistence and restore passed.")
