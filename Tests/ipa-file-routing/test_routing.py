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
assert apk_type["UTTypeTagSpecification"]["public.mime-type"] == "application/vnd.android.package-archive"
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
# The SideStore button must launch the bundled signer directly with the local
# staged IPA. A ShareLink opens the system share sheet instead of installing.
assert 'Button {' in app_list and 'Label("Instalar con SideStore"' in app_list
assert 'link.scheme = "sidestore"' in app_list
assert 'link.host = "install"' in app_list
assert 'URLQueryItem(name: "url", value: sideStoreIPA.absoluteString)' in app_list
assert 'installWithSideStore(installURL)' in app_list
assert 'LCUtils.openSideStore(delegate: self, urlStr: installURL.absoluteString)' in app_list
assert "ShareLink(item:" not in app_list
assert "UIActivityViewController" not in app_list
assert "CoreTransferable" not in app_list
assert "NSFileCoordinator().coordinate(readingItemAt: original" in app_list
assert "guard size > 0" in app_list
assert "sideStoreHandoffError" in app_list
assert "ShareLink(item: fileURL)" not in app_list
assert "await installFromUrl(urlStr: preparedURL.absoluteString)" in app_list
# Files/open-in and the news button must install from a private staged copy.
assert 'let installInBloomBox: (URL) -> Void' in app_list
assert 'if let stagedIPA = sideStoreIPA { installInBloomBox(stagedIPA) }' in app_list
assert '.disabled(sideStoreIPA == nil)' in app_list
assert '["ipa", "tipa"].contains(original.pathExtension.lowercased())' in app_list
assert 'let stagedIPA = try await BloomBoxSideStoreHandoff.prepareFile(fileUrl)' in app_list
assert 'try await installIpaFile(stagedIPA)' in app_list
assert 'try FileManager.default.removeItem(at: fileUrl)' not in app_list
assert 'try? FileManager.default.removeItem(at: preparedURL)' in app_list
assert "LCUtils.openSideStore(delegate: self)" in app_list
assert '"Instalar dentro de BloomBox" = "Install in BloomBox";' in en
assert '"Instalar con SideStore" = "Install with SideStore";' in en
assert "espacios libres sin verificar" in app_list
print("PASS: Files IPA routing, direct SideStore IPA deep link without Share sheet, and English labels")
