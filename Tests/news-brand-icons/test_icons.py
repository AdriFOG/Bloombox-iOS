#!/usr/bin/env python3
"""Prevent blank Google Play / App Store icons in BloomBox News builds."""
import base64
from pathlib import Path
import re
import struct

ROOT = Path(__file__).resolve().parents[2]
source = (ROOT / "LiveContainerSwiftUI/Views/BloomBox/BloomBoxNewsBrandIcons.swift").read_text()
news = (ROOT / "LiveContainerSwiftUI/Views/BloomBox/BloomBoxNewsPage.swift").read_text()

for name in ("googlePlay", "appleAppStore"):
    match = re.search(r"private static let " + name + r'Base64 = """\n(.*?)\n\s*"""',
                      source, flags=re.S)
    assert match, f"Missing self-contained {name} image"
    raw = base64.b64decode("".join(match.group(1).split()), validate=True)
    assert raw.startswith(b"\x89PNG\r\n\x1a\n"), f"Invalid PNG: {name}"
    width, height = struct.unpack(">II", raw[16:24])
    assert min(width, height) >= 64, f"Low resolution image: {name}"
    assert len(raw) > 1000, f"Empty/truncated image: {name}"
    assert f"BloomBoxNewsBrandIcons.{name}" in news, f"Icon not wired: {name}"

assert 'Image("BloomBoxGooglePlayMark")' not in news
assert 'Image("BloomBoxAppleAppStoreMark")' not in news
assert 'LiveContainerHomeAdapter.builtInSignerIcon(dark: false)' in news, "Keep embedded SideStore artwork"
print("PASS: both store logos decode as local PNGs; SideStore keeps its installed icon")
