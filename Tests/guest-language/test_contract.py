#!/usr/bin/env python3
"""Regression contract: selecting a guest language must remain independent from BloomBox and JIT."""
from pathlib import Path

root = Path(__file__).resolve().parents[2]
ui = (root / "LiveContainerSwiftUI/Views/AppList/AppSettings/LCAppSettingsView.swift").read_text()
model = (root / "LiveContainerSwiftUI/Models/LCAppModel.swift").read_text()
catalog = (root / "LiveContainerSwiftUI/Models/BloomBoxGuestLanguageCatalog.swift").read_text()
bootstrap = (root / "LiveContainer/LCBootstrap.m").read_text()
hook = (root / "LiveContainer/Tweaks/NSUserDefaults.m").read_text()
assert "BloomBoxGuestLanguageCatalog.detect(" in model
assert "appInfo.selectedLanguage = uiSelectedLanguage" in model
assert "LCSelectedLanguage" in (root / "LiveContainerSwiftUI/Models/LCAppInfo.m").read_text()
assert "manualLanguages" in ui and "Elegir manualmente" in ui
assert "games using their own translation system may ignore it" in ui
assert "LCSelectedLanguage" in hook
assert 'forKey:@"AppleLanguages"' in hook
assert "requestedLanguages" in hook and "if (languageCache)" in hook
assert "CFBridgingRetain" in hook
assert bootstrap.count("NUDGuestHooksInit();") >= 2  # normal + LiveProcess bootstrap
assert "static let manualChoices" in catalog
assert "CFBundleLocalizations" in catalog
assert ".isSymbolicLinkKey" in catalog
assert "BloomBoxGuestLanguageCatalog.preferredLanguages" not in ui  # presentation never mutates global system locale
print("PASS: per-app language preference, normal/JIT hook, manual fallback and bundled detection")
