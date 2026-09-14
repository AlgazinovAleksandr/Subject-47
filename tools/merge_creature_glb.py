#!/usr/bin/env python3
"""Merge one creature's per-clip GLBs into ONE multi-animation model for the game.

    python3 tools/merge_creature_glb.py                          # hollow_crown: merge + surgery
    python3 tools/merge_creature_glb.py --shrink                 # ...and halve the textures (sips)
    python3 tools/merge_creature_glb.py --measure                # print clip measurements only
    python3 tools/merge_creature_glb.py --profile parasite --shrink
    /Applications/Godot.app/Contents/MacOS/Godot --headless --path game --import

PROFILES (2026-09-12 — the tool was hard-wired to the Hollow Crown until THE NIGHTMARE got its own
creature; everything that was a module constant is now a row in PROFILES, and every number that was
typed for the Meshy files — "bufferViews 0..7 are shared", "the rig is in cm under a 0.01 armature",
"materials[0]" — is now DERIVED from the base file, because the Parasite breaks all three):

  hollow_crown  assets_src/models/hollow_crown/*.glb  (six Meshy exports) -> game/assets/models/hollow_crown.glb
  parasite      assets_src/models/parasite/*.glb      (two Blender exports of Mixamo FBX takes, see
                tools/fbx_to_glb.py)                  -> game/assets/models/parasite.glb

WHY MERGE AT ALL. All six files contain the SAME mesh, the same 24-joint skin and the same
2048x2048 texture; they differ only in their single animation, which is 7-62 KB. Shipping six
is 91 MB of git for 129 KB of new information. Verified: bufferViews 0..7 (POSITION / NORMAL /
TEXCOORD_0 / JOINTS_0 / WEIGHTS_0 / indices / image / inverseBindMatrices) hash identically
across all six.

⚠️ THE GUARD IS THE SAFETY. Animation channels address joints by NODE INDEX, and this tool
copies them verbatim. That is only valid because the node arrays are identical, so the tool
refuses to run unless it has proved that — node names, child lists, skin joints and the
SHA-256 of the shared bufferViews must all match, or it aborts with a diff. A re-download that
renumbered the rig would otherwise produce a scrambled skeleton that looks like a code bug.

⚠️ THE MATERIAL SURGERY IS NOT COSMETIC. Two defects ship in the source and both are invisible
in a lit editor viewport and catastrophic in this game, which runs at ~0.02 ambient with no
tonemapping and no glow:

  1. `materials[0]` has NO `metallicFactor`. **glTF's default is 1.0**, so the creature imports
     as a 100 % metal — a near-black mirror lit only by a spot. Set to 0.0.
  2. The albedo map is ALSO wired as `emissiveTexture` with `emissiveFactor [1,1,1]`, i.e. the
     model is fully self-illuminating at full strength. In a game whose entire new premise is
     "you cannot see anything the torch is not pointing at", a monster that glows is the one
     thing that cannot ship. Both keys are removed.

⚠️ ONE CLIP HAS BAKED ROOT MOTION. `run_fast_10` translates Hips z by 2.25 m over 0.833 s. The
levels drive position in code and the visual rides on the collider, so an unstripped clip would
slide the mesh a whole body-length ahead of its own hitbox and snap back every cycle. The
linear component is subtracted and the residual sway kept. That drift is also the only
ground-truth stride speed the asset carries: 2.2791 m / 0.8333 s = 2.735 m/s, which is what
anchors `CreatureAnim`'s speed scaling instead of a typed guess.

⚠️ NO CLIP STARTS AT t=0. Every input accessor's first key is 1/30 s, so a looped clip carries a
33 ms dead frame per cycle. All times are rebased to 0.
"""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# ⚠️ The clip names are the contract with `game/scripts/creature_anim.gd` (`MODELS[...].clips`).
# Changing one here without changing it there produces a creature that stands still and no
# error at all. `root_motion` is either an explicit set of clip names or "auto" (strip every
# clip whose Hips drift more than AUTO_ROOT_MOTION_M over the clip). `target_h` prints the
# `.import` root_scale for that height, or None to ship the model at its natural size.
PROFILES = {
    "hollow_crown": {
        "src": ROOT / "assets_src" / "models" / "hollow_crown",
        "out": ROOT / "game" / "assets" / "models" / "hollow_crown.glb",
        "clips": {
            "Walking":         "walk",
            "Slow_Orc_Walk":   "shamble",
            "Unsteady_Walk":   "unsteady",
            "Running":         "run",
            "RunFast":         "sprint",
            "run_fast_10":     "charge",
        },
        "base_key": "Walking",         # the file whose mesh/skin/texture/material is kept
        "hips": "Hips",                # node name (suffix match, so "mixamorig:Hips" works too)
        "root_motion": {"charge"},     # stripped, not dropped — see the header
        "target_h": 1.97,
    },
    "parasite": {
        "src": ROOT / "assets_src" / "models" / "parasite",
        "out": ROOT / "game" / "assets" / "models" / "parasite.glb",
        "clips": {
            "parasite_walk": "walk",   # Mixamo "Mutant Walking", 1.43 s, hunched
            "parasite_run":  "run",    # Mixamo "Injured Run", 0.63 s, a limp at speed
        },
        "base_key": "parasite_walk",
        "hips": "mixamorig:Hips",
        "root_motion": "auto",
        "target_h": None,              # 2.01 m natural; the hunter ships at its own size
    },
}
AUTO_ROOT_MOTION_M = 0.2
PROFILE = PROFILES["hollow_crown"]   # rebound by --profile in main()
CLIPS: dict = PROFILE["clips"]       # module aliases kept for the helpers below

GLB_MAGIC = 0x46546C67
JSON_CHUNK = 0x4E4F534A
BIN_CHUNK = 0x004E4942


def die(msg: str) -> None:
    print("merge_creature_glb: " + msg, file=sys.stderr)
    sys.exit(1)


def read_glb(path: Path):
    d = path.read_bytes()
    magic, ver, _total = struct.unpack("<III", d[:12])
    if magic != GLB_MAGIC or ver != 2:
        die("%s is not a glTF 2.0 binary" % path.name)
    pos = 12
    js = None
    bn = b""
    while pos + 8 <= len(d):
        clen, ctype = struct.unpack("<II", d[pos:pos + 8])
        body = d[pos + 8: pos + 8 + clen]
        if ctype == JSON_CHUNK:
            js = json.loads(body.decode("utf-8"))
        elif ctype == BIN_CHUNK:
            bn = body
        pos += 8 + clen + ((4 - clen % 4) % 4 if clen % 4 else 0)
    if js is None:
        die("%s has no JSON chunk" % path.name)
    return js, bn


def write_glb(path: Path, js: dict, bn: bytes) -> None:
    js_bytes = json.dumps(js, separators=(",", ":")).encode("utf-8")
    js_bytes += b" " * ((4 - len(js_bytes) % 4) % 4)
    bn = bn + b"\x00" * ((4 - len(bn) % 4) % 4)
    total = 12 + 8 + len(js_bytes) + 8 + len(bn)
    with path.open("wb") as f:
        f.write(struct.pack("<III", GLB_MAGIC, 2, total))
        f.write(struct.pack("<II", len(js_bytes), JSON_CHUNK))
        f.write(js_bytes)
        f.write(struct.pack("<II", len(bn), BIN_CHUNK))
        f.write(bn)


def bv_bytes(js: dict, bn: bytes, idx: int) -> bytes:
    bv = js["bufferViews"][idx]
    o = bv.get("byteOffset", 0)
    return bn[o:o + bv["byteLength"]]


def acc_floats(js: dict, bn: bytes, idx: int):
    """Read a float accessor as a flat list. Every animation accessor here is 5126/float."""
    a = js["accessors"][idx]
    if a["componentType"] != 5126:
        die("accessor %d is not float (componentType %d)" % (idx, a["componentType"]))
    ncomp = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[a["type"]]
    bv = js["bufferViews"][a["bufferView"]]
    start = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    n = a["count"] * ncomp
    return list(struct.unpack("<%df" % n, bn[start:start + n * 4])), ncomp


def clip_of(path: Path) -> str:
    for frag, name in CLIPS.items():
        if frag in path.name:
            return name
    return ""


def find_node(js: dict, suffix: str) -> int:
    """Index of the node whose name is `suffix` or ends with it ("Hips" / "mixamorig:Hips")."""
    for i, n in enumerate(js["nodes"]):
        if n.get("name") == suffix:
            return i
    for i, n in enumerate(js["nodes"]):
        if str(n.get("name", "")).endswith(suffix):
            return i
    die("no node named '%s' in the base file" % suffix)


def node_scale_chain(js: dict, idx: int) -> float:
    """Product of the ancestors' uniform scale — what turns the rig's cm into world metres.
    The Meshy files put the rig in cm under a 0.01 Armature; Blender exports of Mixamo FBX do
    the same. Derived rather than typed so a re-export at 1.0 does not silently 100x a drift."""
    parent = {}
    for i, n in enumerate(js["nodes"]):
        for c in n.get("children", []):
            parent[c] = i
    k = 1.0
    cur = parent.get(idx)
    while cur is not None:
        sc = js["nodes"][cur].get("scale")
        if sc:
            k *= float(sc[2])
        cur = parent.get(cur)
    return k


def shared_views(js: dict) -> list:
    """Every bufferView the base file's MESH, SKIN and IMAGES reference — the bytes that must
    be identical across the per-clip files. (It was the literal `range(8)` for the Meshy files,
    whose exporter happened to write those first; Blender's exporter interleaves them.)"""
    used = set()
    for m in js["meshes"]:
        for prim in m["primitives"]:
            for acc in list(prim["attributes"].values()) + ([prim["indices"]] if "indices" in prim else []):
                a = js["accessors"][acc]
                if "bufferView" in a:
                    used.add(a["bufferView"])
    for sk in js.get("skins", []):
        if "inverseBindMatrices" in sk:
            used.add(js["accessors"][sk["inverseBindMatrices"]]["bufferView"])
    for im in js.get("images", []):
        if "bufferView" in im:
            used.add(im["bufferView"])
    return sorted(used)


# ---------------------------------------------------------------------------- the guard
def assert_same_rig(loaded: dict, base_clip: str) -> None:
    ref_name = None
    ref = None
    views = shared_views(loaded[base_clip][0])
    for name, (js, bn) in loaded.items():
        sig = {
            "nodes": [n.get("name") for n in js["nodes"]],
            "children": [n.get("children") for n in js["nodes"]],
            "joints": js["skins"][0]["joints"],
            "shared": hashlib.sha256(
                b"".join(bv_bytes(js, bn, i) for i in views)).hexdigest(),
        }
        if ref is None:
            ref, ref_name = sig, name
            continue
        for k in sig:
            if sig[k] != ref[k]:
                die("RIG MISMATCH between %s and %s on '%s'.\n"
                    "  The merge copies animation channels verbatim, which is only valid while\n"
                    "  every file numbers the rig identically. Re-export all six together."
                    % (ref_name, name, k))
    print("  guard: all %d files share one rig (nodes, children, joints, mesh bytes)"
          % len(loaded))
    print("  guard: %d shared bufferViews, SHA-256 %s" % (len(views), ref["shared"][:12]))


# ---------------------------------------------------------------------------- measurement
def measure(js: dict, bn: bytes, clip: str, anim: dict, hips: int, scale: float) -> dict:
    dur = 0.0
    t0 = 1e9
    for s in anim["samplers"]:
        vals, _ = acc_floats(js, bn, s["input"])
        dur = max(dur, max(vals))
        t0 = min(t0, min(vals))
    drift = None
    for c in anim["channels"]:
        if c["target"]["node"] == hips and c["target"]["path"] == "translation":
            s = anim["samplers"][c["sampler"]]
            v, _ = acc_floats(js, bn, s["output"])
            t, _ = acc_floats(js, bn, s["input"])
            # cm in the file; the armature chain's scale (0.01 here) makes them world metres.
            # ⚠️ ALL THREE AXES. The Meshy rig walked along its own z; the Mixamo rig's Hips
            # bone carries its forward travel on its local Y (measured: `walk` drifted 214 cm
            # in y and 0 in x/z, which the x/z-only version of this reported as "in place"
            # while Godot rendered a creature sliding 2.1 m per cycle off its collider).
            dx = (v[-3] - v[0]) * scale
            dy = (v[-2] - v[1]) * scale
            dz = (v[-1] - v[2]) * scale
            span = (t[-1] - t[0]) or 1.0
            mag = (dx * dx + dy * dy + dz * dz) ** 0.5
            drift = (dx, dy, dz, mag / span, len(t), mag)
    return {"clip": clip, "dur": dur, "t0": t0, "drift": drift}


# ---------------------------------------------------------------------------- main
def main() -> int:
    global PROFILE, CLIPS
    shrink = "--shrink" in sys.argv
    measure_only = "--measure" in sys.argv
    prof_name = "hollow_crown"
    if "--profile" in sys.argv:
        prof_name = sys.argv[sys.argv.index("--profile") + 1]
    if prof_name not in PROFILES:
        die("unknown --profile %s (have %s)" % (prof_name, sorted(PROFILES)))
    PROFILE = PROFILES[prof_name]
    CLIPS = PROFILE["clips"]
    SRC_DIR: Path = PROFILE["src"]
    OUT: Path = PROFILE["out"]
    BASE_KEY: str = PROFILE["base_key"]

    if not SRC_DIR.is_dir():
        die("no sources at %s\n  (hollow_crown: extract Meshy_AI_Hollow_Crown_biped.zip there;"
            " parasite: run tools/fbx_to_glb.py on the two Mixamo takes — see assets_src/README.md)"
            % SRC_DIR)
    files = sorted(p for p in SRC_DIR.glob("*.glb"))
    if len(files) != len(CLIPS):
        die("expected %d source GLBs in %s, found %d" % (len(CLIPS), SRC_DIR, len(files)))

    loaded = {}
    for p in files:
        c = clip_of(p)
        if not c:
            die("cannot map %s to a clip name — CLIPS keys are %s"
                % (p.name, sorted(CLIPS)))
        loaded[c] = read_glb(p)
    print("== merge_creature_glb [%s] ==" % prof_name)
    base_clip = CLIPS[BASE_KEY]
    assert_same_rig(loaded, base_clip)

    js, bn = loaded[base_clip]
    js = json.loads(json.dumps(js))          # deep copy; we mutate it
    bn = bytearray(bn)
    hips = find_node(js, PROFILE["hips"])
    scale = node_scale_chain(js, hips)
    print("  rig: hips node %d '%s', ancestor scale %.4f" % (hips, js["nodes"][hips].get("name"), scale))

    # ------------------------------------------------------------------ measure everything
    print("\n  clip        dur      keys   root drift (m)                  implied m/s")
    stats = []
    root_motion_clips = set()
    for clip in CLIPS.values():
        cjs, cbn = loaded[clip]
        m = measure(cjs, cbn, clip, cjs["animations"][0], hips, scale)
        stats.append(m)
        if m["drift"] is None:
            print("  %-10s %6.3fs   (no hips translation channel)" % (clip, m["dur"]))
            continue
        dx, dy, dz, speed, keys, mag = m["drift"]
        moving = mag > AUTO_ROOT_MOTION_M
        if moving:
            root_motion_clips.add(clip)
        print("  %-10s %6.3fs  %4d   dx %+6.3f dy %+7.3f dz %+7.3f   %6.3f%s"
              % (clip, m["dur"], keys, dx, dy, dz, speed, "   <- ROOT MOTION" if moving else ""))
    if PROFILE["root_motion"] != "auto":
        root_motion_clips = set(PROFILE["root_motion"])
    if measure_only:
        return 0

    # ------------------------------------------------------------------ merge the five others
    js["animations"] = []
    for clip in sorted(CLIPS.values()):
        cjs, cbn = loaded[clip]
        anim = json.loads(json.dumps(cjs["animations"][0]))
        acc_map = {}
        for s in anim["samplers"]:
            for key in ("input", "output"):
                old = s[key]
                if old in acc_map:
                    continue
                a = json.loads(json.dumps(cjs["accessors"][old]))
                raw = bytearray(bv_bytes(cjs, cbn, a["bufferView"]))
                # slice out just this accessor's window inside its bufferView
                off = a.get("byteOffset", 0)
                ncomp = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[a["type"]]
                nbytes = a["count"] * ncomp * 4
                chunk = bytes(raw[off:off + nbytes])
                # 4-byte align before appending; every animation accessor is float.
                while len(bn) % 4:
                    bn.append(0)
                js["bufferViews"].append(
                    {"buffer": 0, "byteOffset": len(bn), "byteLength": len(chunk)})
                bn += chunk
                a["bufferView"] = len(js["bufferViews"]) - 1
                a.pop("byteOffset", None)
                js["accessors"].append(a)
                acc_map[old] = len(js["accessors"]) - 1
            s["input"] = acc_map[s["input"]]
            s["output"] = acc_map[s["output"]]
        anim["name"] = clip
        js["animations"].append(anim)

    js["buffers"] = [{"byteLength": len(bn)}]

    # ------------------------------------------------------------------ rebase times to 0
    shifted = 0
    for anim in js["animations"]:
        for s in anim["samplers"]:
            a = js["accessors"][s["input"]]
            bv = js["bufferViews"][a["bufferView"]]
            o = bv.get("byteOffset", 0)
            n = a["count"]
            vals = list(struct.unpack("<%df" % n, bytes(bn[o:o + n * 4])))
            first = vals[0]
            if abs(first) < 1e-9:
                continue
            vals = [v - first for v in vals]
            bn[o:o + n * 4] = struct.pack("<%df" % n, *vals)
            a["min"] = [min(vals)]
            a["max"] = [max(vals)]
            shifted += 1
    print("\n  rebased %d input tracks so every clip starts at t=0 (was 1/30 s)" % shifted)

    # ------------------------------------------------------------------ strip root motion
    for anim in js["animations"]:
        if anim["name"] not in root_motion_clips:
            continue
        for c in anim["channels"]:
            if c["target"]["node"] != hips or c["target"]["path"] != "translation":
                continue
            s = anim["samplers"][c["sampler"]]
            ai, ao = js["accessors"][s["input"]], js["accessors"][s["output"]]
            bi = js["bufferViews"][ai["bufferView"]]
            bo = js["bufferViews"][ao["bufferView"]]
            oi, oo = bi.get("byteOffset", 0), bo.get("byteOffset", 0)
            n = ai["count"]
            t = list(struct.unpack("<%df" % n, bytes(bn[oi:oi + n * 4])))
            v = list(struct.unpack("<%df" % (n * 3), bytes(bn[oo:oo + n * 12])))
            span = (t[-1] - t[0]) or 1.0
            before = (v[-3] - v[0], v[-2] - v[1], v[-1] - v[2])
            # ⚠️ Interpolate on the sampler's own TIMES, not on key index. The keys here are
            # uniform 30 fps, but a re-export need not be, and index-based removal would then
            # leave a sawtooth that reads as a limp. All three axes: see measure().
            for i in range(n):
                f = (t[i] - t[0]) / span
                for k in range(3):
                    v[i * 3 + k] -= before[k] * f
            bn[oo:oo + n * 12] = struct.pack("<%df" % (n * 3), *v)
            after = (v[-3] - v[0], v[-2] - v[1], v[-1] - v[2])
            mag_b = (before[0] ** 2 + before[1] ** 2 + before[2] ** 2) ** 0.5
            mag_a = (after[0] ** 2 + after[1] ** 2 + after[2] ** 2) ** 0.5
            print("  stripped root motion from '%s': |d| %.1f cm -> %.2f cm  "
                  "(ground speed was %.3f m/s — CreatureAnim's anchor)"
                  % (anim["name"], mag_b, mag_a, mag_b * scale / span))

    # ------------------------------------------------------------------ material surgery
    # ⚠️ EVERY material, not materials[0]: the Parasite mesh has two primitives with two
    # materials (body / head-and-growth), and Blender's FBX import gives both metallic 0.5.
    for mi, mat in enumerate(js["materials"]):
        pbr = mat.setdefault("pbrMetallicRoughness", {})
        old_metal = pbr.get("metallicFactor", "ABSENT (glTF default 1.0)")
        pbr["metallicFactor"] = 0.0
        old_rough = pbr.get("roughnessFactor", "absent (default 1.0)")
        pbr["roughnessFactor"] = 0.88
        had_emissive = "emissiveTexture" in mat or mat.get("emissiveFactor")
        mat.pop("emissiveTexture", None)
        mat.pop("emissiveFactor", None)
        mat.pop("extensions", None)
        mat["doubleSided"] = False
        print("\n  material[%d] '%s': metallicFactor %s -> 0.0        <- the 100%%-metal trap"
              % (mi, mat.get("name", ""), old_metal))
        print("  material[%d]: roughnessFactor %s -> 0.88" % (mi, old_rough))
        print("  material[%d]: emissive %s" % (mi,
              "REMOVED (was the albedo map at full strength)" if had_emissive else "already off"))
        print("  material[%d]: doubleSided -> false, KHR_materials_* extensions removed" % mi)
    js.pop("extensionsUsed", None)
    js.pop("extensionsRequired", None)

    # ------------------------------------------------------------------ prune orphan textures
    # A texture only an extension referenced (KHR_materials_specular's map, 2.3 MB on the
    # Parasite) is now unreferenced; drop it and its image so the compact step below can free
    # the bytes. Indices are remapped in place.
    used_tex = set()
    for mat in js["materials"]:
        pbr = mat.get("pbrMetallicRoughness", {})
        for slot in (pbr.get("baseColorTexture"), pbr.get("metallicRoughnessTexture"),
                     mat.get("normalTexture"), mat.get("occlusionTexture"),
                     mat.get("emissiveTexture")):
            if slot:
                used_tex.add(slot["index"])
    if js.get("textures"):
        tex_remap = {}
        new_tex = []
        for ti, tex in enumerate(js["textures"]):
            if ti in used_tex:
                tex_remap[ti] = len(new_tex)
                new_tex.append(tex)
        used_img = {t["source"] for t in new_tex if "source" in t}
        img_remap = {}
        new_img = []
        for ii, im in enumerate(js.get("images", [])):
            if ii in used_img:
                img_remap[ii] = len(new_img)
                new_img.append(im)
        for t in new_tex:
            if "source" in t:
                t["source"] = img_remap[t["source"]]
        for mat in js["materials"]:
            pbr = mat.get("pbrMetallicRoughness", {})
            for slot in (pbr.get("baseColorTexture"), pbr.get("metallicRoughnessTexture"),
                         mat.get("normalTexture"), mat.get("occlusionTexture")):
                if slot:
                    slot["index"] = tex_remap[slot["index"]]
        dropped = len(js["textures"]) - len(new_tex)
        js["textures"] = new_tex
        js["images"] = new_img
        print("  prune: dropped %d unreferenced texture(s), %d image(s) kept" % (dropped, len(new_img)))

    # ------------------------------------------------------------------ optional texture shrink
    if shrink and not shutil.which("sips"):
        print("  shrink: SKIPPED — sips not found (macOS only)")
    elif shrink:
        for img in js.get("images", []):
            bv = js["bufferViews"][img["bufferView"]]
            o = bv.get("byteOffset", 0)
            png = bytes(bn[o:o + bv["byteLength"]])
            ext = ".jpg" if img.get("mimeType") == "image/jpeg" else ".png"
            with tempfile.TemporaryDirectory() as td:
                src = Path(td) / ("t" + ext)
                src.write_bytes(png)
                subprocess.run(["sips", "-Z", "1024", str(src)], check=True,
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                small = src.read_bytes()
            # ⚠️ Image bufferViews sit inside the region the guard hashes. Each is rewritten by
            # APPENDING and re-pointing rather than by editing in place, because every later
            # bufferView's byteOffset is absolute and shifting one would move them all.
            while len(bn) % 4:
                bn.append(0)
            js["bufferViews"].append(
                {"buffer": 0, "byteOffset": len(bn), "byteLength": len(small)})
            bn += small
            img["bufferView"] = len(js["bufferViews"]) - 1
            js["buffers"] = [{"byteLength": len(bn)}]
            print("  shrink: image '%s' -> 1024  (%.2f MB -> %.2f MB)"
                  % (img.get("name", "?"), len(png) / 1e6, len(small) / 1e6))

    # ------------------------------------------------------------------ compact the buffer
    #
    # ⚠️ WITHOUT THIS THE FILE IS BIGGER THAN THE INPUT. Both the merge and the shrink work by
    # APPENDING to the binary chunk and re-pointing the index — deliberately, because every
    # bufferView's byteOffset is absolute, so editing one in place would shift every later one.
    # The cost is that superseded bytes stay in the buffer: the first --shrink run produced a
    # 17.75 MB file that still carried the whole 7.94 MB 2048 texture it had just replaced.
    # Rebuilding the buffer from only the bufferViews something still references is what makes
    # the shrink actually shrink.
    before_bytes = len(bn)
    before_views = len(js["bufferViews"])
    used = set()
    for a in js["accessors"]:
        if "bufferView" in a:
            used.add(a["bufferView"])
    for im in js.get("images", []):
        if "bufferView" in im:
            used.add(im["bufferView"])
    for sk in js.get("skins", []):
        if "inverseBindMatrices" in sk:
            used.add(js["accessors"][sk["inverseBindMatrices"]]["bufferView"])
    new_bn = bytearray()
    remap = {}
    new_views = []
    for old_idx in sorted(used):
        bv = js["bufferViews"][old_idx]
        while len(new_bn) % 4:
            new_bn.append(0)
        chunk = bytes(bn[bv.get("byteOffset", 0): bv.get("byteOffset", 0) + bv["byteLength"]])
        nv = {"buffer": 0, "byteOffset": len(new_bn), "byteLength": len(chunk)}
        if "byteStride" in bv:
            nv["byteStride"] = bv["byteStride"]
        if "target" in bv:
            nv["target"] = bv["target"]
        new_bn += chunk
        remap[old_idx] = len(new_views)
        new_views.append(nv)
    for a in js["accessors"]:
        if "bufferView" in a:
            a["bufferView"] = remap[a["bufferView"]]
    for im in js.get("images", []):
        if "bufferView" in im:
            im["bufferView"] = remap[im["bufferView"]]
    js["bufferViews"] = new_views
    bn = new_bn
    print("  compact: dropped %d orphaned bufferViews, %.2f MB -> %.2f MB"
          % (before_views - len(new_views), before_bytes / 1e6, len(bn) / 1e6))

    js["buffers"] = [{"byteLength": len(bn)}]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    write_glb(OUT, js, bytes(bn))

    prim = js["meshes"][0]["primitives"][0]
    verts = js["accessors"][prim["attributes"]["POSITION"]]["count"]
    tris = js["accessors"][prim["indices"]]["count"] // 3
    height = js["accessors"][prim["attributes"]["POSITION"]]["max"][1]
    print("\n  wrote %s" % OUT)
    print("  %.2f MB  |  %d clips  |  %d verts / %d tris  |  bind height %.4f m"
          % (OUT.stat().st_size / 1e6, len(js["animations"]), verts, tris, height))
    print("  sources total %.1f MB -> saved %.1f MB"
          % (sum(f.stat().st_size for f in files) / 1e6,
             (sum(f.stat().st_size for f in files) - OUT.stat().st_size) / 1e6))
    if PROFILE["target_h"]:
        print("\n  root_scale for a %.2f m figure = %.4f   (put it in the .import)"
              % (PROFILE["target_h"], PROFILE["target_h"] / height))
    else:
        print("\n  ships at natural size: %.3f m tall (root_scale 1.0)" % height)
    print("  NOW RUN:  Godot --headless --path game --import")
    return 0


if __name__ == "__main__":
    sys.exit(main())
