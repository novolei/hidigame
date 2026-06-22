import json
import os

import bpy
from mathutils import Vector


SOURCE_DIR = r"H:\Downaloads\Meshy_AI_Smiling_Gingerbread_biped\Meshy_AI_Smiling_Gingerbread_biped"
FILES = [
    "Meshy_AI_Smiling_Gingerbread_biped_Animation_Walking_withSkin.glb",
    "Meshy_AI_Smiling_Gingerbread_biped_Animation_Running_withSkin.glb",
    "Meshy_AI_Smiling_Gingerbread_biped_Animation_Hip_Hop_Dance_4_withSkin.glb",
]


def reset_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for datablocks in [
        bpy.data.meshes,
        bpy.data.materials,
        bpy.data.images,
        bpy.data.armatures,
        bpy.data.actions,
    ]:
        for datablock in list(datablocks):
            datablocks.remove(datablock, do_unlink=True)


def object_bounds(mesh_objects):
    pts = []
    for obj in mesh_objects:
        pts.extend(obj.matrix_world @ Vector(corner) for corner in obj.bound_box)
    if not pts:
        return None
    return {
        axis: [
            round(min(getattr(p, axis) for p in pts), 5),
            round(max(getattr(p, axis) for p in pts), 5),
        ]
        for axis in ["x", "y", "z"]
    }


def inspect_file(filename):
    reset_scene()
    path = os.path.join(SOURCE_DIR, filename)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    imported = [obj for obj in bpy.data.objects if obj not in before]
    meshes = [obj for obj in imported if obj.type == "MESH"]
    armatures = [obj for obj in imported if obj.type == "ARMATURE"]
    return {
        "file": path,
        "objects": [
            {
                "name": obj.name,
                "type": obj.type,
                "parent": obj.parent.name if obj.parent else None,
                "modifiers": [
                    {
                        "name": mod.name,
                        "type": mod.type,
                        "object": getattr(mod, "object", None).name
                        if getattr(mod, "object", None)
                        else None,
                    }
                    for mod in getattr(obj, "modifiers", [])
                ],
            }
            for obj in imported
        ],
        "mesh_count": len(meshes),
        "mesh_vertices": [len(obj.data.vertices) for obj in meshes],
        "mesh_faces": [len(obj.data.polygons) for obj in meshes],
        "armatures": [
            {
                "name": obj.name,
                "bones": [bone.name for bone in obj.data.bones],
            }
            for obj in armatures
        ],
        "actions": [
            {
                "name": action.name,
                "frame_range": [float(action.frame_range[0]), float(action.frame_range[1])],
            }
            for action in bpy.data.actions
        ],
        "materials": [mat.name for mat in bpy.data.materials],
        "images": [
            {
                "name": image.name,
                "filepath": bpy.path.abspath(image.filepath),
                "packed": bool(image.packed_file),
                "size": list(image.size),
            }
            for image in bpy.data.images
        ],
        "bounds": object_bounds(meshes),
    }


result = [inspect_file(filename) for filename in FILES]
print("MESHY_GINGERBREAD_INSPECTION=" + json.dumps(result, ensure_ascii=False))
