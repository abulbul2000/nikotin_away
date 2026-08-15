#!/usr/bin/env python3
"""Removes duplicate report keys from lib/core/app_texts.dart.

Keeps the FIRST occurrence of each report key in each language block,
deletes any later duplicates (introduced by a manual paste).
"""

import re

PATH = "lib/core/app_texts.dart"

KEYS = {
    "reportsAvertedCigarettes",
    "reportsSmokingTimePattern",
    "reportsNoDataYet",
    "reportsPartMorning",
    "reportsPartMidday",
    "reportsPartAfternoon",
    "reportsPartEvening",
    "reportsPartNight",
    "reportsDisclaimer",
}

with open(PATH, encoding="utf-8") as f:
    lines = f.read().split("\n")

out = []
block = None
seen = {"tr": set(), "en": set()}
removed = 0

for ln in lines:
    if "static const Map<String, String> _tr = {" in ln:
        block = "tr"
    elif "static const Map<String, String> _en = {" in ln:
        block = "en"
    m = re.match(r"    '([^']+)':", ln)
    if m and block:
        key = m.group(1)
        if key in KEYS:
            if key in seen[block]:
                removed += 1
                continue
            seen[block].add(key)
    out.append(ln)

with open(PATH, "w", encoding="utf-8") as f:
    f.write("\n".join(out))

print("Removed {} duplicate lines. TR keys kept: {}, EN keys kept: {}".format(
    removed, len(seen["tr"]), len(seen["en"])))
