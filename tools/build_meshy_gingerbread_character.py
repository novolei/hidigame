import os
import shutil

import bpy
from mathutils import Vector


PROJECT_DIR = r"H:\Downaloads\godot-3d-multiplayer-template"
SOURCE_DIR = r"H:\Downaloads\Meshy_AI_Smiling_Gingerbread_biped\Meshy_AI_Smiling_Gingerbread_biped"
WORK_DIR = os.path.join(PROJECT_DIR, "asset_working", "gingerbread", "meshy_rebuild")
RUNTIME_DIR = os.path.join(PROJECT_DIR, "assets", "characters", "gingerbread")
OUT_BLEND = os.path.join(WORK_DIR, "meshy_gingerbread_combined.blend")
OUT_GLB = os.path.join(RUNTIME_DIR, "gingerbread_animated.glb")
FRONT_PREVIEW = os.path.join(WORK_DIR, "meshy_gingerbread_front_preview.png")
BACK_PREVIEW = os.path.join(WORK_DIR, "meshy_gingerbread_back_preview.png")

SOURCES = {
    "walk": os.path.join(SOURCE_DIR, "Meshy_AI_Smiling_Gingerbread_biped_Animation_Walking_withSkin.glb"),
    "run": os.path.join(SOURCE_DIR, "Meshy_AI_Smiling_Gingerbread_biped_Animation_Running_withSkin.glb"),
    "dance": os.path.join(SOURCE_DIR, "Meshy_AI_Smiling_Gingerbread_biped_Animation_Hip_Hop_Dance_4_withSkin.glb"),
}
REQUIRED_ACTIONS = ["idle", "walk", "run", "jump", "fall", "crouch", "prone"]


def reset_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for datablocks in [
        bpy.data.meshes,
        bpy.data.materials,
        bpy.data.images,
        bpy.data.armatures,
        bpy.data.actions,
        bpy.data.collections,
    ]:
        for datablock in list(datablocks):
            if getattr(datablock, "users", 0) == 0 or datablocks != bpy.data.collections:
                try:
                    datablocks.remove(datablock, do_unlink=True)
                except Exception:
                    pass


def ensure_dirs():
    os.makedirs(WORK_DIR, exist_ok=True)
    gdignore = os.path.join(os.path.dirname(WORK_DIR), ".gdignore")
    if not os.path.exists(gdignore):
        with open(gdignore, "w", encoding="utf-8") as handle:
            handle.write("\n")


def world_bounds(objects):
    pts = []
    for obj in objects:
        pts.extend(obj.matrix_world @ Vector(corner) for corner in obj.bound_box)
    return {
        "x": (min(p.x for p in pts), max(p.x for p in pts)),
        "y": (min(p.y for p in pts), max(p.y for p in pts)),
        "z": (min(p.z for p in pts), max(p.z for p in pts)),
    }


def import_source(path):
    before = set(bpy.data.objects)
    before_actions = set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=path)
    objects = [obj for obj in bpy.data.objects if obj not in before]
    actions = [action for action in bpy.data.actions if action not in before_actions]
    return objects, actions


def cleanup_non_character_meshes(objects):
    kept = []
    removed = []
    for obj in objects:
        if obj.type == "MESH" and obj.name != "char1":
            removed.append(obj.name)
            bpy.data.objects.remove(obj, do_unlink=True)
        else:
            kept.append(obj)
    return kept, removed


def get_base_objects():
    armature = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
    mesh = next(obj for obj in bpy.data.objects if obj.type == "MESH" and obj.name == "char1")
    return armature, mesh


def rename_action(action, name):
    action.name = name
    action.use_fake_user = True
    return action


def create_pose_action(armature, name, frame_values):
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    armature.animation_data_create()
    armature.animation_data.action = action
    for frame, rotations in frame_values:
        bpy.context.scene.frame_set(frame)
        for bone in armature.pose.bones:
            bone.rotation_mode = "XYZ"
            bone.rotation_euler = (0.0, 0.0, 0.0)
            bone.location = (0.0, 0.0, 0.0)
            bone.scale = (1.0, 1.0, 1.0)
        for bone_name, rotation in rotations.items():
            bone = armature.pose.bones.get(bone_name)
            if bone:
                bone.rotation_euler = rotation
        for bone in armature.pose.bones:
            bone.keyframe_insert("rotation_euler", frame=frame)
    return action


def copy_imported_action(path, action_name):
    objects, actions = import_source(path)
    source_action = actions[0] if actions else None
    copied = source_action.copy() if source_action else None
    for obj in objects:
        bpy.data.objects.remove(obj, do_unlink=True)
    for action in actions:
        if action.name in bpy.data.actions:
            try:
                bpy.data.actions.remove(action, do_unlink=True)
            except Exception:
                pass
    if copied:
        rename_action(copied, action_name)
    return copied


def normalize_character(root, visual_objects):
    bounds = world_bounds(visual_objects)
    height = bounds["z"][1] - bounds["z"][0]
    scale = 1.9 / height if height > 1e-6 else 1.0
    center_x = (bounds["x"][0] + bounds["x"][1]) * 0.5
    center_y = (bounds["y"][0] + bounds["y"][1]) * 0.5
    root.scale = (scale, scale, scale)
    root.location = (-center_x * scale, -center_y * scale, -bounds["z"][0] * scale)
    return scale


def render_previews(root, mesh):
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except Exception:
        scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 900
    scene.render.resolution_y = 900
    scene.render.film_transparent = True
    try:
        scene.view_settings.view_transform = "Standard"
        scene.view_settings.look = "None"
        scene.view_settings.exposure = -0.25
        scene.view_settings.gamma = 1.0
    except Exception:
        pass

    def look_at(obj, target):
        direction = Vector(target) - obj.location
        obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()

    camera_data = bpy.data.cameras.new("Meshy_Gingerbread_Preview_Camera_Data")
    camera = bpy.data.objects.new("Meshy_Gingerbread_Preview_Camera", camera_data)
    bpy.context.collection.objects.link(camera)
    camera.data.lens = 55
    scene.camera = camera

    for name, loc, energy, size in [
        ("Meshy_Gingerbread_Key", (-2.0, -3.0, 3.0), 120.0, 4.5),
        ("Meshy_Gingerbread_Fill", (2.2, -1.6, 2.2), 28.0, 5.0),
        ("Meshy_Gingerbread_Back", (0.0, 2.7, 2.4), 48.0, 4.0),
    ]:
        data = bpy.data.lights.new(name + "_Data", "AREA")
        light = bpy.data.objects.new(name, data)
        bpy.context.collection.objects.link(light)
        light.location = loc
        light.data.energy = energy
        light.data.size = size
        look_at(light, (0.0, 0.0, 0.95))

    for loc, path in [((0.0, -3.7, 0.95), FRONT_PREVIEW), ((0.0, 3.7, 0.95), BACK_PREVIEW)]:
        camera.location = loc
        look_at(camera, (0.0, 0.0, 0.95))
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)


def clean_runtime_dir():
    keep = {
        "gingerbread_skin.gd",
        "gingerbread_skin.gd.uid",
        "gingerbread_skin.tscn",
        "gingerbread_animated_skin.gd",
        "gingerbread_animated_skin.gd.uid",
        "gingerbread_animated_skin.tscn",
    }
    for entry in os.listdir(RUNTIME_DIR):
        path = os.path.join(RUNTIME_DIR, entry)
        if os.path.isfile(path) and entry not in keep:
            os.remove(path)


def clear_godot_import_cache():
    imported = os.path.join(PROJECT_DIR, ".godot", "imported")
    if not os.path.isdir(imported):
        return 0
    removed = 0
    for name in os.listdir(imported):
        if name.startswith("gingerbread_animated") or name.startswith("Meshy_AI_Smiling_Gingerbread"):
            os.remove(os.path.join(imported, name))
            removed += 1
    return removed


def main():
    ensure_dirs()
    reset_scene()

    # Connection map:
    #   Meshy walking source armature -> final game armature, direct reuse
    #   Meshy char1 mesh -> final skinned mesh, parented to same armature
    #   walking/running/dance source actions -> same-bone final action datablocks
    #   root empty -> scales and centers final character for Godot
    base_objects, base_actions = import_source(SOURCES["walk"])
    base_objects, removed = cleanup_non_character_meshes(base_objects)
    armature, mesh = get_base_objects()
    armature.name = "GB_Meshy_Gingerbread_Armature"
    mesh.name = "GB_Meshy_Gingerbread_Body"
    mesh.data.name = "GB_Meshy_Gingerbread_Body_Mesh"
    for poly in mesh.data.polygons:
        poly.use_smooth = True
    if not any(mod.type == "WEIGHTED_NORMAL" for mod in mesh.modifiers):
        mesh.modifiers.new("GB_Meshy_weighted_normals", "WEIGHTED_NORMAL")

    walk_action = base_actions[0] if base_actions else None
    if walk_action:
        rename_action(walk_action, "walk")
    copy_imported_action(SOURCES["run"], "run")
    copy_imported_action(SOURCES["dance"], "dance")

    root = bpy.data.objects.new("GB_Meshy_Gingerbread_Root", None)
    root.empty_display_type = "PLAIN_AXES"
    root.empty_display_size = 0.25
    bpy.context.collection.objects.link(root)
    armature.parent = root
    normalize_scale = normalize_character(root, [mesh])

    # Project-required aliases/placeholders. These are deliberately modest; Meshy only supplied walk/run/dance.
    create_pose_action(armature, "idle", [(1, {}), (45, {})])
    create_pose_action(
        armature,
        "jump",
        [
            (1, {"LeftArm": (-0.45, 0.0, 0.25), "RightArm": (-0.45, 0.0, -0.25)}),
            (16, {"LeftArm": (-0.95, 0.0, 0.35), "RightArm": (-0.95, 0.0, -0.35), "LeftUpLeg": (0.35, 0.0, 0.0), "RightUpLeg": (0.35, 0.0, 0.0)}),
            (32, {}),
        ],
    )
    create_pose_action(armature, "fall", [(1, {"Spine": (0.15, 0.0, 0.0)}), (30, {"Spine": (0.05, 0.0, 0.0)})])
    create_pose_action(
        armature,
        "crouch",
        [(1, {"Spine": (0.20, 0.0, 0.0), "LeftUpLeg": (-0.55, 0.0, 0.0), "RightUpLeg": (-0.55, 0.0, 0.0)}), (30, {"Spine": (0.20, 0.0, 0.0), "LeftUpLeg": (-0.55, 0.0, 0.0), "RightUpLeg": (-0.55, 0.0, 0.0)})],
    )
    create_pose_action(
        armature,
        "prone",
        [(1, {"Hips": (1.15, 0.0, 0.0), "Spine": (0.25, 0.0, 0.0), "Head": (-0.20, 0.0, 0.0)}), (30, {"Hips": (1.15, 0.0, 0.0), "Spine": (0.25, 0.0, 0.0), "Head": (-0.20, 0.0, 0.0)})],
    )

    armature.animation_data_create()
    armature.animation_data.action = bpy.data.actions.get("idle")
    render_previews(root, mesh)

    clean_runtime_dir()
    for obj in bpy.data.objects:
        obj.select_set(False)
    for obj in [root, armature, mesh]:
        obj.select_set(True)
        obj.hide_set(False)
        obj.hide_viewport = False
        obj.hide_render = False

    bpy.ops.export_scene.gltf(
        filepath=OUT_GLB,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_texcoords=True,
        export_normals=True,
        export_materials="EXPORT",
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_force_sampling=False,
        export_frame_range=False,
        export_nla_strips=True,
        export_anim_single_armature=True,
        export_skins=True,
        export_influence_nb=4,
        export_yup=True,
    )
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    removed_cache = clear_godot_import_cache()
    print(
        "MESHY_GINGERBREAD_BUILD_RESULT="
        + repr(
            {
                "out_glb": OUT_GLB,
                "out_blend": OUT_BLEND,
                "front_preview": FRONT_PREVIEW,
                "back_preview": BACK_PREVIEW,
                "actions": [action.name for action in bpy.data.actions],
                "removed_aux_meshes": removed,
                "normalize_scale": normalize_scale,
                "removed_godot_cache_files": removed_cache,
            }
        )
    )


main()
