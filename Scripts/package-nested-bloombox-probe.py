"""Package the freshly compiled diagnostic as a separate unsigned guest."""
import copy
import plistlib
import shutil
import sys
from zipfile import ZipFile

SOURCE = sys.argv[1]
TARGET = "BloomBox-Dev-Nested-Probe-v2.ipa"
ROOT = "Payload/LiveContainer.app/"
NEW = "Payload/BloomBoxDev.app/"
with ZipFile(SOURCE) as src:
    assert src.testzip() is None
    info = plistlib.loads(src.read(ROOT + "Info.plist"))
    assert info["CFBundleExecutable"] == "LiveContainer"
    info.update(
        CFBundleExecutable="BloomBoxDev",
        CFBundleIdentifier="com.bloombox.dev.nestedprobe.v2",
        CFBundleDisplayName="BloomBox Dev Probe 02",
        CFBundleName="BloomBox Dev Probe 02",
        BloomBoxNestedProbeMode=2,
    )
    info["CFBundleURLTypes"] = [{"CFBundleURLName": "com.bloombox.dev.nestedprobe.v2",
                                 "CFBundleURLSchemes": ["bloomboxdevprobe2"]}]
    for key in ("ALTAppGroups", "INIntentsSupported", "BGTaskSchedulerPermittedIdentifiers"):
        info.pop(key, None)
    with ZipFile(TARGET, "w") as dst:
        for entry in src.infolist():
            if not entry.filename.startswith(ROOT):
                continue
            rel = entry.filename[len(ROOT):]
            if rel.startswith(("PlugIns/", "_CodeSignature/", "Frameworks/SideStoreApp.framework/")) or rel == "embedded.mobileprovision":
                continue
            if rel.endswith("/InfoPlist.strings") and rel.count("/") == 1:
                continue
            renamed = "BloomBoxDev" if rel == "LiveContainer" else rel
            out = copy.copy(entry)
            out.filename = NEW + renamed
            out.orig_filename = out.filename
            if rel == "Info.plist":
                dst.writestr(out, plistlib.dumps(info))
            else:
                with src.open(entry) as i, dst.open(out, "w") as o:
                    shutil.copyfileobj(i, o, 1024 * 1024)
with ZipFile(TARGET) as dst:
    assert dst.testzip() is None
    assert len(dst.namelist()) == len(set(dst.namelist()))
    names = set(dst.namelist())
    assert NEW + "BloomBoxDev" in names
    assert NEW + "LiveContainer" not in names
    assert not any(n.startswith(NEW + "PlugIns/") for n in names)
    shared = NEW + "Frameworks/LiveContainerShared.framework/LiveContainerShared"
    ui = NEW + "Frameworks/LiveContainerSwiftUI.framework/LiveContainerSwiftUI"
    assert b"BloomBoxNestedProbeMode" in dst.read(shared), "Fresh bootstrap is missing"
    assert b"BloomBoxNestedProbeUIV2" in dst.read(ui), "Fresh SwiftUI entry is missing"
    result = plistlib.loads(dst.read(NEW + "Info.plist"))
    assert result["BloomBoxNestedProbeMode"] == 2
    assert result["CFBundleIdentifier"] == "com.bloombox.dev.nestedprobe.v2"
    assert result["CFBundleExecutable"] == "BloomBoxDev"
    print("PASS: fresh isolated bootstrap and SwiftUI entry; no extensions")
