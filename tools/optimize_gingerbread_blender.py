import json
import math
import sys
from pathlib import Path

import bpy


TARGET_TRIS = 24000
DEFAULT_INPUT_PATH = Path(
    r"H:\Downaloads\godot-3d-multiplayer-template\assets\characters\gingerbread\gingerbread_animated.glb"
)
DEFAULT_OUTPUT_PATH = Path(
    r"H:\Downaloads\godot-3d-multiplayer-template\assets\characters\gingerbread\gingerbread_animated_optimized.glb"
)


def script_args():
    if "--" not in sys.argv:
        return []
    return sys.argv[sys.argv.index("--") + 1:]


ARGS = script_args()
INPUT_PATH = Path(ARGS[0]) if len(ARGS) >= 1 else DEFAULT_INPUT_PATH
OUTPUT_PATH = Path(ARGS[1]) if len(ARGS) >= 2 else DEFAULT_OUTPUT_PATH


def mesh_triangle_count(obj):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = obj.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    try:
        return sum(len(poly.vertices) - 2 for poly in mesh.polygons)
    finally:
        evaluated.to_mesh_clear()


def mesh_vertex_count(obj):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = obj.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    try:
        return len(mesh.vertices)
    finally:
        evaluated.to_mesh_clear()


def visible_bounds(obj):
    corners = [obj.matrix_world @ mathutils.Vector(corner) for corner in obj.bound_box]
    return {
        "min": [round(min(c[i] for c in corners), 4) for i in range(3)],
        "max": [round(max(c[i] for c in corners), 4) for i in range(3)],
    }


def cleanup_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def import_glb(path):
    bpy.ops.import_scene.gltf(filepath=str(path))


def find_main_mesh():
    skinned_meshes = []
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        has_armature = any(mod.type == "ARMATURE" for mod in obj.modifiers)
        if has_armature:
            skinned_meshes.append(obj)
    if not skinned_meshes:
        raise RuntimeError("No skinned mesh with an Armature modifier was found.")
    skinned_meshes.sort(key=mesh_triangle_count, reverse=True)
    return skinned_meshes[0]


def remove_export_leftovers(main_mesh):
    removed = []
    for obj in bpy.context.scene.objects:
        if obj.type == "ARMATURE" and obj.pose:
            for pose_bone in obj.pose.bones:
                pose_bone.custom_shape = None
    for obj in list(bpy.context.scene.objects):
        if obj.type != "MESH" or obj == main_mesh:
            continue
        has_armature = any(mod.type == "ARMATURE" for mod in obj.modifiers)
        if not has_armature:
            removed.append(obj.name)
            bpy.data.objects.remove(obj, do_unlink=True)
    bpy.ops.outliner.orphans_purge(do_local_ids=True, do_linked_ids=True, do_recursive=True)
    return removed


def apply_decimate_before_armature(obj, target_tris):
    before_tris = mesh_triangle_count(obj)
    before_verts = mesh_vertex_count(obj)
    if before_tris <= target_tris:
        return {
            "before_tris": before_tris,
            "before_verts": before_verts,
            "after_tris": before_tris,
            "after_verts": before_verts,
            "ratio": 1.0,
            "applied": False,
        }

    ratio = max(min(float(target_tris) / float(before_tris), 1.0), 0.001)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)

    decimate = obj.modifiers.new("GamePaintTopologyDecimate", "DECIMATE")
    decimate.decimate_type = "COLLAPSE"
    decimate.ratio = ratio
    decimate.use_collapse_triangulate = True
    bpy.ops.object.modifier_move_to_index(modifier=decimate.name, index=0)
    bpy.ops.object.modifier_apply(modifier=decimate.name)

    obj.name = "Gingerbread_Optimized_PaintMesh"
    obj.data.name = "Gingerbread_Optimized_PaintMesh_Data"
    return {
        "before_tris": before_tris,
        "before_verts": before_verts,
        "after_tris": mesh_triangle_count(obj),
        "after_verts": mesh_vertex_count(obj),
        "ratio": ratio,
        "applied": True,
    }


def export_glb(path):
    path.parent.mkdir(parents=True, exist_ok=True)
    for obj in bpy.context.scene.objects:
        obj.select_set(False)
    for obj in bpy.context.scene.objects:
        if obj.type in {"ARMATURE", "MESH", "EMPTY"}:
            obj.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_animations=True,
        export_skins=True,
        export_materials="EXPORT",
    )


def main():
    cleanup_scene()
    import_glb(INPUT_PATH)
    main_mesh = find_main_mesh()
    removed = remove_export_leftovers(main_mesh)
    stats = apply_decimate_before_armature(main_mesh, TARGET_TRIS)
    objects_before_export = [
        {"name": obj.name, "type": obj.type, "parent": obj.parent.name if obj.parent else ""}
        for obj in bpy.context.scene.objects
    ]
    export_glb(OUTPUT_PATH)
    print("GINGER_OPTIMIZE_RESULT=" + json.dumps({
        "input": str(INPUT_PATH),
        "output": str(OUTPUT_PATH),
        "removed_leftovers": removed,
        "objects_before_export": objects_before_export,
        "mesh": main_mesh.name,
        "target_tris": TARGET_TRIS,
        **stats,
        "armatures": [
            {"name": obj.name, "bones": len(obj.data.bones)}
            for obj in bpy.context.scene.objects
            if obj.type == "ARMATURE"
        ],
        "actions": [action.name for action in bpy.data.actions],
    }, ensure_ascii=False))


if __name__ == "__main__":
    import mathutils

    main()
