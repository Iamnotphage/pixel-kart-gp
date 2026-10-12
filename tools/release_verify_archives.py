#!/usr/bin/env python3
"""Check actual target executable headers rather than only archive names."""
from pathlib import Path
import plistlib
import struct
import zipfile

with zipfile.ZipFile("dist/PixelKartGP-Windows-x86_64.zip") as z:
    data = z.read("PixelKartGP.exe")
    assert data[:2] == b"MZ", "Windows binary lacks DOS header"
    pe = struct.unpack_from("<I", data, 0x3C)[0]
    assert data[pe:pe+4] == b"PE\0\0", "Windows binary lacks PE header"
    assert struct.unpack_from("<H", data, pe + 4)[0] == 0x8664, "Expected Windows AMD64"
with zipfile.ZipFile("dist/PixelKartGP-macOS-universal.zip") as z:
    plists = [n for n in z.namelist() if n.endswith(".app/Contents/Info.plist")]
    assert len(plists) == 1, "Expected exactly one app bundle"
    info = plistlib.loads(z.read(plists[0]))
    assert info["CFBundleIdentifier"] == "game.pixelkart.gp", "Unexpected bundle identifier"
    executable = plists[0].removesuffix("Info.plist") + "MacOS/" + info["CFBundleExecutable"]
    data = z.read(executable)
    assert data[:4] == b"\xca\xfe\xba\xbe", "Expected universal Mach-O header"
    count = struct.unpack_from(">I", data, 4)[0]
    cpus = {struct.unpack_from(">I", data, 8 + n * 20)[0] for n in range(count)}
    assert {0x01000007, 0x0100000C}.issubset(cpus), "Expected Intel x86_64 and Apple Silicon arm64"
    assert (z.getinfo(executable).external_attr >> 16) & 0o111, "macOS executable permissions missing"
    assert any("_CodeSignature/CodeResources" in n for n in z.namelist()), "Ad-hoc signature resources missing"
print("Archive checks passed: Windows AMD64 and executable, signed universal macOS bundle.")
