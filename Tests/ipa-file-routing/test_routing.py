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
assert "com.android.package-archive" in registered
by_id = {uti["UTTypeIdentifier"]: uti for uti in plist["UTImportedTypeDeclarations"]}
for name, ext in (("com.bloombox.ipa-archive", "ipa"), ("com.bloombox.tipa-archive", "tipa"), ("com.android.package-archive", "apk")):
    assert ext in by_id[name]["UTTypeTagSpecification"]["public.filename-extension"]

# .apk must behave like IPA/TIPA as a document/data file. public.archive is
# Apple's own archive UTI and can misclassify Android APKs in Files/Quick Look.
apk_type = by_id["com.android.package-archive"]
assert "public.data" in apk_type["UTTypeConformsTo"]
assert "public.content" in apk_type["UTTypeConformsTo"]
assert "public.archive" not in apk_type["UTTypeConformsTo"]
assert apk_type["UTTypeTagSpecification"]["public.mime-type"] == ["application/vnd.android.package-archive"]
apk_handlers = [item for item in document_types
                if "com.android.package-archive" in item.get("LSItemContentTypes", [])]
assert len(apk_handlers) == 1
assert apk_handlers[0]["LSHandlerRank"] == "Owner"
assert apk_handlers[0]["CFBundleTypeRole"] == "Viewer"
# Routing starts with Files' document handoff. iOS's user-selected
# "Always Open With" default can still override the app's handler ranking.

tab = (ROOT / "LiveContainerSwiftUI/Views/LCTabView.swift").read_text()
app_list = (ROOT / "LiveContainerSwiftUI/Views/AppList/LCAppListView.swift").read_text()
en = (ROOT / "Resources/en.lproj/Localizable.strings").read_text()
assert "if url.isFileURL" in tab and "sharedModel.deepLink = url" in tab
assert '["ipa", "tipa", "apk"].contains(url.pathExtension.lowercased())' in app_list
assert "receivedIPA = BloomBoxReceivedIPA(url: url)" in app_list
assert "await importAPK(request.url, host: husk)" in app_list
assert "BloomBoxIPAOpenSheet(" in app_list
assert "ShareLink(item: fileURL)" in app_list
assert "await installFromUrl(urlStr: request.url.absoluteString)" in app_list
assert "LCUtils.openSideStore(delegate: self)" in app_list
assert '"Instalar dentro de BloomBox" = "Install in BloomBox";' in en
assert '"Instalar con SideStore" = "Install with SideStore";' in en
assert "espacios libres sin verificar" in app_list
print("PASS: Files IPA routing, destination sheet, honest SideStore limits, and English labels")
