import json
from pathlib import Path

import bpy
from mathutils import Vector


PROJECT_DIR = Path(r"H:\Downaloads\godot-3d-multiplayer-template")
SOURCE_GLB = PROJECT_DIR / "assets" / "characters" / "gingerbread" / "gingerbread_meshy_runtime.glb"
OUT_GLB = PROJECT_DIR / "assets" / "characters" / "gingerbread" / "gingerbread_meshy_rigged_animated.glb"
WORK_DIR = PROJECT_DIR / "asset_working" / "gingerbread" / "meshy_rigged"
OUT_BLEND = WORK_DIR / "gingerbread_meshy_rigged_animated.blend"

DEFORM_BONES = ["Hips", "Spine", "Chest", "Neck", "Head", "L_Arm", "R_Arm", "L_Leg", "R_Leg"]
LIMB_GROUP_ALIASES = {
    "L_Arm": ["L_UpperArm", "L_ForeArm", "L_Hand", "L_Arm"],
    "R_Arm": ["R_UpperArm", "R_ForeArm", "R_Hand", "R_Arm"],
    "L_Leg": ["L_Thigh", "L_Shin", "L_Foot", "L_Leg"],
    "R_Leg": ["R_Thigh", "R_Shin", "R_Foot", "R_Leg"],
}
ARM_SEGMENTS = {
    "L_Arm": (Vector((-0.24, 0.0, 0.26)), Vector((-0.84, 0.0, -0.25))),
    "R_Arm": (Vector((0.24, 0.0, 0.26)), Vector((0.84, 0.0, -0.25))),
}
LEG_SEGMENTS = {
    "L_Leg": (Vector((-0.15, 0.0, -0.45)), Vector((-0.42, 0.0, -0.94))),
    "R_Leg": (Vector((0.15, 0.0, -0.45)), Vector((0.42, 0.0, -0.94))),
}


def ensure_dirs() -> None:
    WORK_DIR.mkdir(parents=True, exist_ok=True)
    gdignore = WORK_DIR.parent / ".gdignore"
    if not gdignore.exists():
        gdignore.write_text("\n", encoding="utf-8")


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action, do_unlink=True)
    for datablocks in [bpy.data.meshes, bpy.data.armatures, bpy.data.materials, bpy.data.images]:
        for item in list(datablocks):
            if getattr(item, "users", 0) == 0:
                datablocks.remove(item, do_unlink=True)


def import_mesh():
    bpy.ops.import_scene.gltf(filepath=str(SOURCE_GLB))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError("No mesh object found in Meshy gingerbread GLB.")
    meshes.sort(key=lambda obj: len(obj.data.polygons), reverse=True)
    mesh_obj = meshes[0]
    for obj in list(meshes[1:]):
        bpy.data.objects.remove(obj, do_unlink=True)
    mesh_obj.name = "Gingerbread_Meshy_6K_PaintMesh"
    mesh_obj.data.name = "Gingerbread_Meshy_6K_PaintMesh_Data"
    for poly in mesh_obj.data.polygons:
        poly.use_smooth = True
    return mesh_obj


def create_bone(edit_bones, name, head, tail, parent=None, deform=True):
    bone = edit_bones.new(name)
    bone.head = Vector(head)
    bone.tail = Vector(tail)
    bone.roll = 0.0
    bone.use_deform = deform
    if parent:
        bone.parent = edit_bones[parent]
        bone.use_connect = False
    return bone


def create_armature():
    arm_data = bpy.data.armatures.new("Gingerbread_Meshy_Rig_Data")
    arm_obj = bpy.data.objects.new("Gingerbread_Meshy_Rig", arm_data)
    bpy.context.collection.objects.link(arm_obj)
    bpy.context.view_layer.objects.active = arm_obj
    arm_obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    edit_bones = arm_data.edit_bones

    create_bone(edit_bones, "Root", (0.0, 0.0, -0.96), (0.0, 0.0, -0.56), deform=False)
    create_bone(edit_bones, "Hips", (0.0, 0.0, -0.62), (0.0, 0.0, -0.23), parent="Root")
    create_bone(edit_bones, "Spine", (0.0, 0.0, -0.28), (0.0, 0.0, 0.18), parent="Hips")
    create_bone(edit_bones, "Chest", (0.0, 0.0, 0.08), (0.0, 0.0, 0.46), parent="Spine")
    create_bone(edit_bones, "Neck", (0.0, 0.0, 0.41), (0.0, 0.0, 0.56), parent="Chest")
    create_bone(edit_bones, "Head", (0.0, 0.0, 0.53), (0.0, 0.0, 0.91), parent="Neck")
    create_bone(edit_bones, "L_Arm", (-0.24, 0.0, 0.26), (-0.84, 0.0, -0.25), parent="Chest")
    create_bone(edit_bones, "R_Arm", (0.24, 0.0, 0.26), (0.84, 0.0, -0.25), parent="Chest")
    create_bone(edit_bones, "L_Leg", (-0.15, 0.0, -0.45), (-0.42, 0.0, -0.94), parent="Hips")
    create_bone(edit_bones, "R_Leg", (0.15, 0.0, -0.45), (0.42, 0.0, -0.94), parent="Hips")

    bpy.ops.object.mode_set(mode="OBJECT")
    arm_data.display_type = "STICK"
    arm_obj.show_in_front = True
    return arm_obj


def smoothstep(edge0: float, edge1: float, value: float) -> float:
    if abs(edge1 - edge0) < 0.000001:
        return 0.0 if value < edge0 else 1.0
    t = max(0.0, min(1.0, (value - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)


def normalize_scores(scores: dict, limit: int = 3) -> dict:
    ranked = sorted(
        ((name, max(value, 0.0)) for name, value in scores.items() if value > 0.0001),
        key=lambda item: item[1],
        reverse=True,
    )[:limit]
    total = sum(value for _, value in ranked)
    if total <= 0.000001:
        return {"Spine": 1.0}
    return {name: value / total for name, value in ranked}


def segment_position(point: Vector, start: Vector, end: Vector) -> tuple[float, float]:
    segment = end - start
    length_sq = segment.length_squared
    if length_sq <= 0.0000001:
        return 0.0, (point - start).length
    t = max(0.0, min(1.0, (point - start).dot(segment) / length_sq))
    closest = start + segment * t
    return t, (point - closest).length


def collect_old_limb_membership(mesh_obj) -> dict:
    group_indices = {vertex_group.name: vertex_group.index for vertex_group in mesh_obj.vertex_groups}
    membership = {name: set() for name in LIMB_GROUP_ALIASES.keys()}
    for vertex in mesh_obj.data.vertices:
        for limb_name, aliases in LIMB_GROUP_ALIASES.items():
            for alias in aliases:
                group_index = group_indices.get(alias)
                if group_index is None:
                    continue
                if any(group.group == group_index and group.weight > 0.001 for group in vertex.groups):
                    membership[limb_name].add(vertex.index)
                    break
    return membership


def body_scores(point: Vector) -> dict:
    z = point.z
    if z >= 0.58:
        neck = 0.08 * (1.0 - smoothstep(0.58, 0.74, z))
        return normalize_scores({"Head": 1.0 - neck, "Neck": neck})
    if z >= 0.42:
        t = smoothstep(0.42, 0.58, z)
        return normalize_scores({"Chest": 0.46 * (1.0 - t), "Neck": 0.30, "Head": 0.72 * t})
    if z >= 0.16:
        t = smoothstep(0.16, 0.42, z)
        return normalize_scores({"Spine": 0.18 * (1.0 - t), "Chest": 0.82, "Neck": 0.20 * t})
    if z >= -0.22:
        t = smoothstep(-0.22, 0.16, z)
        return normalize_scores({"Hips": 0.34 * (1.0 - t), "Spine": 0.66, "Chest": 0.44 * t})
    if z >= -0.50:
        t = smoothstep(-0.50, -0.22, z)
        return normalize_scores({"Hips": 0.82 * (1.0 - t) + 0.30 * t, "Spine": 0.18 + 0.52 * t})
    return normalize_scores({"Hips": 1.0})


def geometric_limb(point: Vector) -> str:
    side = "L" if point.x < 0.0 else "R"
    arm_name = f"{side}_Arm"
    leg_name = f"{side}_Leg"
    arm_s, arm_distance = segment_position(point, *ARM_SEGMENTS[arm_name])
    _leg_s, leg_distance = segment_position(point, *LEG_SEGMENTS[leg_name])
    abs_x = abs(point.x)
    arm_candidate = (
        abs_x > 0.31
        and -0.44 < point.z < 0.42
        and arm_distance < 0.28
        and (point.z > -0.36 or arm_distance < leg_distance * 0.72 or abs_x > 0.60)
    )
    leg_candidate = (
        point.z < -0.38
        and abs_x > 0.08
        and leg_distance < 0.30
        and (leg_distance < arm_distance * 0.95 or point.z < -0.58)
    )
    if arm_candidate and (not leg_candidate or arm_distance < leg_distance * 0.82 or point.z > -0.36):
        return arm_name
    if leg_candidate:
        return leg_name
    if arm_s > 0.88 and abs_x > 0.60 and -0.45 < point.z < 0.0:
        return arm_name
    return ""


def limb_scores(limb_name: str, point: Vector) -> dict:
    if limb_name.endswith("Arm"):
        s, _distance = segment_position(point, *ARM_SEGMENTS[limb_name])
        chest = 0.38 * (1.0 - smoothstep(0.02, 0.34, s))
        return normalize_scores({limb_name: 1.0 - chest, "Chest": chest})
    s, _distance = segment_position(point, *LEG_SEGMENTS[limb_name])
    hips = 0.46 * (1.0 - smoothstep(0.02, 0.36, s))
    return normalize_scores({limb_name: 1.0 - hips, "Hips": hips})


def add_vertex_weights(mesh_obj) -> dict:
    old_membership = collect_old_limb_membership(mesh_obj)
    use_old_membership = any(len(indices) > 0 for indices in old_membership.values())
    mesh_obj.vertex_groups.clear()
    groups = {name: mesh_obj.vertex_groups.new(name=name) for name in DEFORM_BONES}
    region_counts = {"Body": 0, "L_Arm": 0, "R_Arm": 0, "L_Leg": 0, "R_Leg": 0}
    max_influences = 0
    for vertex in mesh_obj.data.vertices:
        point = vertex.co
        limb_name = ""
        if use_old_membership:
            for candidate in ["L_Arm", "R_Arm", "L_Leg", "R_Leg"]:
                if vertex.index in old_membership[candidate]:
                    limb_name = candidate
                    break
        if not limb_name:
            limb_name = geometric_limb(point)
        scores = limb_scores(limb_name, point) if limb_name else body_scores(point)
        max_influences = max(max_influences, len(scores))
        region_counts[limb_name if limb_name else "Body"] += 1
        for name, weight in scores.items():
            groups[name].add([vertex.index], weight, "REPLACE")
    return {
        "old_limb_membership_used": use_old_membership,
        "old_limb_counts": {name: len(indices) for name, indices in old_membership.items()},
        "region_counts": region_counts,
        "max_influences": max_influences,
    }


def bind_mesh_to_armature(mesh_obj, arm_obj) -> None:
    mesh_obj.parent = arm_obj
    modifier = mesh_obj.modifiers.new("Gingerbread_Meshy_Armature", "ARMATURE")
    modifier.object = arm_obj
    modifier.use_vertex_groups = True


def reset_pose(arm_obj) -> None:
    for bone in arm_obj.pose.bones:
        bone.rotation_mode = "XYZ"
        bone.location = (0.0, 0.0, 0.0)
        bone.rotation_euler = (0.0, 0.0, 0.0)
        bone.scale = (1.0, 1.0, 1.0)


def pose_key(arm_obj, frame: int, rotations=None, locations=None) -> None:
    rotations = rotations or {}
    locations = locations or {}
    bpy.context.scene.frame_set(frame)
    reset_pose(arm_obj)
    for name, rotation in rotations.items():
        bone = arm_obj.pose.bones.get(name)
        if bone:
            bone.rotation_euler = rotation
    for name, location in locations.items():
        bone = arm_obj.pose.bones.get(name)
        if bone:
            bone.location = location
    for bone in arm_obj.pose.bones:
        bone.keyframe_insert("rotation_euler", frame=frame)
        bone.keyframe_insert("location", frame=frame)


def create_action(arm_obj, name: str, length: int, keys: list) -> None:
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    arm_obj.animation_data_create()
    arm_obj.animation_data.action = action
    for frame, rotations, locations in keys:
        pose_key(arm_obj, frame, rotations, locations)
    action.frame_start = 1
    action.frame_end = length


def create_animation_actions(arm_obj) -> None:
    # Small motion range is intentional. This character is primarily a paintable surface,
    # so the rig prioritizes continuity over exaggerated limb articulation.
    create_action(arm_obj, "idle", 60, [
        (1, {"Chest": (0.010, 0.0, 0.0), "Head": (-0.008, 0.0, 0.0)}, {}),
        (30, {"Chest": (-0.010, 0.0, 0.012), "Head": (0.008, 0.0, -0.010)}, {"Root": (0.0, 0.0, 0.010)}),
        (60, {"Chest": (0.010, 0.0, 0.0), "Head": (-0.008, 0.0, 0.0)}, {}),
    ])
    create_action(arm_obj, "walk", 32, [
        (1, {"L_Arm": (-0.055, 0.0, 0.018), "R_Arm": (0.055, 0.0, -0.018), "L_Leg": (0.035, 0.0, 0.0), "R_Leg": (-0.035, 0.0, 0.0), "Chest": (0.015, 0.0, 0.018)}, {}),
        (16, {"L_Arm": (0.055, 0.0, 0.014), "R_Arm": (-0.055, 0.0, -0.014), "L_Leg": (-0.035, 0.0, 0.0), "R_Leg": (0.035, 0.0, 0.0), "Chest": (-0.015, 0.0, -0.018)}, {"Root": (0.0, 0.0, 0.016)}),
        (32, {"L_Arm": (-0.055, 0.0, 0.018), "R_Arm": (0.055, 0.0, -0.018), "L_Leg": (0.035, 0.0, 0.0), "R_Leg": (-0.035, 0.0, 0.0), "Chest": (0.015, 0.0, 0.018)}, {}),
    ])
    create_action(arm_obj, "run", 24, [
        (1, {"L_Arm": (-0.075, 0.0, 0.024), "R_Arm": (0.075, 0.0, -0.024), "L_Leg": (0.050, 0.0, 0.0), "R_Leg": (-0.050, 0.0, 0.0), "Chest": (0.024, 0.0, 0.020)}, {}),
        (12, {"L_Arm": (0.075, 0.0, 0.020), "R_Arm": (-0.075, 0.0, -0.020), "L_Leg": (-0.050, 0.0, 0.0), "R_Leg": (0.050, 0.0, 0.0), "Chest": (-0.012, 0.0, -0.020)}, {"Root": (0.0, 0.0, 0.024)}),
        (24, {"L_Arm": (-0.075, 0.0, 0.024), "R_Arm": (0.075, 0.0, -0.024), "L_Leg": (0.050, 0.0, 0.0), "R_Leg": (-0.050, 0.0, 0.0), "Chest": (0.024, 0.0, 0.020)}, {}),
    ])
    create_action(arm_obj, "jump", 34, [
        (1, {"Spine": (0.035, 0.0, 0.0), "L_Arm": (0.040, 0.0, 0.020), "R_Arm": (0.040, 0.0, -0.020)}, {}),
        (14, {"Spine": (-0.030, 0.0, 0.0), "L_Arm": (-0.105, 0.0, 0.035), "R_Arm": (-0.105, 0.0, -0.035)}, {"Root": (0.0, 0.0, 0.085)}),
        (34, {"Spine": (0.005, 0.0, 0.0), "L_Arm": (-0.030, 0.0, 0.020), "R_Arm": (-0.030, 0.0, -0.020)}, {}),
    ])
    create_action(arm_obj, "fall", 42, [
        (1, {"Chest": (0.030, 0.0, 0.0), "L_Arm": (-0.095, 0.0, 0.040), "R_Arm": (-0.095, 0.0, -0.040)}, {}),
        (21, {"Chest": (0.010, 0.0, 0.025), "L_Arm": (-0.065, 0.0, 0.026), "R_Arm": (-0.065, 0.0, -0.026)}, {"Root": (0.0, 0.0, -0.015)}),
        (42, {"Chest": (0.030, 0.0, 0.0), "L_Arm": (-0.095, 0.0, 0.040), "R_Arm": (-0.095, 0.0, -0.040)}, {}),
    ])
    create_action(arm_obj, "land", 24, [
        (1, {"Spine": (0.010, 0.0, 0.0)}, {}),
        (10, {"Spine": (0.070, 0.0, 0.0), "L_Leg": (-0.050, 0.0, 0.0), "R_Leg": (-0.050, 0.0, 0.0)}, {"Root": (0.0, 0.0, -0.050)}),
        (24, {}, {}),
    ])
    create_action(arm_obj, "crouch", 32, [
        (1, {"Spine": (0.075, 0.0, 0.0), "Chest": (0.035, 0.0, 0.0), "L_Leg": (-0.060, 0.0, 0.0), "R_Leg": (-0.060, 0.0, 0.0)}, {"Root": (0.0, 0.0, -0.065)}),
        (32, {"Spine": (0.075, 0.0, 0.0), "Chest": (0.035, 0.0, 0.0), "L_Leg": (-0.060, 0.0, 0.0), "R_Leg": (-0.060, 0.0, 0.0)}, {"Root": (0.0, 0.0, -0.065)}),
    ])
    create_action(arm_obj, "prone", 48, [
        (1, {"Hips": (0.12, 0.0, 0.0), "Spine": (0.045, 0.0, 0.0), "Chest": (-0.020, 0.0, 0.0), "Head": (-0.035, 0.0, 0.0), "L_Arm": (0.085, 0.0, 0.050), "R_Arm": (0.085, 0.0, -0.050)}, {"Root": (0.0, -0.02, -0.12)}),
        (48, {"Hips": (0.12, 0.0, 0.0), "Spine": (0.045, 0.0, 0.0), "Chest": (-0.020, 0.0, 0.0), "Head": (-0.035, 0.0, 0.0), "L_Arm": (0.085, 0.0, 0.050), "R_Arm": (0.085, 0.0, -0.050)}, {"Root": (0.0, -0.02, -0.12)}),
    ])
    create_action(arm_obj, "prone_crawl", 40, [
        (1, {"Hips": (0.10, 0.0, 0.020), "L_Arm": (0.095, 0.0, 0.040), "R_Arm": (0.065, 0.0, -0.040), "Chest": (0.010, 0.0, 0.012)}, {"Root": (-0.015, -0.02, -0.11)}),
        (20, {"Hips": (0.10, 0.0, -0.020), "L_Arm": (0.065, 0.0, 0.040), "R_Arm": (0.095, 0.0, -0.040), "Chest": (-0.010, 0.0, -0.012)}, {"Root": (0.015, -0.02, -0.11)}),
        (40, {"Hips": (0.10, 0.0, 0.020), "L_Arm": (0.095, 0.0, 0.040), "R_Arm": (0.065, 0.0, -0.040), "Chest": (0.010, 0.0, 0.012)}, {"Root": (-0.015, -0.02, -0.11)}),
    ])
    arm_obj.animation_data.action = bpy.data.actions.get("idle")
    reset_pose(arm_obj)


def export_glb(mesh_obj, arm_obj) -> None:
    for obj in bpy.context.scene.objects:
        obj.select_set(False)
    mesh_obj.select_set(True)
    arm_obj.select_set(True)
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.export_scene.gltf(
        filepath=str(OUT_GLB),
        export_format="GLB",
        use_selection=True,
        export_apply=False,
        export_texcoords=True,
        export_normals=True,
        export_materials="EXPORT",
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_force_sampling=True,
        export_frame_range=False,
        export_nla_strips=True,
        export_anim_single_armature=True,
        export_skins=True,
        export_influence_nb=4,
        export_yup=True,
    )


def mesh_bounds(mesh_obj) -> dict:
    corners = [Vector(corner) for corner in mesh_obj.bound_box]
    return {
        "min": [round(min(corner[index] for corner in corners), 4) for index in range(3)],
        "max": [round(max(corner[index] for corner in corners), 4) for index in range(3)],
    }


def mesh_triangle_count(mesh_obj) -> int:
    return sum(len(poly.vertices) - 2 for poly in mesh_obj.data.polygons)


def main() -> None:
    ensure_dirs()
    reset_scene()
    mesh_obj = import_mesh()
    arm_obj = create_armature()
    weight_report = add_vertex_weights(mesh_obj)
    bind_mesh_to_armature(mesh_obj, arm_obj)
    create_animation_actions(arm_obj)
    export_glb(mesh_obj, arm_obj)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT_BLEND))
    print(
        "MESHY_RIG_RESULT="
        + json.dumps(
            {
                "source": str(SOURCE_GLB),
                "out_glb": str(OUT_GLB),
                "out_blend": str(OUT_BLEND),
                "mesh": mesh_obj.name,
                "verts": len(mesh_obj.data.vertices),
                "tris": mesh_triangle_count(mesh_obj),
                "bounds": mesh_bounds(mesh_obj),
                "bones": len(arm_obj.data.bones),
                "deform_bones": len([bone for bone in arm_obj.data.bones if bone.use_deform]),
                "actions": [action.name for action in bpy.data.actions],
                **weight_report,
            },
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    main()
