#!/usr/bin/env bash
python3 - <<'PY'
from pathlib import Path
import re

bad = []
for p in Path(".").rglob("*.md"):
    in_fence = False
    lines = []
    for i, line in enumerate(p.read_text(encoding="utf-8", errors="ignore").splitlines(), 1):
        if re.match(r'^\s*```', line):
            in_fence = not in_fence
            lines.append(i)
    if in_fence:
        bad.append((p, lines))

if not bad:
    print("OK: no unclosed fences")
else:
    for p, lines in bad:
        print(f"UNCLOSED FENCE: {p}")
        print(f"Fence lines: {lines}")
        print()
PY
