import os

import bpy


PROJECT_DIR = r"H:\Downaloads\godot-3d-multiplayer-template"
WORK_DIR = os.path.join(PROJECT_DIR, "asset_working", "gingerbread", "animation_repair")
OUT_BLEND = os.path.join(WORK_DIR, "gingerbread_animation_repaired.blend")
OUT_GLB = os.path.join(PROJECT_DIR, "assets", "characters", "gingerbread", "gingerbread_animated.glb")

ACTION_NAMES = ["idle", "walk", "run", "jump", "fall", "crouch", "prone"]
ARM_ROTATION_SCALES = {
    "UpperArm": 0.38,
    "ForeArm": 0.24,
    "Hand": 0.0,
}
ARM_BONE_PREFIXES = ("UpperArm", "ForeArm", "Hand")
ARM_WEIGHT_GROUPS = [
    "UpperArm.L",
    "ForeArm.L",
    "Hand.L",
    "UpperArm.R",
    "ForeArm.R",
    "Hand.R",
]
ARM_WEIGHT_SOFTEN_VERSION = 3
ANIMATED_BONES = [
    "Root",
    "Spine",
    "Chest",
    "Head",
    "UpperArm.L",
    "ForeArm.L",
    "Hand.L",
    "UpperArm.R",
    "ForeArm.R",
    "Hand.R",
    "Thigh.L",
    "Shin.L",
    "Foot.L",
    "Thigh.R",
    "Shin.R",
    "Foot.R",
]


def ensure_dirs():
    os.makedirs(WORK_DIR, exist_ok=True)
    gdignore = os.path.join(os.path.dirname(WORK_DIR), ".gdignore")
    if not os.path.exists(gdignore):
        with open(gdignore, "w", encoding="utf-8") as handle:
            handle.write("\n")


def object_mode():
    try:
        if bpy.ops.object.mode_set.poll():
            bpy.ops.object.mode_set(mode="OBJECT")
    except Exception:
        pass


def get_armature():
    arm = bpy.data.objects.get("GB_Original_GameReady_Armature")
    if arm and arm.type == "ARMATURE":
        return arm
    armatures = [obj for obj in bpy.data.objects if obj.type == "ARMATURE"]
    if not armatures:
        raise RuntimeError("No armature found for gingerbread animation repair.")
    return armatures[0]


def get_body_meshes(armature):
    meshes = []
    for obj in bpy.data.objects:
        if obj.type != "MESH" or obj.hide_get() or obj.hide_viewport:
            continue
        if obj.name.startswith("CTRL_") or obj.name.startswith("J_"):
            continue
        if obj.parent == armature or obj.name.startswith("GB_Original_PBR_Mesh"):
            meshes.append(obj)
    if not meshes:
        meshes = [
            obj
            for obj in bpy.data.objects
            if obj.type == "MESH"
            and not obj.name.startswith("CTRL_")
            and not obj.name.startswith("J_")
            and not obj.hide_get()
        ]
    return meshes


def remove_old_actions():
    for action in list(bpy.data.actions):
        if action.name in ACTION_NAMES:
            bpy.data.actions.remove(action, do_unlink=True)


def set_rest_pose(armature):
    for bone in armature.pose.bones:
        bone.rotation_mode = "XYZ"
        bone.rotation_euler = (0.0, 0.0, 0.0)
        bone.location = (0.0, 0.0, 0.0)
        bone.scale = (1.0, 1.0, 1.0)


def apply_pose(armature, rotations, locations):
    set_rest_pose(armature)
    for bone_name, value in rotations.items():
        bone = armature.pose.bones.get(bone_name)
        if bone:
            scale = arm_rotation_scale_for_bone(bone_name)
            bone.rotation_euler = tuple(component * scale for component in value)
    for bone_name, value in locations.items():
        bone = armature.pose.bones.get(bone_name)
        if bone:
            bone.location = value


def arm_rotation_scale_for_bone(bone_name):
    for prefix, scale in ARM_ROTATION_SCALES.items():
        if bone_name.startswith(prefix):
            return scale
    return 1.0


def key_ik_influence(armature, frame, influence):
    for bone in armature.pose.bones:
        for constraint in bone.constraints:
            if constraint.type == "IK":
                constraint.influence = influence
                constraint.keyframe_insert("influence", frame=frame)


def key_bones(armature, frame):
    for bone_name in ANIMATED_BONES:
        bone = armature.pose.bones.get(bone_name)
        if not bone:
            continue
        bone.keyframe_insert("rotation_euler", frame=frame)
        if bone_name == "Root":
            bone.keyframe_insert("location", frame=frame)


def make_action(armature, name, keys):
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    armature.animation_data_create()
    armature.animation_data.action = action
    for frame, rotations, locations in keys:
        bpy.context.scene.frame_set(frame)
        apply_pose(armature, rotations, locations)
        key_ik_influence(armature, frame, 0.0)
        key_bones(armature, frame)
    for fcurve in iter_action_fcurves(action):
        for point in fcurve.keyframe_points:
            point.interpolation = "BEZIER"
    return action


def iter_action_fcurves(action):
    if hasattr(action, "fcurves"):
        yield from action.fcurves
        return
    slots = list(getattr(action, "slots", []))
    for layer in getattr(action, "layers", []):
        for strip in getattr(layer, "strips", []):
            for slot in slots:
                try:
                    channelbag = strip.channelbag(slot)
                except Exception:
                    continue
                yield from getattr(channelbag, "fcurves", [])


def build_actions(armature):
    remove_old_actions()
    actions = {
        "idle": [
            (1, {"Chest": (0.025, 0.0, 0.0), "Head": (-0.012, 0.0, 0.0), "UpperArm.L": (0.08, 0.0, 0.04), "UpperArm.R": (0.08, 0.0, -0.04)}, {"Root": (0.0, 0.0, 0.0)}),
            (30, {"Chest": (-0.018, 0.0, 0.0), "Head": (0.016, 0.0, 0.0), "UpperArm.L": (0.02, 0.0, -0.03), "UpperArm.R": (0.02, 0.0, 0.03)}, {"Root": (0.0, 0.0, 0.018)}),
            (60, {"Chest": (0.025, 0.0, 0.0), "Head": (-0.012, 0.0, 0.0), "UpperArm.L": (0.08, 0.0, 0.04), "UpperArm.R": (0.08, 0.0, -0.04)}, {"Root": (0.0, 0.0, 0.0)}),
        ],
        "walk": [
            (1, {"Chest": (0.04, 0.0, 0.08), "UpperArm.L": (-0.82, 0.0, 0.16), "ForeArm.L": (-0.20, 0.0, 0.03), "UpperArm.R": (0.82, 0.0, -0.16), "ForeArm.R": (0.20, 0.0, -0.03), "Thigh.L": (0.68, 0.0, -0.08), "Shin.L": (-0.08, 0.0, 0.0), "Foot.L": (-0.16, 0.0, 0.0), "Thigh.R": (-0.68, 0.0, 0.08), "Shin.R": (0.50, 0.0, 0.0), "Foot.R": (0.18, 0.0, 0.0)}, {"Root": (0.0, 0.0, 0.0)}),
            (10, {"Chest": (0.01, 0.0, 0.0), "UpperArm.L": (0.0, 0.0, 0.08), "UpperArm.R": (0.0, 0.0, -0.08), "Thigh.L": (0.0, 0.0, -0.04), "Thigh.R": (0.0, 0.0, 0.04), "Shin.L": (0.24, 0.0, 0.0), "Shin.R": (0.24, 0.0, 0.0)}, {"Root": (0.0, 0.0, 0.028)}),
            (19, {"Chest": (0.04, 0.0, -0.08), "UpperArm.L": (0.82, 0.0, 0.16), "ForeArm.L": (0.20, 0.0, 0.03), "UpperArm.R": (-0.82, 0.0, -0.16), "ForeArm.R": (-0.20, 0.0, -0.03), "Thigh.L": (-0.68, 0.0, -0.08), "Shin.L": (0.50, 0.0, 0.0), "Foot.L": (0.18, 0.0, 0.0), "Thigh.R": (0.68, 0.0, 0.08), "Shin.R": (-0.08, 0.0, 0.0), "Foot.R": (-0.16, 0.0, 0.0)}, {"Root": (0.0, 0.0, 0.0)}),
            (28, {"Chest": (0.01, 0.0, 0.0), "UpperArm.L": (0.0, 0.0, 0.08), "UpperArm.R": (0.0, 0.0, -0.08), "Thigh.L": (0.0, 0.0, -0.04), "Thigh.R": (0.0, 0.0, 0.04), "Shin.L": (0.24, 0.0, 0.0), "Shin.R": (0.24, 0.0, 0.0)}, {"Root": (0.0, 0.0, 0.028)}),
            (37, {"Chest": (0.04, 0.0, 0.08), "UpperArm.L": (-0.82, 0.0, 0.16), "ForeArm.L": (-0.20, 0.0, 0.03), "UpperArm.R": (0.82, 0.0, -0.16), "ForeArm.R": (0.20, 0.0, -0.03), "Thigh.L": (0.68, 0.0, -0.08), "Shin.L": (-0.08, 0.0, 0.0), "Foot.L": (-0.16, 0.0, 0.0), "Thigh.R": (-0.68, 0.0, 0.08), "Shin.R": (0.50, 0.0, 0.0), "Foot.R": (0.18, 0.0, 0.0)}, {"Root": (0.0, 0.0, 0.0)}),
        ],
        "run": [
            (1, {"Chest": (0.12, 0.0, 0.12), "UpperArm.L": (-1.12, 0.0, 0.22), "ForeArm.L": (-0.38, 0.0, 0.04), "UpperArm.R": (1.12, 0.0, -0.22), "ForeArm.R": (0.38, 0.0, -0.04), "Thigh.L": (0.92, 0.0, -0.08), "Shin.L": (-0.12, 0.0, 0.0), "Foot.L": (-0.22, 0.0, 0.0), "Thigh.R": (-0.92, 0.0, 0.08), "Shin.R": (0.76, 0.0, 0.0), "Foot.R": (0.28, 0.0, 0.0)}, {"Root": (0.0, 0.0, 0.02)}),
            (7, {"Chest": (0.07, 0.0, 0.0), "UpperArm.L": (0.05, 0.0, 0.10), "UpperArm.R": (-0.05, 0.0, -0.10), "Thigh.L": (0.05, 0.0, -0.04), "Thigh.R": (-0.05, 0.0, 0.04), "Shin.L": (0.44, 0.0, 0.0), "Shin.R": (0.44, 0.0, 0.0)}, {"Root": (0.0, 0.0, 0.065)}),
            (13, {"Chest": (0.12, 0.0, -0.12), "UpperArm.L": (1.12, 0.0, 0.22), "ForeArm.L": (0.38, 0.0, 0.04), "UpperArm.R": (-1.12, 0.0, -0.22), "ForeArm.R": (-0.38, 0.0, -0.04), "Thigh.L": (-0.92, 0.0, -0.08), "Shin.L": (0.76, 0.0, 0.0), "Foot.L": (0.28, 0.0, 0.0), "Thigh.R": (0.92, 0.0, 0.08), "Shin.R": (-0.12, 0.0, 0.0), "Foot.R": (-0.22, 0.0, 0.0)}, {"Root": (0.0, 0.0, 0.02)}),
            (19, {"Chest": (0.07, 0.0, 0.0), "UpperArm.L": (0.05, 0.0, 0.10), "UpperArm.R": (-0.05, 0.0, -0.10), "Thigh.L": (0.05, 0.0, -0.04), "Thigh.R": (-0.05, 0.0, 0.04), "Shin.L": (0.44, 0.0, 0.0), "Shin.R": (0.44, 0.0, 0.0)}, {"Root": (0.0, 0.0, 0.065)}),
            (25, {"Chest": (0.12, 0.0, 0.12), "UpperArm.L": (-1.12, 0.0, 0.22), "ForeArm.L": (-0.38, 0.0, 0.04), "UpperArm.R": (1.12, 0.0, -0.22), "ForeArm.R": (0.38, 0.0, -0.04), "Thigh.L": (0.92, 0.0, -0.08), "Shin.L": (-0.12, 0.0, 0.0), "Foot.L": (-0.22, 0.0, 0.0), "Thigh.R": (-0.92, 0.0, 0.08), "Shin.R": (0.76, 0.0, 0.0), "Foot.R": (0.28, 0.0, 0.0)}, {"Root": (0.0, 0.0, 0.02)}),
        ],
        "jump": [
            (1, {"Root": (-0.10, 0.0, 0.0), "Spine": (0.12, 0.0, 0.0), "UpperArm.L": (0.42, 0.0, 0.26), "UpperArm.R": (0.42, 0.0, -0.26), "Thigh.L": (-0.48, 0.0, 0.0), "Thigh.R": (-0.48, 0.0, 0.0), "Shin.L": (0.60, 0.0, 0.0), "Shin.R": (0.60, 0.0, 0.0)}, {"Root": (0.0, 0.0, -0.03)}),
            (10, {"Root": (0.10, 0.0, 0.0), "Spine": (-0.04, 0.0, 0.0), "UpperArm.L": (-1.18, 0.0, 0.36), "UpperArm.R": (-1.18, 0.0, -0.36), "ForeArm.L": (-0.35, 0.0, 0.0), "ForeArm.R": (-0.35, 0.0, 0.0), "Thigh.L": (0.48, 0.0, 0.0), "Thigh.R": (0.48, 0.0, 0.0), "Shin.L": (0.30, 0.0, 0.0), "Shin.R": (0.30, 0.0, 0.0)}, {"Root": (0.0, 0.0, 0.12)}),
            (22, {"Root": (0.08, 0.0, 0.0), "Spine": (0.02, 0.0, 0.0), "UpperArm.L": (-0.78, 0.0, 0.28), "UpperArm.R": (-0.78, 0.0, -0.28), "Thigh.L": (0.16, 0.0, 0.0), "Thigh.R": (0.16, 0.0, 0.0), "Shin.L": (0.36, 0.0, 0.0), "Shin.R": (0.36, 0.0, 0.0)}, {"Root": (0.0, 0.0, 0.18)}),
            (34, {"Root": (-0.06, 0.0, 0.0), "Spine": (0.10, 0.0, 0.0), "UpperArm.L": (0.30, 0.0, 0.20), "UpperArm.R": (0.30, 0.0, -0.20), "Thigh.L": (-0.36, 0.0, 0.0), "Thigh.R": (-0.36, 0.0, 0.0), "Shin.L": (0.52, 0.0, 0.0), "Shin.R": (0.52, 0.0, 0.0)}, {"Root": (0.0, 0.0, -0.02)}),
        ],
        "fall": [
            (1, {"Chest": (0.06, 0.0, 0.05), "UpperArm.L": (-0.62, 0.0, 0.34), "UpperArm.R": (-0.62, 0.0, -0.34), "Thigh.L": (0.24, 0.0, -0.06), "Thigh.R": (0.18, 0.0, 0.06), "Shin.L": (0.34, 0.0, 0.0), "Shin.R": (0.26, 0.0, 0.0)}, {"Root": (0.0, 0.0, 0.08)}),
            (18, {"Chest": (0.02, 0.0, -0.05), "UpperArm.L": (-0.44, 0.0, 0.26), "UpperArm.R": (-0.44, 0.0, -0.26), "Thigh.L": (0.12, 0.0, -0.03), "Thigh.R": (0.22, 0.0, 0.03), "Shin.L": (0.22, 0.0, 0.0), "Shin.R": (0.38, 0.0, 0.0)}, {"Root": (0.0, 0.0, 0.04)}),
            (36, {"Chest": (0.06, 0.0, 0.05), "UpperArm.L": (-0.62, 0.0, 0.34), "UpperArm.R": (-0.62, 0.0, -0.34), "Thigh.L": (0.24, 0.0, -0.06), "Thigh.R": (0.18, 0.0, 0.06), "Shin.L": (0.34, 0.0, 0.0), "Shin.R": (0.26, 0.0, 0.0)}, {"Root": (0.0, 0.0, 0.08)}),
        ],
        "crouch": [
            (1, {"Root": (0.18, 0.0, 0.0), "Spine": (0.18, 0.0, 0.0), "Chest": (0.05, 0.0, 0.0), "Head": (-0.08, 0.0, 0.0), "UpperArm.L": (0.42, 0.0, 0.12), "UpperArm.R": (0.42, 0.0, -0.12), "Thigh.L": (-0.58, 0.0, -0.04), "Thigh.R": (-0.58, 0.0, 0.04), "Shin.L": (0.70, 0.0, 0.0), "Shin.R": (0.70, 0.0, 0.0)}, {"Root": (0.0, 0.0, -0.08)}),
            (30, {"Root": (0.18, 0.0, 0.0), "Spine": (0.18, 0.0, 0.0), "Chest": (0.05, 0.0, 0.0), "Head": (-0.08, 0.0, 0.0), "UpperArm.L": (0.42, 0.0, 0.12), "UpperArm.R": (0.42, 0.0, -0.12), "Thigh.L": (-0.58, 0.0, -0.04), "Thigh.R": (-0.58, 0.0, 0.04), "Shin.L": (0.70, 0.0, 0.0), "Shin.R": (0.70, 0.0, 0.0)}, {"Root": (0.0, 0.0, -0.08)}),
        ],
        "prone": [
            (1, {"Root": (1.15, 0.0, 0.0), "Spine": (0.36, 0.0, 0.0), "Chest": (0.10, 0.0, 0.0), "Head": (-0.24, 0.0, 0.0), "UpperArm.L": (0.98, 0.0, 0.32), "ForeArm.L": (-0.30, 0.0, 0.0), "UpperArm.R": (0.98, 0.0, -0.32), "ForeArm.R": (-0.30, 0.0, 0.0), "Thigh.L": (0.52, 0.0, -0.03), "Thigh.R": (0.52, 0.0, 0.03), "Shin.L": (0.24, 0.0, 0.0), "Shin.R": (0.24, 0.0, 0.0)}, {"Root": (0.0, 0.0, -0.11)}),
            (30, {"Root": (1.15, 0.0, 0.0), "Spine": (0.36, 0.0, 0.0), "Chest": (0.10, 0.0, 0.0), "Head": (-0.24, 0.0, 0.0), "UpperArm.L": (0.98, 0.0, 0.32), "ForeArm.L": (-0.30, 0.0, 0.0), "UpperArm.R": (0.98, 0.0, -0.32), "ForeArm.R": (-0.30, 0.0, 0.0), "Thigh.L": (0.52, 0.0, -0.03), "Thigh.R": (0.52, 0.0, 0.03), "Shin.L": (0.24, 0.0, 0.0), "Shin.R": (0.24, 0.0, 0.0)}, {"Root": (0.0, 0.0, -0.11)}),
        ],
    }
    for name, keys in actions.items():
        make_action(armature, name, keys)
    armature.animation_data.action = bpy.data.actions.get("idle")


def vertex_group_weight(group, vertex_index):
    try:
        return group.weight(vertex_index)
    except RuntimeError:
        return 0.0


def body_group_for_vertex(obj, z):
    for group_name in (("Root", "Spine", "Chest") if z < 0.55 else ("Spine", "Chest", "Root")):
        group = obj.vertex_groups.get(group_name)
        if group:
            return group
    return None


def transfer_weight(source_group, target_group, vertex_index, scale):
    old_weight = vertex_group_weight(source_group, vertex_index)
    if old_weight <= 0.0:
        return 0.0
    new_weight = old_weight * scale
    removed = old_weight - new_weight
    if new_weight <= 0.0001:
        source_group.remove([vertex_index])
    else:
        source_group.add([vertex_index], new_weight, "REPLACE")
    if target_group and removed > 0.0:
        existing = vertex_group_weight(target_group, vertex_index)
        target_group.add([vertex_index], existing + removed, "REPLACE")
    return removed


def soften_lower_body_arm_weights(meshes):
    report = {}
    for obj in meshes:
        current_version = int(obj.get("gb_arm_weight_soften_version", 0))
        if current_version >= ARM_WEIGHT_SOFTEN_VERSION:
            report[obj.name] = {"base_vertices": 0, "tip_vertices": 0, "transferred_weight": 0.0, "skipped": True}
            continue
        arm_groups = [obj.vertex_groups.get(name) for name in ARM_WEIGHT_GROUPS if obj.vertex_groups.get(name)]
        if not arm_groups:
            report[obj.name] = {"base_vertices": 0, "tip_vertices": 0, "transferred_weight": 0.0}
            continue
        changed_base_vertices = 0
        changed_tip_vertices = 0
        transferred_weight = 0.0
        if current_version < 1:
            for vertex in obj.data.vertices:
                x = vertex.co.x
                z = vertex.co.z
                ax = abs(x)
                damp_scale = None
                if z < 0.44:
                    damp_scale = 0.0
                elif z < 0.58 and ax < 0.64:
                    damp_scale = 0.22
                elif 0.50 <= z <= 1.02 and ax < 0.49:
                    damp_scale = 0.38
                if damp_scale is None:
                    continue

                removed = 0.0
                target_group = body_group_for_vertex(obj, z)
                for group in arm_groups:
                    removed += transfer_weight(group, target_group, vertex.index, damp_scale)
                if removed <= 0.0:
                    continue
                changed_base_vertices += 1
                transferred_weight += removed

        for vertex in obj.data.vertices:
            x = vertex.co.x
            z = vertex.co.z
            removed = 0.0
            for suffix, side in [(".L", -1.0), (".R", 1.0)]:
                hand = obj.vertex_groups.get("Hand" + suffix)
                forearm = obj.vertex_groups.get("ForeArm" + suffix)
                upper = obj.vertex_groups.get("UpperArm" + suffix)
                target_body = body_group_for_vertex(obj, z)
                side_x = x * side

                if hand and (z < 0.525 or side_x < 0.745):
                    target = forearm if forearm and z >= 0.50 and side_x >= 0.62 else target_body
                    removed += transfer_weight(hand, target, vertex.index, 0.0)
                if forearm and (z < 0.475 or side_x < 0.56):
                    target = upper if upper and z >= 0.50 and side_x >= 0.48 else target_body
                    removed += transfer_weight(forearm, target, vertex.index, 0.12)
                if upper and side_x < 0.465:
                    removed += transfer_weight(upper, target_body, vertex.index, 0.22)

            if removed > 0.0:
                changed_tip_vertices += 1
                transferred_weight += removed
        obj.data.update()
        report[obj.name] = {
            "base_vertices": changed_base_vertices,
            "tip_vertices": changed_tip_vertices,
            "transferred_weight": round(transferred_weight, 4),
            "skipped": False,
            "from_version": current_version,
            "to_version": ARM_WEIGHT_SOFTEN_VERSION,
        }
        obj["gb_arm_weight_soften_version"] = ARM_WEIGHT_SOFTEN_VERSION
    return report


def action_report():
    report = {}
    for action_name in ACTION_NAMES:
        action = bpy.data.actions.get(action_name)
        if not action:
            report[action_name] = {"exists": False}
            continue
        fcurves = list(iter_action_fcurves(action))
        limb_curves = [
            fcurve.data_path
            for fcurve in fcurves
            if any(token in fcurve.data_path for token in ["Arm", "ForeArm", "Hand", "Thigh", "Shin", "Foot"])
        ]
        report[action_name] = {
            "exists": True,
            "fcurves": len(fcurves),
            "limb_fcurves": len(limb_curves),
            "frame_range": tuple(round(value, 2) for value in action.frame_range),
        }
    return report


def clear_godot_import_cache():
    imported = os.path.join(PROJECT_DIR, ".godot", "imported")
    if not os.path.isdir(imported):
        return 0
    removed = 0
    for name in os.listdir(imported):
        if name.startswith("gingerbread_animated"):
            os.remove(os.path.join(imported, name))
            removed += 1
    return removed


def clear_pose_constraints(armature):
    stored = []
    for bone in armature.pose.bones:
        for constraint in list(bone.constraints):
            stored.append(
                {
                    "bone": bone.name,
                    "type": constraint.type,
                    "name": constraint.name,
                    "target": constraint.target,
                    "subtarget": getattr(constraint, "subtarget", ""),
                    "chain_count": getattr(constraint, "chain_count", 0),
                    "use_rotation": getattr(constraint, "use_rotation", False),
                    "influence": getattr(constraint, "influence", 1.0),
                }
            )
            bone.constraints.remove(constraint)
    return stored


def restore_pose_constraints(armature, stored):
    for item in stored:
        bone = armature.pose.bones.get(item["bone"])
        if not bone:
            continue
        constraint = bone.constraints.new(item["type"])
        constraint.name = item["name"]
        constraint.target = item["target"]
        if hasattr(constraint, "subtarget"):
            constraint.subtarget = item["subtarget"]
        if hasattr(constraint, "chain_count"):
            constraint.chain_count = item["chain_count"]
        if hasattr(constraint, "use_rotation"):
            constraint.use_rotation = item["use_rotation"]
        if hasattr(constraint, "influence"):
            constraint.influence = item["influence"]


def export_runtime_glb(armature, meshes):
    root = armature.parent
    selected = [armature] + meshes
    if root:
        selected.insert(0, root)
    for obj in bpy.data.objects:
        obj.select_set(False)
    for obj in selected:
        obj.hide_set(False)
        obj.hide_viewport = False
        obj.hide_render = False
        obj.select_set(True)
    bpy.context.view_layer.objects.active = armature
    stored_constraints = clear_pose_constraints(armature)
    try:
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
    finally:
        restore_pose_constraints(armature, stored_constraints)


def main():
    ensure_dirs()
    object_mode()
    bpy.context.scene.render.fps = 30
    armature = get_armature()
    meshes = get_body_meshes(armature)
    weight_report = soften_lower_body_arm_weights(meshes)
    build_actions(armature)
    report = action_report()
    export_runtime_glb(armature, meshes)
    saved_blend = True
    try:
        bpy.context.preferences.filepaths.save_version = 0
        bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    except Exception as exc:
        saved_blend = False
        print("GINGERBREAD_ANIMATION_REPAIR_SAVE_WARNING=" + repr(str(exc)))
    removed_cache = clear_godot_import_cache()
    result = {
        "armature": armature.name,
        "meshes": [obj.name for obj in meshes],
        "weight_softening": weight_report,
        "actions": report,
        "out_glb": OUT_GLB,
        "out_blend": OUT_BLEND,
        "saved_blend": saved_blend,
        "removed_godot_cache_files": removed_cache,
    }
    print("GINGERBREAD_ANIMATION_REPAIR_RESULT=" + repr(result))
    return result


if __name__ == "__main__":
    main()
