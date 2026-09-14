#!/usr/bin/env python3
"""Export one Mixamo FBX (mesh + rig + its single animation) to a glTF Binary, headless.

WHY THIS EXISTS
---------------
The Parasite (THE NIGHTMARE's hunter, 2026-09-12) arrived as three Mixamo FBX downloads:
`character.fbx` (T-pose only, not consumed), `Mutant Walking.fbx` and `Injured Run.fbx` (each a
complete copy of the mesh, the 69-bone `mixamorig:*` rig, two 2048^2 textures, and ONE take named
`mixamo.com`). Godot 4.6 imports FBX natively, but this project ships one GLB per creature with
every clip merged into it (`tools/merge_creature_glb.py`), and that tool speaks glTF only. So each
FBX is exported to its own GLB here, and the merge tool combines them.

Run INSIDE Blender (5.1 tested; the FBX importer and glTF exporter are built in):

    /Applications/Blender.app/Contents/MacOS/Blender --factory-startup -b \
        --python tools/fbx_to_glb.py -- IN.fbx OUT.glb

Everything after `--` is ours. ⚠️ Blender 5.x removed `Action.fcurves`; nothing here touches
f-curves. Root motion, if the take carries any, is left in the file on purpose — the merge tool
detects it, strips it, and PRINTS the implied ground speed, which is the ground-truth anchor for
`CreatureAnim.MODELS[...].speeds` (the same way `charge` anchored the hollow_crown table).
"""
import os
import sys

import bpy


def main() -> None:
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if len(args) != 2:
        print("usage: blender -b --python tools/fbx_to_glb.py -- IN.fbx OUT.glb")
        sys.exit(2)
    src, out = os.path.abspath(args[0]), os.path.abspath(args[1])
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=src, use_anim=True, ignore_leaf_bones=False,
                             automatic_bone_orientation=False)
    arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    if not arms or not meshes:
        print("ERROR: no armature/mesh in", src)
        sys.exit(1)
    arm = arms[0]
    # One take per Mixamo file. Name it after the file stem so the merge tool's CLIPS map can
    # address it (it is renamed to "walk"/"run" there, never here).
    stem = os.path.splitext(os.path.basename(src))[0].replace(" ", "_").lower()
    if arm.animation_data and arm.animation_data.action:
        arm.animation_data.action.name = stem
    for act in bpy.data.actions:
        act.use_fake_user = True
    bpy.ops.export_scene.gltf(
        filepath=out, export_format="GLB",
        export_animations=True, export_animation_mode="ACTIONS",
        export_force_sampling=True, export_apply=True, export_yup=True,
        export_skins=True, export_materials="EXPORT", export_image_format="AUTO",
        export_texcoords=True, export_normals=True, export_def_bones=False,
    )
    print("EXPORTED %s -> %s (%d bytes) armature=%s bones=%d actions=%s" % (
        src, out, os.path.getsize(out), arm.name, len(arm.data.bones),
        [a.name for a in bpy.data.actions]))


main()
