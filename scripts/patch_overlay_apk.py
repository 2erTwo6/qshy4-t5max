#!/usr/bin/env python3
"""Patch a MiuiFrameworkResOverlay.apk copy from version 3 to version 4.

This does NOT ship or extract any Xiaomi code. It reads the user's own
original APK, changes only the 4-byte value of
integer/green_mountain_eyecare_version (3 -> 4), drops the old signature
entries, and writes an unsigned APK. The build script aligns and signs it.

The original file has one Res_value for this integer:

    08 00 00 10 03 00 00 00
    |  |  |  |  +-------- data = 3 (little endian)
    |  |  |  +----------- dataType = TYPE_INT_DEC (0x10)
    |  |  +-------------- res0
    |  +----------------- size = 8
    +-------------------- ...

If the input overlay is from a different firmware and the pattern is not
unique, the script stops instead of patching the wrong value.
"""
from __future__ import annotations

import struct
import sys
import zipfile
from pathlib import Path

PATTERN_V3 = b"\x08\x00\x00\x10\x03\x00\x00\x00"
PATTERN_V4 = b"\x08\x00\x00\x10\x04\x00\x00\x00"
STORE_NAMES = {"resources.arsc", "AndroidManifest.xml"}


def main() -> int:
    if len(sys.argv) != 3:
        print(f"usage: {Path(sys.argv[0]).name} <overlay.apk> <output-unsigned.apk>", file=sys.stderr)
        return 2

    src = Path(sys.argv[1])
    dst = Path(sys.argv[2])

    with zipfile.ZipFile(src) as zin:
        try:
            arsc = zin.read("resources.arsc")
        except KeyError:
            print(f"error: {src} has no resources.arsc", file=sys.stderr)
            return 1

        positions: list[int] = []
        start = 0
        while True:
            pos = arsc.find(PATTERN_V3, start)
            if pos < 0:
                break
            positions.append(pos)
            start = pos + 1

        if len(positions) != 1:
            print(
                f"error: expected exactly one 3-byte integer pattern, found {len(positions)}; "
                "this overlay is not the expected build, update the script for your firmware",
                file=sys.stderr,
            )
            return 1

        pos = positions[0]
        data_off = pos + 4
        old = struct.unpack_from("<I", arsc, data_off)[0]
        if old != 3:
            print(f"error: unexpected value {old} at {data_off}", file=sys.stderr)
            return 1

        arsc = arsc[:data_off] + struct.pack("<I", 4) + arsc[data_off + 4 :]
        if arsc.count(PATTERN_V4) != 1:
            print("error: patched value did not verify", file=sys.stderr)
            return 1

        with zipfile.ZipFile(dst, "w") as zout:
            for info in zin.infolist():
                if info.filename.startswith("META-INF/"):
                    continue  # old signature; apksigner will create a new one
                data = zin.read(info.filename)
                if info.filename == "resources.arsc":
                    data = arsc
                out_info = zipfile.ZipInfo(info.filename, date_time=(1980, 1, 1, 0, 0, 0))
                out_info.compress_type = (
                    zipfile.ZIP_STORED if info.filename in STORE_NAMES else zipfile.ZIP_DEFLATED
                )
                out_info.external_attr = 0o644 << 16
                zout.writestr(out_info, data)

    print(f"wrote {dst}")
    print("  - integer/green_mountain_eyecare_version: 3 -> 4")
    print("  - old META-INF signature entries removed (unsigned)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
