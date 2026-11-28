#!/usr/bin/env python3
"""Guard author-attribution for marked original BloomBox contributions."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
COVERED = (
    "Scripts/generate-bloombox-icon.swift",
    "LiveContainerSwiftUI/Views/BloomBox/BloomBoxReservedSection.swift",
    "LiveContainerSwiftUI/Views/BloomBox/BloomBoxLauncherPreferences.swift",
)
TERMS = (ROOT / "LICENSE-ADDITIONAL-TERMS.md").read_text(encoding="utf-8")
NOTICE = (ROOT / "NOTICE.md").read_text(encoding="utf-8")
README = (ROOT / "README.md").read_text(encoding="utf-8")
THIRD = (ROOT / "THIRD_PARTY_NOTICES.md").read_text(encoding="utf-8")
AGPL = (ROOT / "LICENSE").read_text(encoding="utf-8")
ATTRIBUTION = "Original BloomBox contributions (c) 2026 adri23rep-stack"

assert "GNU AFFERO GENERAL PUBLIC LICENSE" in AGPL
assert "7. Additional Terms." in AGPL
assert "AGPL-3.0-only" in TERMS and "section 7(b)" in TERMS
assert ATTRIBUTION in TERMS and ATTRIBUTION in NOTICE
assert "https://github.com/adri23rep-stack/BloomBox" in NOTICE
assert "original copyrightable material" in TERMS
assert "No new license or condition is asserted over third-party material" in TERMS
for key in ("LiveContainer", "SideStore", "StikJIT", "Husk"):
    assert key in THIRD, "Original upstream license notice missing: " + key
assert "LICENSE-ADDITIONAL-TERMS.md" in README and "LICENSE-ADDITIONAL-TERMS.md" in THIRD
for path in COVERED:
    content = (ROOT / path).read_text(encoding="utf-8")
    assert content.startswith("// SPDX-License-Identifier: AGPL-3.0-only\n"), path
    assert "Copyright (c) 2026 adri23rep-stack" in content, path
    assert "LICENSE-ADDITIONAL-TERMS.md" in content, path
    assert "`" + path + "`" in TERMS, path
print("PASS: AGPL intact, required author credit scoped, upstream licenses preserved.")

# The in-app credits must retain the original-work notice and major upstream references.
credits = (ROOT / "LiveContainerSwiftUI/Views/BloomBox/BloomBoxCredits.swift").read_text(encoding="utf-8")
settings = (ROOT / "LiveContainerSwiftUI/Views/Settings/LCSettingsView.swift").read_text(encoding="utf-8")
assert "BloomBoxCreditsView()" in settings and "bloombox.settings.credits" in settings
assert ATTRIBUTION in credits and "https://github.com/adri23rep-stack/BloomBox" in credits
for name in ("LiveContainer", "SideStore", "StikJIT", "Husk", "Strata", "GetMoreRam", "StosSign", "SideSign", "MeloNX", "Nintendo Switch-ish", "OpenPortsGames", "siboot", "SideInstaller", "Open Minis", "LocalDevVPN"):
    assert name in credits, name
assert "THIRD_PARTY_NOTICES.md" in credits and "LICENSE-ADDITIONAL-TERMS.md" in credits
assert "Créditos" in credits and "Credits" in credits
print("PASS: in-app bilingual credits and upstream attribution.")
