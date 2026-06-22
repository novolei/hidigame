import math
import os

import bpy
from mathutils import Matrix, Vector


PBR_PATH = r"C:\Users\aresr\Documents\Asse\Ginger\base_basic_pbr.glb"
SHADED_PATH = r"C:\Users\aresr\Documents\Asse\Ginger\base_basic_shaded.glb"
PROJECT_DIR = r"H:\Downaloads\godot-3d-multiplayer-template"
CHAR_DIR = os.path.join(PROJECT_DIR, "assets", "characters", "gingerbread")
OUT_BLEND = os.path.join(CHAR_DIR, "current_scene_gingerbread_upright_animated.blend")
OUT_GLB = os.path.join(CHAR_DIR, "gingerbread_animated.glb")
PREVIEW_FRONT = os.path.join(CHAR_DIR, "gingerbread_original_rebuild_front_preview.png")
PREVIEW_BACK = os.path.join(CHAR_DIR, "gingerbread_original_rebuild_back_preview.png")


def ensure_object_mode():
    try:
        if bpy.ops.object.mode_set.poll():
            bpy.ops.object.mode_set(mode="OBJECT")
    except Exception:
        pass


def purge_previous_character():
    prefixes = (
        "GB_Clean",
        "GB_Current",
        "GB_Original",
        "Gingerbread_PBR_Body",
        "J_",
        "CTRL_",
        "TMP_CleanMeta_",
    )
    for obj in list(bpy.data.objects):
        if obj.name.startswith(prefixes):
            bpy.data.objects.remove(obj, do_unlink=True)
    for cname in [
        "GB_Clean_Retopo",
        "GB_Original_Rebuild",
        "GB_Original_Source_Reference",
        "GB_Original_Rig_Helpers",
    ]:
        coll = bpy.data.collections.get(cname)
        if coll:
            for obj in list(coll.objects):
                bpy.data.objects.remove(obj, do_unlink=True)
            bpy.data.collections.remove(coll)
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action, do_unlink=True)


def make_collection(name):
    coll = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(coll)
    return coll


def world_bounds(meshes):
    pts = []
    for obj in meshes:
        pts.extend(obj.matrix_world @ Vector(corner) for corner in obj.bound_box)
    return {
        "minx": min(p.x for p in pts),
        "maxx": max(p.x for p in pts),
        "miny": min(p.y for p in pts),
        "maxy": max(p.y for p in pts),
        "minz": min(p.z for p in pts),
        "maxz": max(p.z for p in pts),
    }


def flatten_meshes(meshes, transform):
    for obj in meshes:
        obj.data = obj.data.copy()
        for vert in obj.data.vertices:
            vert.co = transform @ (obj.matrix_world @ vert.co)
        obj.matrix_world = Matrix.Identity(4)
        obj.parent = None
        obj.data.update()


def import_glb_as_flat_meshes(filepath, prefix, coll, transform=None, visible=True):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=filepath)
    imported = [obj for obj in bpy.data.objects if obj not in before]
    meshes = [obj for obj in imported if obj.type == "MESH"]
    if transform is not None:
        flatten_meshes(meshes, transform)
    for index, obj in enumerate(meshes):
        obj.name = f"{prefix}_Mesh_{index:02d}"
        obj.data.name = f"{prefix}_Mesh_{index:02d}_Data"
        try:
            coll.objects.link(obj)
        except RuntimeError:
            pass
        obj.hide_viewport = not visible
        obj.hide_set(not visible)
        obj.hide_render = not visible
        for poly in obj.data.polygons:
            poly.use_smooth = True
        if visible:
            obj.modifiers.new("GB_Original_weighted_normals", "WEIGHTED_NORMAL")
    for obj in imported:
        if obj.type != "MESH":
            bpy.data.objects.remove(obj, do_unlink=True)
    return meshes


def create_material(name, color, roughness=0.55):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = 0.0
    return mat


def create_control(name, location, radius, material, coll, parent):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=radius, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.data.name = name + "_Mesh"
    obj.data.materials.append(material)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    try:
        coll.objects.link(obj)
    except RuntimeError:
        pass
    obj.parent = parent
    obj.hide_render = True
    return obj


def create_joint_marker(name, location, material, coll, parent):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=0.022, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.data.name = name + "_Mesh"
    obj.data.materials.append(material)
    try:
        coll.objects.link(obj)
    except RuntimeError:
        pass
    obj.parent = parent
    obj.hide_render = True
    return obj


def create_armature(root, coll):
    arm_data = bpy.data.armatures.new("GB_Original_GameReady_Armature_Data")
    arm = bpy.data.objects.new("GB_Original_GameReady_Armature", arm_data)
    coll.objects.link(arm)
    arm.parent = root
    arm.show_in_front = True
    arm_data.display_type = "STICK"
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for bone in list(arm_data.edit_bones):
        arm_data.edit_bones.remove(bone)

    def add_bone(name, head, tail, parent=None, connected=False):
        bone = arm_data.edit_bones.new(name)
        bone.head = head
        bone.tail = tail
        if parent:
            bone.parent = arm_data.edit_bones[parent]
            bone.use_connect = connected
        return bone

    add_bone("Root", (0.0, 0.0, 0.05), (0.0, 0.0, 0.48))
    add_bone("Spine", (0.0, 0.0, 0.48), (0.0, 0.0, 0.93), "Root", True)
    add_bone("Chest", (0.0, 0.0, 0.93), (0.0, 0.0, 1.13), "Spine", True)
    add_bone("Head", (0.0, 0.0, 1.13), (0.0, 0.0, 1.76), "Chest", True)
    for side, suffix in [(-1, ".L"), (1, ".R")]:
        add_bone(f"UpperArm{suffix}", (side * 0.39, 0.0, 0.92), (side * 0.56, 0.0, 0.72), "Chest")
        add_bone(f"ForeArm{suffix}", (side * 0.56, 0.0, 0.72), (side * 0.72, 0.0, 0.56), f"UpperArm{suffix}", True)
        add_bone(f"Hand{suffix}", (side * 0.72, 0.0, 0.56), (side * 0.82, -0.02, 0.49), f"ForeArm{suffix}", True)
        add_bone(f"Thigh{suffix}", (side * 0.17, 0.0, 0.50), (side * 0.25, 0.0, 0.25), "Root")
        add_bone(f"Shin{suffix}", (side * 0.25, 0.0, 0.25), (side * 0.29, 0.0, 0.06), f"Thigh{suffix}", True)
        add_bone(f"Foot{suffix}", (side * 0.29, 0.0, 0.06), (side * 0.34, -0.16, 0.035), f"Shin{suffix}", True)
    bpy.ops.object.mode_set(mode="POSE")
    for pbone in arm.pose.bones:
        pbone.rotation_mode = "XYZ"
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def assign_weights(meshes, arm):
    group_names = [
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

    def clamp(value, low=0.0, high=1.0):
        return max(low, min(high, value))

    def smoothstep(edge0, edge1, value):
        if edge0 == edge1:
            return 0.0
        t = clamp((value - edge0) / (edge1 - edge0))
        return t * t * (3.0 - 2.0 * t)

    for obj in meshes:
        for group in list(obj.vertex_groups):
            obj.vertex_groups.remove(group)
        groups = {name: obj.vertex_groups.new(name=name) for name in group_names}
        for vert in obj.data.vertices:
            x, y, z = vert.co.x, vert.co.y, vert.co.z
            ax = abs(x)
            weights = {}
            if ax > 0.43 and 0.35 < z < 1.03:
                suffix = ".L" if x < 0 else ".R"
                t = clamp((ax - 0.43) / 0.39)
                weights = {
                    "Chest": 0.09 * (1.0 - t),
                    "UpperArm" + suffix: max(0.0, 1.0 - smoothstep(0.26, 0.72, t)),
                    "ForeArm" + suffix: max(0.0, 1.0 - abs(t - 0.57) / 0.43),
                    "Hand" + suffix: smoothstep(0.68, 1.0, t),
                }
            elif z < 0.55 and ax > 0.075:
                suffix = ".L" if x < 0 else ".R"
                t = clamp((0.55 - z) / 0.55)
                hip = (1.0 - t) * 0.12
                weights = {
                    "Root": hip,
                    "Spine": hip * 0.20,
                    "Thigh" + suffix: max(0.0, 1.0 - smoothstep(0.30, 0.72, t)),
                    "Shin" + suffix: max(0.0, 1.0 - abs(t - 0.58) / 0.42),
                    "Foot" + suffix: smoothstep(0.72, 1.0, t),
                }
            else:
                head = smoothstep(1.05, 1.25, z)
                chest = smoothstep(0.70, 1.08, z) * (1.0 - head * 0.70)
                spine = (1.0 - head) * max(0.0, 1.0 - abs(z - 0.72) / 0.50)
                root = (1.0 - head) * max(0.0, 1.0 - smoothstep(0.34, 0.70, z))
                weights = {"Head": head, "Chest": chest, "Spine": spine, "Root": root}
            total = sum(max(0.0, value) for value in weights.values()) or 1.0
            for name, value in weights.items():
                value = max(0.0, value) / total
                if value > 0.001:
                    groups[name].add([vert.index], value, "ADD")
        mod = obj.modifiers.new("GB_Original_armature_deform_with_IK", "ARMATURE")
        mod.object = arm
        mod.use_vertex_groups = True
        obj.parent = arm


def add_ik_constraints(arm, controls):
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    for suffix in [".L", ".R"]:
        hand = arm.pose.bones.get("Hand" + suffix)
        if hand:
            con = hand.constraints.new("IK")
            con.name = "GB_Original_Hand_IK" + suffix
            con.target = controls["hand" + suffix]
            con.chain_count = 2
            con.use_rotation = True
        foot = arm.pose.bones.get("Foot" + suffix)
        if foot:
            con = foot.constraints.new("IK")
            con.name = "GB_Original_Foot_IK" + suffix
            con.target = controls["foot" + suffix]
            con.chain_count = 2
            con.use_rotation = True
    bpy.ops.object.mode_set(mode="OBJECT")


def key_pose(arm, frame, rotations):
    bpy.context.scene.frame_set(frame)
    for bone in arm.pose.bones:
        bone.rotation_euler = (0.0, 0.0, 0.0)
        bone.location = (0.0, 0.0, 0.0)
        bone.scale = (1.0, 1.0, 1.0)
    for name, rot in rotations.items():
        if name in arm.pose.bones:
            arm.pose.bones[name].rotation_euler = rot
    for name in rotations:
        if name in arm.pose.bones:
            arm.pose.bones[name].keyframe_insert("rotation_euler", frame=frame)
    for name in ["Root", "Spine", "Chest", "Head"]:
        if name in arm.pose.bones:
            arm.pose.bones[name].keyframe_insert("rotation_euler", frame=frame)


def make_actions(arm):
    action_specs = {
        "idle": [
            (1, {"Chest": (0.02, 0.0, 0.0), "Head": (-0.015, 0.0, 0.0)}),
            (30, {"Chest": (-0.018, 0.0, 0.0), "Head": (0.018, 0.0, 0.0)}),
            (60, {"Chest": (0.02, 0.0, 0.0), "Head": (-0.015, 0.0, 0.0)}),
        ],
        "walk": [
            (1, {"UpperArm.L": (-0.42, 0.0, 0.08), "UpperArm.R": (0.42, 0.0, -0.08), "Thigh.L": (0.34, 0.0, -0.04), "Thigh.R": (-0.34, 0.0, 0.04), "Shin.R": (0.26, 0.0, 0.0), "Chest": (0.02, 0.0, 0.04)}),
            (15, {"UpperArm.L": (0.42, 0.0, 0.08), "UpperArm.R": (-0.42, 0.0, -0.08), "Thigh.L": (-0.34, 0.0, -0.04), "Thigh.R": (0.34, 0.0, 0.04), "Shin.L": (0.26, 0.0, 0.0), "Chest": (0.02, 0.0, -0.04)}),
            (30, {"UpperArm.L": (-0.42, 0.0, 0.08), "UpperArm.R": (0.42, 0.0, -0.08), "Thigh.L": (0.34, 0.0, -0.04), "Thigh.R": (-0.34, 0.0, 0.04), "Shin.R": (0.26, 0.0, 0.0), "Chest": (0.02, 0.0, 0.04)}),
        ],
        "run": [
            (1, {"UpperArm.L": (-0.74, 0.0, 0.12), "UpperArm.R": (0.74, 0.0, -0.12), "Thigh.L": (0.58, 0.0, -0.05), "Thigh.R": (-0.58, 0.0, 0.05), "Shin.R": (0.55, 0.0, 0.0), "Chest": (0.11, 0.0, 0.05)}),
            (10, {"UpperArm.L": (0.74, 0.0, 0.12), "UpperArm.R": (-0.74, 0.0, -0.12), "Thigh.L": (-0.58, 0.0, -0.05), "Thigh.R": (0.58, 0.0, 0.05), "Shin.L": (0.55, 0.0, 0.0), "Chest": (0.11, 0.0, -0.05)}),
            (20, {"UpperArm.L": (-0.74, 0.0, 0.12), "UpperArm.R": (0.74, 0.0, -0.12), "Thigh.L": (0.58, 0.0, -0.05), "Thigh.R": (-0.58, 0.0, 0.05), "Shin.R": (0.55, 0.0, 0.0), "Chest": (0.11, 0.0, 0.05)}),
        ],
        "jump": [
            (1, {"Root": (-0.06, 0.0, 0.0), "UpperArm.L": (0.18, 0.0, 0.42), "UpperArm.R": (0.18, 0.0, -0.42), "Thigh.L": (-0.22, 0.0, 0.0), "Thigh.R": (-0.22, 0.0, 0.0)}),
            (14, {"Root": (0.12, 0.0, 0.0), "UpperArm.L": (-0.75, 0.0, 0.42), "UpperArm.R": (-0.75, 0.0, -0.42), "Thigh.L": (0.26, 0.0, 0.0), "Thigh.R": (0.26, 0.0, 0.0), "Shin.L": (0.35, 0.0, 0.0), "Shin.R": (0.35, 0.0, 0.0)}),
            (28, {"Root": (-0.06, 0.0, 0.0), "UpperArm.L": (0.18, 0.0, 0.42), "UpperArm.R": (0.18, 0.0, -0.42), "Thigh.L": (-0.22, 0.0, 0.0), "Thigh.R": (-0.22, 0.0, 0.0)}),
        ],
        "crouch": [
            (1, {"Root": (0.18, 0.0, 0.0), "Spine": (0.15, 0.0, 0.0), "Thigh.L": (-0.50, 0.0, 0.0), "Thigh.R": (-0.50, 0.0, 0.0), "Shin.L": (0.56, 0.0, 0.0), "Shin.R": (0.56, 0.0, 0.0), "UpperArm.L": (0.25, 0.0, 0.1), "UpperArm.R": (0.25, 0.0, -0.1)}),
            (30, {"Root": (0.20, 0.0, 0.0), "Spine": (0.16, 0.0, 0.0), "Thigh.L": (-0.50, 0.0, 0.0), "Thigh.R": (-0.50, 0.0, 0.0), "Shin.L": (0.56, 0.0, 0.0), "Shin.R": (0.56, 0.0, 0.0), "UpperArm.L": (0.25, 0.0, 0.1), "UpperArm.R": (0.25, 0.0, -0.1)}),
        ],
        "prone": [
            (1, {"Root": (1.20, 0.0, 0.0), "Spine": (0.30, 0.0, 0.0), "Head": (-0.22, 0.0, 0.0), "UpperArm.L": (0.78, 0.0, 0.28), "UpperArm.R": (0.78, 0.0, -0.28), "Thigh.L": (0.52, 0.0, 0.0), "Thigh.R": (0.52, 0.0, 0.0)}),
            (30, {"Root": (1.20, 0.0, 0.0), "Spine": (0.30, 0.0, 0.0), "Head": (-0.22, 0.0, 0.0), "UpperArm.L": (0.78, 0.0, 0.28), "UpperArm.R": (0.78, 0.0, -0.28), "Thigh.L": (0.52, 0.0, 0.0), "Thigh.R": (0.52, 0.0, 0.0)}),
        ],
    }
    for action_name, keys in action_specs.items():
        action = bpy.data.actions.new(action_name)
        arm.animation_data_create()
        arm.animation_data.action = action
        for frame, rotations in keys:
            key_pose(arm, frame, rotations)
        action.use_fake_user = True
    arm.animation_data.action = bpy.data.actions.get("idle")


def render_preview(paths):
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
        scene.view_settings.exposure = -0.1
        scene.view_settings.gamma = 1.0
    except Exception:
        pass

    def look_at(obj, target):
        direction = Vector(target) - obj.location
        obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()

    cam_data = bpy.data.cameras.new("GB_Original_Preview_Camera_Data")
    cam = bpy.data.objects.new("GB_Original_Preview_Camera", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    scene.camera = cam
    cam.data.lens = 48
    for name, loc, power, size in [
        ("GB_Original_Key_Light", (-2.2, -3.0, 3.0), 90, 4.5),
        ("GB_Original_Fill_Light", (2.4, -1.6, 2.0), 18, 5.5),
        ("GB_Original_Back_Light", (0.0, 2.8, 2.4), 45, 4.0),
    ]:
        light_data = bpy.data.lights.new(name + "_Data", "AREA")
        light = bpy.data.objects.new(name, light_data)
        bpy.context.scene.collection.objects.link(light)
        light.location = loc
        light.data.energy = power
        light.data.size = size
        look_at(light, (0.0, 0.0, 0.95))
    for label, loc, target, path in [
        ("front", (0.0, -3.6, 0.95), (0.0, 0.0, 0.95), paths[0]),
        ("back", (0.0, 3.6, 0.95), (0.0, 0.0, 0.95), paths[1]),
    ]:
        cam.location = loc
        look_at(cam, target)
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)


def clear_pose_constraints(arm):
    stored = []
    for pbone in arm.pose.bones:
        for constraint in list(pbone.constraints):
            stored.append(
                {
                    "bone": pbone.name,
                    "type": constraint.type,
                    "name": constraint.name,
                    "target": constraint.target,
                    "chain_count": getattr(constraint, "chain_count", 0),
                    "use_rotation": getattr(constraint, "use_rotation", False),
                }
            )
            pbone.constraints.remove(constraint)
    return stored


def restore_pose_constraints(arm, stored):
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    for item in stored:
        pbone = arm.pose.bones.get(item["bone"])
        if not pbone:
            continue
        constraint = pbone.constraints.new(item["type"])
        constraint.name = item["name"]
        if item["target"]:
            constraint.target = item["target"]
        if hasattr(constraint, "chain_count"):
            constraint.chain_count = item["chain_count"]
        if hasattr(constraint, "use_rotation"):
            constraint.use_rotation = item["use_rotation"]
    bpy.ops.object.mode_set(mode="OBJECT")


def export_glb(root, arm, meshes):
    for obj in bpy.data.objects:
        obj.select_set(False)
    for obj in [root, arm] + meshes:
        obj.hide_set(False)
        obj.hide_viewport = False
        obj.select_set(True)
    stored_constraints = clear_pose_constraints(arm)
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
    restore_pose_constraints(arm, stored_constraints)


def main():
    if not os.path.exists(PBR_PATH):
        raise RuntimeError("Missing source PBR GLB: " + PBR_PATH)
    if not os.path.exists(SHADED_PATH):
        raise RuntimeError("Missing source shaded GLB: " + SHADED_PATH)
    ensure_object_mode()
    purge_previous_character()
    main_coll = make_collection("GB_Original_Rebuild")
    ref_coll = make_collection("GB_Original_Source_Reference")
    helper_coll = make_collection("GB_Original_Rig_Helpers")
    root = bpy.data.objects.new("GB_Original_Character_Root", None)
    root.empty_display_type = "PLAIN_AXES"
    root.empty_display_size = 0.25
    main_coll.objects.link(root)

    raw_meshes = import_glb_as_flat_meshes(PBR_PATH, "GB_Original_PBR_RAW", main_coll, None, True)
    bounds = world_bounds(raw_meshes)
    height = bounds["maxz"] - bounds["minz"]
    scale = 1.90 / height if height > 1e-6 else 1.0
    center_x = (bounds["minx"] + bounds["maxx"]) * 0.5
    center_y = (bounds["miny"] + bounds["maxy"]) * 0.5
    normalizer = (
        Matrix.Translation(Vector((-center_x * scale, -center_y * scale, -bounds["minz"] * scale)))
        @ Matrix.Diagonal((scale, scale, scale, 1.0))
    )
    flatten_meshes(raw_meshes, normalizer)
    for index, obj in enumerate(raw_meshes):
        obj.name = f"GB_Original_PBR_Mesh_{index:02d}"
        obj.data.name = f"GB_Original_PBR_Mesh_{index:02d}_Data"
        obj.parent = root
        obj.hide_set(False)
        obj.hide_viewport = False
        obj.hide_render = False

    ref_meshes = import_glb_as_flat_meshes(SHADED_PATH, "GB_Original_REF_Shaded", ref_coll, normalizer, False)
    for obj in ref_meshes:
        obj.parent = root

    control_mat = create_material("GB_Original_Rig_Control_Green", (0.18, 0.95, 0.42, 1.0), 0.45)
    joint_mat = create_material("GB_Original_Rig_Joint_Blue", (0.22, 0.48, 1.0, 1.0), 0.50)
    controls = {
        "hand.L": create_control("CTRL_Hand_L_IK", (-0.93, -0.20, 0.55), 0.038, control_mat, helper_coll, root),
        "hand.R": create_control("CTRL_Hand_R_IK", (0.93, -0.20, 0.55), 0.038, control_mat, helper_coll, root),
        "foot.L": create_control("CTRL_Foot_L_IK", (-0.48, -0.32, 0.05), 0.038, control_mat, helper_coll, root),
        "foot.R": create_control("CTRL_Foot_R_IK", (0.48, -0.32, 0.05), 0.038, control_mat, helper_coll, root),
        "head": create_control("CTRL_Head_Look", (0.0, -0.45, 1.42), 0.038, control_mat, helper_coll, root),
    }
    for name, loc in [
        ("J_Root", (0.0, 0.0, 0.05)),
        ("J_Chest", (0.0, 0.0, 0.93)),
        ("J_Head", (0.0, 0.0, 1.58)),
        ("J_Shoulder_L", (-0.39, 0.0, 0.92)),
        ("J_Shoulder_R", (0.39, 0.0, 0.92)),
        ("J_Hip_L", (-0.17, 0.0, 0.50)),
        ("J_Hip_R", (0.17, 0.0, 0.50)),
    ]:
        create_joint_marker(name, loc, joint_mat, helper_coll, root)

    arm = create_armature(root, main_coll)
    assign_weights(raw_meshes, arm)
    add_ik_constraints(arm, controls)
    make_actions(arm)

    render_preview((PREVIEW_FRONT, PREVIEW_BACK))
    export_glb(root, arm, raw_meshes)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    result = {
        "source_pbr": PBR_PATH,
        "source_shaded_reference": SHADED_PATH,
        "visible_mesh_count": len(raw_meshes),
        "reference_mesh_count": len(ref_meshes),
        "actions": [action.name for action in bpy.data.actions if action.name in {"idle", "walk", "run", "jump", "crouch", "prone"}],
        "out_glb": OUT_GLB,
        "out_blend": OUT_BLEND,
        "previews": [PREVIEW_FRONT, PREVIEW_BACK],
    }
    print("GINGERBREAD_ORIGINAL_REBUILD_RESULT=" + repr(result))


main()
