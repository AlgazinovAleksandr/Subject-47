#!/usr/bin/env python3
"""
Spec drift report — is each level's spec as recent as the code it describes?

⚠️ NON-FATAL BY DESIGN (exit 0 always). A guard that reddens on a typo fix gets
disabled within a week; this one is meant to be read. It reports, you judge.

The level -> scripts mapping is read from `.claude/rules/*.md` frontmatter, so
there is exactly one place to keep it correct.

Usage:  python3 tools/check_spec_freshness.py
"""
import os, re, glob, subprocess, datetime, sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def last_change(path):
    """Seconds since epoch of the last git commit touching path; mtime if untracked."""
    try:
        out = subprocess.check_output(
            ["git", "-C", REPO, "log", "-1", "--format=%ct", "--", path],
            text=True, stderr=subprocess.DEVNULL).strip()
        if out:
            return int(out), "git"
    except subprocess.CalledProcessError:
        pass
    try:
        return int(os.path.getmtime(os.path.join(REPO, path))), "mtime"
    except OSError:
        return None, "missing"

def day(ts):
    return datetime.date.fromtimestamp(ts).isoformat() if ts else "—"

rows = []
for rule in sorted(glob.glob(os.path.join(REPO, ".claude/rules/*.md"))):
    t = open(rule, encoding="utf-8").read()
    fm = re.search(r"^---\nglobs:\s*(.+?)\n---", t, re.S)
    spec = re.search(r"`(spec/[^`]+\.md)`", t)
    if not (fm and spec):
        continue
    spec_path = spec.group(1)
    globs = [g.strip() for g in fm.group(1).replace("\n", " ").split(",") if g.strip()]

    newest_code, newest_file = 0, ""
    for g in globs:
        for f in glob.glob(os.path.join(REPO, g), recursive=True):
            rel = os.path.relpath(f, REPO)
            ts, _ = last_change(rel)
            if ts and ts > newest_code:
                newest_code, newest_file = ts, rel
    spec_ts, src = last_change(spec_path)
    drift = newest_code - spec_ts if (spec_ts and newest_code) else 0
    rows.append((os.path.basename(rule)[:-3], spec_path, spec_ts, src,
                 newest_code, newest_file, drift))

rows.sort(key=lambda r: -r[6])
w = max(len(r[0]) for r in rows) if rows else 10
print(f"\n{'area':<{w}}  {'spec':<12} {'newest code':<12}  drift  newest-changed file")
print("-" * (w + 60))
stale = 0
for name, spec_path, spec_ts, src, code_ts, code_file, drift in rows:
    days = drift // 86400
    flag = "  ⚠️" if days >= 1 else "   ·"
    if days >= 1:
        stale += 1
    print(f"{name:<{w}}  {day(spec_ts):<12} {day(code_ts):<12} {days:>4}d{flag} {code_file}")

print(f"\n{len(rows)} areas, {stale} where code is newer than its spec.")
if stale:
    print("⚠️ Drift is not automatically a defect — a refactor or a comment fix needs no spec change.")
    print("   It IS the list to check when you ask 'is this spec still true?'")
print("(non-fatal by design — always exits 0)")
sys.exit(0)
