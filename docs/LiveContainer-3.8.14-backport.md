# LiveContainer 3.8.14 — selective backport into BloomBox 3.0

**Experimental branch:** `feature/livecontainer-3-8-14-selective-backport-20261120`  
**Baseline:** BloomBox v3.0.0, main at `84798c8b359d2ba203a455724cc0c4fb09462853`  
**Upstream version checked:** `LiveContainer/LiveContainer@b7cfda60c39933a94d616f2a358ac2e48fd4e5cd` (2026-11-15)

## Changes adapted line by line

- [Background task identifiers — `53e83476`](https://github.com/LiveContainer/LiveContainer/commit/53e83476f858): vendor `TweakLoader/BackgroundTasks.m`, declare the allowed task family, add per-guest saved option and preserve it on app replacement. **Opt-in; iOS 26+ only.**
- [Helper process options — `64d75c2d`](https://github.com/LiveContainer/LiveContainer/commit/64d75c2d2e88): guest-extension executable patcher, per-app persisted toggle, SwiftUI settings and replacement preservation. **Opt-in; disabled by default.**
- [Helper process XPC support — `7076b961`](https://github.com/LiveContainer/LiveContainer/commit/7076b961df49): original `LivePlugInSupport` sources, guest extension bootstrap and routing through LiveProcess. Added code without replacing BloomBox-specific JIT and launch patches.
- [Lazy source loading — `b7cfda60`](https://github.com/LiveContainer/LiveContainer/commit/b7cfda60c39933a94d616f2a358ac2e48fd4e5cd): only load sources when that tab is opened.
- Same upstream commit: enable the Music Haptics info flag on LiveContainer and LiveProcess.
- Fix the upstream `lcSharedDefaults` initialization test as part of `7076b961`.

## Deliberately untouched

No replacement of BloomBox's Home, GameBox, JIT controls, settings, installation routing, RAM+, licensing or brand. Do not import upstream package identifiers or its version number. SideStore remains SHA-256 pinned. No new release is published automatically.

## Validation checklist before considering a merge

1. GitHub Actions PR build must pass the native Swift and Objective-C compilation, IPA packaging, RAM+/JIT checks and tests.
2. Install the branch IPA over a backed-up test installation; confirm normal launch, profiles and both Home and GameBox.
3. Check SideStore refresh, installation of IPA/TIPA from Files, remote stores, RAM+ validation and JIT on a physical device.
4. On a test guest with an `.appex`, enable **Helper Process Support**, reinstall/repatch/sign the guest if needed, and verify behavior on iOS 27. Disable again if unstable.
5. On an eligible test guest on iOS 26+, enable **Fix Background Processing Tasks** and verify background scheduling and cancellation; no benefit is promised for every guest.
6. Confirm existing app data, containers and app replacement settings survive an update.
7. Keep the original source attribution, license terms and upstream file history.

**Important:** a successful CI archive verifies the build, not end-to-end helper-process behavior. Real device testing is still required before merging into main.
