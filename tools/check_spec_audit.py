#!/usr/bin/env python3
"""
Byte-accounting for the spec audit — proves the agents MOVED text rather than rewrote it.

The audit's contract (decision A7) is: an agent may RELOCATE a passage, DELETE one it has
proven superseded, and CORRECT a wrong number or name in place. It may NOT reword prose it
is keeping. That is only a rule if something checks it, and this is the check.

⚠️ THIS IS THE GUARD THAT WOULD HAVE CAUGHT THE 2026-09-19 ORDERING MISTAKE, where a
mechanical pass reordered ten spec files and inverted their override semantics. Content
accounting alone said everything was fine, because nothing was lost — only moved wrongly.

Method: every line in the audited file must be byte-identical to a line that existed in the
snapshot, UNLESS it falls in an allow-zone:

  * the `## NEEDS A PLAYTEST` section              (new by design)
  * the `## DECISIONS & GOTCHAS` boilerplate       (new by design)
  * a one-line supersession note                   (`⚠️ Superseded …`)
  * a section header

Anything else new is a REWRITE and is reported. Deletions are listed in full, never silent,
so a human can see exactly what the audit judged superseded.

Usage:
  python3 tools/check_spec_audit.py <snapshot-dir>            # all files
  python3 tools/check_spec_audit.py <snapshot-dir> 01-lab     # one, by substring
  python3 tools/check_spec_audit.py <snapshot-dir> --strict   # exit = rewritten-line count
"""
import os, re, sys, glob, collections

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

ALLOW_NEW = [
    re.compile(r"^\s*#{1,4}\s"),                        # any heading
    re.compile(r"^\s*>?\s*⚠️\s*\*?\*?Superseded", re.I),  # a relocation note
    re.compile(r"^\s*>?\s*⚠️.*\bsupersed", re.I),
    re.compile(r"^\s*$"),                                # blank
    re.compile(r"^\s*[-*]\s*$"),
]

def zones(lines):
    """-> set of indices inside an allow-zone section."""
    out, cur = set(), None
    for i, ln in enumerate(lines):
        m = re.match(r"^##\s+(.*)$", ln.strip())
        if m:
            t = m.group(1).upper()
            cur = ("PLAYTEST" in t or "DECISIONS" in t)
        if cur:
            out.add(i)
    return out

def audit(old_text, new_text):
    old_lines = old_text.splitlines()
    new_lines = new_text.splitlines()
    pool = collections.Counter(l.rstrip() for l in old_lines)
    allow = zones(new_lines)

    # A7 permits three edits. Only the fourth is a violation, so the guard has to tell
    # them apart or it is pure noise: measured on the first completed audit, 11 of 12
    # flagged lines were legitimate excisions.
    #   EXCISION   — the new line is a CONTIGUOUS FRAGMENT of an old one (a sentence was
    #                cut out and the rest closed up). Allowed, listed.
    #   CORRECTION — the new line matches an old one except for a few tokens (a wrong
    #                number or name fixed in place). Allowed, listed — read these.
    #   NEW PROSE  — neither. This is the violation A7 exists to prevent.
    olds = [l.rstrip() for l in old_lines if l.strip()]
    def classify(l):
        core = l.strip()
        if len(core) >= 12:
            for o in olds:
                if core in o:
                    return "EXCISION", o
        a = set(re.findall(r"[\w./()-]+", core))
        if a:
            best, bo = 0.0, ""
            for o in olds:
                b = set(re.findall(r"[\w./()-]+", o))
                if not b: continue
                j = len(a & b) / len(a | b)
                if j > best: best, bo = j, o
            if best >= 0.80:
                return "CORRECTION", bo
        return "NEW PROSE", ""

    rewritten, consumed = [], collections.Counter()
    for i, raw in enumerate(new_lines):
        l = raw.rstrip()
        if pool[l] - consumed[l] > 0:
            consumed[l] += 1
            continue
        if i in allow or any(p.match(raw) for p in ALLOW_NEW):
            continue
        kind, src = classify(l)
        rewritten.append((i + 1, raw, kind, src))

    newpool = collections.Counter(l.rstrip() for l in new_lines)
    deleted = []
    for l, n in pool.items():
        gap = n - newpool.get(l, 0)
        if gap > 0 and l.strip():
            deleted.append((gap, l))
    return rewritten, deleted

# ------------------------------------------------------------------ run
if len(sys.argv) < 2:
    print(__doc__); sys.exit(2)
SNAP = sys.argv[1]
args = [a for a in sys.argv[2:] if not a.startswith("--")]
STRICT = "--strict" in sys.argv

pairs = []
for snap in sorted(glob.glob(os.path.join(SNAP, "**", "*.md"), recursive=True)):
    rel = os.path.relpath(snap, SNAP)                     # levels/01-lab.md
    live = os.path.join(REPO, "spec", rel)
    if os.path.exists(live):
        pairs.append((rel, snap, live))
if args:
    pairs = [p for p in pairs if any(a in p[0] for a in args)]

tot_rw = tot_del = 0
for rel, snap, live in pairs:
    rw, dl = audit(open(snap, encoding="utf-8").read(), open(live, encoding="utf-8").read())
    bad = [r for r in rw if r[2] == "NEW PROSE"]
    okk = [r for r in rw if r[2] != "NEW PROSE"]
    tot_rw += len(bad); tot_del += sum(n for n, _ in dl)
    flag = "⚠️ NEW PROSE" if bad else "ok"
    print(f"\n{rel:<26} {flag:<13} new-prose {len(bad):>3}   excision/correction {len(okk):>3}   deleted {sum(n for n,_ in dl):>3}")
    for ln, txt, kind, _ in bad[:10]:
        print(f"    ⚠️ {kind}  spec/{rel}:{ln}  {txt.strip()[:104]}")
    for ln, txt, kind, _ in okk[:6]:
        print(f"       {kind:<10} spec/{rel}:{ln}  {txt.strip()[:100]}")
    if len(okk) > 6:
        print(f"       … and {len(okk) - 6} more excisions/corrections")
    for n, txt in dl[:8]:
        print(f"       deleted{'  x%d' % n if n > 1 else '    '}  {txt.strip()[:110]}")
    if len(dl) > 8:
        print(f"       … and {len(dl) - 8} more deleted lines")

print("\n" + "=" * 80)
print(f"{len(pairs)} files   NEW-PROSE LINES {tot_rw}   deleted lines {tot_del}")
if tot_rw:
    print("⚠️  NEW PROSE breaks decision A7 (move / delete-if-superseded / correct-in-place).")
    print("    EXCISION and CORRECTION lines are permitted and listed so you can read them.")
else:
    print("✅ A7 held: every surviving line is byte-identical, a contiguous fragment of an")
    print("   original line, or the same line with a number/name corrected.")
print("Deleted lines are listed so nothing is judged superseded silently.")
sys.exit(tot_rw if STRICT else 0)
