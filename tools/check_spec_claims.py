#!/usr/bin/env python3
"""
Spec claim checker — verifies the mechanically-checkable claims in `spec/` against the code.

⚠️ REPORT-ONLY and NON-FATAL by design (exit 0 unless --strict). A guard that reddens on
every rename gets disabled; this one is meant to be read.

Built from a 2026-09-19 measurement of where spec drift actually lives:

  test-file existence      0 % drift      names are healthy
  asset existence          2 %
  class / method existence 0 %
  constant WITH a value    9 %
  ⚠️ CARDINALITY          80 %  <- "a 10-room graph (`ROOMS`)" when ROOMS has 38 entries

So the cardinality rule is the point of this tool; the rest is cheap corroboration.

Three things the measurement forced into the design:

  1. VALUES USUALLY SIT OUTSIDE THE BACKTICKS. The house dialect is `` `MARK_EMISSION` 0.14 ``,
     not `` `MARK_EMISSION = 0.14` ``. Parsing only inside the span finds a value for about a
     third of them.
  2. NEGATIVE CLAIMS INVERT THE TEST. "the watch is **gone**" passes when the symbol is
     ABSENT. Flagging every missing symbol floods the report with correct past-tense prose.
     Worse, some are behaviourally gone but textually present, so those are NEEDS-EYES,
     never a failure.
  3. LAST WRITER WINS, PER FILE. The dated ⭐ entries at the top of a spec state current
     values correctly while the older prose below repeats a stale one. Reporting both
     identically buries the real defect, so a constant whose value is right SOMEWHERE in
     the file is reported as STALE-COPY, not DRIFTED.

Usage:
  python3 tools/check_spec_claims.py                 # every spec
  python3 tools/check_spec_claims.py 01-lab          # one, by substring
  python3 tools/check_spec_claims.py --counts        # cardinality findings only
  python3 tools/check_spec_claims.py --strict        # exit = number of findings
"""
import os, re, sys, glob, collections

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAME = os.path.join(REPO, "game")

def _read(p):
    try:    return open(p, encoding="utf-8", errors="replace").read()
    except OSError: return ""

# ------------------------------------------------------------------ code index
SCRIPTS = {os.path.basename(p): p for p in glob.glob(os.path.join(GAME, "scripts", "*.gd"))}
TESTS   = {os.path.basename(p): p for p in glob.glob(os.path.join(GAME, "tests", "**", "*.gd"), recursive=True)}
# ⚠️ .tscn files are NOT only under game/scenes/ — game/assets/elements/environment.tscn is
# instanced by several level scenes. Indexing scenes/ alone reported it "no such scene".
SCENES  = {os.path.basename(p): p for p in
           glob.glob(os.path.join(GAME, "scenes", "**", "*.tscn"), recursive=True) +
           glob.glob(os.path.join(GAME, "assets", "**", "*.tscn"), recursive=True)}
TOOLS   = {os.path.basename(p) for p in glob.glob(os.path.join(REPO, "tools", "*"))}
ASSETS  = set()
for p in glob.glob(os.path.join(GAME, "assets", "**", "*"), recursive=True):
    if os.path.isfile(p):
        ASSETS.add(os.path.basename(p))
        ASSETS.add(os.path.splitext(os.path.basename(p))[0])

ALLGD = dict(SCRIPTS); ALLGD.update(TESTS)
SRC   = {n: _read(p) for n, p in ALLGD.items()}
BLOB  = "\n".join(SRC.values())

CLASSES = set(re.findall(r"^class_name\s+(\w+)", BLOB, re.M))
FUNCS   = set(re.findall(r"^\s*(?:static\s+)?func\s+(\w+)\s*\(", BLOB, re.M))
STRINGS = set(re.findall(r'"([A-Za-z_][A-Za-z0-9_]{2,})"', BLOB))

DECL_RE = re.compile(r"^[ \t]*(?:const|@export\s+var|static\s+var|var)\s+([A-Z][A-Z0-9_]{2,})\s*(?::=|=|:[^=]*=)\s*(.*)$", re.M)
CONSTS = {}                                    # NAME -> (file, rhs)
for n, s in SRC.items():
    for m in DECL_RE.finditer(s):
        CONSTS.setdefault(m.group(1), (n, m.group(2).split("#")[0].strip()))

def _count_literal(src, name):
    """Entries in `const NAME := [ ... ]` — bracket-matched, top level only."""
    m = re.search(r"(?:const|var)\s+" + re.escape(name) + r"\s*(?::=|=|:[^=]*=)\s*\[", src)
    if not m: return None
    i, depth, start = m.end() - 1, 0, None
    for j in range(i, len(src)):
        c = src[j]
        if c in "[{(":
            depth += 1
            if depth == 1: start = j + 1
        elif c in "]})":
            depth -= 1
            if depth == 0:
                inner = src[start:j]
                # Count top-level commas. ⚠️ A TRAILING COMMA is idiomatic GDScript and
                # inflated every count by one until 2026-09-19 (WING_ROOMS read 29, is 28).
                d, n = 0, 1 if inner.strip() else 0
                for ch in inner:
                    if ch in "[{(": d += 1
                    elif ch in "]})": d -= 1
                    elif ch == "," and d == 0: n += 1
                if inner.rstrip().endswith(","):
                    n -= 1
                return n
    return None

# (name, file) -> count, so a symbol declared in six scripts (ROOMS is) can be resolved
# against the spec's OWN scripts rather than whichever file the walk reached first.
ARRAY_BY_FILE = collections.defaultdict(dict)
for n, s in SRC.items():
    for m in re.finditer(r"(?:const|var)\s+([A-Z][A-Z0-9_]{2,})\s*(?::=|=|:[^=]*=)\s*\[", s):
        c = _count_literal(s, m.group(1))
        if c is not None:
            ARRAY_BY_FILE[m.group(1)][n] = c

CONST_BY_FILE = collections.defaultdict(dict)
for n, s in SRC.items():
    for m in DECL_RE.finditer(s):
        CONST_BY_FILE[m.group(1)][n] = m.group(2).split("#")[0].strip()

# spec path -> the scripts that spec is about, read from the rules stubs' globs so there
# is one mapping in the repo rather than two that can disagree.
def _scope_for(spec_rel):
    out = set()
    for rule in glob.glob(os.path.join(REPO, ".claude", "rules", "*.md")):
        t = _read(rule)
        if spec_rel.replace("\\", "/") not in t:
            continue
        fm = re.search(r"^---\nglobs:\s*(.+?)\n---", t, re.S)
        if not fm:
            continue
        for g in (x.strip() for x in fm.group(1).replace("\n", " ").split(",")):
            for f in glob.glob(os.path.join(REPO, g), recursive=True):
                out.add(os.path.basename(f))
    return out

def _pick(by_file, name, scope):
    """Prefer a declaration in the spec's own scripts; fall back to any, flagged."""
    d = by_file.get(name)
    if not d:
        return None, None, False
    for f in d:
        if f in scope:
            return f, d[f], True
    f = next(iter(d))
    return f, d[f], False

# ------------------------------------------------------------------ helpers
WORDNUM = {"one":1,"two":2,"three":3,"four":4,"five":5,"six":6,"seven":7,"eight":8,"nine":9,
 "ten":10,"eleven":11,"twelve":12,"thirteen":13,"fourteen":14,"fifteen":15,"sixteen":16,
 "seventeen":17,"eighteen":18,"nineteen":19,"twenty":20,"twenty-one":21,"twenty-two":22,
 "twenty-three":23,"twenty-four":24,"twenty-five":25,"twenty-six":26,"twenty-seven":27,
 "twenty-eight":28,"twenty-nine":29,"thirty":30}

NEG = re.compile(r"\b(gone|deleted|removed|retired|superseded|no longer|used to|gets? deleted"
                 r"|gone\.|gone,|is an orphan|gone since|was cut|is CUT|stays on disk|history)\b", re.I)

def numbers(t):
    return [x.replace("−", "-") for x in re.findall(r"-?−?\d+(?:\.\d+)?", t.replace("−", "-"))]

def same_num(a, b):
    try: return abs(float(a) - float(b)) < 1e-6
    except ValueError: return False

# ------------------------------------------------------------------ extraction
def scan(text, scope):
    """Yield findings: (line, kind, token, status, detail)."""
    lines = text.splitlines()
    # ---- pass 1: constants, for last-writer-wins
    seen_vals = collections.defaultdict(set)
    for ln in lines:
        for m in re.finditer(r"`([A-Z][A-Z0-9_]{2,})`((?:[^`\n]{0,28}))", ln):
            for v in numbers(m.group(2))[:1]:
                seen_vals[m.group(1)].add(v)

    for i, ln in enumerate(lines, 1):
        neg = bool(NEG.search(ln))

        # ---- cardinality. Work BACKWARD from the array name: find every number in a
        # window around it, drop anything carrying a unit (a distance is not a count),
        # and report when none of them equals the array's real length. The noun is not
        # matched ("segments" vs a points array), so this is advisory by construction —
        # it hands over both numbers and a human adjudicates in five seconds.
        for m in re.finditer(r"`([A-Z][A-Z0-9_]{2,})`", ln):
            name = m.group(1)
            f, actual, in_scope = _pick(ARRAY_BY_FILE, name, scope)
            if f is None or not in_scope:
                continue          # out-of-scope homonym (ROOMS lives in six scripts)
            lo, hi = max(0, m.start() - 55), min(len(ln), m.end() + 30)
            window = ln[lo:m.start()] + " " + ln[m.end():hi]
            cands = []
            for wm in re.finditer(r"\b([\w-]+)\b(?!\s*(?:m\b|s\b|dB|%|×|x\b|\u00b0|/s))", window):
                w = wm.group(1).lower()
                v = WORDNUM.get(w) or (int(w) if w.isdigit() and len(w) <= 3 else None)
                if v is not None and 1 <= v <= 400:
                    cands.append(v)
            if cands and actual not in cands:
                yield (i, "count", name, "COUNT?",
                       f"spec says {'/'.join(str(c) for c in dict.fromkeys(cands))}, "
                       f"`{name}` in {f} has {actual} entries")

        for tok in re.findall(r"`([^`\n]{2,90})`", ln):
            t = tok.strip()
            base = os.path.basename(t)
            if t.endswith(".gd"):
                idx = TESTS if re.search(r"(check|walk|autoplay|probe|screenshot|test)_", base) else SCRIPTS
                if base not in idx and base not in SCRIPTS and base not in TESTS:
                    yield (i, "file", t, "NEEDS-EYES" if neg else "GONE", "no such .gd")
            elif t.endswith(".tscn") and base not in SCENES:
                yield (i, "scene", t, "NEEDS-EYES" if neg else "GONE", "no such scene")
            elif t.endswith((".png",".jpg",".wav",".ogg",".mp3",".ogv",".glb",".gdshader")) and base not in ASSETS:
                yield (i, "asset", t, "NEEDS-EYES" if neg else "GONE", "not under game/assets")
            elif t.endswith((".py",".sh")) and base not in TOOLS:
                yield (i, "tool", t, "NEEDS-EYES" if neg else "GONE", "no such tool")
            elif re.fullmatch(r"_?\w+\(\)", t):
                fn = t[:-2]
                if fn not in FUNCS:
                    yield (i, "func", t, "NEEDS-EYES" if neg else "GONE", "no func of that name")
            elif re.fullmatch(r"[A-Z][A-Z0-9_]{2,}", t):
                if t not in CONSTS:
                    if t not in STRINGS and t not in CLASSES:
                        yield (i, "const", t, "NEEDS-EYES" if neg else "GONE", "not declared")
                    continue
                # ⚠️ A name can be declared in several of the spec's OWN scripts (FAR_DB is
                # in both flood_plate.gd and sprawl_crate.gd with different values). Accept
                # the spec's number if it matches ANY in-scope declaration, or the claim is
                # a false positive rather than drift.
                cands = {fn: rhs for fn, rhs in CONST_BY_FILE.get(t, {}).items() if fn in scope} \
                        or {CONSTS[t][0]: CONSTS[t][1]}
                f, rhs = next(iter(cands.items()))
                code_n = [n for r in cands.values() for n in numbers(r)]
                after = ln[ln.find("`" + t + "`") + len(t) + 2:][:28]
                spec_n = numbers(after)[:1]
                if spec_n and code_n and not any(same_num(spec_n[0], c) for c in code_n):
                    right_elsewhere = any(any(same_num(v, c) for c in code_n) for v in seen_vals[t])
                    yield (i, "value", t,
                           "STALE-COPY" if right_elsewhere else "DRIFTED",
                           f"spec {spec_n[0]}, {'/'.join(sorted(cands))} has {'/'.join(sorted(set(str(c) for c in code_n)))[:40]}"
                           + ("  (another line in this file has it right)" if right_elsewhere else ""))

# ------------------------------------------------------------------ run
args    = [a for a in sys.argv[1:] if not a.startswith("--")]
STRICT  = "--strict" in sys.argv
ONLY_C  = "--counts" in sys.argv

specs = sorted(glob.glob(os.path.join(REPO, "spec", "levels", "*.md")) +
               glob.glob(os.path.join(REPO, "spec", "systems", "*.md")))
if args:
    specs = [p for p in specs if any(a in p for a in args)]

tally, total = collections.Counter(), 0
for p in specs:
    rel  = os.path.relpath(p, REPO)
    rows = [r for r in scan(_read(p), _scope_for(rel)) if not ONLY_C or r[1] == "count"]
    seen, uniq = set(), []
    for r in rows:
        k = (r[1], r[2], r[3])
        if k in seen: continue
        seen.add(k); uniq.append(r)
    for r in uniq: tally[r[3]] += 1
    total += len(uniq)
    print(f"\n{rel}  —  {len(uniq)} finding(s)")
    for i, kind, tok, st, detail in sorted(uniq):
        print(f"   {rel}:{i:<4} {st:<11} {kind:<6} `{tok}`  — {detail}")

print("\n" + "=" * 80)
print("  ".join(f"{k} {v}" for k, v in sorted(tally.items())) or "  no findings")
print(f"TOTAL {total}")
print("⚠️  DRIFTED = the spec disagrees with the code.  STALE-COPY = an older line repeats a value")
print("    a newer line in the same file already states correctly.  NEEDS-EYES = a negative claim")
print("    ('X is gone') whose symbol still exists — usually correct prose, sometimes not.")
print("(non-fatal by design; --strict exits with the finding count)")
sys.exit(total if STRICT else 0)
