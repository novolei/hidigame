extends Area3D
class_name PartyMonsterAccessoryPickup

const AccessoryCatalog := preload("res://scripts/party_monster_accessory_catalog.gd")
const PARTY_MONSTER_SKIN_SCENE := preload("res://assets/characters/party_monster/party_monster_skin.tscn")
const PICKUP_RANGE := 2.35
const RESPAWN_TIME := 42.0
const BOB_HEIGHT := 0.14
const BOB_SPEED := 2.6
const ROTATION_SPEED := 1.35
const PREVIEW_SCALE := Vector3(0.34, 0.34, 0.34)
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
var respawn_timer := 0.0
var _nearby_player_ids := {}
var _visual_root: Node3D = null
var _base_visual_y := 0.64
var _time := 0.0
var _label: Label3D = null
var _aura_material: StandardMaterial3D = null


func _ready() -> void:
	add_to_group("party_monster_accessory_pickups")
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_process(true)
	set_process_unhandled_input(true)
	_refresh_accessory_metadata()
	_ensure_collision_shape()
	_apply_visual()


func _process(delta: float) -> void:
	_time += delta
	_update_visual_motion()
	if not multiplayer.is_server():
		return
	if not is_available:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			_respawn()


func _unhandled_input(event: InputEvent) -> void:
	if not is_available or not event.is_action_pressed("interact"):
		return
	var local_id := multiplayer.get_unique_id()
	if not _nearby_player_ids.has(local_id):
		return
	request_pickup_for_player(local_id)
	get_viewport().set_input_as_handled()


func configure(new_accessory_id: String) -> void:
	accessory_id = new_accessory_id
	_refresh_accessory_metadata()
	_apply_visual()


func request_pickup_for_player(peer_id: int) -> void:
	if not is_available:
		return
	if multiplayer.is_server():
		_server_try_pickup_by_id(peer_id)
	else:
		_request_pickup_rpc.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func _request_pickup_rpc() -> void:
	if not multiplayer.is_server():
		return
	_server_try_pickup_by_id(multiplayer.get_remote_sender_id())


func _server_try_pickup_by_id(peer_id: int) -> void:
	if not multiplayer.is_server() or not is_available:
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
	if not _is_player_close_enough(player_node):
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


func _is_player_close_enough(player_node: Node3D) -> bool:
	if not player_node or not is_instance_valid(player_node):
		return false
	return global_position.distance_to(player_node.global_position) <= PICKUP_RANGE + 0.9


func _find_player_node(peer_id: int) -> Node3D:
	var tree := get_tree()
	if not tree:
		return null
	var scene := tree.current_scene
	if not scene:
		return null
	var container := scene.get_node_or_null("PlayersContainer")
	if not container:
		return null
	return container.get_node_or_null(str(peer_id)) as Node3D


func _consume() -> void:
	if not multiplayer.is_server():
		return
	_set_available.rpc(false, RESPAWN_TIME)


func _respawn() -> void:
	if not multiplayer.is_server():
		return
	_set_available.rpc(true, 0.0)


@rpc("authority", "call_local", "reliable")
func _set_available(available: bool, next_respawn_time: float = 0.0) -> void:
	is_available = available
	respawn_timer = maxf(next_respawn_time, 0.0)
	visible = available
	monitoring = available
	monitorable = available
	for child in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = not available


func _on_body_entered(body: Node) -> void:
	if not body or not body.is_in_group("players"):
		return
	if body.has_method("get_multiplayer_authority"):
		_nearby_player_ids[int(body.get_multiplayer_authority())] = true
	_update_prompt_visibility()


func _on_body_exited(body: Node) -> void:
	if not body or not body.is_in_group("players"):
		return
	if body.has_method("get_multiplayer_authority"):
		_nearby_player_ids.erase(int(body.get_multiplayer_authority()))
	_update_prompt_visibility()


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
	var color := _slot_color()
	_visual_root = Node3D.new()
	_visual_root.name = "AccessoryVisualRoot"
	_visual_root.position = Vector3(0.0, _base_visual_y, 0.0)
	add_child(_visual_root)
	_add_real_accessory_preview(_visual_root)
	_add_aura(color)
	_add_label(color)
	_update_prompt_visibility()


func _clear_visual_nodes() -> void:
	for node_name in ["AccessoryVisualRoot", "AccessoryAura", "AccessoryLabel"]:
		var child := get_node_or_null(node_name)
		if child:
			child.queue_free()
	_visual_root = null
	_label = null


func _add_real_accessory_preview(parent: Node3D) -> void:
	var preview := PARTY_MONSTER_SKIN_SCENE.instantiate() as Node3D
	if not preview:
		_add_fallback_preview(parent)
		return
	preview.name = "AccessoryPreview"
	preview.scale = PREVIEW_SCALE
	preview.rotation.y = PI
	if preview.has_method("set_accessory_preview_id"):
		preview.call("set_accessory_preview_id", accessory_id)
	parent.add_child(preview)


func _add_fallback_preview(parent: Node3D) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "AccessoryFallbackPreview"
	mesh_instance.mesh = _fallback_mesh_for_slot()
	mesh_instance.material_override = _slot_material(_slot_color())
	parent.add_child(mesh_instance)


func _fallback_mesh_for_slot() -> Mesh:
	if slot == "head":
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.42
		cone.height = 0.72
		cone.radial_segments = 16
		return cone
	if slot == "tail" or slot == "gloves":
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.22
		cylinder.bottom_radius = 0.22
		cylinder.height = 0.65
		cylinder.radial_segments = 16
		return cylinder
	var sphere := SphereMesh.new()
	sphere.radius = 0.34
	sphere.height = 0.68
	return sphere


func _add_aura(color: Color) -> void:
	var aura := MeshInstance3D.new()
	aura.name = "AccessoryAura"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.78
	mesh.bottom_radius = 0.78
	mesh.height = 0.035
	mesh.radial_segments = 40
	aura.mesh = mesh
	aura.position = Vector3(0.0, 0.04, 0.0)
	aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_aura_material = _slot_material(color)
	_aura_material.albedo_color.a = 0.34
	_aura_material.emission_energy_multiplier = 0.9
	aura.material_override = _aura_material
	add_child(aura)


func _add_label(color: Color) -> void:
	_label = Label3D.new()
	_label.name = "AccessoryLabel"
	_label.position = Vector3(0.0, 1.28, 0.0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.fixed_size = true
	_label.no_depth_test = true
	_label.font_size = 38
	_label.outline_size = 10
	_label.modulate = Color.WHITE
	_label.outline_modulate = color
	_label.text = _prompt_text(false)
	add_child(_label)


func _update_visual_motion() -> void:
	if _visual_root and is_instance_valid(_visual_root):
		_visual_root.position.y = _base_visual_y + sin(_time * BOB_SPEED) * BOB_HEIGHT
		_visual_root.rotation.y += ROTATION_SPEED * get_process_delta_time()
	if _aura_material:
		_aura_material.emission_energy_multiplier = 0.65 + sin(_time * 5.1) * 0.20


func _update_prompt_visibility() -> void:
	if not _label:
		return
	var local_id := multiplayer.get_unique_id()
	var local_nearby := is_available and _nearby_player_ids.has(local_id)
	_label.text = _prompt_text(local_nearby)
	_label.modulate.a = 1.0 if local_nearby else 0.74


func _prompt_text(local_nearby: bool) -> String:
	var accessory_label := AccessoryCatalog.accessory_label(accessory_id)
	if not local_nearby:
		return "%s  %s" % [AccessoryCatalog.slot_label(slot), accessory_label]
	var local_id := multiplayer.get_unique_id()
	if Network.players.has(local_id):
		var info: Dictionary = Network.players.get(local_id, {})
		var model_id := CharacterSkinCatalog.normalize(str(info.get("character_model", CharacterSkinCatalog.DEFAULT_ID)))
		if CharacterSkinCatalog.is_party_monster(model_id):
			var loadout: Dictionary = AccessoryCatalog.sanitize_loadout(info.get("party_monster_accessories", {}), model_id)
			var current_id := str(loadout.get(slot, ""))
			if current_id == accessory_id:
				return "Equipped  %s" % accessory_label
			if not current_id.is_empty():
				return "F  Swap %s -> %s" % [AccessoryCatalog.slot_label(slot), accessory_label]
	return "F  Equip %s" % accessory_label


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
