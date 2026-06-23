extends CharacterBody3D
class_name Character

# =============================================================================
# Character 鈥?Prop Hunt 鐜╁绫?v0.3.3)
#
# 瑙掕壊绯荤粺:
#   - 閫氳繃 Network.Role 鏋氫妇璇嗗埆瑙掕壊
#   - 鍑嗗闃舵:Hunter 琚攣瀹?涓嶈兘绉诲姩
#   - 鎴樻枟闃舵:鎵€鏈夎鑹叉寜鍚勮嚜閫昏緫杩愪綔
# =============================================================================

const NORMAL_SPEED = 6.8
const SPRINT_SPEED = 10.4
const JUMP_VELOCITY = 8.2
const GROUND_ACCELERATION := 20.0
const GROUND_DECELERATION := 24.0
const AIR_ACCELERATION := 7.0
const AIR_DECELERATION := 2.4
const TURN_INPUT_DEADZONE := 0.05
const FOOTSTEP_WALK_INTERVAL := 0.38
const FOOTSTEP_SPRINT_INTERVAL := 0.24
const FOOTSTEP_MIN_SPEED := 0.6
const PROP_DISGUISE_HEIGHT_SPEED := 1.4
const PROP_DISGUISE_MIN_HEIGHT_OFFSET := -1.5
const PROP_DISGUISE_MAX_HEIGHT_OFFSET := 3.0
const PROP_DISGUISE_DROP_MIN_HEIGHT := 1.1
const PROP_DISGUISE_DROP_MAX_HEIGHT := 3.0
const PROP_COLLISION_MIN_RADIUS := 0.30
const PROP_COLLISION_MAX_RADIUS := 1.30
const PROP_COLLISION_MIN_HEIGHT := 0.42
const PROP_COLLISION_MAX_HEIGHT := 3.20
const PROP_PUSH_CONTACT_PADDING := 0.24
const PROP_PUSH_FORWARD_REACH := 0.34
const WORLD_COLLISION_MASK := 2
const PROP_DISGUISE_GROUND_SNAP_UP := 2.5
const PROP_DISGUISE_GROUND_SNAP_DOWN := 8.0
const CAMOUFLAGE_PAINT_LAYER_SHADER := preload("res://shaders/camouflage_paint_layer.gdshader")
const CHAMELEON_GPU_PBR_OVERLAY_SHADER := preload("res://shaders/chameleon_gpu_pbr_overlay.gdshader")
const CAMOUFLAGE_GPU_OVERLAY_LAYER := 20
const CAMOUFLAGE_GPU_ATLAS_SIZE := 2048
const CAMOUFLAGE_GPU_DEFAULT_LIGHTMAP_HINT := Vector2i(512, 512)
const CAMOUFLAGE_GPU_BRUSH_TIME := 0.035
const CAMOUFLAGE_GPU_MAX_QUEUED_STROKES := 96

enum SkinColor { BLUE, YELLOW, GREEN, RED }

# -----------------------------------------------------------------------------
# 瑙掕壊(浠?Network 鍚屾杩囨潵)
# -----------------------------------------------------------------------------
var role: int = Network.Role.NONE

# 鍑嗗闃舵閿佸畾鐘舵€?server 鎺у埗)
var prep_phase_locked: bool = false

@onready var nickname: Label3D = $PlayerNick/Nickname

var player_inventory: PlayerInventory

@export_category("Objects")
@export var _body: Node3D = null
@export var _spring_arm_offset: Node3D = null

@export_category("Skin Colors")
@export var blue_texture : CompressedTexture2D
@export var yellow_texture : CompressedTexture2D
@export var green_texture : CompressedTexture2D
@export var red_texture : CompressedTexture2D

@onready var _bottom_mesh: MeshInstance3D = get_node("3DGodotRobot/RobotArmature/Skeleton3D/Bottom")
@onready var _chest_mesh: MeshInstance3D = get_node("3DGodotRobot/RobotArmature/Skeleton3D/Chest")
@onready var _face_mesh: MeshInstance3D = get_node("3DGodotRobot/RobotArmature/Skeleton3D/Face")
@onready var _limbs_head_mesh: MeshInstance3D = get_node("3DGodotRobot/RobotArmature/Skeleton3D/Llimbs and head")
@onready var _collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")

var character_model_id := CharacterSkinCatalog.DEFAULT_ID
var _active_skin_node: Node3D = null
var _robot_visual_root: Node3D = null
var _prop_disguise_node: Node3D = null
var _prop_disguise_tween: Tween = null
var _is_prop_disguised := false
var _current_disguise_name := ""
var _prop_disguise_base_position := Vector3.ZERO
var _prop_disguise_height_offset := 0.0
var _jump_audio: AudioStreamPlayer3D = null
var _land_audio: AudioStreamPlayer3D = null
var _step_audio: AudioStreamPlayer3D = null
var _disguise_audio: AudioStreamPlayer3D = null
var _step_sounds: Array[AudioStream] = []
var _footstep_timer := 0.0
var _default_collision_shape: Shape3D = null
var _default_collision_transform := Transform3D.IDENTITY

var _current_speed: float
var _respawn_point = Vector3(0, 5, 0)
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var can_double_jump = true
var has_double_jumped = false
var health: float = 100.0
var _camouflage_brush_locked := false
var _camouflage_paint_texture: Texture2D = null
var _camouflage_paint_textures: Dictionary = {}
var _camouflage_surface_materials: Dictionary = {}
var _camouflage_paint_layer_materials: Dictionary = {}
var _camouflage_source_material_infos: Dictionary = {}
var _camouflage_brush_base_color := Color(0.42, 0.95, 0.72, 1.0)
var _camouflage_paint_exact_color_match := false
var _camouflage_paint_roughness := 1.0
var _camouflage_paint_metallic := 0.0
var _camouflage_paint_specular := 0.5
var _camouflage_paint_normal_texture: Texture2D = null
var _camouflage_paint_normal_scale := 1.0
var _camouflage_gpu_atlas_manager: Node3D = null
var _camouflage_gpu_camera_brush: Node3D = null
var _camouflage_gpu_stroke_queue: Array[Dictionary] = []
var _camouflage_gpu_draw_timer := 0.0
var _camouflage_gpu_unavailable := false
var _camouflage_paused_animation_players: Dictionary = {}
var _remote_visual_position := Vector3.ZERO
var _remote_visual_position_initialized := false
var _remote_visual_move_hold := 0.0

signal health_changed(value: float)

func _enter_tree():
	set_multiplayer_authority(str(name).to_int())
	$SpringArmOffset/SpringArm3D/Camera3D.current = is_multiplayer_authority()
	add_to_group("players")

func _ready():
	var is_local_player = is_multiplayer_authority()
	var local_client_id = multiplayer.get_unique_id()
	_robot_visual_root = get_node_or_null("3DGodotRobot/RobotArmature")
	_cache_default_collision_shape()
	_setup_player_audio()

	# 浠?Network 鍚屾瑙掕壊
	_sync_role_from_network()
	_sync_character_model_from_network()

	# 鐩戝惉瑙掕壊鍙樺寲
	if Network.player_role_changed.connect(_on_role_changed) != OK:
		pass  # 宸茶繛鎺?

	print("Debug: Player ", name, " ready - authority: ", get_multiplayer_authority(),
		", local client: ", local_client_id, ", is_local: ", is_local_player,
		", role: ", Network.role_to_string(role))

	# Hunter 鐜╁:鏈湴绔礋璐ｈ緭鍏?瑙嗚,鏈嶅姟鍣ㄧ璐熻矗鏉冨▉寮硅嵂/鍛戒腑鐘舵€併€?
	if is_hunter():
		_setup_hunter_systems()
	elif is_stalker():
		_setup_stalker_systems()
	else:
		# 瑙掕壊鍚庡垎閰?寤跺悗鎸傝浇
		call_deferred("_check_role_after_assignment")

	if is_local_player:
		player_inventory = PlayerInventory.new()
		_add_starting_items()
	elif multiplayer.is_server():
		player_inventory = PlayerInventory.new()
		_add_starting_items()
	else:
		if get_multiplayer_authority() == local_client_id:
			request_inventory_sync.rpc_id(1)


func _check_role_after_assignment() -> void:
	_sync_role_from_network()
	if is_hunter():
		_setup_hunter_systems()
	elif is_chameleon() and is_multiplayer_authority() and not has_node("CamouflageSystem"):
		_setup_chameleon_systems()
	elif is_stalker() and not has_node("ShadowVisibilitySystem"):
		_setup_stalker_systems()


# =============================================================================
# 钘忓尶鑰呯郴缁熷垵濮嬪寲(PoC-3)
# =============================================================================

var shape_system: ShapeShiftSystem = null
var camouflage_system: CamouflageSystem = null
var shadow_visibility = null
var stalker_grapple_system = null
var hunter_flashlight_system = null
var _stalker_original_material_overrides := {}
var _stalker_ghost_material: ShaderMaterial = null
var _stalker_glass_material: ShaderMaterial = null
var _stalker_visual_mode := "normal"
var _stalker_visual_alpha := -1.0

func _setup_chameleon_systems() -> void:
	if not is_chameleon() or not is_multiplayer_authority():
		return

	# 环境取色伪装系统(Godot 4.7 DrawableTexture2D)
	if not has_node("CamouflageSystem"):
		var cs = preload("res://scripts/camouflage_system.gd").new()
		cs.name = "CamouflageSystem"
		add_child(cs)
		var camera_node = $SpringArmOffset/SpringArm3D/Camera3D
		cs.initialize(self, camera_node)
		camouflage_system = cs

	# 鍙樺舰绯荤粺
	if not has_node("ShapeShiftSystem"):
		var ss = preload("res://scripts/shape_shift_system.gd").new()
		ss.name = "ShapeShiftSystem"
		add_child(ss)
		ss.initialize(self)
		shape_system = ss

	print("[Player] Chameleon systems initialized")


func _setup_stalker_systems() -> void:
	if not is_stalker():
		return

	if not has_node("ShadowVisibilitySystem"):
		var system := preload("res://scripts/shadow_visibility_system.gd").new()
		system.name = "ShadowVisibilitySystem"
		add_child(system)

	shadow_visibility = get_node_or_null("ShadowVisibilitySystem")
	if shadow_visibility:
		shadow_visibility.initialize(self)
		if not shadow_visibility.visibility_changed.is_connected(_on_stalker_visibility_changed):
			shadow_visibility.visibility_changed.connect(_on_stalker_visibility_changed)
	var camera := $SpringArmOffset/SpringArm3D/Camera3D if has_node("SpringArmOffset/SpringArm3D/Camera3D") else null
	if not has_node("StalkerGrappleSystem"):
		var grapple := preload("res://scripts/stalker_grapple_system.gd").new()
		grapple.name = "StalkerGrappleSystem"
		add_child(grapple)
	stalker_grapple_system = get_node_or_null("StalkerGrappleSystem")
	if stalker_grapple_system:
		stalker_grapple_system.initialize(self, camera if is_multiplayer_authority() else null)
	_refresh_stalker_visibility_view(true)


func _teardown_stalker_systems() -> void:
	_restore_stalker_materials()
	if shadow_visibility and is_instance_valid(shadow_visibility):
		shadow_visibility.queue_free()
	shadow_visibility = null
	if stalker_grapple_system and is_instance_valid(stalker_grapple_system):
		stalker_grapple_system.queue_free()
	stalker_grapple_system = null
	_stalker_visual_mode = "normal"
	_stalker_visual_alpha = -1.0


func _on_stalker_visibility_changed(_level: int, _alpha: float, _blocked_rays: int) -> void:
	_refresh_stalker_visibility_view(true)


func get_stalker_visual_mode() -> String:
	return _stalker_visual_mode


func _refresh_stalker_visibility_view(force: bool = false) -> void:
	if not is_stalker():
		return
	if not shadow_visibility:
		shadow_visibility = get_node_or_null("ShadowVisibilitySystem")
		if not shadow_visibility:
			return

	var shadow_alpha: float = float(shadow_visibility.get_visibility_alpha())
	var next_mode := _get_stalker_visual_mode_for_viewer(shadow_alpha)
	var next_material: Material = null
	match next_mode:
		"ghost":
			next_material = _get_stalker_ghost_material(_ghost_alpha_from_shadow(shadow_alpha))
		"glass":
			next_material = _get_stalker_glass_material(_glass_alpha_from_shadow(shadow_alpha))
	if not force and next_mode == _stalker_visual_mode and is_equal_approx(shadow_alpha, _stalker_visual_alpha):
		if next_mode == "normal" or _stalker_visual_meshes_have_material(next_material):
			return

	_stalker_visual_mode = next_mode
	_stalker_visual_alpha = shadow_alpha

	match next_mode:
		"ghost":
			_apply_stalker_material(next_material)
		"glass":
			_apply_stalker_material(next_material)
		_:
			_restore_stalker_materials()

	_update_stalker_nickname_visibility(shadow_alpha)


func _get_stalker_visual_mode_for_viewer(shadow_alpha: float) -> String:
	if shadow_alpha >= 0.99:
		return "normal"
	if is_multiplayer_authority():
		return "ghost"

	var viewer_role := _get_local_viewer_role()
	if viewer_role == Network.Role.HUNTER:
		return "glass"
	return "ghost"


func _get_local_viewer_role() -> int:
	var local_id := multiplayer.get_unique_id()
	if Network.players.has(local_id):
		return int(Network.players[local_id].get("role", Network.Role.NONE))
	return Network.Role.NONE


func _ghost_alpha_from_shadow(shadow_alpha: float) -> float:
	return clampf(lerpf(0.24, 0.72, shadow_alpha), 0.24, 0.72)


func _glass_alpha_from_shadow(shadow_alpha: float) -> float:
	var ceiling := _stalker_glass_alpha_ceiling()
	var floor_alpha := minf(0.018, ceiling * 0.22)
	var reveal_alpha := minf(ceiling * 0.52, 0.065)
	return clampf(lerpf(floor_alpha, reveal_alpha, shadow_alpha), floor_alpha, reveal_alpha)


func _stalker_glass_alpha_ceiling() -> float:
	return clampf(float(Network.lobby_config.get("stalker_glass_alpha_max", 0.125)), 0.04, 0.24)


func _apply_stalker_material(material: Material) -> void:
	var meshes := _get_stalker_visual_meshes()
	for mesh in meshes:
		var id := mesh.get_instance_id()
		if not _stalker_original_material_overrides.has(id):
			_stalker_original_material_overrides[id] = mesh.material_override
		mesh.material_override = material


func _restore_stalker_materials() -> void:
	var meshes := _get_stalker_visual_meshes()
	for mesh in meshes:
		var id := mesh.get_instance_id()
		if _stalker_original_material_overrides.has(id):
			mesh.material_override = _stalker_original_material_overrides[id]
		else:
			mesh.material_override = null
	if nickname:
		nickname.visible = true


func _stalker_visual_meshes_have_material(material: Material) -> bool:
	if not material:
		return true
	var meshes := _get_stalker_visual_meshes()
	if meshes.is_empty():
		return false
	for mesh in meshes:
		if mesh.material_override != material:
			return false
	return true


func _get_stalker_visual_meshes() -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	if _prop_disguise_node and is_instance_valid(_prop_disguise_node) and _prop_disguise_node.visible:
		_find_visible_meshes(_prop_disguise_node, meshes)
	elif _active_skin_node and is_instance_valid(_active_skin_node) and _active_skin_node.visible:
		_find_visible_meshes(_active_skin_node, meshes)
	elif _robot_visual_root and _robot_visual_root.visible:
		_find_visible_meshes(_robot_visual_root, meshes)
	elif _body:
		_find_visible_meshes(_body, meshes)
	return meshes


func _find_visible_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is Node3D and not (node as Node3D).visible:
		return
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		_find_visible_meshes(child, result)


func _update_stalker_nickname_visibility(shadow_alpha: float) -> void:
	if not nickname:
		return
	var viewer_role := _get_local_viewer_role()
	nickname.visible = shadow_alpha >= 0.99 or viewer_role != Network.Role.HUNTER


func _get_stalker_ghost_material(alpha: float) -> ShaderMaterial:
	if not _stalker_ghost_material:
		var shader := Shader.new()
		shader.code = """
shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, specular_schlick_ggx;

uniform vec4 tint : source_color = vec4(0.55, 0.82, 1.0, 1.0);
uniform float alpha = 0.35;

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.0);
	ALBEDO = tint.rgb;
	ALPHA = clamp(alpha + fresnel * 0.20, 0.0, 0.9);
	EMISSION = tint.rgb * (0.12 + fresnel * 0.35);
	ROUGHNESS = 0.18;
	METALLIC = 0.0;
	SPECULAR = 0.75;
}
"""
		_stalker_ghost_material = ShaderMaterial.new()
		_stalker_ghost_material.resource_local_to_scene = true
		_stalker_ghost_material.shader = shader
	_stalker_ghost_material.set_shader_parameter("alpha", alpha)
	return _stalker_ghost_material


func _get_stalker_glass_material(alpha: float) -> ShaderMaterial:
	if not _stalker_glass_material:
		var shader := Shader.new()
		shader.code = """
shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, specular_schlick_ggx;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec4 edge_tint : source_color = vec4(0.50, 0.58, 0.62, 1.0);
uniform float alpha = 0.025;
uniform float visibility_ceiling = 0.125;
uniform float refraction_strength = 0.015;
uniform float shimmer_strength = 0.006;

void fragment() {
	float view_dot = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - view_dot, 4.0);
	float shimmer = sin((SCREEN_UV.x * 1.3 + SCREEN_UV.y * 1.7 + TIME * 0.08) * 95.0) * 0.5 + 0.5;
	vec2 normal_warp = normalize(NORMAL.xy + vec2(0.0001, 0.0001));
	vec2 heat_warp = vec2(sin(SCREEN_UV.y * 120.0 + TIME * 1.2), cos(SCREEN_UV.x * 105.0 - TIME)) * shimmer_strength;
	vec2 wobble = normal_warp * refraction_strength * (0.12 + fresnel * 0.85) + heat_warp * (0.25 + fresnel);
	vec3 refracted = texture(screen_texture, SCREEN_UV + wobble).rgb;
	vec3 base_screen = texture(screen_texture, SCREEN_UV).rgb;
	vec3 distortion_delta = abs(refracted - base_screen);
	ALBEDO = mix(refracted, edge_tint.rgb, fresnel * 0.18);
	ALPHA = clamp(alpha + fresnel * 0.045 + length(distortion_delta) * 0.05, 0.006, visibility_ceiling);
	EMISSION = edge_tint.rgb * fresnel * 0.018;
	ROUGHNESS = 0.04;
	METALLIC = 0.0;
	SPECULAR = 0.45;
}
"""
		_stalker_glass_material = ShaderMaterial.new()
		_stalker_glass_material.resource_local_to_scene = true
		_stalker_glass_material.shader = shader
		_stalker_glass_material.set_shader_parameter("edge_tint", Color(0.50, 0.58, 0.62, 1.0))
		_stalker_glass_material.set_shader_parameter("refraction_strength", 0.015)
		_stalker_glass_material.set_shader_parameter("shimmer_strength", 0.006)
	_stalker_glass_material.set_shader_parameter("alpha", alpha)
	_stalker_glass_material.set_shader_parameter("visibility_ceiling", _stalker_glass_alpha_ceiling())
	return _stalker_glass_material


# =============================================================================
# Hunter 姝﹀櫒鍒濆鍖?
# =============================================================================

func _setup_hunter_systems() -> void:
	if not is_hunter():
		return
	if is_multiplayer_authority() or multiplayer.is_server():
		_setup_hunter_weapon()
	_setup_hunter_flashlight()


func _setup_hunter_weapon() -> void:
	var is_local_player = is_multiplayer_authority()
	var camera = $SpringArmOffset/SpringArm3D/Camera3D

	# 鍔犺浇 AK47 妯″瀷(浠呮湰鍦拌瑙?
	if is_local_player:
		var ak47_scene = preload("res://scenes/weapons/ak47.tscn")
		if not camera.has_node("WeaponVisual"):
			var visual = ak47_scene.instantiate()
			visual.name = "WeaponVisual"
			# 鎸傚湪 Camera3D 涓?浣滀负鏈湴绗竴/涓変汉绉拌瑙?
			camera.add_child(visual)
			visual.position = Vector3(0.3, -0.3, -0.5)
			visual.rotation = Vector3(0, 0, 0)

	# 鍔犺浇 WeaponSystem(缃戠粶鏉冨▉)
	if not has_node("WeaponSystem"):
		var weapon = preload("res://scripts/weapon_system.gd").new()
		weapon.name = "WeaponSystem"
		add_child(weapon)
		weapon.initialize(self, camera if is_local_player else null)

	# 娉ㄥ唽寮硅嵂鍙樺寲淇″彿
	var weapon = get_node_or_null("WeaponSystem")
	if weapon:
		if not weapon.ammo_changed.is_connected(_on_ammo_changed):
			weapon.ammo_changed.connect(_on_ammo_changed)


func _setup_hunter_flashlight() -> void:
	var camera := $SpringArmOffset/SpringArm3D/Camera3D if has_node("SpringArmOffset/SpringArm3D/Camera3D") else null
	if not has_node("HunterFlashlightSystem"):
		var flashlight := preload("res://scripts/hunter_flashlight_system.gd").new()
		flashlight.name = "HunterFlashlightSystem"
		add_child(flashlight)
	hunter_flashlight_system = get_node_or_null("HunterFlashlightSystem")
	if hunter_flashlight_system:
		hunter_flashlight_system.initialize(self, camera if is_multiplayer_authority() else null)


func _teardown_hunter_flashlight() -> void:
	if hunter_flashlight_system and is_instance_valid(hunter_flashlight_system):
		hunter_flashlight_system.queue_free()
	hunter_flashlight_system = null


func _on_ammo_changed(current_magazine: int, total_ammo: int) -> void:
	# TODO: 鏇存柊 HUD 寮硅嵂鏄剧ず
	pass


# =============================================================================
# Hunter 杈撳叆澶勭悊
# =============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return

	# Hunter 杈撳叆
	if is_hunter():
		_handle_hunter_input(event)

	# Chameleon 杈撳叆
	if is_chameleon():
		_handle_chameleon_input(event)

	if is_stalker():
		_handle_stalker_input(event)


func _handle_hunter_input(event: InputEvent) -> void:
	# 鍑嗗闃舵閿佸畾涓嶈兘寮€鏋?
	if prep_phase_locked:
		return

	if event.is_action_pressed("flashlight") and hunter_flashlight_system:
		hunter_flashlight_system.request_toggle()
		get_viewport().set_input_as_handled()

	var weapon = get_node_or_null("WeaponSystem")
	if not weapon:
		return

	# 寮€鐏?
	if event.is_action_pressed("shoot"):
		weapon.request_fire()
	# 鎹㈠脊
	if event.is_action_pressed("reload"):
		weapon.request_reload()
	if event.is_action_pressed("paint_trigger") and weapon.has_method("request_scan"):
		weapon.request_scan()


func _handle_chameleon_input(event: InputEvent) -> void:
	if not camouflage_system and not shape_system:
		return

	if camouflage_system and camouflage_system.is_brush_mode():
		if camouflage_system.handle_brush_input(event):
			get_viewport().set_input_as_handled()
		return

	# Environment blend: C toggles the paintable camouflage tool.
	if event.is_action_pressed("camouflage_absorb") and camouflage_system:
		camouflage_system.toggle_skill()
		get_viewport().set_input_as_handled()
		return

	# 鍙樺舰杞洏:Q 鍒囨崲寮€/鍏?
	if event.is_action_pressed("shape_shift") and shape_system:
		if shape_system.has_method("has_nearby_replicable_prop") and shape_system.has_nearby_replicable_prop():
			shape_system.try_replicate_nearby_prop()
			return
		var wheel = _get_shape_wheel()
		if wheel:
			if wheel.visible:
				wheel.hide_wheel()
			else:
				wheel.show_wheel(shape_system)
				# 閿佷綇瑙掕壊绉诲姩
				shape_system.open_wheel()


func _handle_stalker_input(event: InputEvent) -> void:
	if prep_phase_locked:
		return
	if event.is_action_pressed("stalker_grapple") and stalker_grapple_system:
		if stalker_grapple_system.request_grapple():
			get_viewport().set_input_as_handled()


func _process_input_held():
	# 鍦?_process 涓寔缁娴?shoot / paint 鎸変綇鐘舵€?
	if not is_multiplayer_authority():
		return

	# Hunter 鎸佺画寮€鐏?
	if is_hunter():
		if prep_phase_locked:
			return
		var weapon = get_node_or_null("WeaponSystem")
		if weapon and Input.is_action_pressed("shoot"):
			weapon.request_fire()

	# Chameleon 鎸佺画鍠锋秱
	if is_chameleon():
		if camouflage_system and camouflage_system.is_brush_mode():
			return


# 鏌ユ壘 level 涓殑鍙樺舰杞洏 UI
func _get_shape_wheel() -> ShapeShiftWheelUI:
	var level = get_tree().get_current_scene() if get_tree() else null
	if not level:
		return null
	var wheel = level.get_node_or_null("ShapeShiftWheelUI")
	if wheel and wheel is ShapeShiftWheelUI:
		return wheel
	return null


func _sync_role_from_network() -> void:
	var my_id = str(name).to_int()
	if Network.players.has(my_id):
		role = Network.players[my_id].get("role", Network.Role.NONE)
	else:
		role = Network.Role.NONE


func _sync_character_model_from_network() -> void:
	var my_id = str(name).to_int()
	if Network.players.has(my_id):
		set_character_model(str(Network.players[my_id].get("character_model", CharacterSkinCatalog.DEFAULT_ID)))
	else:
		set_character_model(CharacterSkinCatalog.DEFAULT_ID)


func _on_role_changed(peer_id: int, new_role: int) -> void:
	if peer_id == str(name).to_int():
		role = new_role
		_sync_character_model_from_network()
		print("[Player ", name, "] Role updated to ", Network.role_to_string(new_role))
		if new_role != Network.Role.STALKER and shadow_visibility:
			_teardown_stalker_systems()
		if new_role != Network.Role.HUNTER and hunter_flashlight_system:
			_teardown_hunter_flashlight()
		# 濡傛灉鏄?Hunter 涓旇繕娌℃寕姝﹀櫒,琛ユ寕
		if new_role == Network.Role.HUNTER:
			_setup_hunter_systems()
		elif new_role == Network.Role.CHAMELEON and is_multiplayer_authority() and not has_node("CamouflageSystem"):
			_setup_chameleon_systems()
		elif new_role == Network.Role.STALKER:
			_setup_stalker_systems()


# =============================================================================
# 瑙掕壊 helper
# =============================================================================
func is_chameleon() -> bool:
	return role == Network.Role.CHAMELEON

func is_stalker() -> bool:
	return role == Network.Role.STALKER

func is_hunter() -> bool:
	return role == Network.Role.HUNTER

func is_prop() -> bool:
	return role == Network.Role.CHAMELEON or role == Network.Role.STALKER


# =============================================================================
# 鍑嗗闃舵閿佸畾(鏈嶅姟鍣ㄦ帶鍒?Hunter 涓嶈兘绉诲姩)
# =============================================================================
func set_prep_locked(locked: bool) -> void:
	prep_phase_locked = locked
	if locked:
		# 鍋滄浠讳綍绉诲姩
		velocity = Vector3.ZERO
		_current_speed = 0.0
		# 瑙嗚鎻愮ず(3D 鑺傜偣娌℃湁 modulate,鏀圭敤 mesh material albedo_color)
		_set_player_tint(Color(0.5, 0.5, 0.5))
	else:
		_set_player_tint(Color(1, 1, 1))


func _set_player_tint(color: Color) -> void:
	# 閬嶅巻鎵€鏈?MeshInstance3D,鏀?albedo_color(3D 鐗?modulate)
	var meshes: Array[MeshInstance3D] = []
	_find_meshes(self, meshes)
	for mesh_inst in meshes:
		for i in range(_get_mesh_surface_count(mesh_inst)):
			var source_material := _get_mesh_surface_material(mesh_inst, i)
			if not source_material is StandardMaterial3D:
				continue
			var material := source_material as StandardMaterial3D
			if not bool(material.get_meta("player_tint_unique", false)):
				material = material.duplicate()
				material.resource_local_to_scene = true
				material.set_meta("player_tint_unique", true)
				mesh_inst.set_surface_override_material(i, material)
			material.albedo_color = color


func _find_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		_find_meshes(child, result)


func _set_active_skin_animation_paused(paused: bool) -> void:
	if paused:
		if not _active_skin_node or not is_instance_valid(_active_skin_node):
			return
		if _active_skin_node.has_method("set_animation_paused"):
			_active_skin_node.call("set_animation_paused", true)
		var players: Array[AnimationPlayer] = []
		_find_animation_players(_active_skin_node, players)
		for animation_player in players:
			var key := animation_player.get_instance_id()
			if not _camouflage_paused_animation_players.has(key):
				_camouflage_paused_animation_players[key] = {
					"player": animation_player,
					"speed_scale": animation_player.speed_scale,
				}
			animation_player.speed_scale = 0.0
		return

	for key in _camouflage_paused_animation_players.keys():
		var pause_info := _camouflage_paused_animation_players[key] as Dictionary
		var animation_player := pause_info.get("player", null) as AnimationPlayer
		if animation_player and is_instance_valid(animation_player):
			animation_player.speed_scale = float(pause_info.get("speed_scale", 1.0))
	_camouflage_paused_animation_players.clear()
	if _active_skin_node and is_instance_valid(_active_skin_node) and _active_skin_node.has_method("set_animation_paused"):
		_active_skin_node.call("set_animation_paused", false)


func _find_animation_players(node: Node, result: Array[AnimationPlayer]) -> void:
	if node is AnimationPlayer:
		result.append(node as AnimationPlayer)
	for child in node.get_children():
		_find_animation_players(child, result)


func _force_active_skin_skeleton_update() -> void:
	if _active_skin_node and is_instance_valid(_active_skin_node):
		_force_skeleton_update_recursive(_active_skin_node)
	_force_skeleton_update_recursive(_body)


func _force_skeleton_update_recursive(node: Node) -> void:
	if not node:
		return
	if node is Skeleton3D:
		(node as Skeleton3D).force_update_all_bone_transforms()
	for child in node.get_children():
		_force_skeleton_update_recursive(child)

func _physics_process(delta):
	if not is_multiplayer_authority(): return

	if _camouflage_brush_locked:
		freeze()
		move_and_slide()
		return

	# 鍑嗗闃舵 Hunter 閿佸畾(涓嶈兘绉诲姩)
	if is_hunter() and prep_phase_locked:
		velocity = Vector3.ZERO
		_current_speed = 0.0
		move_and_slide()
		return

	var current_scene = get_tree().get_current_scene()
	if current_scene and is_on_floor():
		var should_freeze = false
		if current_scene.has_method("is_chat_visible") and current_scene.is_chat_visible():
			should_freeze = true
		elif current_scene.has_method("is_inventory_visible") and current_scene.is_inventory_visible():
			should_freeze = true

		if should_freeze:
			freeze()
			return

	var was_on_floor := is_on_floor()
	if is_on_floor():
		can_double_jump = true
		has_double_jumped = false

		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
			can_double_jump = true
			_play_body_jump("Jump")
	else:
		if can_double_jump and not has_double_jumped and Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
			has_double_jumped = true
			can_double_jump = false
			_play_body_jump("Jump2")

	velocity.y -= gravity * delta

	_move(delta)
	var impact_velocity := velocity
	move_and_slide()
	if _apply_prop_collision_impacts(impact_velocity) and impact_velocity.y <= 0.1:
		velocity.y = minf(velocity.y, 0.0)
	_animate_body(velocity)
	_update_movement_audio(delta, was_on_floor)

func _process(delta):
	_process_camouflage_gpu_painter(delta)
	if is_stalker():
		_refresh_stalker_visibility_view(false)
	if not is_multiplayer_authority():
		_animate_remote_skin_from_network_motion(delta)
		return
	_check_fall_and_respawn()
	# Hunter 鎸佺画寮€鐏娴?
	_process_input_held()
	_process_prop_disguise_height(delta)

func freeze():
	velocity.x = 0
	velocity.z = 0
	_current_speed = 0
	_animate_body(Vector3.ZERO)

func _move(delta: float) -> void:
	var _input_direction: Vector2 = Vector2.ZERO
	if is_multiplayer_authority():
		_input_direction = Input.get_vector(
			"move_left", "move_right",
			"move_forward", "move_backward"
			)

	var camera_basis := _spring_arm_offset.global_transform.basis if _spring_arm_offset else global_transform.basis
	var camera_forward := -camera_basis.z
	camera_forward.y = 0.0
	camera_forward = camera_forward.normalized()
	var camera_right := camera_basis.x
	camera_right.y = 0.0
	camera_right = camera_right.normalized()
	var _direction := (camera_right * _input_direction.x + camera_forward * -_input_direction.y)
	if _direction.length_squared() > 1.0:
		_direction = _direction.normalized()

	is_running()
	var has_move_input := _direction.length_squared() > TURN_INPUT_DEADZONE * TURN_INPUT_DEADZONE
	var target_horizontal_velocity := Vector3.ZERO
	if has_move_input:
		target_horizontal_velocity = _direction.normalized() * _current_speed

	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var acceleration := GROUND_ACCELERATION if has_move_input else GROUND_DECELERATION
	if not is_on_floor():
		acceleration = AIR_ACCELERATION if has_move_input else AIR_DECELERATION
	horizontal_velocity = horizontal_velocity.move_toward(target_horizontal_velocity, acceleration * delta)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	if has_move_input:
		_apply_body_rotation(velocity)


func _apply_prop_collision_impacts(impact_velocity: Vector3) -> bool:
	var horizontal_speed := Vector2(impact_velocity.x, impact_velocity.z).length()
	if horizontal_speed < 1.0:
		return false
	var impacted := {}
	var did_impact := false
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		if not collision:
			continue
		var collider := collision.get_collider()
		if not collider or not collider.has_method("apply_player_impact"):
			continue
		var collider_id := collider.get_instance_id()
		if impacted.has(collider_id):
			continue
		impacted[collider_id] = true
		collider.apply_player_impact(impact_velocity, collision.get_position(), collision.get_normal(), _is_prop_disguised)
		did_impact = true
	did_impact = _apply_nearby_prop_impacts(impact_velocity, impacted) or did_impact
	return did_impact


func _apply_nearby_prop_impacts(impact_velocity: Vector3, impacted: Dictionary) -> bool:
	if not is_inside_tree():
		return false
	var horizontal_velocity := Vector3(impact_velocity.x, 0.0, impact_velocity.z)
	if horizontal_velocity.length_squared() < 0.01:
		return false
	var move_direction := horizontal_velocity.normalized()
	var player_radius := _get_active_collision_radius()
	var did_impact := false
	for node in get_tree().get_nodes_in_group("map_props"):
		if not node is Node3D:
			continue
		if not node.has_method("apply_player_impact"):
			continue
		var node_id := node.get_instance_id()
		if impacted.has(node_id):
			continue
		var prop_position := (node as Node3D).global_position
		var to_prop := prop_position - global_position
		to_prop.y = 0.0
		var distance := to_prop.length()
		var prop_radius := 0.45
		var radius_value = node.get("collision_radius")
		if radius_value != null:
			prop_radius = float(radius_value)
		var contact_distance := player_radius + prop_radius + PROP_PUSH_CONTACT_PADDING
		var forward_distance := to_prop.dot(move_direction)
		if forward_distance < -0.05 or forward_distance > contact_distance + PROP_PUSH_FORWARD_REACH:
			continue
		if distance > contact_distance:
			continue
		var normal := Vector3.ZERO
		if distance > 0.001:
			normal = -to_prop.normalized()
		node.apply_player_impact(impact_velocity, prop_position, normal, _is_prop_disguised)
		impacted[node_id] = true
		did_impact = true
	return did_impact


func _get_active_collision_radius() -> float:
	if not _collision_shape or not _collision_shape.shape:
		return 0.42
	var shape := _collision_shape.shape
	if shape is CapsuleShape3D:
		return (shape as CapsuleShape3D).radius
	if shape is CylinderShape3D:
		return (shape as CylinderShape3D).radius
	if shape is SphereShape3D:
		return (shape as SphereShape3D).radius
	if shape is BoxShape3D:
		var size := (shape as BoxShape3D).size
		return maxf(size.x, size.z) * 0.5
	return 0.42

func is_running() -> bool:
	if Input.is_action_pressed("shift"):
		_current_speed = SPRINT_SPEED
		return true
	else:
		_current_speed = NORMAL_SPEED
		return false

func _check_fall_and_respawn():
	if global_transform.origin.y < -15.0:
		_respawn()

func _respawn():
	global_transform.origin = _respawn_point
	velocity = Vector3.ZERO
	clear_prop_disguise()

@rpc("any_peer", "reliable")
func change_nick(new_nick: String):
	if nickname:
		nickname.text = new_nick

func get_texture_from_name(skin_color: SkinColor) -> CompressedTexture2D:
	match skin_color:
		SkinColor.BLUE: return blue_texture
		SkinColor.GREEN: return green_texture
		SkinColor.RED: return red_texture
		SkinColor.YELLOW: return yellow_texture
		_: return blue_texture

@rpc("any_peer", "reliable")
func set_player_skin(skin_name: SkinColor) -> void:
	var texture = get_texture_from_name(skin_name)

	set_mesh_texture(_bottom_mesh, texture)
	set_mesh_texture(_chest_mesh, texture)
	set_mesh_texture(_face_mesh, texture)
	set_mesh_texture(_limbs_head_mesh, texture)


func submit_camouflage_palette(palette: Array, confidence: float) -> void:
	var clean_palette := _sanitize_camouflage_palette(palette)
	var clean_confidence := clampf(confidence, 0.0, 1.0)
	if multiplayer.is_server():
		_apply_camouflage_palette.rpc(clean_palette, clean_confidence)
	else:
		_request_camouflage_palette.rpc_id(1, clean_palette, clean_confidence)


@rpc("any_peer", "call_local", "reliable")
func _request_camouflage_palette(palette: Array, confidence: float) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		push_warning("Client " + str(sender) + " tried to camouflage player " + str(get_multiplayer_authority()))
		return
	if not is_chameleon():
		return
	_apply_camouflage_palette.rpc(_sanitize_camouflage_palette(palette), clampf(confidence, 0.0, 1.0))


@rpc("any_peer", "call_local", "reliable")
func _apply_camouflage_palette(palette: Array, confidence: float) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1 and not multiplayer.is_server():
		return
	var clean_palette := _sanitize_camouflage_palette(palette)
	var texture := CamouflageSystem.create_camouflage_texture(clean_palette, get_instance_id())
	_apply_camouflage_texture_to_character(texture, clean_palette[0], confidence)
	var level = get_tree().get_current_scene() if get_tree() else null
	if level and is_multiplayer_authority() and level.has_method("show_combat_feedback"):
		level.show_combat_feedback("环境融合 %d%%" % int(round(confidence * 100.0)), clean_palette[0], 0.9)


func set_camouflage_brush_locked(locked: bool) -> void:
	_camouflage_brush_locked = locked
	_set_active_skin_animation_paused(locked)
	if locked:
		_force_active_skin_skeleton_update()
	if locked:
		freeze()


func is_camouflage_brushing() -> bool:
	return _camouflage_brush_locked


func adjust_camouflage_brush_rotation(delta_yaw: float) -> void:
	if not _camouflage_brush_locked or not _body:
		return
	_body.rotation.y = wrapf(_body.rotation.y + delta_yaw, -PI, PI)


func adjust_camouflage_camera_orbit(relative: Vector2) -> void:
	if not _camouflage_brush_locked or not _spring_arm_offset:
		return
	if _spring_arm_offset.has_method("orbit_camera"):
		_spring_arm_offset.call("orbit_camera", relative)


func adjust_camouflage_camera_zoom(step_count: float) -> void:
	if not _camouflage_brush_locked or not _spring_arm_offset:
		return
	if _spring_arm_offset.has_method("zoom_camera_for_camouflage"):
		_spring_arm_offset.call("zoom_camera_for_camouflage", step_count)
		return
	if _spring_arm_offset.has_method("zoom_camera"):
		_spring_arm_offset.call("zoom_camera", step_count)


func set_camouflage_paint_material_controls(exact_color_match: bool, roughness: float, metallic: float, specular: float = 0.5) -> void:
	_camouflage_paint_exact_color_match = exact_color_match
	_camouflage_paint_roughness = clampf(roughness, 0.0, 1.0)
	_camouflage_paint_metallic = clampf(metallic, 0.0, 1.0)
	_camouflage_paint_specular = clampf(specular, 0.0, 1.0)
	for material in _camouflage_paint_layer_materials.values():
		if material is ShaderMaterial and is_instance_valid(material):
			_configure_camouflage_paint_layer_controls(material as ShaderMaterial)
	for material in _camouflage_surface_materials.values():
		if material is StandardMaterial3D and is_instance_valid(material):
			_configure_camouflage_display_material(material as StandardMaterial3D)
	_configure_camouflage_gpu_overlay_materials()


func set_camouflage_paint_material_profile(profile: Dictionary) -> void:
	_camouflage_paint_roughness = clampf(float(profile.get("roughness", _camouflage_paint_roughness)), 0.0, 1.0)
	_camouflage_paint_metallic = clampf(float(profile.get("metallic", _camouflage_paint_metallic)), 0.0, 1.0)
	_camouflage_paint_specular = clampf(float(profile.get("specular", _camouflage_paint_specular)), 0.0, 1.0)
	_camouflage_paint_normal_texture = profile.get("normal_texture", null) as Texture2D
	_camouflage_paint_normal_scale = clampf(float(profile.get("normal_scale", _camouflage_paint_normal_scale)), 0.0, 2.0)
	for material in _camouflage_paint_layer_materials.values():
		if material is ShaderMaterial and is_instance_valid(material):
			_configure_camouflage_paint_layer_controls(material as ShaderMaterial)
	for material in _camouflage_surface_materials.values():
		if material is StandardMaterial3D and is_instance_valid(material):
			_configure_camouflage_display_material(material as StandardMaterial3D)
	_configure_camouflage_gpu_overlay_materials()


func submit_camouflage_brush_start(base_color: Color) -> void:
	base_color.a = 1.0
	if multiplayer.is_server() and _has_active_camouflage_multiplayer_peer():
		_start_camouflage_brush_visual.rpc(base_color)
	elif _should_apply_camouflage_brush_without_server_peer():
		_start_camouflage_brush_visual(base_color)
	else:
		_request_camouflage_brush_start.rpc_id(1, base_color)


func submit_camouflage_brush_stroke(
	uv: Vector2,
	color: Color,
	brush_radius: float,
	angle: float,
	world_position: Vector3 = Vector3.ZERO,
	world_normal: Vector3 = Vector3.UP,
	target_mesh_path: String = "",
	target_surface: int = 0,
	material_roughness: float = -1.0,
	material_metallic: float = -1.0,
	material_specular: float = -1.0
) -> void:
	color.a = 1.0
	var clean_uv := Vector2(clampf(uv.x, 0.0, 1.0), clampf(uv.y, 0.0, 1.0))
	var clean_radius := _sanitize_camouflage_brush_radius(brush_radius)
	var clean_normal := world_normal.normalized() if world_normal.length_squared() > 0.001 else Vector3.UP
	_apply_camouflage_material_scalars(material_roughness, material_metallic, material_specular)
	if multiplayer.is_server() and _has_active_camouflage_multiplayer_peer():
		_apply_camouflage_brush_stroke.rpc(clean_uv, color, clean_radius, angle, world_position, clean_normal, target_mesh_path, target_surface, _camouflage_paint_roughness, _camouflage_paint_metallic, _camouflage_paint_specular)
	elif _should_apply_camouflage_brush_without_server_peer():
		_apply_camouflage_brush_stroke(clean_uv, color, clean_radius, angle, world_position, clean_normal, target_mesh_path, target_surface, _camouflage_paint_roughness, _camouflage_paint_metallic, _camouflage_paint_specular)
	else:
		_request_camouflage_brush_stroke.rpc_id(1, clean_uv, color, clean_radius, angle, world_position, clean_normal, target_mesh_path, target_surface, _camouflage_paint_roughness, _camouflage_paint_metallic, _camouflage_paint_specular)


func submit_camouflage_brush_stroke_batch(
	uvs: PackedVector2Array,
	color: Color,
	brush_radius: float,
	angle: float,
	world_positions: PackedVector3Array = PackedVector3Array(),
	world_normal: Vector3 = Vector3.UP,
	target_mesh_path: String = "",
	target_surface: int = 0,
	brush_radii: PackedFloat32Array = PackedFloat32Array(),
	uv_clip_triangles: PackedVector2Array = PackedVector2Array(),
	uv_clip_triangle_counts: PackedInt32Array = PackedInt32Array(),
	uv_footprint_metrics: PackedFloat32Array = PackedFloat32Array(),
	material_roughness: float = -1.0,
	material_metallic: float = -1.0,
	material_specular: float = -1.0
) -> void:
	if uvs.is_empty():
		return
	color.a = 1.0
	var clean_uvs := PackedVector2Array()
	for uv in uvs:
		clean_uvs.append(Vector2(clampf(uv.x, 0.0, 1.0), clampf(uv.y, 0.0, 1.0)))
	var clean_radius := _sanitize_camouflage_brush_radius(brush_radius)
	var clean_radii := _sanitize_camouflage_brush_radii(brush_radii, clean_uvs.size(), clean_radius)
	var clean_uv_clip := _sanitize_camouflage_uv_clip_data(uv_clip_triangles, uv_clip_triangle_counts, clean_uvs.size())
	var clean_uv_footprint_metrics := _sanitize_camouflage_uv_footprint_metrics(uv_footprint_metrics, clean_uvs.size())
	var clean_normal := world_normal.normalized() if world_normal.length_squared() > 0.001 else Vector3.UP
	_apply_camouflage_material_scalars(material_roughness, material_metallic, material_specular)
	if multiplayer.is_server() and _has_active_camouflage_multiplayer_peer():
		_apply_camouflage_brush_stroke_batch.rpc(clean_uvs, color, clean_radius, angle, world_positions, clean_normal, target_mesh_path, target_surface, clean_radii, clean_uv_clip.get("triangles", PackedVector2Array()), clean_uv_clip.get("counts", PackedInt32Array()), clean_uv_footprint_metrics, _camouflage_paint_roughness, _camouflage_paint_metallic, _camouflage_paint_specular)
	elif _should_apply_camouflage_brush_without_server_peer():
		_apply_camouflage_brush_stroke_batch(clean_uvs, color, clean_radius, angle, world_positions, clean_normal, target_mesh_path, target_surface, clean_radii, clean_uv_clip.get("triangles", PackedVector2Array()), clean_uv_clip.get("counts", PackedInt32Array()), clean_uv_footprint_metrics, _camouflage_paint_roughness, _camouflage_paint_metallic, _camouflage_paint_specular)
	else:
		_request_camouflage_brush_stroke_batch.rpc_id(1, clean_uvs, color, clean_radius, angle, world_positions, clean_normal, target_mesh_path, target_surface, clean_radii, clean_uv_clip.get("triangles", PackedVector2Array()), clean_uv_clip.get("counts", PackedInt32Array()), clean_uv_footprint_metrics, _camouflage_paint_roughness, _camouflage_paint_metallic, _camouflage_paint_specular)


func _should_apply_camouflage_brush_without_server_peer() -> bool:
	return not _has_active_camouflage_multiplayer_peer()


func _has_active_camouflage_multiplayer_peer() -> bool:
	var peer := multiplayer.multiplayer_peer
	if peer == null:
		return false
	return peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED


@rpc("any_peer", "call_local", "reliable")
func _request_camouflage_brush_start(base_color: Color) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	if not is_chameleon():
		return
	base_color.a = 1.0
	_start_camouflage_brush_visual.rpc(base_color)


@rpc("any_peer", "call_local", "unreliable_ordered")
func _request_camouflage_brush_stroke(
	uv: Vector2,
	color: Color,
	brush_radius: float,
	angle: float,
	world_position: Vector3 = Vector3.ZERO,
	world_normal: Vector3 = Vector3.UP,
	target_mesh_path: String = "",
	target_surface: int = 0,
	material_roughness: float = -1.0,
	material_metallic: float = -1.0,
	material_specular: float = -1.0
) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	color.a = 1.0
	var clean_normal := world_normal.normalized() if world_normal.length_squared() > 0.001 else Vector3.UP
	_apply_camouflage_material_scalars(material_roughness, material_metallic, material_specular)
	_apply_camouflage_brush_stroke.rpc(
		Vector2(clampf(uv.x, 0.0, 1.0), clampf(uv.y, 0.0, 1.0)),
		color,
		_sanitize_camouflage_brush_radius(brush_radius),
		angle,
		world_position,
		clean_normal,
		target_mesh_path,
		target_surface,
		_camouflage_paint_roughness,
		_camouflage_paint_metallic,
		_camouflage_paint_specular
	)


@rpc("any_peer", "call_local", "unreliable_ordered")
func _request_camouflage_brush_stroke_batch(
	uvs: PackedVector2Array,
	color: Color,
	brush_radius: float,
	angle: float,
	world_positions: PackedVector3Array = PackedVector3Array(),
	world_normal: Vector3 = Vector3.UP,
	target_mesh_path: String = "",
	target_surface: int = 0,
	brush_radii: PackedFloat32Array = PackedFloat32Array(),
	uv_clip_triangles: PackedVector2Array = PackedVector2Array(),
	uv_clip_triangle_counts: PackedInt32Array = PackedInt32Array(),
	uv_footprint_metrics: PackedFloat32Array = PackedFloat32Array(),
	material_roughness: float = -1.0,
	material_metallic: float = -1.0,
	material_specular: float = -1.0
) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	color.a = 1.0
	var clean_uvs := PackedVector2Array()
	for uv in uvs:
		clean_uvs.append(Vector2(clampf(uv.x, 0.0, 1.0), clampf(uv.y, 0.0, 1.0)))
	var clean_radius := _sanitize_camouflage_brush_radius(brush_radius)
	var clean_radii := _sanitize_camouflage_brush_radii(brush_radii, clean_uvs.size(), clean_radius)
	var clean_uv_clip := _sanitize_camouflage_uv_clip_data(uv_clip_triangles, uv_clip_triangle_counts, clean_uvs.size())
	var clean_uv_footprint_metrics := _sanitize_camouflage_uv_footprint_metrics(uv_footprint_metrics, clean_uvs.size())
	var clean_normal := world_normal.normalized() if world_normal.length_squared() > 0.001 else Vector3.UP
	_apply_camouflage_material_scalars(material_roughness, material_metallic, material_specular)
	_apply_camouflage_brush_stroke_batch.rpc(
		clean_uvs,
		color,
		clean_radius,
		angle,
		world_positions,
		clean_normal,
		target_mesh_path,
		target_surface,
		clean_radii,
		clean_uv_clip.get("triangles", PackedVector2Array()),
		clean_uv_clip.get("counts", PackedInt32Array()),
		clean_uv_footprint_metrics,
		_camouflage_paint_roughness,
		_camouflage_paint_metallic,
		_camouflage_paint_specular
	)


@rpc("any_peer", "call_local", "reliable")
func _start_camouflage_brush_visual(base_color: Color) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1 and not multiplayer.is_server():
		return
	base_color.a = 1.0
	_camouflage_brush_base_color = base_color
	_camouflage_paint_textures.clear()
	_camouflage_surface_materials.clear()
	_camouflage_paint_layer_materials.clear()
	_camouflage_source_material_infos.clear()
	_camouflage_paint_texture = CamouflageSystem.create_brush_canvas(base_color)
	_camouflage_gpu_stroke_queue.clear()
	_camouflage_gpu_draw_timer = 0.0
	_ensure_camouflage_gpu_painter()


@rpc("any_peer", "call_local", "unreliable_ordered")
func _apply_camouflage_brush_stroke(
	uv: Vector2,
	color: Color,
	brush_radius: float,
	angle: float,
	world_position: Vector3 = Vector3.ZERO,
	world_normal: Vector3 = Vector3.UP,
	target_mesh_path: String = "",
	target_surface: int = 0,
	material_roughness: float = -1.0,
	material_metallic: float = -1.0,
	material_specular: float = -1.0
) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1 and not multiplayer.is_server():
		return
	color.a = 1.0
	_apply_camouflage_material_scalars(material_roughness, material_metallic, material_specular)
	if not _camouflage_paint_texture:
		_camouflage_paint_texture = CamouflageSystem.create_brush_canvas(color.darkened(0.24))
	_queue_camouflage_gpu_brush_stroke(world_position, world_normal, color, brush_radius)
	if target_mesh_path.is_empty():
		var global_painted := CamouflageSystem.paint_brush_on_texture(_camouflage_paint_texture, uv, color, brush_radius, angle)
		if global_painted != _camouflage_paint_texture:
			_camouflage_paint_texture = global_painted
		_apply_camouflage_texture_to_character(_camouflage_paint_texture, color, 1.0)
		return
	var mesh_instance := get_node_or_null(target_mesh_path) as MeshInstance3D
	if not mesh_instance:
		return
	var surface := _normalize_camouflage_target_surface(mesh_instance, target_surface)
	var target_texture := _get_camouflage_target_texture(target_mesh_path, surface)
	var painted := CamouflageSystem.paint_brush_on_texture(target_texture, uv, color, brush_radius, angle)
	_camouflage_paint_textures[_camouflage_texture_key(target_mesh_path, surface)] = painted
	_apply_camouflage_texture_to_mesh_surface(target_mesh_path, surface, painted, color, 1.0)


@rpc("any_peer", "call_local", "unreliable_ordered")
func _apply_camouflage_brush_stroke_batch(
	uvs: PackedVector2Array,
	color: Color,
	brush_radius: float,
	angle: float,
	world_positions: PackedVector3Array = PackedVector3Array(),
	world_normal: Vector3 = Vector3.UP,
	target_mesh_path: String = "",
	target_surface: int = 0,
	brush_radii: PackedFloat32Array = PackedFloat32Array(),
	uv_clip_triangles: PackedVector2Array = PackedVector2Array(),
	uv_clip_triangle_counts: PackedInt32Array = PackedInt32Array(),
	uv_footprint_metrics: PackedFloat32Array = PackedFloat32Array(),
	material_roughness: float = -1.0,
	material_metallic: float = -1.0,
	material_specular: float = -1.0
) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1 and not multiplayer.is_server():
		return
	if uvs.is_empty():
		return
	color.a = 1.0
	_apply_camouflage_material_scalars(material_roughness, material_metallic, material_specular)
	if not _camouflage_paint_texture:
		_camouflage_paint_texture = CamouflageSystem.create_brush_canvas(color.darkened(0.24))
	var clean_radii := _sanitize_camouflage_brush_radii(brush_radii, uvs.size(), brush_radius)
	var clean_normal := world_normal.normalized() if world_normal.length_squared() > 0.001 else Vector3.UP
	var clean_uv_clip := _sanitize_camouflage_uv_clip_data(uv_clip_triangles, uv_clip_triangle_counts, uvs.size())
	var clean_uv_footprint_metrics := _sanitize_camouflage_uv_footprint_metrics(uv_footprint_metrics, uvs.size())
	if target_mesh_path.is_empty():
		var global_painted := CamouflageSystem.paint_brush_strokes_on_texture(_camouflage_paint_texture, uvs, color, brush_radius, angle, clean_radii, clean_uv_clip.get("triangles", PackedVector2Array()), clean_uv_clip.get("counts", PackedInt32Array()), clean_uv_footprint_metrics)
		if global_painted != _camouflage_paint_texture:
			_camouflage_paint_texture = global_painted
		_apply_camouflage_texture_to_character(_camouflage_paint_texture, color, 1.0)
		_queue_camouflage_gpu_brush_strokes(world_positions, clean_normal, color, brush_radius, clean_radii)
		return
	var mesh_instance := get_node_or_null(target_mesh_path) as MeshInstance3D
	if not mesh_instance:
		return
	var surface := _normalize_camouflage_target_surface(mesh_instance, target_surface)
	var target_texture := _get_camouflage_target_texture(target_mesh_path, surface)
	var painted := CamouflageSystem.paint_brush_strokes_on_texture(target_texture, uvs, color, brush_radius, angle, clean_radii, clean_uv_clip.get("triangles", PackedVector2Array()), clean_uv_clip.get("counts", PackedInt32Array()), clean_uv_footprint_metrics)
	_camouflage_paint_textures[_camouflage_texture_key(target_mesh_path, surface)] = painted
	_apply_camouflage_texture_to_mesh_surface(target_mesh_path, surface, painted, color, 1.0)
	_queue_camouflage_gpu_brush_strokes(world_positions, clean_normal, color, brush_radius, clean_radii)


func _get_camouflage_target_texture(target_mesh_path: String, target_surface: int) -> Texture2D:
	var key := _camouflage_texture_key(target_mesh_path, target_surface)
	if _camouflage_paint_textures.has(key):
		return _camouflage_paint_textures[key] as Texture2D
	var texture := CamouflageSystem.create_paint_layer_canvas()
	_camouflage_paint_textures[key] = texture
	return texture


func _camouflage_texture_key(target_mesh_path: String, target_surface: int) -> String:
	return "%s:%d" % [target_mesh_path, target_surface]


func _normalize_camouflage_target_surface(mesh_instance: MeshInstance3D, target_surface: int) -> int:
	return clampi(target_surface, 0, _get_mesh_surface_count(mesh_instance) - 1)


func _apply_camouflage_texture_to_mesh_surface(
	target_mesh_path: String,
	target_surface: int,
	texture: Texture2D,
	primary_color: Color,
	confidence: float
) -> void:
	var mesh_instance := get_node_or_null(target_mesh_path) as MeshInstance3D
	if not mesh_instance:
		return
	var surface := _normalize_camouflage_target_surface(mesh_instance, target_surface)
	var key := _camouflage_texture_key(target_mesh_path, surface)
	var source_info := _get_camouflage_surface_source_info(mesh_instance, surface, key)
	var material := _ensure_camouflage_paint_layer_material(mesh_instance, surface, key, source_info)
	_configure_camouflage_paint_layer_controls(material)
	var display_strength := clampf(confidence, 0.0, 1.0)
	var bound_texture = material.get_meta("camouflage_bound_paint_texture") if material.has_meta("camouflage_bound_paint_texture") else null
	if bound_texture != texture:
		material.set_shader_parameter("paint_texture", texture)
		material.set_meta("camouflage_bound_paint_texture", texture)
	var bound_strength := float(material.get_meta("camouflage_bound_paint_strength")) if material.has_meta("camouflage_bound_paint_strength") else -1.0
	if absf(bound_strength - display_strength) > 0.001:
		material.set_shader_parameter("paint_display_strength", display_strength)
		material.set_meta("camouflage_bound_paint_strength", display_strength)


func _apply_camouflage_texture_to_character(texture: Texture2D, primary_color: Color, confidence: float) -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect_camouflage_meshes(meshes)
	for mesh_instance in meshes:
		var surface_count := _get_mesh_surface_count(mesh_instance)
		for surface in range(surface_count):
			var material := _ensure_unique_standard_material(mesh_instance, surface)
			_configure_camouflage_display_material(material)
			material.albedo_texture = texture
			material.albedo_color = Color.WHITE


func _collect_camouflage_meshes(result: Array[MeshInstance3D]) -> void:
	for mesh in [_bottom_mesh, _chest_mesh, _face_mesh, _limbs_head_mesh]:
		if mesh and is_instance_valid(mesh):
			result.append(mesh)
	if _active_skin_node and is_instance_valid(_active_skin_node):
		_find_meshes(_active_skin_node, result)


func _configure_camouflage_display_material(material: StandardMaterial3D) -> void:
	if not material:
		return
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.disable_receive_shadows = false
	material.roughness = _camouflage_paint_roughness
	material.metallic = _camouflage_paint_metallic
	material.set("metallic_specular", _camouflage_paint_specular)
	if _camouflage_paint_normal_texture:
		material.set("normal_enabled", true)
		material.set("normal_texture", _camouflage_paint_normal_texture)
		material.set("normal_scale", _camouflage_paint_normal_scale)


func _get_mesh_surface_count(mesh_instance: MeshInstance3D) -> int:
	var count := mesh_instance.get_surface_override_material_count()
	if count <= 0 and mesh_instance.mesh:
		count = mesh_instance.mesh.get_surface_count()
	return max(1, count)


func _get_mesh_surface_material(mesh_instance: MeshInstance3D, surface: int) -> Material:
	if not mesh_instance:
		return null
	var material := mesh_instance.get_surface_override_material(surface)
	if not material:
		material = mesh_instance.material_override
	if not material and mesh_instance.mesh and surface < mesh_instance.mesh.get_surface_count():
		material = mesh_instance.mesh.surface_get_material(surface)
	return material


func _get_material_base_color(material: Material) -> Color:
	if material is StandardMaterial3D:
		var color := (material as StandardMaterial3D).albedo_color
		color.a = 1.0
		return color
	return Color.WHITE


func _get_material_albedo_texture(material: Material) -> Texture2D:
	if material is StandardMaterial3D:
		return (material as StandardMaterial3D).albedo_texture
	return null


func _get_camouflage_surface_source_info(mesh_instance: MeshInstance3D, surface: int, key: String) -> Dictionary:
	if _camouflage_source_material_infos.has(key):
		return _camouflage_source_material_infos[key] as Dictionary
	var material := _get_mesh_surface_material(mesh_instance, surface)
	if material is ShaderMaterial and bool((material as ShaderMaterial).get_meta("camouflage_paint_layer", false)):
		var shader_material := material as ShaderMaterial
		var existing_info := {
			"base_color": shader_material.get_shader_parameter("base_color") as Color,
			"base_texture": shader_material.get_shader_parameter("base_texture") as Texture2D,
			"use_base_texture": bool(shader_material.get_shader_parameter("use_base_texture")),
		}
		_camouflage_source_material_infos[key] = existing_info
		return existing_info
	var source_texture := _get_material_albedo_texture(material)
	var source_info := {
		"base_color": _get_material_base_color(material),
		"base_texture": source_texture,
		"use_base_texture": source_texture != null,
	}
	_camouflage_source_material_infos[key] = source_info
	return source_info


func _ensure_camouflage_paint_layer_material(
	mesh_instance: MeshInstance3D,
	surface: int,
	key: String,
	source_info: Dictionary
) -> ShaderMaterial:
	if _camouflage_paint_layer_materials.has(key):
		var cached_material := _camouflage_paint_layer_materials[key] as ShaderMaterial
		if cached_material and is_instance_valid(cached_material):
			mesh_instance.set_surface_override_material(surface, cached_material)
			return cached_material

	var material := _get_mesh_surface_material(mesh_instance, surface)
	if material is ShaderMaterial and bool((material as ShaderMaterial).get_meta("camouflage_paint_layer", false)):
		_camouflage_paint_layer_materials[key] = material
		return material as ShaderMaterial

	var shader_material := ShaderMaterial.new()
	shader_material.shader = CAMOUFLAGE_PAINT_LAYER_SHADER
	shader_material.resource_local_to_scene = true
	shader_material.set_meta("camouflage_paint_layer", true)
	shader_material.set_shader_parameter("base_color", source_info.get("base_color", Color.WHITE))
	var source_texture := source_info.get("base_texture", null) as Texture2D
	if source_texture:
		shader_material.set_shader_parameter("base_texture", source_texture)
	shader_material.set_shader_parameter("use_base_texture", bool(source_info.get("use_base_texture", false)))
	_configure_camouflage_paint_layer_controls(shader_material)
	mesh_instance.set_surface_override_material(surface, shader_material)
	_camouflage_paint_layer_materials[key] = shader_material
	return shader_material


func _configure_camouflage_paint_layer_controls(material: ShaderMaterial) -> void:
	if not material:
		return
	material.set_shader_parameter("paint_exact_color_match", _camouflage_paint_exact_color_match)
	material.set_shader_parameter("paint_roughness", _camouflage_paint_roughness)
	material.set_shader_parameter("paint_metallic", _camouflage_paint_metallic)
	material.set_shader_parameter("paint_specular", _camouflage_paint_specular)
	material.set_shader_parameter("use_paint_normal_texture", _camouflage_paint_normal_texture != null)
	if _camouflage_paint_normal_texture:
		material.set_shader_parameter("paint_normal_texture", _camouflage_paint_normal_texture)
	material.set_shader_parameter("paint_normal_scale", _camouflage_paint_normal_scale)


func _apply_camouflage_material_scalars(roughness: float, metallic: float, specular: float) -> void:
	var changed := false
	if roughness >= 0.0:
		var next_roughness := clampf(roughness, 0.0, 1.0)
		changed = changed or absf(next_roughness - _camouflage_paint_roughness) > 0.001
		_camouflage_paint_roughness = next_roughness
	if metallic >= 0.0:
		var next_metallic := clampf(metallic, 0.0, 1.0)
		changed = changed or absf(next_metallic - _camouflage_paint_metallic) > 0.001
		_camouflage_paint_metallic = next_metallic
	if specular >= 0.0:
		var next_specular := clampf(specular, 0.0, 1.0)
		changed = changed or absf(next_specular - _camouflage_paint_specular) > 0.001
		_camouflage_paint_specular = next_specular
	if not changed:
		return
	for material in _camouflage_paint_layer_materials.values():
		if material is ShaderMaterial and is_instance_valid(material):
			_configure_camouflage_paint_layer_controls(material as ShaderMaterial)
	for material in _camouflage_surface_materials.values():
		if material is StandardMaterial3D and is_instance_valid(material):
			_configure_camouflage_display_material(material as StandardMaterial3D)
	_configure_camouflage_gpu_overlay_materials()


func _ensure_camouflage_gpu_painter() -> bool:
	if _camouflage_gpu_unavailable:
		return false
	if _camouflage_gpu_atlas_manager and is_instance_valid(_camouflage_gpu_atlas_manager) and _camouflage_gpu_camera_brush and is_instance_valid(_camouflage_gpu_camera_brush):
		return true

	var manager_script = load("res://addons/gpu_texture_painter/manager/overlay_atlas_manager.gd")
	var brush_script = load("res://addons/gpu_texture_painter/brush/camera_brush.gd")
	if not manager_script or not brush_script:
		_camouflage_gpu_unavailable = true
		push_warning("Chameleon GPU painter addon is unavailable; falling back to CPU camouflage paint.")
		return false

	if not _prepare_camouflage_gpu_meshes():
		_camouflage_gpu_unavailable = true
		push_warning("Chameleon GPU painter could not find or build UV2 paint meshes; falling back to CPU camouflage paint.")
		return false

	var manager = manager_script.new()
	if not manager is Node3D:
		_camouflage_gpu_unavailable = true
		return false
	manager.name = "ChameleonGPUOverlayAtlasManager"
	add_child(manager)
	_camouflage_gpu_atlas_manager = manager as Node3D
	_camouflage_gpu_atlas_manager.set("atlas_size", CAMOUFLAGE_GPU_ATLAS_SIZE)
	_camouflage_gpu_atlas_manager.set("overlay_shader", CHAMELEON_GPU_PBR_OVERLAY_SHADER)
	_camouflage_gpu_atlas_manager.set("apply_on_ready", false)

	var brush = brush_script.new()
	if not brush is Node3D:
		_camouflage_gpu_unavailable = true
		return false
	brush.name = "ChameleonGPUCameraBrush"
	add_child(brush)
	_camouflage_gpu_camera_brush = brush as Node3D
	_camouflage_gpu_camera_brush.top_level = true
	_camouflage_gpu_camera_brush.set("projection", Camera3D.PROJECTION_ORTHOGONAL)
	_camouflage_gpu_camera_brush.set("size", 0.35)
	_camouflage_gpu_camera_brush.set("max_distance", 3.0)
	_camouflage_gpu_camera_brush.set("start_distance_fade", 1.0)
	_camouflage_gpu_camera_brush.set("min_bleed", 1)
	_camouflage_gpu_camera_brush.set("max_bleed", 2)
	_camouflage_gpu_camera_brush.set("resolution", Vector2i(256, 256))
	_camouflage_gpu_camera_brush.set("draw_speed", 180.0)
	_camouflage_gpu_camera_brush.set("drawing", false)

	if _camouflage_gpu_atlas_manager.has_method("apply"):
		_camouflage_gpu_atlas_manager.call("apply")
	_configure_camouflage_gpu_overlay_materials()
	return true


func _prepare_camouflage_gpu_meshes() -> bool:
	var meshes: Array[MeshInstance3D] = []
	_collect_camouflage_meshes(meshes)
	var prepared_count := 0
	for mesh_instance in meshes:
		if not mesh_instance or not is_instance_valid(mesh_instance):
			continue
		if not _ensure_mesh_uv2_from_uv(mesh_instance):
			continue
		mesh_instance.layers |= 1 << CAMOUFLAGE_GPU_OVERLAY_LAYER
		var mesh := mesh_instance.mesh
		if mesh.lightmap_size_hint == Vector2i.ZERO:
			mesh.lightmap_size_hint = CAMOUFLAGE_GPU_DEFAULT_LIGHTMAP_HINT
		prepared_count += 1
	return prepared_count > 0


func _ensure_mesh_uv2_from_uv(mesh_instance: MeshInstance3D) -> bool:
	if not mesh_instance or not mesh_instance.mesh:
		return false
	if _mesh_has_uv2(mesh_instance.mesh):
		return true
	var source_mesh := mesh_instance.mesh
	var paint_mesh := ArrayMesh.new()
	paint_mesh.resource_local_to_scene = true
	paint_mesh.lightmap_size_hint = CAMOUFLAGE_GPU_DEFAULT_LIGHTMAP_HINT
	for surface in range(source_mesh.get_surface_count()):
		var arrays := CamouflageSystem._get_mesh_surface_arrays_static(source_mesh, surface)
		if not arrays is Array or arrays.is_empty() or arrays.size() <= Mesh.ARRAY_TEX_UV2:
			return false
		var uv_value = arrays[Mesh.ARRAY_TEX_UV]
		if not uv_value is PackedVector2Array or (uv_value as PackedVector2Array).is_empty():
			return false
		arrays[Mesh.ARRAY_TEX_UV2] = uv_value
		var primitive := Mesh.PRIMITIVE_TRIANGLES
		if source_mesh.has_method("surface_get_primitive_type"):
			primitive = int(source_mesh.call("surface_get_primitive_type", surface))
		paint_mesh.add_surface_from_arrays(primitive, arrays)
		if surface < paint_mesh.get_surface_count():
			var surface_material := source_mesh.surface_get_material(surface)
			if surface_material:
				paint_mesh.surface_set_material(surface, surface_material)
	if paint_mesh.get_surface_count() <= 0:
		return false
	mesh_instance.mesh = paint_mesh
	return _mesh_has_uv2(paint_mesh)


func _mesh_has_uv2(mesh: Mesh) -> bool:
	if not mesh:
		return false
	for surface in range(mesh.get_surface_count()):
		var arrays := []
		if mesh is PrimitiveMesh:
			arrays = (mesh as PrimitiveMesh).get_mesh_arrays()
		elif mesh.has_method("surface_get_arrays"):
			arrays = mesh.call("surface_get_arrays", surface)
		if arrays.is_empty() or arrays.size() <= Mesh.ARRAY_TEX_UV2:
			return false
		var uv2_value = arrays[Mesh.ARRAY_TEX_UV2]
		if not uv2_value is PackedVector2Array:
			return false
		var uv2s: PackedVector2Array = uv2_value
		if uv2s.is_empty():
			return false
	return true


func _configure_camouflage_gpu_overlay_materials() -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect_camouflage_meshes(meshes)
	for mesh_instance in meshes:
		if not mesh_instance or not is_instance_valid(mesh_instance):
			continue
		var material := mesh_instance.material_overlay as ShaderMaterial
		if not material:
			continue
		material.set_shader_parameter("paint_display_strength", 1.0)
		material.set_shader_parameter("paint_roughness", _camouflage_paint_roughness)
		material.set_shader_parameter("paint_metallic", _camouflage_paint_metallic)
		material.set_shader_parameter("paint_specular", _camouflage_paint_specular)
		material.set_shader_parameter("use_paint_normal_texture", _camouflage_paint_normal_texture != null)
		if _camouflage_paint_normal_texture:
			material.set_shader_parameter("paint_normal_texture", _camouflage_paint_normal_texture)
		material.set_shader_parameter("paint_normal_scale", _camouflage_paint_normal_scale)


func _queue_camouflage_gpu_brush_strokes(
	world_positions: PackedVector3Array,
	world_normal: Vector3,
	color: Color,
	brush_radius: float,
	brush_radii: PackedFloat32Array = PackedFloat32Array()
) -> void:
	if world_positions.is_empty():
		return
	for index in range(world_positions.size()):
		var radius := brush_radius
		if index < brush_radii.size():
			radius = brush_radii[index]
		_queue_camouflage_gpu_brush_stroke(world_positions[index], world_normal, color, radius)


func _queue_camouflage_gpu_brush_stroke(world_position: Vector3, world_normal: Vector3, color: Color, brush_radius: float) -> void:
	if _camouflage_gpu_unavailable:
		return
	var normal := world_normal.normalized() if world_normal.length_squared() > 0.001 else Vector3.UP
	var clean_color := color
	clean_color.a = 1.0
	_camouflage_gpu_stroke_queue.append({
		"position": world_position,
		"normal": normal,
		"color": clean_color,
		"radius": _sanitize_camouflage_brush_radius(brush_radius),
		"roughness": _camouflage_paint_roughness,
		"metallic": _camouflage_paint_metallic,
		"specular": _camouflage_paint_specular,
	})
	while _camouflage_gpu_stroke_queue.size() > CAMOUFLAGE_GPU_MAX_QUEUED_STROKES:
		_camouflage_gpu_stroke_queue.pop_front()


func _process_camouflage_gpu_painter(delta: float) -> void:
	if _camouflage_gpu_draw_timer > 0.0:
		_camouflage_gpu_draw_timer = maxf(0.0, _camouflage_gpu_draw_timer - delta)
		if _camouflage_gpu_draw_timer <= 0.0 and _camouflage_gpu_camera_brush and is_instance_valid(_camouflage_gpu_camera_brush):
			_camouflage_gpu_camera_brush.set("drawing", false)
		return
	if _camouflage_gpu_stroke_queue.is_empty():
		return
	if not _ensure_camouflage_gpu_painter():
		_camouflage_gpu_stroke_queue.clear()
		return
	var stroke: Dictionary = _camouflage_gpu_stroke_queue.pop_front()
	_apply_camouflage_material_scalars(
		float(stroke.get("roughness", _camouflage_paint_roughness)),
		float(stroke.get("metallic", _camouflage_paint_metallic)),
		float(stroke.get("specular", _camouflage_paint_specular))
	)
	_start_camouflage_gpu_brush_stroke(stroke)


func _start_camouflage_gpu_brush_stroke(stroke: Dictionary) -> void:
	if not _camouflage_gpu_camera_brush or not is_instance_valid(_camouflage_gpu_camera_brush):
		return
	var world_position: Vector3 = stroke.get("position", global_position)
	var normal: Vector3 = stroke.get("normal", Vector3.UP)
	normal = normal.normalized() if normal.length_squared() > 0.001 else Vector3.UP
	var color: Color = stroke.get("color", _camouflage_brush_base_color)
	color.a = 1.0
	var texture_radius := clampf(float(stroke.get("radius", 46.0)), 10.0, 160.0)
	var world_size := clampf(texture_radius / 120.0, 0.10, 1.85)
	var brush_distance := clampf(world_size * 1.35 + 0.30, 0.38, 3.0)
	var brush_origin := world_position + normal * brush_distance
	var up := Vector3.UP
	if absf(normal.dot(up)) > 0.92:
		up = Vector3.RIGHT

	_camouflage_gpu_camera_brush.global_position = brush_origin
	_camouflage_gpu_camera_brush.look_at(world_position, up)
	_camouflage_gpu_camera_brush.set("color", color)
	_camouflage_gpu_camera_brush.set("size", world_size)
	_camouflage_gpu_camera_brush.set("max_distance", brush_distance + world_size + 0.45)
	_camouflage_gpu_camera_brush.set("drawing", true)
	_camouflage_gpu_draw_timer = CAMOUFLAGE_GPU_BRUSH_TIME


func _ensure_unique_standard_material(mesh_instance: MeshInstance3D, surface: int) -> StandardMaterial3D:
	if not mesh_instance:
		return StandardMaterial3D.new()
	var cache_key := _camouflage_texture_key(str(get_path_to(mesh_instance)), surface) if mesh_instance.is_inside_tree() else "%d:%d" % [mesh_instance.get_instance_id(), surface]
	if _camouflage_surface_materials.has(cache_key):
		var cached_material := _camouflage_surface_materials[cache_key] as StandardMaterial3D
		if cached_material and is_instance_valid(cached_material):
			mesh_instance.set_surface_override_material(surface, cached_material)
			return cached_material

	var material := _get_mesh_surface_material(mesh_instance, surface)
	if material is StandardMaterial3D and bool((material as StandardMaterial3D).get_meta("camouflage_unique_surface", false)):
		_camouflage_surface_materials[cache_key] = material
		return material as StandardMaterial3D

	var standard: StandardMaterial3D = null
	if material is StandardMaterial3D:
		standard = (material as StandardMaterial3D).duplicate()
	else:
		standard = StandardMaterial3D.new()
	standard.resource_local_to_scene = true
	standard.set_meta("camouflage_unique_surface", true)
	mesh_instance.set_surface_override_material(surface, standard)
	_camouflage_surface_materials[cache_key] = standard
	return standard


func _sanitize_camouflage_palette(palette: Array) -> Array:
	var clean: Array[Color] = []
	for value in palette:
		if value is Color:
			var color := value as Color
			color.a = 1.0
			clean.append(color)
	if clean.is_empty():
		clean.append(Color(0.5, 0.58, 0.48, 1.0))
	while clean.size() < 4:
		var base: Color = clean[0]
		clean.append(base.lightened(0.12 * float(clean.size())))
	return clean.slice(0, 4)


func _sanitize_camouflage_brush_radii(
	brush_radii: PackedFloat32Array,
	expected_count: int,
	fallback_radius: float
) -> PackedFloat32Array:
	var clean := PackedFloat32Array()
	if brush_radii.size() != expected_count:
		return clean
	for radius in brush_radii:
		clean.append(_sanitize_camouflage_brush_radius(radius))
	return clean


func _sanitize_camouflage_uv_clip_data(
	uv_clip_triangles: PackedVector2Array,
	uv_clip_triangle_counts: PackedInt32Array,
	expected_stamp_count: int
) -> Dictionary:
	var clean_triangles := PackedVector2Array()
	var clean_counts := PackedInt32Array()
	if uv_clip_triangle_counts.size() != expected_stamp_count:
		return {"triangles": clean_triangles, "counts": clean_counts}
	var read_index := 0
	for count_value in uv_clip_triangle_counts:
		var count := clampi(int(count_value), 0, CamouflageSystem.BRUSH_UV_CLIP_MAX_TRIANGLES)
		if read_index + count * 3 > uv_clip_triangles.size():
			return {"triangles": PackedVector2Array(), "counts": PackedInt32Array()}
		clean_counts.append(count)
		for _triangle in range(count):
			for _corner in range(3):
				var uv := uv_clip_triangles[read_index]
				clean_triangles.append(Vector2(clampf(uv.x, 0.0, 1.0), clampf(uv.y, 0.0, 1.0)))
				read_index += 1
	if read_index != uv_clip_triangles.size():
		return {"triangles": PackedVector2Array(), "counts": PackedInt32Array()}
	return {"triangles": clean_triangles, "counts": clean_counts}


func _sanitize_camouflage_uv_footprint_metrics(
	uv_footprint_metrics: PackedFloat32Array,
	expected_stamp_count: int
) -> PackedFloat32Array:
	var clean := PackedFloat32Array()
	if uv_footprint_metrics.size() != expected_stamp_count * 3:
		return clean
	for value in uv_footprint_metrics:
		clean.append(clampf(value, -100000000.0, 100000000.0))
	return clean


func _sanitize_camouflage_brush_radius(radius: float) -> float:
	return clampf(radius, CamouflageSystem.BRUSH_PRECISION_SAMPLE_MIN_RADIUS, CamouflageSystem.BRUSH_MAX_RADIUS)


func set_character_model(model_id: String) -> void:
	var normalized := _resolve_character_model_for_role(model_id)
	character_model_id = normalized
	_remote_visual_position_initialized = false
	if not _body:
		return

	if normalized == CharacterSkinCatalog.GODOT_ROBOT_ID:
		if _active_skin_node and is_instance_valid(_active_skin_node):
			if _active_skin_node.get_parent():
				_active_skin_node.get_parent().remove_child(_active_skin_node)
			_active_skin_node.queue_free()
		_active_skin_node = null
		if _robot_visual_root:
			_robot_visual_root.visible = true
		if is_stalker():
			_refresh_stalker_visibility_view(true)
			call_deferred("_refresh_stalker_visibility_view", true)
		return

	var scene_path := CharacterSkinCatalog.scene_path_for(normalized)
	var scene: PackedScene = load(scene_path)
	if not scene:
		push_warning("Character model scene could not be loaded: " + scene_path)
		return

	if _active_skin_node and is_instance_valid(_active_skin_node):
		if _active_skin_node.get_parent():
			_active_skin_node.get_parent().remove_child(_active_skin_node)
		_active_skin_node.queue_free()

	_active_skin_node = scene.instantiate() as Node3D
	if not _active_skin_node:
		return

	_active_skin_node.name = "CustomCharacterSkin"
	var model := CharacterSkinCatalog.get_model(normalized)
	_active_skin_node.scale = model.get("scale", Vector3.ONE)
	_active_skin_node.position = model.get("offset", Vector3.ZERO)
	if _robot_visual_root:
		_robot_visual_root.visible = false
	_body.add_child(_active_skin_node)
	_play_skin_action("idle")
	if is_stalker():
		_refresh_stalker_visibility_view(true)
		call_deferred("_refresh_stalker_visibility_view", true)


func _resolve_character_model_for_role(model_id: String) -> String:
	var normalized := CharacterSkinCatalog.normalize(model_id)
	if role == Network.Role.HUNTER and normalized == CharacterSkinCatalog.DEFAULT_ID:
		return CharacterSkinCatalog.HUNTER_SHOOTER_ID
	if role != Network.Role.HUNTER and normalized == CharacterSkinCatalog.HUNTER_SHOOTER_ID:
		return CharacterSkinCatalog.BASIC_HUMANOID_ID
	return normalized


@rpc("any_peer", "call_local", "reliable")
func apply_prop_disguise(preset: Dictionary) -> void:
	if not _body:
		push_warning("Cannot apply prop disguise without a body node.")
		return
	var mesh_type := str(preset.get("mesh", "none"))
	if mesh_type == "none":
		clear_prop_disguise()
		return

	var effective_preset := preset.duplicate(true)
	_clear_prop_disguise_node()
	_prop_disguise_node = _build_prop_disguise_node(effective_preset)
	if not _prop_disguise_node:
		return

	_prop_disguise_node.name = "PropDisguise"
	_prop_disguise_height_offset = 0.0
	_body.add_child(_prop_disguise_node)
	var visual_bounds := _align_prop_disguise_visual_to_ground()
	if visual_bounds.size != Vector3.ZERO:
		effective_preset["prop_height"] = visual_bounds.size.y
	_prop_disguise_base_position = _prop_disguise_node.position
	_set_character_visual_visible(false)
	_is_prop_disguised = true
	_current_disguise_name = str(effective_preset.get("name", "Prop"))
	_apply_prop_disguise_collision(effective_preset)
	_snap_prop_disguise_to_floor()
	_play_prop_disguise_land_animation(effective_preset)
	_play_audio(_disguise_audio)
	print("[ShapeShift] ", name, " disguised as ", _current_disguise_name)


@rpc("any_peer", "call_local", "reliable")
func clear_prop_disguise() -> void:
	_clear_prop_disguise_node()
	_set_character_visual_visible(true)
	_is_prop_disguised = false
	_current_disguise_name = ""
	_prop_disguise_base_position = Vector3.ZERO
	_prop_disguise_height_offset = 0.0
	_restore_default_collision_shape()
	print("[ShapeShift] ", name, " cleared disguise")


func is_disguised() -> bool:
	return _is_prop_disguised


func get_disguise_name() -> String:
	return _current_disguise_name


func _process_prop_disguise_height(delta: float) -> void:
	if not _is_prop_disguised:
		return
	var direction := 0.0
	if Input.is_physical_key_pressed(KEY_UP):
		direction += 1.0
	if Input.is_physical_key_pressed(KEY_DOWN):
		direction -= 1.0
	if is_zero_approx(direction):
		return
	_adjust_prop_disguise_height(direction * PROP_DISGUISE_HEIGHT_SPEED * delta)


func _adjust_prop_disguise_height(delta: float) -> void:
	if _prop_disguise_tween and _prop_disguise_tween.is_valid():
		_prop_disguise_tween.kill()
		_prop_disguise_tween = null
	if _prop_disguise_node and is_instance_valid(_prop_disguise_node):
		_prop_disguise_node.scale = Vector3.ONE
	var next_offset := clampf(
		_prop_disguise_height_offset + delta,
		PROP_DISGUISE_MIN_HEIGHT_OFFSET,
		PROP_DISGUISE_MAX_HEIGHT_OFFSET
	)
	_apply_prop_disguise_height_offset(next_offset)
	_set_prop_disguise_height_offset.rpc(next_offset)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _set_prop_disguise_height_offset(offset: float) -> void:
	_apply_prop_disguise_height_offset(offset)


func _apply_prop_disguise_height_offset(offset: float) -> void:
	_prop_disguise_height_offset = clampf(offset, PROP_DISGUISE_MIN_HEIGHT_OFFSET, PROP_DISGUISE_MAX_HEIGHT_OFFSET)
	if _prop_disguise_node and is_instance_valid(_prop_disguise_node):
		_prop_disguise_node.position = _prop_disguise_base_position + Vector3(0.0, _prop_disguise_height_offset, 0.0)


func _cache_default_collision_shape() -> void:
	if not _collision_shape or not _collision_shape.shape:
		return
	_default_collision_shape = _collision_shape.shape.duplicate()
	_default_collision_transform = _collision_shape.transform


func _apply_prop_disguise_collision(preset: Dictionary) -> void:
	if not _collision_shape:
		return
	var dimensions := _get_prop_collision_dimensions(preset)
	var radius: float = dimensions.x
	var height: float = dimensions.y
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = height
	_collision_shape.shape = cylinder
	_collision_shape.position = Vector3(0.0, height * 0.5, 0.0)
	_collision_shape.rotation = Vector3.ZERO
	_collision_shape.scale = Vector3.ONE


func _snap_prop_disguise_to_floor() -> void:
	if not is_inside_tree() or not get_world_3d():
		return
	var space_state := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * PROP_DISGUISE_GROUND_SNAP_UP
	var to := global_position + Vector3.DOWN * PROP_DISGUISE_GROUND_SNAP_DOWN
	var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_COLLISION_MASK)
	query.exclude = [get_rid()]
	query.hit_from_inside = false
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var hit_position: Vector3 = hit.get("position", global_position)
	global_position.y = hit_position.y
	velocity.y = 0.0


func _align_prop_disguise_visual_to_ground() -> AABB:
	if not _body or not _prop_disguise_node or not is_instance_valid(_prop_disguise_node):
		return AABB()
	var bounds := _calculate_prop_disguise_bounds_in_body_space()
	if bounds.size == Vector3.ZERO:
		return AABB()
	var ground_local_y := _body.to_local(global_position).y
	_prop_disguise_node.position.y += ground_local_y - bounds.position.y
	return _calculate_prop_disguise_bounds_in_body_space()


func _calculate_prop_disguise_bounds_in_body_space() -> AABB:
	if not _body or not _prop_disguise_node or not is_instance_valid(_prop_disguise_node):
		return AABB()
	var meshes: Array[MeshInstance3D] = []
	_find_prop_disguise_mesh_instances(_prop_disguise_node, meshes)
	var has_bounds := false
	var bounds := AABB()
	for mesh_instance in meshes:
		if not mesh_instance.mesh:
			continue
		var local_bounds := _transform_aabb(_body.global_transform.affine_inverse() * mesh_instance.global_transform, mesh_instance.get_aabb())
		if not has_bounds:
			bounds = local_bounds
			has_bounds = true
		else:
			bounds = bounds.merge(local_bounds)
	return bounds if has_bounds else AABB()


func _find_prop_disguise_mesh_instances(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		_find_prop_disguise_mesh_instances(child, result)


func _transform_aabb(transform: Transform3D, box: AABB) -> AABB:
	var min_corner := Vector3(INF, INF, INF)
	var max_corner := Vector3(-INF, -INF, -INF)
	for x in [0.0, 1.0]:
		for y in [0.0, 1.0]:
			for z in [0.0, 1.0]:
				var point := box.position + Vector3(box.size.x * x, box.size.y * y, box.size.z * z)
				var transformed := transform * point
				min_corner = min_corner.min(transformed)
				max_corner = max_corner.max(transformed)
	return AABB(min_corner, max_corner - min_corner)


func _restore_default_collision_shape() -> void:
	if not _collision_shape or not _default_collision_shape:
		return
	_collision_shape.shape = _default_collision_shape.duplicate()
	_collision_shape.transform = _default_collision_transform


func _get_prop_collision_dimensions(preset: Dictionary) -> Vector2:
	var radius := float(preset.get("collision_radius", 0.0))
	var height := float(preset.get("collision_height", 0.0))
	if radius <= 0.0 or height <= 0.0:
		var size: Vector3 = preset.get("size", Vector3.ONE)
		radius = maxf(absf(size.x), absf(size.z)) * 0.42
		height = maxf(absf(size.y) * 0.82, radius * 0.75)
	if preset.has("prop_height"):
		height = maxf(height, float(preset.get("prop_height", height)))
	radius = clampf(radius, PROP_COLLISION_MIN_RADIUS, PROP_COLLISION_MAX_RADIUS)
	height = clampf(height, PROP_COLLISION_MIN_HEIGHT, PROP_COLLISION_MAX_HEIGHT)
	return Vector2(radius, height)


func _clear_prop_disguise_node() -> void:
	if _prop_disguise_tween and _prop_disguise_tween.is_valid():
		_prop_disguise_tween.kill()
	_prop_disguise_tween = null
	if _prop_disguise_node and is_instance_valid(_prop_disguise_node):
		_prop_disguise_node.queue_free()
	_prop_disguise_node = null


func _play_prop_disguise_land_animation(preset: Dictionary) -> void:
	if not _prop_disguise_node or not is_instance_valid(_prop_disguise_node):
		return
	if _prop_disguise_tween and _prop_disguise_tween.is_valid():
		_prop_disguise_tween.kill()

	var final_position: Vector3 = _prop_disguise_base_position
	var prop_height: float = maxf(float(preset.get("prop_height", 1.0)), 0.6)
	var drop_height: float = clampf(float(preset.get("drop_height", prop_height * 0.32)), PROP_DISGUISE_DROP_MIN_HEIGHT, PROP_DISGUISE_DROP_MAX_HEIGHT)
	var bounce_height: float = clampf(prop_height * 0.045, 0.12, 0.42)

	_prop_disguise_node.position = final_position + Vector3(0.0, drop_height, 0.0)
	_prop_disguise_node.scale = Vector3(0.96, 1.04, 0.96)

	_prop_disguise_tween = create_tween()
	_prop_disguise_tween.set_parallel(false)
	_prop_disguise_tween.tween_property(_prop_disguise_node, "position", final_position, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_prop_disguise_tween.parallel().tween_property(_prop_disguise_node, "scale", Vector3(1.0, 1.0, 1.0), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_prop_disguise_tween.tween_property(_prop_disguise_node, "scale", Vector3(1.08, 0.82, 1.08), 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_prop_disguise_tween.parallel().tween_property(_prop_disguise_node, "position", final_position - Vector3(0.0, 0.035, 0.0), 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_prop_disguise_tween.tween_property(_prop_disguise_node, "scale", Vector3(0.95, 1.08, 0.95), 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_prop_disguise_tween.parallel().tween_property(_prop_disguise_node, "position", final_position + Vector3(0.0, bounce_height, 0.0), 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_prop_disguise_tween.tween_property(_prop_disguise_node, "position", final_position, 0.13).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_prop_disguise_tween.parallel().tween_property(_prop_disguise_node, "scale", Vector3.ONE, 0.13).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _set_character_visual_visible(visible_value: bool) -> void:
	if _robot_visual_root:
		_robot_visual_root.visible = visible_value and character_model_id == CharacterSkinCatalog.GODOT_ROBOT_ID
	if _active_skin_node and is_instance_valid(_active_skin_node):
		_active_skin_node.visible = visible_value and character_model_id != CharacterSkinCatalog.GODOT_ROBOT_ID


func _build_prop_disguise_node(preset: Dictionary) -> Node3D:
	var holder := Node3D.new()
	holder.position = preset.get("offset", Vector3.ZERO)
	holder.rotation = preset.get("rotation", Vector3.ZERO)
	var mesh_type := str(preset.get("mesh", "box"))
	if mesh_type == "scene":
		var scene_path := str(preset.get("scene_path", ""))
		var scene := load(scene_path)
		if scene is PackedScene:
			var scene_node := (scene as PackedScene).instantiate() as Node3D
			if scene_node:
				scene_node.name = "ScenePropVisual"
				scene_node.scale = preset.get("scale", Vector3.ONE)
				holder.add_child(scene_node)
				_apply_scene_prop_material(scene_node, str(preset.get("material_path", "")))
				_disable_prop_collisions(scene_node)
		return holder
	match mesh_type:
		"cactus":
			_add_prop_mesh(holder, "cylinder", Vector3(0.38, 1.7, 0.38), Vector3(0, 0, 0), preset.get("color", Color.GREEN))
			_add_prop_mesh(holder, "sphere", Vector3(0.42, 0.42, 0.42), Vector3(0, 0.82, 0), preset.get("color", Color.GREEN))
			_add_prop_mesh(holder, "cylinder", Vector3(0.18, 0.72, 0.18), Vector3(0.36, 0.24, 0), preset.get("color", Color.GREEN), Vector3(0, 0, PI * 0.5))
			_add_prop_mesh(holder, "cylinder", Vector3(0.18, 0.62, 0.18), Vector3(-0.33, 0.08, 0), preset.get("color", Color.GREEN), Vector3(0, 0, PI * 0.5))
		_:
			_add_prop_mesh(holder, mesh_type, preset.get("size", Vector3.ONE), Vector3.ZERO, preset.get("color", Color.WHITE))
	return holder


func _add_prop_mesh(parent: Node3D, mesh_type: String, mesh_size: Vector3, local_pos: Vector3, color: Color, local_rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.position = local_pos
	mesh_instance.rotation = local_rot
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	match mesh_type:
		"sphere":
			var sphere := SphereMesh.new()
			sphere.radius = 0.5
			sphere.height = 1.0
			mesh_instance.mesh = sphere
		"cylinder":
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.5
			cylinder.bottom_radius = 0.5
			cylinder.height = 1.0
			mesh_instance.mesh = cylinder
		_:
			var box := BoxMesh.new()
			box.size = Vector3.ONE
			mesh_instance.mesh = box
	mesh_instance.scale = mesh_size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.72
	mat.metallic = 0.18 if mesh_type == "cylinder" else 0.0
	mesh_instance.material_override = mat
	parent.add_child(mesh_instance)
	return mesh_instance


func _disable_prop_collisions(node: Node) -> void:
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true
	elif node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0
	for child in node.get_children():
		_disable_prop_collisions(child)


func _apply_scene_prop_material(node: Node, material_path: String) -> void:
	if material_path.is_empty():
		return
	var material_resource := load(material_path)
	if not material_resource is Material:
		return
	_apply_material_to_unassigned_prop_meshes(node, material_resource as Material)


func _apply_material_to_unassigned_prop_meshes(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if not _prop_mesh_has_material(mesh_instance):
			mesh_instance.material_override = material
	for child in node.get_children():
		_apply_material_to_unassigned_prop_meshes(child, material)


func _prop_mesh_has_material(mesh_instance: MeshInstance3D) -> bool:
	if mesh_instance.material_override:
		return true
	var override_count := mesh_instance.get_surface_override_material_count()
	for i in range(override_count):
		if mesh_instance.get_surface_override_material(i):
			return true
	if mesh_instance.mesh:
		for i in range(mesh_instance.mesh.get_surface_count()):
			if mesh_instance.mesh.surface_get_material(i):
				return true
	return false


func _apply_body_rotation(move_velocity: Vector3) -> void:
	if _body and _body.has_method("apply_rotation"):
		_body.apply_rotation(move_velocity)


func _animate_body(move_velocity: Vector3) -> void:
	if _active_skin_node:
		if not is_on_floor():
			_play_skin_action("fall" if move_velocity.y < 0.0 else "jump")
		elif Vector2(move_velocity.x, move_velocity.z).length_squared() > 0.01:
			_play_skin_action("move")
		else:
			_play_skin_action("idle")
		return

	if _body and _body.has_method("animate"):
		_body.animate(move_velocity)


func _play_body_jump(jump_type: String = "Jump") -> void:
	_play_audio(_jump_audio)
	if _active_skin_node:
		_play_skin_action("jump")
	elif _body and _body.has_method("play_jump_animation"):
		_body.play_jump_animation(jump_type)


func _setup_player_audio() -> void:
	_jump_audio = _make_audio_player("JumpAudio", "res://assets/audio/player/robot_jump.wav", -7.0)
	_land_audio = _make_audio_player("LandAudio", "res://assets/audio/player/robot_land.wav", -5.0)
	_step_audio = _make_audio_player("StepAudio", "", -12.0)
	_disguise_audio = _make_audio_player("DisguiseAudio", "res://assets/audio/player/prop_disguise.wav", -3.5, 30.0)
	_step_sounds.clear()
	for path in [
		"res://assets/audio/player/robot_step_01.wav",
		"res://assets/audio/player/robot_step_02.wav",
		"res://assets/audio/player/robot_step_03.wav",
		"res://assets/audio/player/robot_step_04.wav",
		"res://assets/audio/player/robot_step_05.wav",
	]:
		var stream := load(path)
		if stream is AudioStream:
			_step_sounds.append(stream)


func _make_audio_player(node_name: String, stream_path: String, volume_db: float, max_distance: float = 22.0) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.name = node_name
	player.volume_db = volume_db
	player.max_distance = max_distance
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	if not stream_path.is_empty():
		var stream := load(stream_path)
		if stream is AudioStream:
			player.stream = stream
	add_child(player)
	return player


func _update_movement_audio(delta: float, was_on_floor: bool) -> void:
	if is_on_floor() and not was_on_floor:
		_play_audio(_land_audio)
		_footstep_timer = 0.0

	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and horizontal_speed > FOOTSTEP_MIN_SPEED:
		_footstep_timer -= delta
		if _footstep_timer <= 0.0:
			_play_step_audio()
			_footstep_timer = FOOTSTEP_SPRINT_INTERVAL if Input.is_action_pressed("shift") else FOOTSTEP_WALK_INTERVAL
	else:
		_footstep_timer = 0.0


func _play_step_audio() -> void:
	if not _step_audio or _step_sounds.is_empty():
		return
	_step_audio.stream = _step_sounds.pick_random()
	_play_audio(_step_audio)


func _play_audio(player: AudioStreamPlayer3D) -> void:
	if not player or not player.stream:
		return
	player.pitch_scale = randf_range(0.94, 1.06)
	player.play()


func _play_skin_action(action: String) -> void:
	if not _active_skin_node:
		return

	match action:
		"move":
			if _active_skin_node.has_method("set_walk_run_blending"):
				_active_skin_node.call("set_walk_run_blending", 1.0 if Input.is_action_pressed("shift") else 0.25)
			if _active_skin_node.has_method("move"):
				_active_skin_node.call("move")
			elif _active_skin_node.has_method("run"):
				_active_skin_node.call("run")
			elif _active_skin_node.has_method("idle"):
				_active_skin_node.call("idle")
		"jump":
			if _active_skin_node.has_method("jump"):
				_active_skin_node.call("jump")
			elif _active_skin_node.has_method("idle"):
				_active_skin_node.call("idle")
		"fall":
			if _active_skin_node.has_method("fall"):
				_active_skin_node.call("fall")
			elif _active_skin_node.has_method("idle"):
				_active_skin_node.call("idle")
		_:
			if _active_skin_node.has_method("idle"):
				_active_skin_node.call("idle")


func _animate_remote_skin_from_network_motion(delta: float) -> void:
	if not _active_skin_node or not is_instance_valid(_active_skin_node):
		return
	if delta <= 0.0:
		return
	if not _remote_visual_position_initialized:
		_remote_visual_position = global_position
		_remote_visual_position_initialized = true
		_play_skin_action("idle")
		return

	var visual_velocity := (global_position - _remote_visual_position) / maxf(delta, 0.001)
	_remote_visual_position = global_position
	var horizontal_speed_sq := Vector2(visual_velocity.x, visual_velocity.z).length_squared()
	if visual_velocity.y > 0.75:
		_play_skin_action("jump")
	elif visual_velocity.y < -0.75:
		_play_skin_action("fall")
	elif horizontal_speed_sq > 0.04:
		_remote_visual_move_hold = 0.18
		if _active_skin_node.has_method("set_walk_run_blending"):
			_active_skin_node.call("set_walk_run_blending", 1.0 if horizontal_speed_sq > 36.0 else 0.25)
		_play_skin_action("move")
	elif _remote_visual_move_hold > 0.0:
		_remote_visual_move_hold = maxf(0.0, _remote_visual_move_hold - delta)
		_play_skin_action("move")
	else:
		_play_skin_action("idle")


func set_mesh_texture(mesh_instance: MeshInstance3D, texture: Texture2D) -> void:
	if mesh_instance:
		var material := _ensure_unique_standard_material(mesh_instance, 0)
		material.albedo_texture = texture
		material.albedo_color = Color.WHITE

# Inventory Network Functions - Server authoritative, client-specific
@rpc("any_peer", "call_local", "reliable")
func request_inventory_sync():
	print("Debug: request_inventory_sync called on player ", name, " (authority: ", get_multiplayer_authority(), ") by client ", multiplayer.get_remote_sender_id())

	if not multiplayer.is_server():
		return

	var requesting_client = multiplayer.get_remote_sender_id()
	if requesting_client != get_multiplayer_authority():
		push_warning("Client " + str(requesting_client) + " tried to request inventory for player " + str(get_multiplayer_authority()))
		return

	if player_inventory:
		sync_inventory_to_owner.rpc_id(requesting_client, player_inventory.to_dict())

@rpc("any_peer", "call_local", "reliable")
func sync_inventory_to_owner(inventory_data: Dictionary):
	print("Debug: sync_inventory_to_owner called on player ", name, " (authority: ", get_multiplayer_authority(), ") - local unique id: ", multiplayer.get_unique_id(), " from: ", multiplayer.get_remote_sender_id())

	if multiplayer.get_remote_sender_id() != 1:
		return

	if not is_multiplayer_authority():
		return

	if not player_inventory:
		player_inventory = PlayerInventory.new()
	player_inventory.from_dict(inventory_data)

	var level_scene = get_tree().get_current_scene()
	if level_scene:
		if is_multiplayer_authority() or get_multiplayer_authority() == multiplayer.get_unique_id():
			print("Debug: This is the local player, updating UI")
			if level_scene.has_method("update_local_inventory_display"):
				level_scene.update_local_inventory_display()
			if level_scene.has_node("InventoryUI"):
				var inventory_ui = level_scene.get_node("InventoryUI")
				if inventory_ui.visible and inventory_ui.has_method("refresh_display"):
					print("Debug: Calling refresh_display directly on InventoryUI")
					inventory_ui.refresh_display()
		else:
			print("Debug: Not the local player, skipping UI update")

@rpc("any_peer", "call_local", "reliable")
func request_move_item(from_slot: int, to_slot: int, quantity: int = -1):
	print("Debug: request_move_item called - from:", from_slot, " to:", to_slot, " on player ", name, " (authority: ", get_multiplayer_authority(), ") by client ", multiplayer.get_remote_sender_id())

	if not multiplayer.is_server():
		return

	var requesting_client = multiplayer.get_remote_sender_id()
	if requesting_client != get_multiplayer_authority():
		push_warning("Client " + str(requesting_client) + " tried to modify inventory for player " + str(get_multiplayer_authority()))
		return

	if not player_inventory:
		return

	if from_slot < 0 or from_slot >= PlayerInventory.INVENTORY_SIZE or to_slot < 0 or to_slot >= PlayerInventory.INVENTORY_SIZE:
		push_warning("Invalid slot indices: from=" + str(from_slot) + " to=" + str(to_slot))
		return

	var success = false
	if quantity == -1:
		success = player_inventory.move_item(from_slot, to_slot)
		if not success:
			success = player_inventory.swap_items(from_slot, to_slot)
			print("Debug: Swapped items between slots ", from_slot, " and ", to_slot)
		else:
			print("Debug: Moved item from slot ", from_slot, " to ", to_slot)
	else:
		success = player_inventory.move_item(from_slot, to_slot, quantity)
		print("Debug: Moved ", quantity, " items from slot ", from_slot, " to ", to_slot)

	if success:
		print("Debug: Move successful, syncing inventory to owner ", get_multiplayer_authority())
		var owner_id = get_multiplayer_authority()
		if owner_id != 1:
			sync_inventory_to_owner.rpc_id(owner_id, player_inventory.to_dict())
		else:
			var level_scene = get_tree().get_current_scene()
			if level_scene and level_scene.has_method("update_local_inventory_display"):
				level_scene.update_local_inventory_display()
	else:
		print("Debug: Move/swap failed")

@rpc("any_peer", "call_local", "reliable")
func request_add_item(item_id: String, quantity: int = 1):
	print("Debug: request_add_item called on player ", name, " (authority: ", get_multiplayer_authority(), ") by client ", multiplayer.get_remote_sender_id())

	if not multiplayer.is_server():
		return

	var requesting_client = multiplayer.get_remote_sender_id()
	if requesting_client != get_multiplayer_authority() and requesting_client != 1:
		push_warning("Client " + str(requesting_client) + " tried to add items to player " + str(get_multiplayer_authority()))
		return

	if not player_inventory:
		return

	if quantity <= 0:
		push_warning("Invalid quantity: " + str(quantity))
		return

	var item = ItemDatabase.get_item(item_id)
	if not item:
		push_warning("Item not found: " + item_id)
		return

	var remaining = player_inventory.add_item(item, quantity)
	var added = quantity - remaining
	print("Debug: Added ", added, " ", item_id, " to inventory (", remaining, " remaining)")

	if added > 0:
		var owner_id = get_multiplayer_authority()
		print("Debug: Syncing inventory to owner ", owner_id)
		if owner_id != 1:
			sync_inventory_to_owner.rpc_id(owner_id, player_inventory.to_dict())
		else:
			var level_scene = get_tree().get_current_scene()
			if level_scene and level_scene.has_method("update_local_inventory_display"):
				level_scene.update_local_inventory_display()

@rpc("any_peer", "call_local", "reliable")
func request_remove_item(item_id: String, quantity: int = 1):
	print("Debug: request_remove_item called on player ", name, " (authority: ", get_multiplayer_authority(), ") by client ", multiplayer.get_remote_sender_id())

	if not multiplayer.is_server():
		return

	var requesting_client = multiplayer.get_remote_sender_id()
	if requesting_client != get_multiplayer_authority():
		push_warning("Client " + str(requesting_client) + " tried to remove items from player " + str(get_multiplayer_authority()))
		return

	if not player_inventory:
		return

	if quantity <= 0:
		push_warning("Invalid quantity: " + str(quantity))
		return

	var removed = player_inventory.remove_item(item_id, quantity)

	if removed > 0:
		var owner_id = get_multiplayer_authority()
		if owner_id != 1:
			sync_inventory_to_owner.rpc_id(owner_id, player_inventory.to_dict())

func get_inventory() -> PlayerInventory:
	return player_inventory

func get_health() -> float:
	return health

func _add_starting_items():
	if not player_inventory:
		return

	var sword = ItemDatabase.get_item("iron_sword")
	var potion = ItemDatabase.get_item("health_potion")

	if sword:
		player_inventory.add_item(sword, 1)
	if potion:
		player_inventory.add_item(potion, 3)


# =============================================================================
# 鎴樻枟绯荤粺(琚?WeaponSystem 璋冪敤)
# =============================================================================

# 鏈嶅姟鍣ㄤ晶:鐜╁鍙楀埌浼ゅ
@rpc("any_peer", "call_local", "reliable")
func take_damage(amount: float, attacker_id: int, is_headshot: bool = false):
	if not multiplayer.is_server():
		return

	print("[Combat] Player ", name, " took ", amount, "% damage from ",
		attacker_id, " (headshot=", is_headshot, ")")

	health = max(0.0, health - amount)
	_sync_health.rpc(health)

	if health <= 0.0:
		_server_die(attacker_id)


func _server_die(killer_id: int) -> void:
	if not multiplayer.is_server():
		return
	print("[Combat] Player ", name, " killed by ", killer_id)

	# 骞挎挱姝讳骸
	_broadcast_death.rpc(killer_id)

	# 绠€鍖栫殑姝讳骸澶勭悊:5s 鍚庨噸鐢?
	await get_tree().create_timer(5.0).timeout
	if multiplayer.is_server() and is_instance_valid(self):
		health = 100.0
		_sync_health.rpc(health)
		# 閲嶇疆浣嶇疆
		var level = get_tree().get_current_scene()
		if level and level.has_method("get_spawn_point_for_role"):
			var role = Network.players.get(int(name), {}).get("role", Network.Role.NONE)
			global_position = level.get_spawn_point_for_role(role, int(name))


@rpc("authority", "call_local", "reliable")
func _broadcast_death(killer_id: int):
	print("[Combat] ", name, " was killed by ", killer_id)
	clear_prop_disguise()
	# TODO: 瑙﹀彂姝讳骸鍔ㄧ敾 + UI


@rpc("authority", "call_local", "reliable")
func _sync_health(new_health: float):
	health = new_health
	health_changed.emit(health)


# 鏈嶅姟鍣ㄤ晶:澶撮儴鍒ゅ畾(绠€鍖?鐢ㄧ鎾炰綅缃?vs 澶撮儴楂樺害)
func is_head_shot() -> bool:
	# 绠€鍖?浠讳綍鍑讳腑澶撮儴楂樺害鐨勫皠绾胯涓虹垎澶?
	# 鐪熷疄瀹炵幇:raycast 鍛戒腑鐐?y 鍧愭爣 vs 瑙掕壊澶撮儴 y 鍧愭爣
	return false  # TODO: 瀹炵幇绮剧‘鐖嗗ご鍒ゅ畾
