#!/usr/bin/env python3
"""Guard the primary BloomBox UX for user-defined MediaBloom labels."""
from pathlib import Path
root = Path("LiveContainerSwiftUI/Views")
picker = (root / "AppList/AppSettings/LCAppSettingsView.swift").read_text()
home = (root / "BloomBox/BloomBoxHomeScreen.swift").read_text()
menu = (root / "BloomBox/BloomBoxHomeContextMenu.swift").read_text()
store = (root / "BloomBox/BloomBoxMediaTags.swift").read_text()

assert 'BloomBoxMediaLabelPicker(bundleID: model.bundleIdentifier, isShared: model.uiIsShared)' in picker
assert 'BloomBoxMediaTagStore.key(for: bundleID)' in picker
assert 'BloomBoxL10n.isEnglish ? "Labels" : "Etiquetas"' in picker
assert 'model.uiIsShared' in picker
assert 'let mediaTag: BloomBoxMediaTag' in menu
assert 'let setMediaTag: (BloomBoxMediaTag) -> Void' in menu
assert 'actions.setMediaTag(tag)' in menu
assert 'BloomBoxMediaTagStore.set(tag, for: app.bundleIdentifier' in home
assert 'BloomBoxMediaTagStore.selection(' in home
for raw in ['"music"', '"video"', '"none"', '"auto"', 'BloomBoxMediaTagV1.']:
    assert raw in store, raw
assert 'LCUtils.appGroupUserDefault' in home
# Settings should not migrate storage as a side-effect of choosing a tag.
assert 'moveToAppGroup()' not in picker.split('private struct BloomBoxMediaLabelPicker:', 1)[-1]
print("PASS: BloomBox tags exposed in app settings and home menu; shared store only")
