#!/usr/bin/env python3
"""Patch a Xiaomi dash.xml copy for the Qingshan 4.0 module.

The script only edits two device-feature booleans; all other lines are kept.
It expects the input to be the file pulled from the user's own device
(/product/etc/device_features/dash.xml).
"""
from __future__ import annotations

import sys
import xml.etree.ElementTree as ET
from pathlib import Path

FLAG_1 = "support_night_wakeup_mode_setting"
FLAG_2 = "enable_eyecare_wave_render"
ANCHOR = '<bool name="is_rhythmic_mode_v2_supported">true</bool>'


def bool_tag(name: str, value: str) -> str:
    return f'<bool name="{name}">{value}</bool>'


def main() -> int:
    if len(sys.argv) != 3:
        print(f"usage: {Path(sys.argv[0]).name} <dash.xml> <output.xml>", file=sys.stderr)
        return 2

    src = Path(sys.argv[1])
    dst = Path(sys.argv[2])
    text = src.read_text(encoding="utf-8")

    changes: list[str] = []

    # 1) support_night_wakeup_mode_setting: false -> true
    false_1 = bool_tag(FLAG_1, "false")
    true_1 = bool_tag(FLAG_1, "true")
    if false_1 in text:
        text = text.replace(false_1, true_1, 1)
        changes.append(f"{FLAG_1}: false -> true")
    elif true_1 in text:
        changes.append(f"{FLAG_1}: already true")
    else:
        print(f"error: {FLAG_1} not found in {src}", file=sys.stderr)
        return 1

    # 2) enable_eyecare_wave_render: add or force true
    false_2 = bool_tag(FLAG_2, "false")
    true_2 = bool_tag(FLAG_2, "true")
    if false_2 in text:
        text = text.replace(false_2, true_2, 1)
        changes.append(f"{FLAG_2}: false -> true")
    elif true_2 in text:
        changes.append(f"{FLAG_2}: already true")
    else:
        if ANCHOR not in text:
            print(f"error: anchor not found for {FLAG_2}", file=sys.stderr)
            return 1
        text = text.replace(ANCHOR, f"{ANCHOR}\n    {true_2}", 1)
        changes.append(f"{FLAG_2}: added true")

    dst.write_text(text, encoding="utf-8")

    # Validate that the result is still well-formed XML.
    ET.parse(dst)

    print(f"wrote {dst}")
    for change in changes:
        print(f"  - {change}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
