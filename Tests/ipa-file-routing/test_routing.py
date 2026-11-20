#!/usr/bin/env python3
"""Regression guard for the iOS Files -> BloomBox IPA destination chooser."""
from pathlib import Path
import plistlib

ROOT = Path(__file__).resolve().parents[2]
plist = plistlib.loads((ROOT / "LiveContainer/Info.plist").read_bytes())
document_types = plist["CFBundleDocumentTypes"]
registered = {uti for item in document_types for uti in item.get("LSItemContentTypes", [])}
assert "com.bloombox.ipa-archive" in registered
assert "com.bloombox.tipa-archive" in registered
by_id = {uti["UTTypeIdentifier"]: uti for uti in plist["UTImportedTypeDeclarations"]}
for name, ext in (("com.bloombox.ipa-archive", "ipa"), ("com.bloombox.tipa-archive", "tipa")):
    assert ext in by_id[name]["UTTypeTagSpecification"]["public.filename-extension"]

tab = (ROOT / "LiveContainerSwiftUI/Views/LCTabView.swift").read_text()
app_list = (ROOT / "LiveContainerSwiftUI/Views/AppList/LCAppListView.swift").read_text()
en = (ROOT / "Resources/en.lproj/Localizable.strings").read_text()
assert "if url.isFileURL" in tab and "sharedModel.deepLink = url" in tab
assert '["ipa", "tipa"].contains(url.pathExtension.lowercased())' in app_list
assert "receivedIPA = BloomBoxReceivedIPA(url: url)" in app_list
assert "BloomBoxIPAOpenSheet(" in app_list
assert "isPreparingSideStoreIPA" in app_list
assert "sourceURL.startAccessingSecurityScopedResource()" in app_list
assert "fm.copyItem(at: sourceURL, to: destination)" in app_list
assert "LCUtils.openSideStore(delegate: self, urlStr: handoffURL.absoluteString)" in app_list
assert "ShareLink(item: fileURL)" not in app_list
assert "await installFromUrl(urlStr: request.url.absoluteString)" in app_list
assert "LCUtils.openSideStore(delegate: self)" in app_list
assert '"Instalar dentro de BloomBox" = "Install in BloomBox";' in en
assert '"Instalar con SideStore" = "Install with SideStore";' in en
assert "espacios libres sin verificar" in app_list
print("PASS: Files IPA routing, direct SideStore handoff, honest limits, and English labels")
