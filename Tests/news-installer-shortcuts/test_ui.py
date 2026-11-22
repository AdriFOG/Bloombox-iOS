#!/usr/bin/env python3
"""Guard the new News installer tip and removable built-in shortcuts."""
from pathlib import Path
root = Path(__file__).resolve().parents[2] / "LiveContainerSwiftUI/Views/BloomBox"
news = (root / "BloomBoxNewsPage.swift").read_text()
home = (root / "BloomBoxHomeScreen.swift").read_text()
layout = (root / "BloomBoxHomeLayout.swift").read_text()
profiles = (root / "BloomBoxProfileVisuals.swift").read_text()
assert 'BloomBoxNewsInstallerUsedV1' in news
assert '¡Instala apps aquí!' in news and 'Install apps here!' in news
assert 'bloombox.news.install' in news
assert 'hasUsedNewsInstaller = true' in news and 'openInstall()' in news
assert 'openInstall: openInstall' in home
assert 'layout.hide(key)' in home and 'guard key != Self.sideStoreKey' not in home
assert 'placementMenu(key)' in home
assert 'Self.pinnedKeys' not in layout
assert 'Color.black.opacity(0.38)' in profiles and '.liveBoardGlass(radius: 26)' not in profiles
print("PASS: installer shortcut with bilingual first-use tip and removable built-in apps")
