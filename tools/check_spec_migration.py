#!/usr/bin/env python3
"""
Verifies the 2026-09-19 CLAUDE.md -> spec/ migration lost nothing.

Usage:  python3 tools/check_spec_migration.py [path/to/original/CLAUDE.md]

Without an argument it reconstructs the original from git (the last commit that
still had the monolithic file) so the check stays runnable after the fact.
Exit code = number of failures.
"""
import os, re, sys, glob, subprocess

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
fails, checks = [], 0

def ck(cond, msg):
    global checks
    checks += 1
    if not cond:
        fails.append(msg)
    return cond

# ---- the original ------------------------------------------------------
if len(sys.argv) > 1:
    original = open(sys.argv[1], encoding="utf-8").read()
    src = sys.argv[1]
else:
    try:
        original = subprocess.check_output(
            ["git", "-C", REPO, "show", "HEAD:CLAUDE.md"], text=True)
        src = "git HEAD:CLAUDE.md"
    except subprocess.CalledProcessError:
        print("FATAL: pass the original CLAUDE.md as an argument")
        sys.exit(1)

SPEC = sorted(glob.glob(os.path.join(REPO, "spec/levels/*.md")) +
              glob.glob(os.path.join(REPO, "spec/systems/*.md")) +
              glob.glob(os.path.join(REPO, "spec/design/proposed-levels.md")))

# Lines DELIBERATELY rewritten by the migration, each with the reason. A line is
# forgiven only if it appears here; the list asserts its own size so a new loss
# cannot hide behind an entry written for a different one (check_wall_overlap.gd's
# _allow discipline).
REWRITTEN = {
    "\u26a0\ufe0f **Four new levels are specified but not yet built**":
        "corrected: THE NIGHTMARE shipped as Level 7, so it is three, not four",
    "CHAMBER, THE RETURN) and `DUNGEON_NIGHTMARES.md` (THE NIGHTMARE). The agreed target order is:":
        "same correction; detail moved to spec/design/proposed-levels.md",
    "The renumbering must land as **one commit** (`GameState`'s level map + scene constants,":
        "re-set as a bullet list in spec/design/proposed-levels.md",
    "`Screamer.LEVEL_SCREAMERS`, the `level_progress` rows, `level_3.gd`'s `current_level`, the back-door":
        "same",
    "chain), with `tests/check_level_resume.gd` extended to assert the full chain both directions.":
        "same",
    "### Making the game scarier \u2014 read `SCARY.md`":
        "repointed to spec/design/SCARY.md",
    "`SCARY.md` is the authoritative fear document: the diagnosis (predictable/habituating \u00b7 no dread":
        "repointed to spec/design/SCARY.md",
    "Before diagnosing any bug, read `ISSUES_SOLUTIONS.md`.":
        "repointed to docs/ISSUES_SOLUTIONS.md",
    "\u26a0\ufe0f **`GAME_MECHANICS_IDEAS.md` is the entry point":
        "repointed to spec/GAME_MECHANICS_IDEAS.md (Phase 2, Q23/Q26)",
    "- **(superseded) Gate 6 \u2014 THE PHONE**":
        "BUG_FIX citation 4.6 -> 4.5: BUG_FIX has no 4.7 and 4.5 IS the Gate 6 hammer (Q15)",
    "- **Gate 8 \u2014 THE AIRLOCK** (*catch* \u2014 was a 9 s stillness *wait* until **BUG_FIX.md 4.7**)":
        "BUG_FIX citation 4.7 -> 4.6: there is no section 4.7 (Q15)",
    "| `rotary_phone.gd` | `class_name RotaryPhone`":
        "BUG_FIX citation 4.6 -> 4.5 in the scripts reference (Q15)",
}
ALLOWED_REWRITES = 12
new_claude = open(os.path.join(REPO, "CLAUDE.md"), encoding="utf-8").read()
spec_text = {p: open(p, encoding="utf-8").read() for p in SPEC}
haystack = new_claude + "\n" + "\n".join(spec_text.values())

# ---- 1. every substantive source line survives somewhere ---------------
missing, forgiven = [], 0
for ln in original.splitlines():
    s = ln.strip()
    if len(s) < 12:            # blank lines, fence markers, tiny separators
        continue
    if s in haystack:
        continue
    if any(s.startswith(k) for k in REWRITTEN):
        forgiven += 1
        continue
    missing.append(s)
ck(not missing, f"{len(missing)} source lines lost "
                f"(first: {missing[0][:90] if missing else ''!r})")
ck(forgiven == ALLOWED_REWRITES,
   f"deliberate-rewrite allowlist matched {forgiven} lines, expected {ALLOWED_REWRITES} "
   f"- update REWRITTEN with a reason, do not widen it silently")

# ---- 2. marker audit ---------------------------------------------------
for ch, name in (("⚠", "warning"), ("⭐", "star")):
    a, b = original.count(ch), haystack.count(ch)
    ck(b >= a, f"{name} markers dropped: original {a}, now {b}")

# ---- 3. CLAUDE.md is actually smaller ----------------------------------
ck(len(new_claude) < len(original) * 0.25,
   f"CLAUDE.md is {len(new_claude)} ch, expected well under 25% of {len(original)}")

# ---- 4. every spec path named in CLAUDE.md resolves --------------------
ck(os.path.exists(os.path.join(REPO, "spec/design/proposed-levels.md")),
   "spec/design/proposed-levels.md is missing - the unbuilt levels have no home")
for m in re.findall(r"`(spec/[A-Za-z0-9_./-]+\.md)`", new_claude):
    ck(os.path.exists(os.path.join(REPO, m)), f"CLAUDE.md names a missing spec: {m}")
for m in re.findall(r"`(docs/[A-Za-z0-9_./-]+\.md)`", new_claude):
    ck(os.path.exists(os.path.join(REPO, m)), f"CLAUDE.md names a missing doc: {m}")

# ---- 5. level specs carry both sections + the protocol header ----------
for p in sorted(glob.glob(os.path.join(REPO, "spec/levels/0*.md"))):
    t = spec_text[p]; n = os.path.basename(p)
    ck("\n## SPEC\n" in t, f"{n}: no SPEC section")
    ck("\n## DECISIONS & GOTCHAS\n" in t, f"{n}: no DECISIONS & GOTCHAS section")
    ck("SPEC-FIRST" in t, f"{n}: no SPEC-FIRST protocol header")

# ---- 6. the protocol itself is resident --------------------------------
ck("SPEC-FIRST" in new_claude, "CLAUDE.md has no SPEC-FIRST protocol section")
ck("Where the docs live" in new_claude, "CLAUDE.md has no doc-location table")

# ---- 7. every rules stub points at a spec that exists, and its globs match
for p in sorted(glob.glob(os.path.join(REPO, ".claude/rules/*.md"))):
    t = open(p, encoding="utf-8").read(); n = os.path.basename(p)
    fm = re.search(r"^---\nglobs:\s*(.+?)\n---", t, re.S)
    if not ck(fm is not None, f"{n}: no globs: frontmatter"):
        continue
    for g in [x.strip() for x in fm.group(1).replace("\n", " ").split(",") if x.strip()]:
        ck(bool(glob.glob(os.path.join(REPO, g), recursive=True)),
           f"{n}: glob matches no file -> {g}")
    for ref in re.findall(r"`(spec/[A-Za-z0-9_./-]+\.md)`", t):
        ck(os.path.exists(os.path.join(REPO, ref)), f"{n}: points at missing {ref}")

# ---- 8. Level 7 points at its authority, never copies it ---------------
n7 = os.path.join(REPO, "spec/levels/07-nightmare.md")
if os.path.exists(n7):
    t = open(n7, encoding="utf-8").read()
    ck("spec/design/DUNGEON_NIGHTMARES.md" in t,
       "07-nightmare.md does not point at DUNGEON_NIGHTMARES.md")

print(f"\nsource: {src}")
print(f"original {len(original):>7} ch   new CLAUDE.md {len(new_claude):>6} ch "
      f"({len(new_claude)*100//len(original)}%)   spec/ {sum(len(v) for v in spec_text.values()):>7} ch")
print(f"{checks} checks, {len(fails)} failed")
for f in fails:
    print("  FAIL " + f)
print("SPEC-MIGRATION " + ("PASS" if not fails else "FAIL"))
sys.exit(len(fails))
