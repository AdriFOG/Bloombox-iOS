import Foundation

let defaults = UserDefaults(suiteName: "com.bloombox.audio-mix-contract-tests")!
let bundle = "Com.Husk.App"
let key = BloomBoxAudioMixStore.key(for: bundle)
defer { defaults.removeObject(forKey: key) }

assert(key == "BloomBoxAudioMixEnabledV1.com.husk.app")
assert(!BloomBoxAudioMixStore.isEnabled(for: bundle, defaults: defaults))
BloomBoxAudioMixStore.setEnabled(true, for: bundle, defaults: defaults)
assert(defaults.bool(forKey: key))
assert(BloomBoxAudioMixStore.isEnabled(for: "com.husk.app", defaults: defaults))
BloomBoxAudioMixStore.setEnabled(false, for: bundle, defaults: defaults)
assert(defaults.object(forKey: key) == nil)
assert(!BloomBoxAudioMixStore.isEnabled(for: bundle, defaults: defaults))
BloomBoxAudioMixStore.setEnabled(true, for: " ", defaults: defaults)
assert(defaults.object(forKey: BloomBoxAudioMixStore.key(for: " ")) == nil)
print("PASS: default disabled, per-guest opt-in, stable shared key and reset")
