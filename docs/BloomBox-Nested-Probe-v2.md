# Nested BloomBox probe 02
Device-only diagnostic, not a full nested container or release. The first
probe entered the second LiveContainerMain then crashed while looking up the
App Group. This build routes the marked guest before the normal initializer.
It loads the compiled SwiftUI diagnostic from the guest bundle, rejects a
nonstandard guest home, and stores a counter and boot phases in
Library/BloomBoxDevProbeV2. It does not start the normal launcher, signing,
account code or JIT. Import as a new private guest, with a fresh default
container and no additional tweaks. Open, increment the counter, close and
reopen, then copy the boot log. If it fails, share the host exception.
No changes to main or to the installed host are required to attempt the
probe. Do not merge this branch. Successful launch is not proof of full
nested container support.
