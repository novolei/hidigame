import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def mesh_stats(obj):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = obj.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    try:
        tris = sum(len(poly.vertices) - 2 for poly in mesh.polygons)
        corners = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
        return {
            "name": obj.name,
            "verts": len(mesh.vertices),
            "polygons": len(mesh.polygons),
            "tris": tris,
            "uv_layers": len(mesh.uv_layers),
            "materials": [slot.material.name if slot.material else "" for slot in obj.material_slots],
            "modifiers": [mod.type for mod in obj.modifiers],
            "parent": obj.parent.name if obj.parent else "",
            "bounds": {
                "min": [round(min(c[i] for c in corners), 4) for i in range(3)],
                "max": [round(max(c[i] for c in corners), 4) for i in range(3)],
            },
        }
    finally:
        evaluated.to_mesh_clear()


def main():
    if "--" in sys.argv:
        args = sys.argv[sys.argv.index("--") + 1:]
    else:
        args = sys.argv[1:]
    if not args:
        raise SystemExit("Usage: blender --background --python tools/analyze_glb_blender.py -- path.glb")
    path = Path(args[0])

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    bpy.ops.import_scene.gltf(filepath=str(path))

    meshes = []
    armatures = []
    total_tris = 0
    total_verts = 0
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            stats = mesh_stats(obj)
            meshes.append(stats)
            total_tris += stats["tris"]
            total_verts += stats["verts"]
        elif obj.type == "ARMATURE":
            armatures.append({"name": obj.name, "bones": len(obj.data.bones)})

    result = {
        "path": str(path),
        "objects": [
            {"name": obj.name, "type": obj.type, "parent": obj.parent.name if obj.parent else ""}
            for obj in bpy.context.scene.objects
        ],
        "meshes": meshes,
        "total_verts": total_verts,
        "total_tris": total_tris,
        "armatures": armatures,
        "actions": [action.name for action in bpy.data.actions],
        "materials": [material.name for material in bpy.data.materials],
        "images": [
            {"name": image.name, "size": [image.size[0], image.size[1]], "packed": bool(image.packed_file)}
            for image in bpy.data.images
        ],
    }
    print("GLB_ANALYSIS=" + json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
