"""
Connection Map:
  BaseModel.obj visual surface <-> voxel remesh shell    overlap: watertight voxel remesh
  remesh shell                 <-> Godot SDF grid        overlap: sampled signed distance field

This is an offline bake: it converts the artist-authored Basic Human idle FBX
into a watertight solid clone mesh and a compact SDF body profile for the
in-game clay shell. The generated profile is loaded at runtime instead of
voxelizing the player mesh during the C-key environment blend skill.
"""

import json
import math
import os
import sys

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SOURCE_MODEL = os.path.join(ROOT, "assets", "characters", "basic", "animations", "BaseModel@Idle.fbx")
OUTPUT_OBJ = os.path.join(ROOT, "assets", "characters", "basic", "basic_human_solid_clone_remesh.obj")
OUTPUT_JSON = os.path.join(ROOT, "assets", "characters", "basic", "basic_human_solid_clone_profile.json")

GRID_WIDTH = 32
GRID_HEIGHT = 32
GRID_DEPTH = 32
VOXEL_SCALE = 0.0625
GRID_MIN = (-1.0, 0.0, -1.0)
BASIC_HUMAN_PLAYABLE_HEIGHT = 1.75
SNAPSHOT_SDF_SCALE = 1024.0
BASIC_HUMAN_COLOR = "b8adff"
SDF_SURFACE_INFLATE = 0.035


def log(message):
    print("[BakeBasicHumanSolidClone] " + message)


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def import_model(path):
    extension = os.path.splitext(path)[1].lower()
    if extension == ".fbx":
        bpy.ops.import_scene.fbx(filepath=path)
    elif hasattr(bpy.ops.wm, "obj_import"):
        bpy.ops.wm.obj_import(filepath=path)
    else:
        bpy.ops.import_scene.obj(filepath=path)
    bpy.context.scene.frame_set(1)
    bpy.context.view_layer.update()
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError("No mesh objects imported from " + path)
    depsgraph = bpy.context.evaluated_depsgraph_get()
    vertices = []
    faces = []
    for source in meshes:
        evaluated = source.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        mesh.calc_loop_triangles()
        vertex_offset = len(vertices)
        vertices.extend([evaluated.matrix_world @ vertex.co for vertex in mesh.vertices])
        faces.extend([
            tuple(vertex_offset + int(index) for index in tri.vertices)
            for tri in mesh.loop_triangles
        ])
        evaluated.to_mesh_clear()
    baked_mesh = bpy.data.meshes.new("BasicHumanIdleEvaluatedMesh")
    baked_mesh.from_pydata([tuple(vertex) for vertex in vertices], [], faces)
    baked_mesh.update()
    baked = bpy.data.objects.new("BasicHumanIdleSource", baked_mesh)
    bpy.context.collection.objects.link(baked)
    bpy.ops.object.select_all(action="SELECT")
    baked.select_set(False)
    bpy.ops.object.delete()
    bpy.context.view_layer.objects.active = baked
    baked.select_set(True)
    return baked


def transform_to_godot_local(obj):
    mesh = obj.data
    vertices = [v.co.copy() for v in mesh.vertices]
    min_x = min(v.x for v in vertices)
    max_x = max(v.x for v in vertices)
    min_y = min(v.y for v in vertices)
    max_y = max(v.y for v in vertices)
    min_z = min(v.z for v in vertices)
    max_z = max(v.z for v in vertices)
    center_x = (min_x + max_x) * 0.5
    center_y = (min_y + max_y) * 0.5
    height = max(max_z - min_z, 0.0001)
    scale = BASIC_HUMAN_PLAYABLE_HEIGHT / height
    for vertex in mesh.vertices:
        source = vertex.co.copy()
        vertex.co = Vector((
            (source.x - center_x) * scale,
            (source.z - min_z) * scale + 0.04,
            (source.y - center_y) * scale,
        ))
    mesh.update()
    return scale


def voxel_remesh(obj):
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    modifier = obj.modifiers.new("SolidCloneVoxelRemesh", "REMESH")
    modifier.mode = "VOXEL"
    modifier.voxel_size = 0.035
    modifier.adaptivity = 0.0
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.ops.object.shade_smooth()
    obj.name = "BasicHumanSolidCloneRemesh"
    obj.data.name = "BasicHumanSolidCloneRemeshMesh"
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


def export_obj_raw(obj, path):
    mesh = obj.data
    mesh.calc_loop_triangles()
    with open(path, "w", encoding="utf-8") as handle:
        handle.write("# Baked from BaseModel@Idle.fbx by bake_basic_human_solid_clone_blender.py\n")
        handle.write("o BasicHumanSolidCloneRemesh\n")
        for vertex in mesh.vertices:
            co = vertex.co
            handle.write("v %.6f %.6f %.6f\n" % (co.x, co.y, co.z))
        for tri in mesh.loop_triangles:
            a, b, c = tri.vertices
            handle.write("f %d %d %d\n" % (a + 1, b + 1, c + 1))


def build_bvh(obj):
    mesh = obj.data
    mesh.calc_loop_triangles()
    verts = [obj.matrix_world @ v.co for v in mesh.vertices]
    polys = [tuple(tri.vertices) for tri in mesh.loop_triangles]
    return BVHTree.FromPolygons(verts, polys, all_triangles=True), verts, polys


def ray_inside(bvh, point):
    direction = Vector((1.0, 0.271, 0.173)).normalized()
    origin = Vector(point)
    remaining = 8.0
    hits = 0
    for _ in range(96):
        loc, _normal, _index, dist = bvh.ray_cast(origin, direction, remaining)
        if loc is None:
            break
        hits += 1
        step = max(dist, 0.0001) + 0.0003
        origin = origin + direction * step
        remaining -= step
        if remaining <= 0.0:
            break
    return hits % 2 == 1


def clamp_sdf(value):
    if math.isnan(value) or value > 1.0:
        return 1.0
    if value < -1.0:
        return -1.0
    return value


def voxel_center(x, y, z):
    return Vector((
        GRID_MIN[0] + (x + 0.5) * VOXEL_SCALE,
        GRID_MIN[1] + (y + 0.5) * VOXEL_SCALE,
        GRID_MIN[2] + (z + 0.5) * VOXEL_SCALE,
    ))


def encode_int_rle(values):
    if not values:
        return []
    encoded = []
    current = int(values[0])
    count = 1
    for raw in values[1:]:
        value = int(raw)
        if value == current and count < 65535:
            count += 1
            continue
        encoded.append([current, count])
        current = value
        count = 1
    encoded.append([current, count])
    return encoded


def compact_checksum(sdf_q, color_indices):
    checksum = 29
    for i, value in enumerate(sdf_q):
        checksum = (checksum * 131 + int(value) + i * 17) & 0x7FFFFFFF
    for i, value in enumerate(color_indices):
        checksum = (checksum * 131 + int(value) + i * 31) & 0x7FFFFFFF
    return checksum


def bake_profile(obj):
    bvh, _verts, _polys = build_bvh(obj)
    sdf_q = []
    color_indices = []
    solid_count = 0
    for z in range(GRID_DEPTH):
        for y in range(GRID_HEIGHT):
            for x in range(GRID_WIDTH):
                center = voxel_center(x, y, z)
                nearest = bvh.find_nearest(center)
                distance = nearest[3] if nearest and nearest[0] is not None else VOXEL_SCALE
                inside = ray_inside(bvh, center)
                signed = (-distance if inside else distance) - SDF_SURFACE_INFLATE
                normalized = clamp_sdf(signed / VOXEL_SCALE)
                if normalized <= 0.0:
                    solid_count += 1
                sdf_q.append(max(-32768, min(32767, int(round(normalized * SNAPSHOT_SDF_SCALE)))))
                color_indices.append(0)
    body = {
        "version": 1,
        "grid": [GRID_WIDTH, GRID_HEIGHT, GRID_DEPTH],
        "voxel_scale": VOXEL_SCALE,
        "sdf_scale": SNAPSHOT_SDF_SCALE,
        "sdf_q_rle": encode_int_rle(sdf_q),
        "palette": [BASIC_HUMAN_COLOR],
        "color_indices_rle": encode_int_rle(color_indices),
        "solid_count": solid_count,
        "checksum": compact_checksum(sdf_q, color_indices),
    }
    return {
        "name": "BasicHumanSolidClone",
        "source": "basic_humanoid_blender_remesh_solid_clone",
        "source_model": "res://assets/characters/basic/animations/BaseModel@Idle.fbx",
        "source_mesh": "res://assets/characters/basic/basic_human_solid_clone_remesh.obj",
        "body": body,
        "notes": "Offline Blender voxel-remesh bake from BaseModel.obj. Loaded directly by the Chameleon clay shell.",
    }


def main():
    if not os.path.exists(SOURCE_MODEL):
        raise FileNotFoundError(SOURCE_MODEL)
    clear_scene()
    source = import_model(SOURCE_MODEL)
    scale = transform_to_godot_local(source)
    solid = voxel_remesh(source)
    export_obj_raw(solid, OUTPUT_OBJ)
    payload = bake_profile(solid)
    with open(OUTPUT_JSON, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, ensure_ascii=False, indent="\t")
    mesh = solid.data
    log("source_scale=%.6f remesh_vertices=%d remesh_triangles=%d solid_voxels=%d checksum=%s" % (
        scale,
        len(mesh.vertices),
        len(mesh.loop_triangles),
        payload["body"]["solid_count"],
        payload["body"]["checksum"],
    ))
    log("wrote " + OUTPUT_OBJ)
    log("wrote " + OUTPUT_JSON)


if __name__ == "__main__":
    main()
