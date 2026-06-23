import json
import math
import os
from pathlib import Path

import bpy
from mathutils import Euler, Quaternion, Vector


SOURCE_BLEND = Path(os.environ.get("BUD_SOURCE_BLEND", r"H:\Downaloads\basic-bud\source\Bud.blend"))
OUTPUT_GLB = Path(os.environ.get("BUD_OUTPUT_GLB", r"H:\Downaloads\godot-3d-multiplayer-template\assets\characters\bud\bud_character.glb"))
OUTPUT_BLEND = Path(os.environ.get("BUD_OUTPUT_BLEND", r"H:\Downaloads\basic-bud\source\bud_character_processed.blend"))
THICKNESS_SCALE = float(os.environ.get("BUD_THICKNESS_SCALE", "0.76"))


def ensure_loaded() -> None:
    if not bpy.data.filepath or Path(bpy.data.filepath).resolve() != SOURCE_BLEND.resolve():
        bpy.ops.wm.open_mainfile(filepath=str(SOURCE_BLEND))


def world_bounds(objects):
    points = []
    for obj in objects:
        if obj.type != "MESH":
            continue
        for corner in obj.bound_box:
            points.append(obj.matrix_world @ Vector(corner))
    if not points:
        return Vector((0, 0, 0)), Vector((0, 0, 0))
    min_v = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    max_v = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    return min_v, max_v


def find_main_armature():
    armatures = [obj for obj in bpy.data.objects if obj.type == "ARMATURE"]
    if not armatures:
        return None
    return max(armatures, key=lambda obj: len(obj.data.bones))


def find_meshes():
    meshes = [obj for obj in bpy.data.objects if obj.type == "MESH"]
    return [obj for obj in meshes if obj.data and len(obj.data.vertices) > 0]


def local_axis_dimensions(obj):
    coords = [v.co.copy() for v in obj.data.vertices]
    mins = Vector((min(v.x for v in coords), min(v.y for v in coords), min(v.z for v in coords)))
    maxs = Vector((max(v.x for v in coords), max(v.y for v in coords), max(v.z for v in coords)))
    return maxs - mins, (mins + maxs) * 0.5


def thin_meshes(meshes):
    changed = []
    for obj in meshes:
        dims, center = local_axis_dimensions(obj)
        if max(dims) <= 0.0001:
            continue
        height_axis = max(range(3), key=lambda i: dims[i])
        horizontal_axes = [i for i in range(3) if i != height_axis]
        depth_axis = min(horizontal_axes, key=lambda i: dims[i])
        if dims[depth_axis] <= 0.0001:
            continue
        for vert in obj.data.vertices:
            co = vert.co
            co[depth_axis] = center[depth_axis] + (co[depth_axis] - center[depth_axis]) * THICKNESS_SCALE
        obj.data.update()
        changed.append({"object": obj.name, "height_axis": height_axis, "depth_axis": depth_axis, "scale": THICKNESS_SCALE})
    return changed


def bone_name_map(armature):
    names = [bone.name for bone in armature.data.bones]
    lower = {name.lower(): name for name in names}

    def pick(candidates):
        for key in candidates:
            if key in lower:
                return lower[key]
        for name in names:
            n = name.lower()
            if any(key in n for key in candidates):
                return name
        return None

    def pick_side(side, candidates):
        side_keys = [".l", "_l", "left", " l", "-l"] if side == "L" else [".r", "_r", "right", " r", "-r"]
        for name in names:
            n = name.lower()
            if any(k in n for k in side_keys) and any(c in n for c in candidates):
                return name
        return None

    mapping = {
        "root": pick(["root", "hips", "pelvis", "spine"]),
        "spine": pick(["spine", "chest", "body", "torso"]),
        "head": pick(["head", "neck"]),
        "upper_arm_L": pick_side("L", ["upper_arm", "upperarm", "arm", "shoulder"]),
        "lower_arm_L": pick_side("L", ["forearm", "lower_arm", "lowerarm"]),
        "hand_L": pick_side("L", ["hand", "wrist"]),
        "upper_arm_R": pick_side("R", ["upper_arm", "upperarm", "arm", "shoulder"]),
        "lower_arm_R": pick_side("R", ["forearm", "lower_arm", "lowerarm"]),
        "hand_R": pick_side("R", ["hand", "wrist"]),
        "upper_leg_L": pick_side("L", ["thigh", "upper_leg", "upperleg", "hip", "leg"]),
        "lower_leg_L": pick_side("L", ["shin", "calf", "lower_leg", "lowerleg", "knee"]),
        "foot_L": pick_side("L", ["foot", "ankle"]),
        "upper_leg_R": pick_side("R", ["thigh", "upper_leg", "upperleg", "hip", "leg"]),
        "lower_leg_R": pick_side("R", ["shin", "calf", "lower_leg", "lowerleg", "knee"]),
        "foot_R": pick_side("R", ["foot", "ankle"]),
    }
    if not any(mapping.values()):
        mapping.update(spatial_bone_name_map(armature))
    else:
        fallback = spatial_bone_name_map(armature)
        for key, value in fallback.items():
            if not mapping.get(key):
                mapping[key] = value
    return mapping


def spatial_bone_name_map(armature):
    bones = list(armature.data.bones)
    children = {bone.name: [] for bone in bones}
    for bone in bones:
        if bone.parent:
            children[bone.parent.name].append(bone)

    def chain_from(bone):
        chain = [bone]
        current = bone
        while children.get(current.name):
            current = max(children[current.name], key=lambda b: b.tail_local.z)
            chain.append(current)
        return chain

    vertical_roots = [b for b in bones if b.parent is None and b.tail_local.z >= b.head_local.z]
    spine_chain = chain_from(max(vertical_roots, key=lambda b: b.tail_local.z)) if vertical_roots else []
    torso_branch = spine_chain[2] if len(spine_chain) > 2 else (spine_chain[-1] if spine_chain else None)
    arm_candidates = children.get(torso_branch.name, []) if torso_branch else []
    arm_candidates = [b for b in arm_candidates if abs(b.tail_local.x - b.head_local.x) > abs(b.tail_local.z - b.head_local.z)]
    left_arm_root = min(arm_candidates, key=lambda b: b.tail_local.x, default=None)
    right_arm_root = max(arm_candidates, key=lambda b: b.tail_local.x, default=None)
    left_arm = chain_from(left_arm_root) if left_arm_root else []
    right_arm = chain_from(right_arm_root) if right_arm_root else []

    leg_roots = [b for b in bones if b.parent is None and b.tail_local.z < b.head_local.z]
    left_leg_root = min(leg_roots, key=lambda b: b.tail_local.x, default=None)
    right_leg_root = max(leg_roots, key=lambda b: b.tail_local.x, default=None)
    left_leg = chain_from(left_leg_root) if left_leg_root else []
    right_leg = chain_from(right_leg_root) if right_leg_root else []

    return {
        "root": spine_chain[0].name if len(spine_chain) > 0 else None,
        "spine": spine_chain[2].name if len(spine_chain) > 2 else (spine_chain[0].name if spine_chain else None),
        "head": spine_chain[-1].name if len(spine_chain) > 0 else None,
        "upper_arm_L": left_arm[0].name if len(left_arm) > 0 else None,
        "lower_arm_L": left_arm[1].name if len(left_arm) > 1 else None,
        "hand_L": left_arm[2].name if len(left_arm) > 2 else None,
        "upper_arm_R": right_arm[0].name if len(right_arm) > 0 else None,
        "lower_arm_R": right_arm[1].name if len(right_arm) > 1 else None,
        "hand_R": right_arm[2].name if len(right_arm) > 2 else None,
        "upper_leg_L": left_leg[0].name if len(left_leg) > 0 else None,
        "lower_leg_L": left_leg[1].name if len(left_leg) > 1 else None,
        "foot_L": left_leg[2].name if len(left_leg) > 2 else None,
        "upper_leg_R": right_leg[0].name if len(right_leg) > 0 else None,
        "lower_leg_R": right_leg[1].name if len(right_leg) > 1 else None,
        "foot_R": right_leg[2].name if len(right_leg) > 2 else None,
    }


def clear_pose(armature):
    bpy.context.view_layer.objects.active = armature
    armature.select_set(True)
    bpy.ops.object.mode_set(mode="POSE")
    for pb in armature.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.location = (0, 0, 0)
        pb.rotation_euler = (0, 0, 0)
        pb.scale = (1, 1, 1)
    bpy.ops.object.mode_set(mode="OBJECT")


def set_pose(armature, mapping, pose):
    for key, rot in pose.items():
        name = mapping.get(key)
        if not name or name not in armature.pose.bones:
            continue
        pb = armature.pose.bones[name]
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = Euler(rot, "XYZ")


def insert_pose_keys(armature, mapping, frame, pose):
    set_pose(armature, mapping, pose)
    for name in set(mapping.values()):
        if name and name in armature.pose.bones:
            pb = armature.pose.bones[name]
            pb.keyframe_insert("rotation_euler", frame=frame)


def make_action(armature, mapping, name, length, keys, loop=True):
    bpy.context.view_layer.objects.active = armature
    armature.select_set(True)
    bpy.ops.object.mode_set(mode="POSE")
    clear_pose(armature)
    action = bpy.data.actions.new(name)
    armature.animation_data_create()
    armature.animation_data.action = action
    for frame, pose in keys:
        insert_pose_keys(armature, mapping, frame, pose)
    for fc in get_action_fcurves(action):
        for kp in fc.keyframe_points:
            kp.interpolation = "SINE"
        if loop:
            fc.modifiers.new(type="CYCLES")
    action.frame_start = 1
    action.frame_end = length
    bpy.ops.object.mode_set(mode="OBJECT")
    return action


def get_action_fcurves(action):
    if hasattr(action, "fcurves"):
        return list(action.fcurves)
    curves = []
    for layer in getattr(action, "layers", []):
        for strip in getattr(layer, "strips", []):
            channelbag = getattr(strip, "channelbag", None)
            if not channelbag:
                continue
            curves.extend(list(getattr(channelbag, "fcurves", [])))
    return curves


def pose_idle(s=1.0):
    return {
        "spine": (0.035 * s, 0, 0.04 * s),
        "head": (-0.025 * s, 0, -0.035 * s),
        "upper_arm_L": (0.12, 0.08, 0.12 + 0.04 * s),
        "lower_arm_L": (0.16, 0, 0.04),
        "upper_arm_R": (0.12, -0.08, -0.12 + 0.04 * s),
        "lower_arm_R": (0.16, 0, -0.04),
    }


def pose_locomotion(phase, intensity):
    stride = math.sin(phase)
    counter = -stride
    lift = abs(math.cos(phase))
    return {
        "spine": (-0.05 * intensity + 0.04 * lift, 0, 0.08 * stride * intensity),
        "head": (0.04 * lift * intensity, 0, -0.05 * stride * intensity),
        "upper_arm_L": (0.62 * counter * intensity, 0.10, 0.18),
        "lower_arm_L": (0.18 + 0.22 * max(counter, 0) * intensity, 0, 0.06),
        "hand_L": (0.08 * counter * intensity, 0, 0),
        "upper_arm_R": (0.62 * stride * intensity, -0.10, -0.18),
        "lower_arm_R": (0.18 + 0.22 * max(stride, 0) * intensity, 0, -0.06),
        "hand_R": (0.08 * stride * intensity, 0, 0),
        "upper_leg_L": (0.62 * stride * intensity, 0, 0.05),
        "lower_leg_L": (-0.38 * max(stride, 0) * intensity, 0, 0),
        "foot_L": (0.18 * max(counter, 0) * intensity, 0, 0),
        "upper_leg_R": (0.62 * counter * intensity, 0, -0.05),
        "lower_leg_R": (-0.38 * max(counter, 0) * intensity, 0, 0),
        "foot_R": (0.18 * max(stride, 0) * intensity, 0, 0),
    }


def pose_jump():
    return {
        "spine": (-0.18, 0, 0),
        "head": (0.12, 0, 0),
        "upper_arm_L": (-0.88, 0.18, 0.28),
        "lower_arm_L": (0.24, 0, 0.08),
        "upper_arm_R": (-0.88, -0.18, -0.28),
        "lower_arm_R": (0.24, 0, -0.08),
        "upper_leg_L": (0.34, 0, 0.05),
        "lower_leg_L": (-0.24, 0, 0),
        "upper_leg_R": (0.34, 0, -0.05),
        "lower_leg_R": (-0.24, 0, 0),
    }


def pose_crouch(s=1.0):
    return {
        "spine": (0.24, 0, 0.04 * s),
        "head": (-0.18, 0, -0.03 * s),
        "upper_arm_L": (0.36, 0.12, 0.18),
        "lower_arm_L": (0.38, 0, 0.08),
        "upper_arm_R": (0.36, -0.12, -0.18),
        "lower_arm_R": (0.38, 0, -0.08),
        "upper_leg_L": (0.72, 0, 0.10),
        "lower_leg_L": (-0.78, 0, 0),
        "foot_L": (0.24, 0, 0),
        "upper_leg_R": (0.72, 0, -0.10),
        "lower_leg_R": (-0.78, 0, 0),
        "foot_R": (0.24, 0, 0),
    }


def pose_prone(s=1.0):
    pose = pose_crouch(s)
    pose.update({
        "spine": (0.48, 0, 0.03 * s),
        "head": (-0.32, 0, -0.03 * s),
        "upper_arm_L": (0.72, 0.20, 0.24),
        "lower_arm_L": (0.58, 0, 0.08),
        "upper_arm_R": (0.72, -0.20, -0.24),
        "lower_arm_R": (0.58, 0, -0.08),
        "upper_leg_L": (0.95, 0, 0.10),
        "upper_leg_R": (0.95, 0, -0.10),
    })
    return pose


def make_animations(armature):
    mapping = bone_name_map(armature)
    clear_pose(armature)
    make_action(armature, mapping, "idle", 48, [(1, pose_idle(1)), (24, pose_idle(-1)), (48, pose_idle(1))], True)
    make_action(armature, mapping, "walk", 28, [(1 + i * 7, pose_locomotion(math.tau * i / 4, 0.72)) for i in range(5)], True)
    make_action(armature, mapping, "run", 20, [(1 + i * 5, pose_locomotion(math.tau * i / 4, 1.0)) for i in range(5)], True)
    make_action(armature, mapping, "jump", 22, [(1, pose_crouch(0.4)), (8, pose_jump()), (22, pose_idle(0))], False)
    make_action(armature, mapping, "fall", 28, [(1, pose_jump()), (14, pose_idle(0.5)), (28, pose_jump())], True)
    make_action(armature, mapping, "crouch", 36, [(1, pose_crouch(1)), (18, pose_crouch(-1)), (36, pose_crouch(1))], True)
    make_action(armature, mapping, "prone", 36, [(1, pose_prone(1)), (18, pose_prone(-1)), (36, pose_prone(1))], True)
    make_action(
        armature,
        mapping,
        "prone_crawl",
        32,
        [(1 + i * 8, {**pose_prone(0), **pose_locomotion(math.tau * i / 4, 0.36)}) for i in range(5)],
        True,
    )
    clear_pose(armature)
    return mapping


def export_glb():
    OUTPUT_GLB.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_BLEND.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT_BLEND))
    bpy.ops.export_scene.gltf(
        filepath=str(OUTPUT_GLB),
        export_format="GLB",
        export_yup=True,
        export_apply=False,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_extra_animations=True,
        export_action_filter=False,
        export_nla_strips=False,
        export_skins=True,
        export_morph=False,
    )


def main():
    ensure_loaded()
    meshes = find_meshes()
    armature = find_main_armature()
    if not meshes:
        raise RuntimeError("No mesh objects found in Bud.blend")
    if not armature:
        raise RuntimeError("No armature found in Bud.blend")
    before_min, before_max = world_bounds(meshes)
    changed = thin_meshes(meshes)
    mapping = make_animations(armature)
    after_min, after_max = world_bounds(meshes)
    export_glb()
    summary = {
        "source": str(SOURCE_BLEND),
        "output_glb": str(OUTPUT_GLB),
        "output_blend": str(OUTPUT_BLEND),
        "mesh_count": len(meshes),
        "armature": armature.name,
        "bone_count": len(armature.data.bones),
        "bone_mapping": mapping,
        "thin_changes": changed,
        "before_size": list(before_max - before_min),
        "after_size": list(after_max - after_min),
        "actions": [a.name for a in bpy.data.actions],
    }
    print("__BUD_PREPARE_JSON_START__")
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    print("__BUD_PREPARE_JSON_END__")


if __name__ == "__main__":
    main()
