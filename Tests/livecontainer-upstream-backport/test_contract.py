#!/usr/bin/env python3
"""Static guardrails for selectively backported LiveContainer 3.8.14 features."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def source(path):
    file = ROOT / path
    assert file.is_file(), f"Missing backport file: {path}"
    return file.read_text(encoding="utf-8")

def contains(path, *needles):
    text = source(path)
    for item in needles:
        assert item in text, f"Missing {item!r} from {path}"

contains("TweakLoader/BackgroundTasks.m", "BackgroundTasksGuestHooksInit", "fixBackgroundTaskIdentifiers", "hostTaskIdentifier")
contains("LiveContainer/Info.plist", "<key>BGTaskSchedulerPermittedIdentifiers</key>", "com.kdt.livecontainer.bgtask.*")
contains("LiveContainerSwiftUI/Models/LCAppInfo.h", "fixBackgroundTaskIdentifiers", "helperProcessesSupport")
contains("LiveContainerSwiftUI/Models/LCAppInfo.m", "patchGuestExtensions", "setHelperProcessesSupport", "setFixBackgroundTaskIdentifiers")
contains("LiveContainerSwiftUI/Models/LCAppModel.swift", "uiHelperProcessesSupport", "uiFixBackgroundTaskIdentifiers")
contains("LiveContainerSwiftUI/Views/AppList/AppSettings/LCAppSettingsView.swift", "$model.uiHelperProcessesSupport", "$model.uiFixBackgroundTaskIdentifiers")
contains("LiveContainerSwiftUI/Views/AppList/LCAppListView.swift", "finalNewApp.helperProcessesSupport", "finalNewApp.fixBackgroundTaskIdentifiers")
contains("LiveContainer/LCBootstrap.m", "LCRunGuestExtension", "NSExtensionGuestHooksInit", 'if ([guestAppInfo[@"helperProcessesSupport"] boolValue])')
contains("LiveContainer/LivePlugInSupport/LivePlugInServer.m", "LCLivePlugIn", "resolvePendingRequests")
contains("LiveContainer/LivePlugInSupport/NSExtension+GuestHooks.m", "NSExtensionGuestHooksInit", "GuestExtensionHooksInit")
contains("LiveProcess/LivePlugIn.m", "LivePlugInMain", "LCRunGuestExtension")
contains("LiveProcess/main.m", "bootstrap_look_up", "return LivePlugInMain(", "BloomBoxReportJIT")
contains("LiveContainer/Tweaks/NSFileManager+GuestHooks.m", "NSFMGuestExtensionHooksInit", "extensionParentContainerPath")
contains("LiveContainerSwiftUI/Views/LCAltStoreSourcesView.swift", "func loadSourcesIfNeeded()", "viewModel.loadSourcesIfNeeded()")
project = source("LiveContainer.xcodeproj/project.pbxproj")
assert "BackgroundTasks.m," in project
assert project.count("1768BBF030A9B61D0037D5C8 /* LivePlugInSupport */") == 3
# Keep host and widget synchronized across future releases; never hard-code an old version.
import plistlib
host = plistlib.loads((ROOT / "LiveContainer/Info.plist").read_bytes())
widget = plistlib.loads((ROOT / "ManzanaExpiryWidget/Info.plist").read_bytes())
assert host["CFBundleShortVersionString"] == widget["CFBundleShortVersionString"], "Host/widget marketing versions differ"
assert str(host["CFBundleVersion"]) == str(widget["CFBundleVersion"]), "Host/widget build numbers differ"
assert host["CFBundleShortVersionString"] and host["CFBundleVersion"], "Missing version metadata"
assert "helperProcessesSupport = YES" not in source("LiveContainerSwiftUI/Models/LCAppInfo.m"), "Helper processing must stay opt-in"
print("PASS: BloomBox upstream backport contracts, feature gates and synchronized version")
