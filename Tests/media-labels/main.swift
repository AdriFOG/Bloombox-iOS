import Foundation

let defaults = UserDefaults(suiteName: "com.bloombox.media-tags-contract")!
let input = "Com.Example.Music-App"
let key = BloomBoxMediaTagStore.key(for: input)
defer { defaults.removeObject(forKey: key) }

assert(key == "BloomBoxMediaTagV1.com.example.music-app")
assert(BloomBoxMediaTagStore.selection(for: input, defaults: defaults) == .automatic)

BloomBoxMediaTagStore.set(.music, for: input, defaults: defaults)
assert(defaults.string(forKey: key) == "music")
assert(BloomBoxMediaTagStore.selection(for: input, defaults: defaults) == .music)

BloomBoxMediaTagStore.set(.video, for: input, defaults: defaults)
assert(defaults.string(forKey: key) == "video")

BloomBoxMediaTagStore.set(.excluded, for: input, defaults: defaults)
assert(defaults.string(forKey: key) == "none")

BloomBoxMediaTagStore.set(.automatic, for: input, defaults: defaults)
assert(defaults.object(forKey: key) == nil)

defaults.set("unrecognized", forKey: key)
assert(BloomBoxMediaTagStore.selection(for: input, defaults: defaults) == .automatic)
print("PASS BloomBox media labels: stable keys, case folding, override and reset")
