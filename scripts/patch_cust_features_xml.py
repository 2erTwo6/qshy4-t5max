#!/usr/bin/env python3
"""Enable the HyperOS 4 "new eye care" scope in a mi_ext cust feature file.

The file is /mi_ext/product/etc/cust_features/device_features.xml pulled
from the user's own phone.  HyperOSCustFeatureResolve reads
is_new_eye_care from it; when the key is missing it defaults to false, and
EffectScopeManagerV4 then disables eye care on the lock screen.

Only this one boolean is added or flipped; every other cust feature is
kept byte-for-byte (apart from the inserted line).
"""
from __future__ import annotations

import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

FLAG = "is_new_eye_care"
FLAG_RE = re.compile(r'(<bool\s+name="' + FLAG + r'"\s*>\s*)(true|false)(\s*</bool>)')
CLOSE = "</cust_feature>"


def main() -> int:
    if len(sys.argv) != 3:
        print(
            f"usage: {Path(sys.argv[0]).name} <device_features.xml> <output.xml>",
            file=sys.stderr,
        )
        return 2

    src = Path(sys.argv[1])
    dst = Path(sys.argv[2])
    text = src.read_text(encoding="utf-8")

    match = FLAG_RE.search(text)
    if match:
        if match.group(2) == "true":
            change = f"{FLAG}: already true"
        else:
            text = text[: match.start(2)] + "true" + text[match.end(2) :]
            change = f"{FLAG}: false -> true"
    else:
        close_at = text.rfind(CLOSE)
        if close_at < 0:
            print(f"error: {CLOSE} not found in {src}", file=sys.stderr)
            return 1
        line_start = text.rfind("\n", 0, close_at) + 1
        indent = text[line_start:close_at]
        if indent.strip():
            print(f"error: unexpected layout before {CLOSE} in {src}", file=sys.stderr)
            return 1
        insertion = f'{indent}    <bool name="{FLAG}">true</bool>\n'
        text = text[:line_start] + insertion + text[line_start:]
        change = f"{FLAG}: added true"

    dst.write_text(text, encoding="utf-8")

    # Validate that the result is still well-formed XML.
    root = ET.parse(dst).getroot()
    if root.tag != "cust_features":
        print(f"error: root tag is {root.tag!r}, expected 'cust_features'", file=sys.stderr)
        return 1

    print(f"wrote {dst}")
    print(f"  - {change}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
