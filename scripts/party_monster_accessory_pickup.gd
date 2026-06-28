extends Area3D
class_name PartyMonsterAccessoryPickup

const AccessoryCatalog := preload("res://scripts/party_monster_accessory_catalog.gd")
const PARTY_MONSTER_SKIN_SCENE := preload("res://assets/characters/party_monster/party_monster_skin.tscn")
const BEACON_SHADER: Shader = preload("res://shaders/party_monster_accessory_beam.gdshader")
const PICKUP_RANGE := 2.35
const RESPAWN_TIME := 42.0
const BOB_HEIGHT := 0.14
const BOB_SPEED := 2.6
const ROTATION_SPEED := 1.35
const PREVIEW_TARGET_SIZE := 0.5
const PREVIEW_VISIBILITY_RANGE := 28.0
const PREVIEW_VISIBILITY_MARGIN := 4.0
const BEACON_HEIGHT := 640.0
const BEACON_BASE_Y := 0.16
const BEACON_SPACE_FADE_START := 0.035
const BEACON_RIBBON_WIDTH := 0.82
const BEACON_CORE_WIDTH := 0.36
const BEACON_IMPACT_CORE_RADIUS := 0.26
const BEACON_IMPACT_GLOW_RADIUS := 0.78
const BEACON_REFRESH_INTERVAL := 0.18
const BEACON_IDLE_REFRESH_INTERVAL := 0.42
const PROMPT_LOCAL_POSITION := Vector3(-0.78, 1.38, 0.0)
const VISUAL_UPDATE_INTERVAL := 1.0 / 30.0
const IDLE_VISUAL_UPDATE_INTERVAL := 1.0 / 12.0
const BEACON_PULSE_INTERVAL := 1.0 / 30.0
const SLOT_COLORS := {
	"eyes": Color(0.35, 0.86, 1.0, 1.0),
	"mouth": Color(1.0, 0.42, 0.46, 1.0),
	"nose": Color(1.0, 0.72, 0.34, 1.0),
	"head": Color(0.72, 0.52, 1.0, 1.0),
	"ears": Color(0.44, 1.0, 0.62, 1.0),
	"gloves": Color(1.0, 0.92, 0.28, 1.0),
	"tail": Color(0.35, 1.0, 0.88, 1.0),
}

@export var accessory_id: String = "":
	set(value):
		accessory_id = str(value).strip_edges()
		_refresh_accessory_metadata()
		if is_inside_tree():
			_apply_visual()

var slot := ""
var is_available := true
var match_active := true
var respawn_timer := 0.0
var _nearby_player_ids := {}
var _visual_root: Node3D = null
var _base_visual_y := 0.64
var _time := 0.0
var _prompt_root: Node3D = null
var _prompt_key_label: Label3D = null
var _prompt_action_label: Label3D = null
var _prompt_accent: MeshInstance3D = null
var _prompt_key_box: MeshInstance3D = null
var _beacon_root: Node3D = null
var _beacon_materials: Array[ShaderMaterial] = []
var _beacon_impact_root: Node3D = null
var _beacon_impact_ring: MeshInstance3D = null
var _beacon_impact_core: MeshInstance3D = null
var _beacon_impact_particles: GPUParticles3D = null
var _beacon_impact_requested := false
var _beacon_refresh_time := 0.0
var _visual_update_time := 0.0
var _visual_motion_elapsed := 0.0
var _beacon_pulse_time := 0.0
var _accessory_color := Color(0.85, 0.92, 1.0, 1.0)


func _ready() -> void:
	add_to_group("party_monster_accessory_pickups")
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_seed_process_stagger()
	set_process(_should_process_pickup())
	set_process_unhandled_input(false)
	_refresh_accessory_metadata()
	_ensure_collision_shape()
	_apply_visual()
	_apply_match_active_state()


func set_match_active(active: bool) -> void:
	match_active = active
	_apply_match_active_state()


func _is_runtime_server() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return true
	return multiplayer.is_server()


func _remote_sender_id() -> int:
	if not multiplayer.has_multiplayer_peer():
		return 1
	return multiplayer.get_remote_sender_id()


func _apply_match_active_state() -> void:
	var pickup_active: bool = match_active and is_available
	visible = pickup_active
	set_deferred("monitoring", pickup_active)
	set_deferred("monitorable", pickup_active)
	for child in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).set_deferred("disabled", not pickup_active)
	if pickup_active:
		_seed_process_stagger()
		_update_local_hint_visibility()
	else:
		_nearby_player_ids.clear()
		_clear_prompt_hud()
		set_process_unhandled_input(false)
		if _beacon_root and is_instance_valid(_beacon_root):
			_beacon_root.visible = false
		if _beacon_impact_particles and is_instance_valid(_beacon_impact_particles):
			_beacon_impact_particles.emitting = false
	_sync_process_state()


func _process(delta: float) -> void:
	if not match_active:
		set_process(false)
		return
	if not is_available:
		if _is_runtime_server():
			respawn_timer -= delta
			if respawn_timer <= 0.0:
				_respawn()
		else:
			set_process(false)
		return

	_time += delta
	_visual_motion_elapsed += delta
	_visual_update_time -= delta
	if _visual_update_time <= 0.0:
		var visual_interval: float = _visual_update_interval()
		_visual_update_time = visual_interval
		_update_visual_motion(_visual_motion_elapsed)
		_visual_motion_elapsed = 0.0
	if _beacon_root and _beacon_root.visible:
		_beacon_pulse_time -= delta
		if _beacon_pulse_time <= 0.0:
			_beacon_pulse_time = BEACON_PULSE_INTERVAL
			_update_beacon_pulse()
	_beacon_refresh_time -= delta
	if _beacon_refresh_time <= 0.0:
		var refresh_interval: float = _beacon_refresh_interval()
		_beacon_refresh_time = refresh_interval
		_update_local_hint_visibility()


func _should_process_pickup() -> bool:
	if not match_active:
		return false
	if not is_available:
		return _is_runtime_server()
	return _is_local_player_nearby() or _is_bounty_beacon_visible()


func _sync_process_state() -> void:
	set_process(_should_process_pickup())


func _is_bounty_beacon_visible() -> bool:
	return _beacon_root != null and is_instance_valid(_beacon_root) and _beacon_root.visible


func _seed_process_stagger() -> void:
	var phase_seed: int = hash("%s:%s" % [String(name), accessory_id])
	if phase_seed < 0:
		phase_seed = -phase_seed
	var phase: float = float(phase_seed % 997) / 997.0
	_visual_update_time = maxf(VISUAL_UPDATE_INTERVAL * phase, 0.001)
	_beacon_refresh_time = maxf(_beacon_refresh_interval() * fposmod(phase + 0.37, 1.0), 0.001)
	_beacon_pulse_time = maxf(BEACON_PULSE_INTERVAL * fposmod(phase + 0.71, 1.0), 0.001)


func _visual_update_interval() -> float:
	if _is_local_player_nearby() or (_beacon_root and _beacon_root.visible):
		return VISUAL_UPDATE_INTERVAL
	return IDLE_VISUAL_UPDATE_INTERVAL


func _beacon_refresh_interval() -> float:
	if _is_local_player_nearby() or (_beacon_root and _beacon_root.visible):
		return BEACON_REFRESH_INTERVAL
	return BEACON_IDLE_REFRESH_INTERVAL


func _local_peer_id() -> int:
	if multiplayer.has_multiplayer_peer():
		return multiplayer.get_unique_id()
	return 1


func _is_local_player_nearby() -> bool:
	return _nearby_player_ids.has(_local_peer_id())


func _unhandled_input(event: InputEvent) -> void:
	if not match_active or not is_available or not event.is_action_pressed("interact"):
		return
	var local_id := _local_peer_id()
	if not _nearby_player_ids.has(local_id):
		return
	request_pickup_for_player(local_id)
	get_viewport().set_input_as_handled()


func configure(new_accessory_id: String) -> void:
	accessory_id = new_accessory_id
	_refresh_accessory_metadata()
	_apply_visual()


func refresh_bounty_beacon_visibility() -> void:
	_update_local_hint_visibility()
	_sync_process_state()


func request_pickup_for_player(peer_id: int) -> void:
	if not match_active or not is_available:
		return
	var player_node: Node3D = _find_player_node(peer_id)
	var query_tick: int = _pickup_query_tick_for_player(player_node)
	if _is_runtime_server():
		_server_try_pickup_by_id(peer_id, query_tick)
	else:
		_request_pickup_rpc.rpc_id(1, query_tick)


@rpc("any_peer", "call_local", "reliable")
func _request_pickup_rpc(query_tick: int = -1) -> void:
	if not _is_runtime_server():
		return
	_server_try_pickup_by_id(_remote_sender_id(), query_tick)


func _pickup_query_tick_for_player(player_node: Node) -> int:
	if player_node and player_node.has_method("get_network_input_tick"):
		return int(player_node.call("get_network_input_tick"))
	return NetworkTime.tick


func _server_try_pickup_by_id(peer_id: int, query_tick: int = -1) -> void:
	if not _is_runtime_server() or not match_active or not is_available:
		return
	var accessory := AccessoryCatalog.get_accessory(accessory_id)
	if accessory.is_empty():
		return
	if not Network.players.has(peer_id):
		return
	var info: Dictionary = Network.players.get(peer_id, {}) as Dictionary
	var role := int(info.get("role", Network.Role.NONE))
	if role != Network.Role.CHAMELEON and role != Network.Role.STALKER:
		return
	var model_id := CharacterSkinCatalog.normalize(str(info.get("character_model", CharacterSkinCatalog.DEFAULT_ID)))
	if not CharacterSkinCatalog.is_party_monster(model_id):
		return
	var player_node := _find_player_node(peer_id)
	if not _server_player_was_in_pickup_range(peer_id, player_node, query_tick):
		return
	var current_loadout := AccessoryCatalog.sanitize_loadout(info.get("party_monster_accessories", {}), model_id)
	var replaced_id := str(current_loadout.get(str(accessory.get("slot", "")), ""))
	var next_loadout := AccessoryCatalog.replace_accessory(current_loadout, accessory_id, model_id)
	if next_loadout == current_loadout:
		return
	Network.server_set_player_party_monster_accessories(peer_id, next_loadout)
	if player_node and player_node.has_method("send_party_monster_accessory_feedback"):
		player_node.call("send_party_monster_accessory_feedback", accessory_id, replaced_id)
	_consume()


func _server_player_was_in_pickup_range(peer_id: int, player_node: Node3D, query_tick: int) -> bool:
	var history: NetworkRewindHistory = NetworkRewindHistory.find_in_tree(get_tree())
	if history != null and query_tick >= 0:
		if history.player_was_in_radius(peer_id, global_position, PICKUP_RANGE + 0.9, query_tick):
			return true
	return _is_player_close_enough(player_node)


func _is_player_close_enough(player_node: Node3D) -> bool:
	if not player_node or not is_instance_valid(player_node):
		return false
	return global_position.distance_to(player_node.global_position) <= PICKUP_RANGE + 0.9


func _find_player_node(peer_id: int) -> Node3D:
	var tree := get_tree()
	if not tree:
		return null
	var peer_name := str(peer_id)
	var scene := tree.current_scene
	if scene:
		var container := scene.get_node_or_null("PlayersContainer")
		if container:
			var by_name := container.get_node_or_null(peer_name) as Node3D
			if by_name:
				return by_name
	for raw_player in tree.get_nodes_in_group("players"):
		var player := raw_player as Node3D
		if not player:
			continue
		if str(player.name) == peer_name:
			return player
		if player.has_method("get_multiplayer_authority") and int(player.get_multiplayer_authority()) == peer_id:
			return player
	return null


func _consume() -> void:
	if not _is_runtime_server():
		return
	_set_available.rpc(false, RESPAWN_TIME)


func _respawn() -> void:
	if not _is_runtime_server():
		return
	_set_available.rpc(true, 0.0)


@rpc("authority", "call_local", "reliable")
func _set_available(available: bool, next_respawn_time: float = 0.0) -> void:
	is_available = available
	respawn_timer = maxf(next_respawn_time, 0.0)
	_apply_match_active_state()


func _on_body_entered(body: Node) -> void:
	if not match_active or not body or not body.is_in_group("players"):
		return
	if body.has_method("get_multiplayer_authority"):
		_nearby_player_ids[int(body.get_multiplayer_authority())] = true
	_update_local_hint_visibility()
	_sync_process_state()


func _on_body_exited(body: Node) -> void:
	if not body or not body.is_in_group("players"):
		return
	if body.has_method("get_multiplayer_authority"):
		_nearby_player_ids.erase(int(body.get_multiplayer_authority()))
	_update_local_hint_visibility()
	_sync_process_state()


func _refresh_accessory_metadata() -> void:
	var accessory := AccessoryCatalog.get_accessory(accessory_id)
	slot = str(accessory.get("slot", "")) if not accessory.is_empty() else ""


func _ensure_collision_shape() -> void:
	var collision := get_node_or_null("PickupTrigger") as CollisionShape3D
	if not collision:
		collision = CollisionShape3D.new()
		collision.name = "PickupTrigger"
		add_child(collision)
	var sphere := collision.shape as SphereShape3D
	if not sphere:
		sphere = SphereShape3D.new()
		collision.shape = sphere
	sphere.radius = PICKUP_RANGE


func _apply_visual() -> void:
	_clear_visual_nodes()
	var fallback_color := _slot_color()
	_accessory_color = fallback_color
	_visual_root = Node3D.new()
	_visual_root.name = "AccessoryVisualRoot"
	_visual_root.position = Vector3(0.0, _base_visual_y, 0.0)
	add_child(_visual_root)
	_add_fallback_preview(_visual_root, fallback_color)
	_update_local_hint_visibility()


func _clear_visual_nodes() -> void:
	_clear_prompt_hud()
	for node_name in ["AccessoryVisualRoot", "AccessoryBountyBeacon", "AccessoryInteractPrompt", "AccessoryAura", "AccessoryLabel"]:
		var child := get_node_or_null(node_name)
		if child:
			child.queue_free()
	_visual_root = null
	_beacon_root = null
	_beacon_materials.clear()
	_beacon_impact_root = null
	_beacon_impact_ring = null
	_beacon_impact_core = null
	_beacon_impact_particles = null
	_beacon_impact_requested = false


func _add_real_accessory_preview(parent: Node3D, fallback_color: Color) -> Color:
	var preview := PARTY_MONSTER_SKIN_SCENE.instantiate() as Node3D
	if not preview:
		_add_fallback_preview(parent, fallback_color)
		return fallback_color
	preview.name = "AccessoryPreview"
	preview.scale = Vector3.ONE
	preview.rotation.y = PI
	if preview.has_method("set_accessory_preview_id"):
		preview.call("set_accessory_preview_id", accessory_id)
	parent.add_child(preview)
	if preview.has_method("_build_skin"):
		preview.call("_build_skin")
	_normalize_accessory_preview(preview)
	return _color_from_visible_preview(preview, fallback_color)


func _add_fallback_preview(parent: Node3D, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "AccessoryFallbackPreview"
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mesh_instance.visibility_range_end = PREVIEW_VISIBILITY_RANGE
	mesh_instance.visibility_range_end_margin = PREVIEW_VISIBILITY_MARGIN
	mesh_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	mesh_instance.mesh = _fallback_mesh_for_slot()
	mesh_instance.material_override = _slot_material(color)
	parent.add_child(mesh_instance)
	_normalize_accessory_preview(mesh_instance)


func _fallback_mesh_for_slot() -> Mesh:
	if slot == "head":
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.42
		cone.height = 0.72
		cone.radial_segments = 10
		return cone
	if slot == "tail" or slot == "gloves":
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.22
		cylinder.bottom_radius = 0.22
		cylinder.height = 0.65
		cylinder.radial_segments = 10
		return cylinder
	var sphere := SphereMesh.new()
	sphere.radius = 0.34
	sphere.height = 0.68
	sphere.radial_segments = 12
	sphere.rings = 6
	return sphere


func _add_bounty_beacon(color: Color) -> void:
	_beacon_root = Node3D.new()
	_beacon_root.name = "AccessoryBountyBeacon"
	_beacon_root.visible = false
	add_child(_beacon_root)
	var ribbon_yaws: Array[float] = [0.0, PI * 0.5, PI * 0.25, -PI * 0.25]
	for index in range(ribbon_yaws.size()):
		var node_name := "BountyBeamRibbon%s" % char(65 + index)
		_beacon_root.add_child(_make_beacon_ribbon(node_name, BEACON_RIBBON_WIDTH, BEACON_HEIGHT, color, ribbon_yaws[index], 0.24, 0.68, 8.2, 0.018, 2.05 + float(index) * 0.21))
	var core_yaws: Array[float] = [PI * 0.125, PI * 0.625]
	for index in range(core_yaws.size()):
		var node_name := "BountyBeamCore%s" % char(65 + index)
		_beacon_root.add_child(_make_beacon_ribbon(node_name, BEACON_CORE_WIDTH, BEACON_HEIGHT, color, core_yaws[index], 0.20, 0.82, 10.8, 0.012, 2.75 + float(index) * 0.24))
	_beacon_root.add_child(_make_beacon_impact(color))


func _make_beacon_ribbon(node_name: String, width: float, height: float, color: Color, yaw: float, base_alpha: float, core_alpha: float, emission: float, top_fade: float, flow_speed: float) -> MeshInstance3D:
	var ribbon := MeshInstance3D.new()
	ribbon.name = node_name
	var mesh := QuadMesh.new()
	mesh.size = Vector2(width, height)
	ribbon.mesh = mesh
	ribbon.position = Vector3(0.0, height * 0.5 + BEACON_BASE_Y, 0.0)
	ribbon.rotation.y = yaw
	ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ribbon.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	ribbon.extra_cull_margin = height * 2.0
	var material := _beacon_material(color, base_alpha, core_alpha, emission, top_fade, flow_speed)
	ribbon.material_override = material
	_beacon_materials.append(material)
	return ribbon


func _beacon_material(color: Color, base_alpha: float, core_alpha: float, emission: float, top_fade: float, flow_speed: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.resource_local_to_scene = true
	material.shader = BEACON_SHADER
	material.set_shader_parameter("beam_color", Color(color.r, color.g, color.b, 1.0))
	material.set_shader_parameter("base_alpha", base_alpha)
	material.set_shader_parameter("core_alpha", core_alpha)
	material.set_shader_parameter("emission_power", emission)
	material.set_shader_parameter("top_fade", top_fade)
	material.set_shader_parameter("flow_speed", flow_speed)
	material.set_shader_parameter("energy_wobble", 0.74)
	material.set_shader_parameter("dual_beam_offset", 0.086)
	material.set_shader_parameter("pulse_rate", 5.4)
	material.set_shader_parameter("beam_thickness", 0.112)
	material.set_shader_parameter("outline_thickness", 0.185)
	material.set_shader_parameter("space_fade_start", BEACON_SPACE_FADE_START)
	material.set_shader_parameter("atmospheric_falloff", 1.75)
	material.set_shader_parameter("cosmic_entry_strength", 0.72)
	return material


func _make_beacon_impact(color: Color) -> Node3D:
	var impact_root := Node3D.new()
	impact_root.name = "BountyBeamImpact"
	impact_root.position = Vector3(0.0, BEACON_BASE_Y + 0.025, 0.0)
	_beacon_impact_root = impact_root
	_beacon_impact_ring = _make_impact_glow_disc("BountyBeamImpactGlow", BEACON_IMPACT_GLOW_RADIUS, 0.018, color, 0.20, 2.4)
	impact_root.add_child(_beacon_impact_ring)
	_beacon_impact_core = _make_impact_glow_disc("BountyBeamImpactCore", BEACON_IMPACT_CORE_RADIUS, 0.026, color, 0.46, 4.6)
	impact_root.add_child(_beacon_impact_core)
	var particles := GPUParticles3D.new()
	particles.name = "BountyBeamSparks"
	particles.amount = 96
	particles.lifetime = 0.92
	particles.explosiveness = 0.12
	particles.randomness = 0.92
	particles.preprocess = 0.22
	particles.local_coords = true
	particles.emitting = false
	particles.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	particles.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD
	particles.visibility_aabb = AABB(Vector3(-2.4, -0.35, -2.4), Vector3(4.8, 3.8, 4.8))
	particles.process_material = _make_impact_process_material(color)
	particles.draw_pass_1 = _make_impact_particle_mesh(color)
	impact_root.add_child(particles)
	_beacon_impact_particles = particles
	return impact_root


func _make_impact_glow_disc(node_name: String, radius: float, height: float, color: Color, alpha: float, energy: float) -> MeshInstance3D:
	var disc := MeshInstance3D.new()
	disc.name = node_name
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	disc.position = Vector3(0.0, height * 0.5, 0.0)
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 18
	mesh.rings = 1
	mesh.material = _impact_glow_material(color, alpha, energy)
	disc.mesh = mesh
	return disc


func _impact_glow_material(color: Color, alpha: float, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_local_to_scene = true
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = energy
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.disable_receive_shadows = true
	material.disable_fog = true
	material.no_depth_test = true
	return material


func _set_impact_disc_energy(disc: MeshInstance3D, color: Color, energy: float) -> void:
	if not disc or not is_instance_valid(disc) or not disc.mesh is PrimitiveMesh:
		return
	var primitive := disc.mesh as PrimitiveMesh
	var material := primitive.material as StandardMaterial3D
	if not material:
		return
	material.albedo_color = color
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = energy


func _make_impact_process_material(color: Color) -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.resource_local_to_scene = true
	material.direction = Vector3.UP
	material.spread = 118.0
	material.gravity = Vector3(0.0, -1.55, 0.0)
	material.initial_velocity_min = 0.85
	material.initial_velocity_max = 2.90
	material.radial_velocity_min = 0.62
	material.radial_velocity_max = 2.35
	material.angular_velocity_min = -420.0
	material.angular_velocity_max = 420.0
	material.damping_min = 0.02
	material.damping_max = 0.18
	material.scale_min = 0.070
	material.scale_max = 0.180
	material.color = Color(color.r, color.g, color.b, 0.96)
	return material


func _make_impact_particle_mesh(color: Color) -> Mesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.12, 0.12)
	var material := StandardMaterial3D.new()
	material.resource_local_to_scene = true
	material.albedo_color = Color(color.r, color.g, color.b, 0.92)
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = 5.2
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.disable_receive_shadows = true
	material.disable_fog = true
	material.no_depth_test = true
	mesh.material = material
	return mesh


func _normalize_accessory_preview(preview: Node3D) -> void:
	var bounds := _calculate_visible_bounds(preview)
	var max_size := _max_axis(bounds.size)
	if max_size <= 0.001:
		preview.scale = Vector3.ONE * PREVIEW_TARGET_SIZE
		return
	preview.scale *= PREVIEW_TARGET_SIZE / max_size
	var scaled_bounds := _calculate_visible_bounds(preview)
	if scaled_bounds.size == Vector3.ZERO:
		return
	var center := scaled_bounds.position + scaled_bounds.size * 0.5
	preview.position -= Vector3(center.x, scaled_bounds.position.y, center.z)


func _update_visual_motion(delta: float) -> void:
	if _visual_root and is_instance_valid(_visual_root):
		_visual_root.position.y = _base_visual_y + sin(_time * BOB_SPEED) * BOB_HEIGHT
		_visual_root.rotation.y += ROTATION_SPEED * maxf(delta, 0.0)
	_face_prompt_hud_to_camera()


func _update_beacon_pulse() -> void:
	var pulse := 0.78 + sin(_time * 4.8) * 0.22
	var slow_pulse := 0.90 + sin(_time * 2.35) * 0.10
	for material in _beacon_materials:
		if material:
			material.set_shader_parameter("shimmer_strength", 0.82 + pulse * 0.62)
			material.set_shader_parameter("energy_wobble", 0.58 + pulse * 0.26)
	if _beacon_impact_ring and is_instance_valid(_beacon_impact_ring):
		_beacon_impact_ring.scale = Vector3.ONE * (1.0 + slow_pulse * 0.12)
		_set_impact_disc_energy(_beacon_impact_ring, Color(_accessory_color.r, _accessory_color.g, _accessory_color.b, 0.18 + pulse * 0.08), 2.0 + pulse * 1.25)
	if _beacon_impact_core and is_instance_valid(_beacon_impact_core):
		_beacon_impact_core.scale = Vector3.ONE * (0.94 + pulse * 0.18)
		_set_impact_disc_energy(_beacon_impact_core, Color(_accessory_color.r, _accessory_color.g, _accessory_color.b, 0.42 + pulse * 0.18), 4.2 + pulse * 2.0)
	if _beacon_impact_particles and is_instance_valid(_beacon_impact_particles):
		_beacon_impact_particles.amount_ratio = 0.72 + pulse * 0.28 if _beacon_impact_particles.emitting else 0.0


func _update_local_hint_visibility() -> void:
	_update_prompt_visibility()
	_update_beacon_visibility()


func _update_prompt_visibility() -> void:
	var local_id := _local_peer_id()
	var local_nearby := is_available and _nearby_player_ids.has(local_id)
	set_process_unhandled_input(local_nearby)
	if not local_nearby:
		_clear_prompt_hud()
		return
	var local_player := _find_player_node(local_id)
	if not local_player:
		_clear_prompt_hud()
		return
	_ensure_prompt_hud(local_player, _accessory_color)


func _ensure_prompt_hud(local_player: Node3D, color: Color) -> void:
	if _prompt_root and is_instance_valid(_prompt_root) and _prompt_root.get_parent() != local_player:
		_prompt_root.queue_free()
		_prompt_root = null
	if not _prompt_root or not is_instance_valid(_prompt_root):
		_prompt_root = Node3D.new()
		_prompt_root.name = "AccessoryInteractionHUD"
		_prompt_root.position = PROMPT_LOCAL_POSITION
		local_player.add_child(_prompt_root)
		_prompt_root.add_child(_make_prompt_piece("InteractPromptBack", Color(0.025, 0.028, 0.038, 0.66), Vector3(0.0, 0.0, 0.0), Vector3(0.46, 0.17, 0.022)))
		_prompt_accent = _make_prompt_piece("InteractPromptAccent", color, Vector3(-0.22, 0.0, 0.017), Vector3(0.025, 0.14, 0.034))
		_prompt_root.add_child(_prompt_accent)
		_prompt_key_box = _make_prompt_piece("InteractPromptKeyBox", Color(1.0, 1.0, 1.0, 0.18), Vector3(-0.115, 0.0, 0.025), Vector3(0.105, 0.115, 0.036))
		_prompt_root.add_child(_prompt_key_box)
		_prompt_key_label = _make_prompt_label("InteractPromptKey", "F", Vector3(-0.115, -0.004, 0.051), 24, Color(1.0, 1.0, 1.0, 0.96), Color(0.05, 0.06, 0.08, 0.9))
		_prompt_root.add_child(_prompt_key_label)
		_prompt_action_label = _make_prompt_label("InteractPromptAction", "", Vector3(0.075, -0.004, 0.051), 19, Color(0.92, 0.96, 1.0, 0.94), color)
		_prompt_root.add_child(_prompt_action_label)
	_prompt_root.position = PROMPT_LOCAL_POSITION
	_prompt_root.visible = true
	_refresh_prompt_hud_visuals(color)
	_face_prompt_hud_to_camera()


func _clear_prompt_hud() -> void:
	if _prompt_root and is_instance_valid(_prompt_root):
		_prompt_root.queue_free()
	_prompt_root = null
	_prompt_key_label = null
	_prompt_action_label = null
	_prompt_accent = null
	_prompt_key_box = null


func _make_prompt_piece(node_name: String, color: Color, local_position: Vector3, size: Vector3) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.name = node_name
	piece.position = local_position
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _prompt_material(color)
	piece.mesh = mesh
	return piece


func _prompt_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_local_to_scene = true
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.disable_fog = true
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = 0.38
	return material


func _make_prompt_label(node_name: String, label_text: String, local_position: Vector3, font_size: int, color: Color, outline_color: Color) -> Label3D:
	var label := Label3D.new()
	label.name = node_name
	label.position = local_position
	label.text = label_text
	label.font_size = font_size
	label.pixel_size = 0.0035
	label.fixed_size = false
	label.no_depth_test = true
	label.shaded = false
	label.double_sided = true
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.modulate = color
	label.outline_size = 4
	label.outline_modulate = outline_color
	return label


func _refresh_prompt_hud_visuals(color: Color) -> void:
	_update_prompt_piece_color(_prompt_accent, Color(color.r, color.g, color.b, 0.82), 0.72)
	_update_prompt_piece_color(_prompt_key_box, Color(1.0, 1.0, 1.0, 0.18), 0.24)
	if _prompt_key_label and is_instance_valid(_prompt_key_label):
		_prompt_key_label.text = "F"
	if _prompt_action_label and is_instance_valid(_prompt_action_label):
		_prompt_action_label.text = _prompt_action_text()
		_prompt_action_label.outline_modulate = Color(color.r, color.g, color.b, 0.95)


func _update_prompt_piece_color(piece: MeshInstance3D, color: Color, energy: float) -> void:
	if not piece or not is_instance_valid(piece) or not piece.mesh is PrimitiveMesh:
		return
	var primitive := piece.mesh as PrimitiveMesh
	var material := primitive.material as StandardMaterial3D
	if not material:
		return
	material.albedo_color = color
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = energy


func _face_prompt_hud_to_camera() -> void:
	if not _prompt_root or not is_instance_valid(_prompt_root):
		return
	var camera := get_viewport().get_camera_3d()
	if camera:
		_prompt_root.global_basis = camera.global_basis


func _update_beacon_visibility() -> void:
	var should_show := _should_show_bounty_beacon()
	if should_show and not _beacon_root:
		_add_bounty_beacon(_accessory_color)
	if not _beacon_root:
		_beacon_impact_requested = false
		return
	var was_visible := _beacon_root.visible
	_beacon_root.visible = should_show
	_beacon_impact_requested = should_show
	if _beacon_impact_particles and is_instance_valid(_beacon_impact_particles):
		if should_show and not was_visible:
			_beacon_impact_particles.restart()
		_beacon_impact_particles.emitting = should_show
	if should_show != was_visible:
		_sync_process_state()


func _prompt_action_text() -> String:
	var local_id := _local_peer_id()
	if Network.players.has(local_id):
		var info: Dictionary = Network.players.get(local_id, {})
		var model_id := CharacterSkinCatalog.normalize(str(info.get("character_model", CharacterSkinCatalog.DEFAULT_ID)))
		if CharacterSkinCatalog.is_party_monster(model_id):
			var loadout: Dictionary = AccessoryCatalog.sanitize_loadout(info.get("party_monster_accessories", {}), model_id)
			var current_id := str(loadout.get(slot, ""))
			if current_id == accessory_id:
				return "ON"
			if not current_id.is_empty():
				return "SWAP"
	return "EQUIP"


func _should_show_bounty_beacon() -> bool:
	if not is_available or slot.is_empty():
		return false
	var local_id := _local_peer_id()
	if not Network.players.has(local_id):
		return false
	var info: Dictionary = Network.players.get(local_id, {})
	var role: int = int(info.get("role", Network.Role.NONE))
	var scene_bounty_ids := _current_bounty_accessory_ids()
	if role == Network.Role.HUNTER:
		return not scene_bounty_ids.is_empty() and _is_bounty_replacement_pickup(scene_bounty_ids)
	var local_player := _find_player_node(local_id)
	if not local_player or not local_player.has_method("is_party_monster_bounty_marked"):
		return false
	if not bool(local_player.call("is_party_monster_bounty_marked")):
		return false
	var bounty_ids: Array = _marked_player_bounty_accessory_ids(local_player)
	if bounty_ids.is_empty():
		bounty_ids = scene_bounty_ids
	if bounty_ids.is_empty():
		return false
	var model_id := CharacterSkinCatalog.normalize(str(info.get("character_model", CharacterSkinCatalog.DEFAULT_ID)))
	if not CharacterSkinCatalog.is_party_monster(model_id):
		return false
	var loadout: Dictionary = AccessoryCatalog.sanitize_loadout(info.get("party_monster_accessories", {}), model_id)
	var current_id := str(loadout.get(slot, ""))
	if current_id.is_empty() or current_id == accessory_id:
		return false
	for raw_id in bounty_ids:
		if AccessoryCatalog.normalize_accessory_id(str(raw_id)) == current_id:
			return true
	return false


func _marked_player_bounty_accessory_ids(local_player: Node) -> Array:
	if local_player and local_player.has_method("get_party_monster_bounty_accessory_ids"):
		var value: Variant = local_player.call("get_party_monster_bounty_accessory_ids")
		if value is Array:
			return _normalize_bounty_accessory_ids(value as Array)
	return []


func _is_bounty_replacement_pickup(bounty_ids: Array) -> bool:
	var pickup_id: String = AccessoryCatalog.normalize_accessory_id(accessory_id)
	if pickup_id.is_empty():
		return false
	for raw_id in bounty_ids:
		var bounty_id: String = AccessoryCatalog.normalize_accessory_id(str(raw_id))
		if bounty_id.is_empty() or bounty_id == pickup_id:
			continue
		if AccessoryCatalog.accessory_slot(bounty_id) == slot:
			return true
	return false


func _current_bounty_accessory_ids() -> Array:
	var candidates: Array[Node] = []
	var node: Node = self
	while node:
		candidates.append(node)
		node = node.get_parent()
	if owner:
		candidates.append(owner)
	var tree := get_tree()
	if tree:
		if tree.current_scene:
			candidates.append(tree.current_scene)
		for grouped_node in tree.get_nodes_in_group("party_monster_level"):
			if grouped_node is Node:
				candidates.append(grouped_node as Node)
	for candidate in candidates:
		var ids: Array = _bounty_accessory_ids_from_node(candidate)
		if not ids.is_empty():
			return ids
	return []


func _bounty_accessory_ids_from_node(node: Node) -> Array:
	if not node or not _object_has_property(node, "party_monster_bounty_accessories"):
		return []
	var value: Variant = node.get("party_monster_bounty_accessories")
	return _normalize_bounty_accessory_ids(value as Array) if value is Array else []


func _normalize_bounty_accessory_ids(raw_ids: Array) -> Array:
	var result: Array = []
	for raw_id in raw_ids:
		var normalized_id: String = AccessoryCatalog.normalize_accessory_id(str(raw_id))
		if normalized_id.is_empty() or result.has(normalized_id):
			continue
		result.append(normalized_id)
	return result


func _color_from_visible_preview(root: Node3D, fallback_color: Color) -> Color:
	var colors: Array[Color] = []
	_collect_visible_material_colors(root, Transform3D.IDENTITY, true, colors)
	if colors.is_empty():
		return fallback_color
	var result := Color(0.0, 0.0, 0.0, 1.0)
	for color in colors:
		result.r += color.r
		result.g += color.g
		result.b += color.b
	result.r /= float(colors.size())
	result.g /= float(colors.size())
	result.b /= float(colors.size())
	result.a = 1.0
	return _usable_beacon_color(result, fallback_color)


func _collect_visible_material_colors(node: Node, parent_transform: Transform3D, visible_chain: bool, colors: Array[Color]) -> void:
	var local_transform := parent_transform
	var local_visible := visible_chain
	if node is Node3D:
		var node_3d := node as Node3D
		local_transform = parent_transform * node_3d.transform
		local_visible = visible_chain and node_3d.visible
	if local_visible and node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh:
			for surface in range(mesh_instance.mesh.get_surface_count()):
				var material := mesh_instance.get_active_material(surface)
				var color := _color_from_material(material)
				if color.a > 0.0:
					colors.append(color)
	for child in node.get_children():
		_collect_visible_material_colors(child, local_transform, local_visible, colors)


func _color_from_material(material: Material) -> Color:
	if not material:
		return Color(0.0, 0.0, 0.0, 0.0)
	if material is StandardMaterial3D:
		var standard := material as StandardMaterial3D
		var color := standard.albedo_color
		if standard.albedo_texture:
			var texture_color := _average_texture_color(standard.albedo_texture)
			if texture_color.a > 0.0:
				color = Color(color.r * texture_color.r, color.g * texture_color.g, color.b * texture_color.b, 1.0)
		color.a = 1.0
		return color
	if material is ShaderMaterial:
		return _color_from_shader_material(material as ShaderMaterial)
	return Color(0.0, 0.0, 0.0, 0.0)


func _color_from_shader_material(material: ShaderMaterial) -> Color:
	var texture_color := _average_texture_color(material.get_shader_parameter("albedo_texture") as Texture2D)
	var tint := _shader_color_parameter(material, ["surface_tint", "albedo_color", "albedo", "color", "base_color"], Color.WHITE)
	if texture_color.a > 0.0:
		return Color(texture_color.r * tint.r, texture_color.g * tint.g, texture_color.b * tint.b, 1.0)
	return _shader_color_parameter(material, ["surface_tint", "emission", "emission_color", "color_01"], Color(0.0, 0.0, 0.0, 0.0))


func _shader_color_parameter(material: ShaderMaterial, names: Array[String], fallback_color: Color) -> Color:
	for parameter_name in names:
		var value: Variant = material.get_shader_parameter(parameter_name)
		if value is Color:
			var color := value as Color
			color.a = 1.0
			return color
	return fallback_color


func _average_texture_color(texture: Texture2D) -> Color:
	if not texture:
		return Color(0.0, 0.0, 0.0, 0.0)
	var image := texture.get_image()
	if not image or image.get_width() <= 0 or image.get_height() <= 0:
		return Color(0.0, 0.0, 0.0, 0.0)
	if image.is_compressed():
		var error := image.decompress()
		if error != OK:
			return Color(0.0, 0.0, 0.0, 0.0)
	var sample_count := 0
	var red := 0.0
	var green := 0.0
	var blue := 0.0
	var width := image.get_width()
	var height := image.get_height()
	for y_index in range(5):
		for x_index in range(5):
			var x := clampi(roundi((float(x_index) + 0.5) / 5.0 * float(width - 1)), 0, width - 1)
			var y := clampi(roundi((float(y_index) + 0.5) / 5.0 * float(height - 1)), 0, height - 1)
			var color := image.get_pixel(x, y)
			if color.a <= 0.03:
				continue
			red += color.r
			green += color.g
			blue += color.b
			sample_count += 1
	if sample_count <= 0:
		return Color(0.0, 0.0, 0.0, 0.0)
	return Color(red / float(sample_count), green / float(sample_count), blue / float(sample_count), 1.0)


func _usable_beacon_color(color: Color, fallback_color: Color) -> Color:
	var strongest := maxf(color.r, maxf(color.g, color.b))
	var weakest := minf(color.r, minf(color.g, color.b))
	if strongest <= 0.04:
		return fallback_color
	if strongest - weakest < 0.04 and _color_distance(color, fallback_color) > 0.32:
		return fallback_color
	return Color(color.r, color.g, color.b, 1.0)


func _color_distance(a: Color, b: Color) -> float:
	var delta := Vector3(a.r - b.r, a.g - b.g, a.b - b.b)
	return delta.length()


func _object_has_property(object: Object, property_name: String) -> bool:
	for raw_property in object.get_property_list():
		var property: Dictionary = raw_property as Dictionary
		if str(property.get("name", "")) == property_name:
			return true
	return false


func _slot_color() -> Color:
	return SLOT_COLORS.get(slot, Color(0.85, 0.92, 1.0, 1.0))


func _slot_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_local_to_scene = true
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.75
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.62
	return material


func _calculate_visible_bounds(root: Node3D) -> AABB:
	if not root:
		return AABB()
	return _calculate_visible_bounds_with_transform(root, Transform3D.IDENTITY, true)


func _calculate_visible_bounds_with_transform(node: Node, parent_transform: Transform3D, visible_chain: bool) -> AABB:
	var local_transform := parent_transform
	var local_visible := visible_chain
	if node is Node3D:
		var node_3d := node as Node3D
		local_transform = parent_transform * node_3d.transform
		local_visible = visible_chain and node_3d.visible
	var initialized := false
	var bounds := AABB()
	if local_visible and node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh:
			bounds = _transformed_aabb(local_transform, mesh_instance.mesh.get_aabb())
			initialized = true
	for child in node.get_children():
		var child_bounds := _calculate_visible_bounds_with_transform(child, local_transform, local_visible)
		if child_bounds.size == Vector3.ZERO:
			continue
		if not initialized:
			bounds = child_bounds
			initialized = true
		else:
			bounds = bounds.merge(child_bounds)
	return bounds


func _transformed_aabb(source_transform: Transform3D, local_aabb: AABB) -> AABB:
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
	var first: Vector3 = source_transform * points[0]
	var bounds := AABB(first, Vector3.ZERO)
	for index in range(1, points.size()):
		bounds = bounds.expand(source_transform * points[index])
	return bounds


func _max_axis(value: Vector3) -> float:
	return maxf(value.x, maxf(value.y, value.z))


func get_debug_bounty_beacon_visible() -> bool:
	return _beacon_root != null and is_instance_valid(_beacon_root) and _beacon_root.visible


func get_debug_accessory_preview_size() -> float:
	if not _visual_root or not is_instance_valid(_visual_root):
		return 0.0
	return _max_axis(_calculate_visible_bounds(_visual_root).size)


func get_debug_beacon_height() -> float:
	return BEACON_HEIGHT


func get_debug_accessory_color() -> Color:
	return _accessory_color


func get_debug_prompt_hud_visible() -> bool:
	return _prompt_root != null and is_instance_valid(_prompt_root) and _prompt_root.visible


func get_debug_beacon_impact_requested() -> bool:
	return _beacon_impact_requested
