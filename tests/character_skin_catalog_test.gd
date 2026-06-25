extends SceneTree


func _init() -> void:
	var failures: Array[String] = []
	var party_monster_count := 0
	for model in CharacterSkinCatalog.all():
		var model_id := str(model.get("id", ""))
		var scene_path := str(model.get("scene", ""))
		if CharacterSkinCatalog.is_party_monster(model_id):
			party_monster_count += 1
			if scene_path != CharacterSkinCatalog.PARTY_MONSTER_SCENE_PATH:
				failures.append("Party Monster variants should use the shared wrapper scene")
		if scene_path.is_empty():
			continue
		var scene := load(scene_path)
		if not scene is PackedScene:
			failures.append("Model %s did not load as PackedScene: %s" % [model_id, scene_path])
			continue
		var node := (scene as PackedScene).instantiate()
		if not node is Node3D:
			failures.append("Model %s did not instantiate as Node3D" % model_id)
		if model_id == "gingerbread" and node:
			if scene_path != "res://assets/characters/gingerbread/gingerbread_animated_skin.tscn":
				failures.append("Gingerbread should use the animated skin wrapper scene")
			var gingerbread_skin_source := FileAccess.get_file_as_string("res://assets/characters/gingerbread/gingerbread_animated_skin.gd")
			var gingerbread_asset_paths := [
				"res://assets/characters/gingerbread/gingerbread_24k_animated.glb",
				"res://assets/characters/gingerbread/gingerbread_24k_animated_texture_diffuse.png",
				"res://assets/characters/gingerbread/gingerbread_24k_animated_texture_normal.png",
				"res://assets/characters/gingerbread/gingerbread_24k_animated_texture_metallic-texture_roughness.png",
			]
			for required_path in gingerbread_asset_paths:
				if not FileAccess.file_exists(required_path):
					failures.append("Gingerbread source asset is missing: %s" % required_path)
				if required_path.ends_with(".glb") and not gingerbread_skin_source.contains(required_path):
					failures.append("Gingerbread wrapper should load source asset: %s" % required_path)
			if node.has_method("_build_skin"):
				node.call("_build_skin")
			if not (node as Node3D).has_node("GingerbreadVisual"):
				failures.append("Gingerbread skin did not instantiate its 24K GLB visual")
			if not _has_descendant_named(node, "Skeleton3D"):
				failures.append("Gingerbread skin should keep the imported Skeleton3D")
			var gingerbread_animation_player := _find_animation_player(node)
			if not gingerbread_animation_player:
				failures.append("Gingerbread skin should include an AnimationPlayer for its imported skeleton")
			else:
				for animation_name in ["EXPORT_idle", "EXPORT_walk", "EXPORT_run", "EXPORT_jump", "EXPORT_fall", "EXPORT_crouch", "EXPORT_prone", "EXPORT_prone_crawl"]:
					if not gingerbread_animation_player.has_animation(animation_name):
						failures.append("Gingerbread imported AnimationPlayer is missing animation: %s" % animation_name)
			for method_name in ["idle", "move", "run", "jump", "fall", "land", "crouch", "prone", "prone_crawl"]:
				if not node.has_method(method_name):
					failures.append("Gingerbread skin is missing action method: %s" % method_name)
			for action_name in ["idle", "walk", "run", "jump", "fall", "crouch", "prone", "prone_crawl"]:
				if node.has_method("has_action") and not node.call("has_action", action_name):
					failures.append("Gingerbread skin should expose gameplay-compatible action: %s" % action_name)
			var gingerbread_triangle_count := _count_triangles(node)
			if gingerbread_triangle_count <= 0:
				failures.append("Gingerbread 24K GLB should expose a paintable mesh")
			elif gingerbread_triangle_count < 18000 or gingerbread_triangle_count > 30000:
				failures.append("Gingerbread 24K GLB runtime mesh should stay near the 24K target; got %d triangles" % gingerbread_triangle_count)
			var gingerbread_bounds := _calculate_bounds(node)
			if gingerbread_bounds.size.y < 1.0 or gingerbread_bounds.size.y > 2.2:
				failures.append("Gingerbread skin should be player-sized after scaling; got height %.2f" % gingerbread_bounds.size.y)
			if gingerbread_bounds.size.y <= gingerbread_bounds.size.z:
				failures.append("Gingerbread skin should stand upright on the Y axis; got bounds %s" % [gingerbread_bounds])
			var gingerbread_skeleton := _find_skeleton(node)
			if gingerbread_skeleton:
				var upper_arm_index := gingerbread_skeleton.find_bone("Bone.001")
				if upper_arm_index < 0:
					failures.append("Gingerbread skeleton should include Bone.001 for imported action animation")
				elif node.has_method("run"):
					node.call("run")
					gingerbread_animation_player.advance(0.18)
					var pose_rotation := gingerbread_skeleton.get_bone_pose_rotation(upper_arm_index)
					if _quaternion_offset_from_identity(pose_rotation) < 0.01:
						failures.append("Gingerbread run animation should rotate Bone.001 through Skeleton3D bone tracks")
		if model_id == "basic_humanoid" and node:
			if scene_path != "res://assets/characters/basic/basic_humanoid_skin.tscn":
				failures.append("Basic humanoid should use the Basic wrapper scene")
			var basic_skin_source := FileAccess.get_file_as_string("res://assets/characters/basic/basic_humanoid_skin.gd")
			for required_path in [
				"res://assets/characters/basic/BaseModel.fbx",
				"res://assets/characters/basic/animations/BaseModel@Idle.fbx",
				"res://assets/characters/basic/animations/BaseModel@Jump.fbx",
				"res://assets/characters/basic/animations/BaseModel@Running.fbx",
			]:
				if not FileAccess.file_exists(required_path):
					failures.append("Basic humanoid source asset is missing: %s" % required_path)
				if not basic_skin_source.contains(required_path):
					failures.append("Basic humanoid wrapper should load source asset: %s" % required_path)
			if node.has_method("_build_skin"):
				node.call("_build_skin")
			if not (node as Node3D).has_node("BasicHumanoidVisual"):
				failures.append("Basic humanoid skin did not instantiate its source FBX")
			for method_name in ["idle", "move", "run", "jump", "fall"]:
				if not node.has_method(method_name):
					failures.append("Basic humanoid skin is missing action method: %s" % method_name)
			for action_name in ["idle", "run", "jump", "fall"]:
				if node.has_method("has_action") and not node.call("has_action", action_name):
					failures.append("Basic humanoid skin should expose gameplay-compatible action: %s" % action_name)
		if model_id == "hunter_shooter" and node:
			if scene_path != "res://assets/characters/hunter_shooter/hunter_shooter_skin.tscn":
				failures.append("Hunter shooter should use the hunter-shooter wrapper scene")
			var hunter_skin_source := FileAccess.get_file_as_string("res://assets/characters/hunter_shooter/hunter_shooter_skin.gd")
			var hunter_model_path := "res://assets/characters/hunter_shooter/GodotRobot3rdPersonShooterFinal.glb"
			if not FileAccess.file_exists(hunter_model_path):
				failures.append("Hunter shooter GLB should exist")
			if not hunter_skin_source.contains(hunter_model_path):
				failures.append("Hunter shooter wrapper should load the provided GLB")
			if node.has_method("_build_skin"):
				node.call("_build_skin")
			if not (node as Node3D).has_node("HunterShooterVisual"):
				failures.append("Hunter shooter skin did not instantiate its GLB visual")
			if not _has_descendant_named(node, "Rifle"):
				failures.append("Hunter shooter skin should keep the integrated Rifle node")
			for method_name in ["idle", "move", "run", "jump", "fall", "attack"]:
				if not node.has_method(method_name):
					failures.append("Hunter shooter skin is missing action method: %s" % method_name)
			for action_name in ["idle", "run", "jump", "fall", "attack"]:
				if node.has_method("has_action") and not node.call("has_action", action_name):
					failures.append("Hunter shooter skin should expose gameplay-compatible action: %s" % action_name)
		if model_id == "bud" and node:
			if scene_path != "res://assets/characters/bud/bud_skin.tscn":
				failures.append("Bud should use the Bud wrapper scene")
			var bud_skin_source := FileAccess.get_file_as_string("res://assets/characters/bud/bud_skin.gd")
			var bud_model_path := "res://assets/characters/bud/bud_character.glb"
			if not FileAccess.file_exists(bud_model_path):
				failures.append("Bud GLB should exist")
			if not bud_skin_source.contains(bud_model_path):
				failures.append("Bud wrapper should load the generated GLB")
			if node.has_method("_build_skin"):
				node.call("_build_skin")
			if not (node as Node3D).has_node("BudVisual"):
				failures.append("Bud skin did not instantiate its GLB visual")
			var bud_bounds := _calculate_bounds(node)
			if bud_bounds.position.y < -0.01:
				failures.append("Bud skin should ground its visual model at player feet; got lower Y %.3f" % bud_bounds.position.y)
			var bud_catalog_scale: Vector3 = model.get("scale", Vector3.ONE)
			var bud_catalog_offset: Vector3 = model.get("offset", Vector3.ZERO)
			var bud_scaled_height := bud_bounds.size.y * bud_catalog_scale.y
			if bud_scaled_height < 0.65 or bud_scaled_height > 0.9:
				failures.append("Bud catalog scale should make it player-readable; got scaled height %.2f" % bud_scaled_height)
			if bud_catalog_offset.y < 0.08 or bud_catalog_offset.y > 0.26:
				failures.append("Bud catalog offset should keep its small legs above the floor; got offset Y %.2f" % bud_catalog_offset.y)
			var bud_animation_player := _find_animation_player(node)
			if not bud_animation_player:
				failures.append("Bud skin should include imported gameplay animations")
			else:
				for animation_name in ["idle", "walk", "run", "jump", "fall", "crouch", "prone"]:
					if not node.call("has_action", animation_name):
						failures.append("Bud skin should expose gameplay-compatible action: %s" % animation_name)
			for method_name in ["idle", "move", "run", "jump", "fall", "crouch", "prone"]:
				if not node.has_method(method_name):
					failures.append("Bud skin is missing action method: %s" % method_name)
		if model_id == "walkall" and node:
			if scene_path != "res://assets/characters/walkall/walkall_skin.tscn":
				failures.append("Walkall should use the Walkall wrapper scene")
			var walkall_skin_source := FileAccess.get_file_as_string("res://assets/characters/walkall/walkall_skin.gd")
			var walkall_model_path := "res://assets/characters/walkall/walkall.fbx"
			if not FileAccess.file_exists(walkall_model_path):
				failures.append("Walkall source FBX is missing")
			if not walkall_skin_source.contains(walkall_model_path):
				failures.append("Walkall wrapper should load the provided FBX")
			if node.has_method("_build_skin"):
				node.call("_build_skin")
			if not (node as Node3D).has_node("WalkallVisual"):
				failures.append("Walkall skin did not instantiate its FBX visual")
			if not _has_descendant_named(node, "pCube20"):
				failures.append("Walkall skin should keep the skinned mesh from walkall.fbx")
			var walkall_skeleton := _find_skeleton_with_bone(node, "QuickRigCharacter_Hips")
			if not walkall_skeleton:
				failures.append("Walkall skeleton should include QuickRigCharacter_Hips")
			var walkall_animation_player := _find_animation_player(node)
			if not walkall_animation_player:
				failures.append("Walkall skin should include the imported AnimationPlayer")
			elif not walkall_animation_player.has_animation("all"):
				failures.append("Walkall imported AnimationPlayer should expose the all animation")
			for method_name in ["idle", "move", "run", "jump", "fall", "crouch", "prone"]:
				if not node.has_method(method_name):
					failures.append("Walkall skin is missing action method: %s" % method_name)
			for action_name in ["idle", "walk", "run", "jump", "fall", "crouch", "prone"]:
				if node.has_method("has_action") and not node.call("has_action", action_name):
					failures.append("Walkall skin should expose gameplay-compatible action: %s" % action_name)
			var walkall_bounds := _calculate_bounds(node)
			if walkall_bounds.position.y < -0.01:
				failures.append("Walkall skin should ground its FBX at player feet; got lower Y %.3f" % walkall_bounds.position.y)
			var walkall_catalog_scale: Vector3 = model.get("scale", Vector3.ONE)
			var walkall_scaled_height := walkall_bounds.size.y * walkall_catalog_scale.y
			if walkall_scaled_height < 1.2 or walkall_scaled_height > 1.8:
				failures.append("Walkall catalog scale should make the tiny FBX player-sized; got scaled height %.2f" % walkall_scaled_height)
			if walkall_animation_player:
				node.call("run")
				walkall_animation_player.advance(0.18)
				if walkall_animation_player.current_animation != "all":
					failures.append("Walkall run should drive the imported all animation segment")
		if model_id == "cute_ice_cream" and node:
			if scene_path != "res://assets/characters/cute_ice_cream/cute_ice_cream_skin.tscn":
				failures.append("Cute Ice Cream should use the wrapper scene")
			var ice_cream_skin_source := FileAccess.get_file_as_string("res://assets/characters/cute_ice_cream/cute_ice_cream_skin.gd")
			for required_path in [
				"res://assets/characters/cute_ice_cream/ice_cream.fbx",
				"res://assets/characters/cute_ice_cream/obj/ice_cream.obj",
				"res://assets/characters/cute_ice_cream/obj/Ice cream.mtl",
				"res://assets/characters/cute_ice_cream/images/thumbnail.png",
			]:
				if not FileAccess.file_exists(required_path):
					failures.append("Cute Ice Cream source asset is missing: %s" % required_path)
			if not ice_cream_skin_source.contains("res://assets/characters/cute_ice_cream/ice_cream.fbx"):
				failures.append("Cute Ice Cream wrapper should load the provided FBX")
			if node.has_method("_build_skin"):
				node.call("_build_skin")
			if not (node as Node3D).has_node("CuteIceCreamVisual"):
				failures.append("Cute Ice Cream skin did not instantiate its FBX visual")
			for required_mesh in ["Body", "Face", "Pants", "wood"]:
				if not _has_descendant_named(node, required_mesh):
					failures.append("Cute Ice Cream skin is missing mesh: %s" % required_mesh)
			var ice_cream_animation_player := _find_animation_player(node)
			if not ice_cream_animation_player:
				failures.append("Cute Ice Cream skin should generate an AnimationPlayer")
			else:
				for animation_name in ["idle", "walk", "run", "jump", "fall", "crouch", "prone", "prone_crawl"]:
					if not ice_cream_animation_player.has_animation(animation_name):
						failures.append("Cute Ice Cream generated AnimationPlayer is missing animation: %s" % animation_name)
			for method_name in ["idle", "move", "run", "jump", "fall", "crouch", "prone", "prone_crawl"]:
				if not node.has_method(method_name):
					failures.append("Cute Ice Cream skin is missing action method: %s" % method_name)
			for action_name in ["idle", "walk", "run", "jump", "fall", "crouch", "prone", "prone_crawl"]:
				if node.has_method("has_action") and not node.call("has_action", action_name):
					failures.append("Cute Ice Cream skin should expose gameplay-compatible action: %s" % action_name)
			var ice_cream_bounds := _calculate_bounds(node)
			if ice_cream_bounds.position.y < -0.01:
				failures.append("Cute Ice Cream skin should ground its FBX at player feet; got lower Y %.3f" % ice_cream_bounds.position.y)
			var ice_cream_catalog_scale: Vector3 = model.get("scale", Vector3.ONE)
			var ice_cream_scaled_height := ice_cream_bounds.size.y * ice_cream_catalog_scale.y
			if ice_cream_scaled_height < 1.35 or ice_cream_scaled_height > 1.7:
				failures.append("Cute Ice Cream catalog scale should make it player-sized; got scaled height %.2f" % ice_cream_scaled_height)
			var material_surface_count := _count_standard_material_surfaces(node)
			if material_surface_count < 5:
				failures.append("Cute Ice Cream should preserve the source color-material surfaces; got %d" % material_surface_count)
			if ice_cream_animation_player:
				node.call("run")
				ice_cream_animation_player.advance(0.18)
				if ice_cream_animation_player.current_animation != "run":
					failures.append("Cute Ice Cream run should drive the generated run animation")
		if node:
			node.free()

	if party_monster_count < 36:
		failures.append("Party Monster catalog should expose all imported variants; got %d" % party_monster_count)
	if CharacterSkinCatalog.normalize(CharacterSkinCatalog.party_monster_default_id()) != CharacterSkinCatalog.party_monster_default_id():
		failures.append("Party Monster default id should normalize to itself")
	var party_monster_model := CharacterSkinCatalog.get_model(CharacterSkinCatalog.party_monster_default_id())
	var party_monster_offset: Vector3 = party_monster_model.get("offset", Vector3.ZERO)
	if absf(party_monster_offset.y - CharacterSkinCatalog.PARTY_MONSTER_GAMEPLAY_GROUND_OFFSET) > 0.001:
		failures.append("Party Monster gameplay offset should match the grounded visual calibration")
	if party_monster_offset.y > -0.15:
		failures.append("Party Monster gameplay offset should sink the round visual toward the floor")
	_append_party_monster_pbr_failures(failures)
	_append_character_setup_overlay_perf_failures(failures)

	if failures.is_empty():
		print("[CharacterSkinCatalogTest] PASS")
		quit(0)
	else:
		for failure in failures:
			push_error("[CharacterSkinCatalogTest] " + failure)
		quit(1)


func _append_character_setup_overlay_perf_failures(failures: Array[String]) -> void:
	var overlay_path := "res://scripts/character_setup_overlay.gd"
	if not FileAccess.file_exists(overlay_path):
		failures.append("Character setup overlay script should exist")
		return
	var overlay_source := FileAccess.get_file_as_string(overlay_path)
	for forbidden_token in ["SMOKE_TEXTURE_PATH", "NOISE_TEXTURE_PATH", "_make_haze_material", "_add_preview_mist", "ThumbViewport", "_make_skin_thumbnail_viewport", "_thumbnail_queue", "THUMBNAILS_PER_FRAME"]:
		if overlay_source.contains(forbidden_token):
			failures.append("Character setup overlay should not use heavy smoke or per-card 3D thumbnail token: %s" % forbidden_token)
	if not overlay_source.contains("SETUP_BACKGROUND_COLOR := Color(0.76, 0.88, 0.98, 1.0)"):
		failures.append("Character setup overlay should use the opaque pale sky-blue background")
	if not overlay_source.contains("TextureRect.new()") or not overlay_source.contains("ImageTexture.create_from_image"):
		failures.append("Character setup overlay should use lightweight generated 2D skin thumbnails")
	if not overlay_source.contains("SubViewport.UPDATE_DISABLED") or not overlay_source.contains("_request_preview_model_load"):
		failures.append("Character setup overlay should idle its 3D preview viewport and defer preview model loading")


func _append_party_monster_pbr_failures(failures: Array[String]) -> void:
	_expect_party_monster_shader_source("res://assets/characters/party_monster/party_monster_default_pbr.gdshader", failures)
	_expect_party_monster_shader_source("res://assets/characters/party_monster/party_monster_mask_tint.gdshader", failures)
	var default_skin: Node = _instantiate_party_monster_skin("party_monster_c01", failures)
	if default_skin:
		_expect_party_monster_shader_texture(default_skin, "MainBody01", "albedo_texture", "DefaultPBR01_Albedo.png", failures)
		_expect_party_monster_shader_texture(default_skin, "Eye01", "albedo_texture", "DefaultPBR01_Albedo.png", failures)
		_expect_party_monster_shader_texture(default_skin, "Mouth01", "albedo_texture", "DefaultPBR01_Albedo.png", failures)
		_expect_party_monster_shader_texture(default_skin, "Glove01", "albedo_texture", "DefaultPBR02_Albedo.png", failures)
		_expect_party_monster_shader_texture(default_skin, "Hat16", "albedo_texture", "DefaultPBR02_Albedo.png", failures)
		default_skin.free()

	var mask_tint_skin: Node = _instantiate_party_monster_skin("party_monster_masktint01", failures)
	if mask_tint_skin:
		_expect_party_monster_shader_texture(mask_tint_skin, "MainBody01", "albedo_texture", "MaskTintPBR/Albedo01.png", failures)
		_expect_party_monster_shader_texture(mask_tint_skin, "Glove01", "albedo_texture", "MaskTintPBR/Albedo02.png", failures)
		mask_tint_skin.free()


func _expect_party_monster_shader_source(shader_path: String, failures: Array[String]) -> void:
	if not FileAccess.file_exists(shader_path):
		failures.append("Party Monster shader should exist: %s" % shader_path)
		return
	var shader_source: String = FileAccess.get_file_as_string(shader_path)
	if not shader_source.contains("cull_back"):
		failures.append("Party Monster shader should keep backface culling to avoid hollow interiors: %s" % shader_path)
	if shader_source.contains("cull_disabled"):
		failures.append("Party Monster shader should not render model interiors double-sided: %s" % shader_path)
	for forbidden_token in ["albedo_boost", "ambient_fill", "EMISSION", "roughness_floor", "ALPHA", "blend_", "DIFFUSE_LIGHT", "SPECULAR_LIGHT", "_party_monster_soft_vinyl_tone", "_party_monster_toy_tone", "toy_midtone_lift", "toy_highlight_milk", "RIM =", "AO = 1.0", "ROUGHNESS = toy_roughness"]:
		if shader_source.contains(forbidden_token):
			failures.append("Party Monster shader should stay as a lightweight opaque PBR bridge without old bias, transparency, custom-light, fixed-AO, or extra tone token %s in %s" % [forbidden_token, shader_path])
	if not shader_source.contains("METALLIC = clamp(unity_metallic * metallic_strength"):
		failures.append("Party Monster shader should keep imported metallic as a tunable PBR channel: %s" % shader_path)
	if not shader_source.contains("ROUGHNESS = clamp(1.0 - unity_smoothness, min_roughness, max_roughness)"):
		failures.append("Party Monster shader should use Unity smoothness with bounded Godot roughness instead of a flat material: %s" % shader_path)
	if not shader_source.contains("AO = mix(1.0, unity_occlusion, occlusion_strength)"):
		failures.append("Party Monster shader should preserve imported AO at a tunable strength for 3D form: %s" % shader_path)
	if not shader_source.contains("SPECULAR = specular_level"):
		failures.append("Party Monster shader should expose a lightweight specular control: %s" % shader_path)
	for required_token in ["surface_tint", "pastel_blend", "saturation", "highlight_rolloff", "shadow_warmth"]:
		if not shader_source.contains(required_token):
			failures.append("Party Monster shader should expose lightweight warm soft-toy color control %s in %s" % [required_token, shader_path])
	if shader_path.ends_with("party_monster_default_pbr.gdshader"):
		if not shader_source.contains("ALBEDO = final_albedo"):
			failures.append("Party Monster default PBR should keep opaque albedo color shaping inside a lightweight final_albedo path")
		if not shader_source.contains("float unity_metallic = clamp(metallic_smoothness.r"):
			failures.append("Party Monster default PBR should read metallic from metallic-smoothness red channel")
		if not shader_source.contains("float unity_smoothness = clamp(metallic_smoothness.a"):
			failures.append("Party Monster default PBR should read Unity smoothness from metallic-smoothness alpha channel")
		if not shader_source.contains("float unity_occlusion = clamp(ambient_occlusion.g"):
			failures.append("Party Monster default PBR should read occlusion from AO green channel")
	if shader_path.ends_with("party_monster_mask_tint.gdshader"):
		if not shader_source.contains("ALBEDO = final_albedo"):
			failures.append("Party Monster mask tint should keep the Unity mask-tinted albedo without extra tone mapping")
		if not shader_source.contains("vec3 tinted = clamp((base * tint).rgb"):
			failures.append("Party Monster mask tint should preserve Unity multiply tint blending")
		if not shader_source.contains("float unity_metallic = clamp(sam.b"):
			failures.append("Party Monster mask tint should read metallic from SAM blue channel")
		if not shader_source.contains("float unity_smoothness = clamp(sam.r"):
			failures.append("Party Monster mask tint should read Unity smoothness from SAM red channel")
		if not shader_source.contains("float unity_occlusion = clamp(sam.g"):
			failures.append("Party Monster mask tint should read occlusion from SAM green channel")
		if not shader_source.contains("float mask_amount = clamp"):
			failures.append("Party Monster mask tint shader should clamp mask accumulation before tint blending")


func _instantiate_party_monster_skin(model_id: String, failures: Array[String]) -> Node:
	var scene_path: String = CharacterSkinCatalog.PARTY_MONSTER_SCENE_PATH
	var loaded_scene: Variant = load(scene_path)
	if not loaded_scene is PackedScene:
		failures.append("Party Monster wrapper did not load as PackedScene: %s" % scene_path)
		return null
	var skin: Node = (loaded_scene as PackedScene).instantiate()
	if skin == null:
		failures.append("Party Monster wrapper did not instantiate for material checks")
		return null
	if not skin.has_method("set_character_model_id") or not skin.has_method("_build_skin"):
		failures.append("Party Monster wrapper should expose runtime skin build methods")
		skin.free()
		return null
	skin.call("set_character_model_id", model_id)
	skin.call("_build_skin")
	return skin


func _expect_party_monster_shader_texture(skin: Node, mesh_name: String, parameter_name: String, expected_path_fragment: String, failures: Array[String]) -> void:
	var material: Material = _find_mesh_material(skin, mesh_name)
	if material == null:
		failures.append("Party Monster mesh should receive a material override: %s" % mesh_name)
		return
	if not material is ShaderMaterial:
		failures.append("Party Monster mesh should use the restored PBR shader material: %s" % mesh_name)
		return
	var texture_value: Variant = (material as ShaderMaterial).get_shader_parameter(parameter_name)
	if not texture_value is Texture2D:
		failures.append("Party Monster mesh %s should expose shader texture parameter %s" % [mesh_name, parameter_name])
		return
	var texture_path: String = (texture_value as Texture2D).resource_path
	if not texture_path.contains(expected_path_fragment):
		failures.append("Party Monster mesh %s should use %s; got %s" % [mesh_name, expected_path_fragment, texture_path])


func _find_mesh_material(node: Node, mesh_name: String) -> Material:
	if node is MeshInstance3D and String(node.name) == mesh_name:
		var mesh_instance := node as MeshInstance3D
		var override_material: Material = mesh_instance.get_surface_override_material(0)
		if override_material:
			return override_material
		if mesh_instance.mesh and mesh_instance.mesh.get_surface_count() > 0:
			return mesh_instance.mesh.surface_get_material(0)
		return null
	for child in node.get_children():
		var found := _find_mesh_material(child, mesh_name)
		if found:
			return found
	return null


func _count_triangles(node: Node) -> int:
	var total := 0
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		if mesh:
			for surface in range(mesh.get_surface_count()):
				var arrays := mesh.surface_get_arrays(surface)
				if arrays.size() <= Mesh.ARRAY_VERTEX or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
					continue
				var indices := PackedInt32Array()
				if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
					indices = arrays[Mesh.ARRAY_INDEX]
				if not indices.is_empty():
					total += floori(float(indices.size()) / 3.0)
				else:
					var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					total += floori(float(vertices.size()) / 3.0)
	for child in node.get_children():
		total += _count_triangles(child)
	return total


func _has_descendant_named(node: Node, node_name: String) -> bool:
	if node.name == node_name:
		return true
	for child in node.get_children():
		if _has_descendant_named(child, node_name):
			return true
	return false


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null


func _find_skeleton_with_bone(node: Node, bone_name: String) -> Skeleton3D:
	if node is Skeleton3D and (node as Skeleton3D).find_bone(bone_name) >= 0:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton_with_bone(child, bone_name)
		if found:
			return found
	return null


func _quaternion_offset_from_identity(quaternion: Quaternion) -> float:
	return absf(quaternion.x) + absf(quaternion.y) + absf(quaternion.z) + absf(quaternion.w - 1.0)


func _count_standard_material_surfaces(node: Node) -> int:
	var count := 0
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh:
			for surface in range(mesh_instance.mesh.get_surface_count()):
				var material := mesh_instance.mesh.surface_get_material(surface)
				if mesh_instance.get_surface_override_material(surface):
					material = mesh_instance.get_surface_override_material(surface)
				if material is StandardMaterial3D:
					count += 1
	for child in node.get_children():
		count += _count_standard_material_surfaces(child)
	return count


func _calculate_bounds(node: Node) -> AABB:
	return _calculate_bounds_with_transform(node, Transform3D.IDENTITY)


func _calculate_bounds_with_transform(node: Node, parent_transform: Transform3D) -> AABB:
	var local_transform := parent_transform
	if node is Node3D:
		local_transform = parent_transform * (node as Node3D).transform
	var initialized := false
	var bounds := AABB()
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		var mesh_bounds := _transformed_aabb(local_transform, (node as MeshInstance3D).mesh.get_aabb())
		bounds = mesh_bounds
		initialized = true
	for child in node.get_children():
		var child_bounds := _calculate_bounds_with_transform(child, local_transform)
		if child_bounds.size == Vector3.ZERO:
			continue
		if not initialized:
			bounds = child_bounds
			initialized = true
		else:
			bounds = bounds.merge(child_bounds)
	return bounds


func _transformed_aabb(transform: Transform3D, local_aabb: AABB) -> AABB:
	var points := [
		local_aabb.position,
		local_aabb.position + Vector3(local_aabb.size.x, 0.0, 0.0),
		local_aabb.position + Vector3(0.0, local_aabb.size.y, 0.0),
		local_aabb.position + Vector3(0.0, 0.0, local_aabb.size.z),
		local_aabb.position + Vector3(local_aabb.size.x, local_aabb.size.y, 0.0),
		local_aabb.position + Vector3(local_aabb.size.x, 0.0, local_aabb.size.z),
		local_aabb.position + Vector3(0.0, local_aabb.size.y, local_aabb.size.z),
		local_aabb.position + local_aabb.size,
	]
	var first: Vector3 = transform * points[0]
	var bounds := AABB(first, Vector3.ZERO)
	for index in range(1, points.size()):
		bounds = bounds.expand(transform * points[index])
	return bounds
