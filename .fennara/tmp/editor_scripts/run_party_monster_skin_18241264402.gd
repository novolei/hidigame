@tool
extends RefCounted

const MODEL_SCENE_PATH := "res://assets/characters/party_monster/source/PartyMonsterRumblePBR/Mesh/DefaultCharacterMesh.fbx"
const DEFAULT_01_ALBEDO := "res://assets/characters/party_monster/source/PartyMonsterRumblePBR/Texture/DefaultPBR/DefaultPBR01_Albedo.png"
const DEFAULT_01_MS := "res://assets/characters/party_monster/source/PartyMonsterRumblePBR/Texture/DefaultPBR/DefaultPBR01_MetallicSmoothness.png"
const DEFAULT_01_AO := "res://assets/characters/party_monster/source/PartyMonsterRumblePBR/Texture/DefaultPBR/DefaultPBR01_AO.png"
const DEFAULT_02_ALBEDO := "res://assets/characters/party_monster/source/PartyMonsterRumblePBR/Texture/DefaultPBR/DefaultPBR02_Albedo.png"
const DEFAULT_02_MS := "res://assets/characters/party_monster/source/PartyMonsterRumblePBR/Texture/DefaultPBR/DefaultPBR02_MetallicSmoothness.png"
const DEFAULT_02_AO := "res://assets/characters/party_monster/source/PartyMonsterRumblePBR/Texture/DefaultPBR/DefaultPBR02_AO.png"

func run(ctx) -> void:
	var scene: Variant = load(MODEL_SCENE_PATH)
	if not scene is PackedScene:
		ctx.error("model load failed")
		return
	var root: Node = (scene as PackedScene).instantiate()
	if root == null:
		ctx.error("model instantiate failed")
		return
	_report_mesh_uv_stats(ctx, root, "MainBody01", DEFAULT_01_ALBEDO, DEFAULT_01_MS, DEFAULT_01_AO)
	_report_mesh_uv_stats(ctx, root, "Glove01", DEFAULT_02_ALBEDO, DEFAULT_02_MS, DEFAULT_02_AO)
	_report_mesh_uv_stats(ctx, root, "Eye01", DEFAULT_01_ALBEDO, DEFAULT_01_MS, DEFAULT_01_AO)
	_report_mesh_uv_stats(ctx, root, "Mouth01", DEFAULT_01_ALBEDO, DEFAULT_01_MS, DEFAULT_01_AO)
	root.free()

func _report_mesh_uv_stats(ctx: Variant, root: Node, mesh_name: String, albedo_path: String, ms_path: String, ao_path: String) -> void:
	var mesh_instance: MeshInstance3D = _find_mesh(root, mesh_name)
	if mesh_instance == null or mesh_instance.mesh == null:
		ctx.log("mesh_missing=%s" % mesh_name)
		return
	var albedo: Image = Image.load_from_file(albedo_path)
	var ms: Image = Image.load_from_file(ms_path)
	var ao: Image = Image.load_from_file(ao_path)
	if albedo == null or ms == null or ao == null:
		ctx.error("image load failed for %s" % mesh_name)
		return
	var sum_albedo: Color = Color(0.0, 0.0, 0.0, 0.0)
	var sum_ms: Color = Color(0.0, 0.0, 0.0, 0.0)
	var sum_ao: float = 0.0
	var sample_count: int = 0
	for surface: int in range(mesh_instance.mesh.get_surface_count()):
		var arrays: Array = mesh_instance.mesh.surface_get_arrays(surface)
		if arrays.size() <= Mesh.ARRAY_TEX_UV or not arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array:
			continue
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var step: int = maxi(1, int(uvs.size() / 128))
		for index: int in range(0, uvs.size(), step):
			var uv: Vector2 = uvs[index]
			var px: int = clampi(int(posmod(uv.x, 1.0) * float(albedo.get_width() - 1)), 0, albedo.get_width() - 1)
			var py: int = clampi(int(posmod(uv.y, 1.0) * float(albedo.get_height() - 1)), 0, albedo.get_height() - 1)
			sum_albedo += albedo.get_pixel(px, py)
			sum_ms += ms.get_pixel(px, py)
			sum_ao += ao.get_pixel(px, py).r
			sample_count += 1
	if sample_count <= 0:
		ctx.log("mesh=%s no uv samples" % mesh_name)
		return
	var mean_albedo: Color = sum_albedo / float(sample_count)
	var mean_ms: Color = sum_ms / float(sample_count)
	var mean_ao: float = sum_ao / float(sample_count)
	ctx.log("mesh=%s samples=%d mean_albedo=%s mean_ms_rgba=%s mean_ao=%.3f unity_smoothness_alpha=%.3f" % [mesh_name, sample_count, str(mean_albedo), str(mean_ms), mean_ao, mean_ms.a])

func _find_mesh(node: Node, mesh_name: String) -> MeshInstance3D:
	if node is MeshInstance3D and String(node.name) == mesh_name:
		return node as MeshInstance3D
	for child in node.get_children():
		var found: MeshInstance3D = _find_mesh(child, mesh_name)
		if found != null:
			return found
	return null
