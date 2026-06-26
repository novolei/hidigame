class_name ChameleonEnvironmentBlendSystem
extends Node

const STATE_INACTIVE := "inactive"
const STATE_WHEEL := "wheel"
const STATE_PROP_PREVIEW := "prop_preview"
const STATE_PROP_PAINT := "prop_paint"
const STATE_CLOUD_CAPTURE := "cloud_capture"
const STATE_CLOUD_PENDING := "cloud_pending"

const PREVIEW_SECONDS := 4.0
const WHEEL_RADIUS := 190.0

var camouflage_owner: CharacterBody3D = null
var camera: Camera3D = null
var camouflage_system: Node = null
var session_seed := ""

var _state := STATE_INACTIVE
var _hand: Array = []
var _options: Array = []
var _selected_preset: Dictionary = {}
var _preview_node: Node3D = null
var _preview_generation := 0
var _wheel_layer: CanvasLayer = null
var _capture_layer: CanvasLayer = null
var _cloud_service: Hunyuan3DService = null
var _white_material: StandardMaterial3D = null


func initialize(owner_node: CharacterBody3D, owner_camera: Camera3D, paint_system: Node = null) -> void:
	camouflage_owner = owner_node
	camera = owner_camera
	camouflage_system = paint_system
	session_seed = "%s:%d" % [Time.get_unix_time_from_system(), owner_node.get_instance_id() if owner_node else 0]
	_refresh_hand()
	_ensure_cloud_service()


func is_active() -> bool:
	return _state != STATE_INACTIVE


func is_prop_paint_mode() -> bool:
	return _state == STATE_PROP_PAINT


func get_state() -> String:
	return _state


func get_random_hand() -> Array:
	_refresh_hand()
	return _duplicate_array(_hand)


func get_wheel_options() -> Array:
	_refresh_options()
	return _duplicate_array(_options)


func get_debug_summary() -> Dictionary:
	return {
		"active": is_active(),
		"state": _state,
		"hand_count": _hand.size(),
		"option_count": _options.size(),
		"selected_id": str(_selected_preset.get("id", "")),
		"selected_name": str(_selected_preset.get("name", "")),
		"has_preview": _preview_node != null and is_instance_valid(_preview_node),
		"cloud_configured": _cloud_service != null and _cloud_service.is_configured(),
	}


func toggle_wheel() -> bool:
	if is_active():
		deactivate()
		return true
	open_wheel()
	return true


func open_wheel() -> void:
	if not camouflage_owner:
		return
	_set_state(STATE_WHEEL)
	_refresh_options()
	_set_owner_locked(true)
	_set_owner_preview_visual(false)
	_show_wheel()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func deactivate() -> void:
	if _state == STATE_INACTIVE:
		return
	_preview_generation += 1
	_hide_wheel()
	_hide_capture_overlay()
	_clear_preview()
	_selected_preset.clear()
	_set_owner_preview_visual(false)
	if camouflage_system and camouflage_system.has_method("deactivate_skill"):
		if bool(camouflage_system.get("skill_active")):
			camouflage_system.call("deactivate_skill")
	_set_owner_locked(false)
	_set_state(STATE_INACTIVE)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func handle_skill_input(event: InputEvent) -> bool:
	if not is_active():
		return false
	match _state:
		STATE_WHEEL:
			return _handle_wheel_input(event)
		STATE_PROP_PREVIEW:
			return _handle_preview_input(event)
		STATE_PROP_PAINT:
			return _handle_prop_paint_input(event)
		STATE_CLOUD_CAPTURE:
			return _handle_cloud_capture_input(event)
		STATE_CLOUD_PENDING:
			return _handle_cloud_pending_input(event)
	return true


func select_option(option_index: int) -> bool:
	_refresh_options()
	if option_index < 0 or option_index >= _options.size():
		return false
	var option := _options[option_index] as Dictionary
	match str(option.get("type", "")):
		"paint_self":
			_begin_self_paint()
		"preset_prop":
			_begin_prop_preview(option.get("preset", {}) as Dictionary)
		"cloud_3d":
			_begin_cloud_capture()
		_:
			return false
	return true


func select_preset_by_id(preset_id: String) -> bool:
	_refresh_options()
	for i in range(_options.size()):
		var option := _options[i] as Dictionary
		if str(option.get("preset_id", "")) == preset_id:
			return select_option(i)
	return false


func force_cancel_for_death() -> void:
	deactivate()


func notify_paint_session_expired() -> void:
	if _state == STATE_PROP_PAINT:
		_commit_selected_prop()
	elif is_active():
		deactivate()


func _handle_wheel_input(event: InputEvent) -> bool:
	if event.is_action_pressed("camouflage_absorb") or _is_escape(event):
		deactivate()
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		var number_index := _number_key_to_index(event.keycode)
		if number_index >= 0:
			select_option(number_index)
			return true
	return true


func _handle_preview_input(event: InputEvent) -> bool:
	if _is_escape(event):
		deactivate()
		return true
	return true


func _handle_prop_paint_input(event: InputEvent) -> bool:
	if _is_escape(event):
		deactivate()
		return true
	if event.is_action_pressed("camouflage_absorb") or _is_accept(event):
		_commit_selected_prop()
		return true
	return false


func _handle_cloud_capture_input(event: InputEvent) -> bool:
	if _is_escape(event) or event.is_action_pressed("camouflage_absorb"):
		deactivate()
		return true
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
			_submit_cloud_capture()
			return true
	return false


func _handle_cloud_pending_input(event: InputEvent) -> bool:
	if _is_escape(event):
		deactivate()
		return true
	return true


func _begin_self_paint() -> void:
	_hide_wheel()
	_set_state(STATE_INACTIVE)
	_set_owner_locked(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if camouflage_system and camouflage_system.has_method("activate_skill"):
		camouflage_system.call("activate_skill")


func _begin_prop_preview(raw_preset: Dictionary) -> void:
	_hide_wheel()
	_selected_preset = ChameleonPropCatalog.normalize_preset(raw_preset)
	_set_state(STATE_PROP_PREVIEW)
	_set_owner_locked(true)
	_set_owner_preview_visual(true)
	_spawn_preview_node(_selected_preset)
	_start_preview_timer()


func _start_preview_timer() -> void:
	_preview_generation += 1
	var token := _preview_generation
	var tree := get_tree()
	if not tree:
		_enter_prop_paint_mode(token)
		return
	tree.create_timer(PREVIEW_SECONDS).timeout.connect(func():
		_enter_prop_paint_mode(token)
	)


func _enter_prop_paint_mode(token: int) -> void:
	if token != _preview_generation or _state != STATE_PROP_PREVIEW:
		return
	_set_state(STATE_PROP_PAINT)
	_apply_white_model_material(_preview_node)
	if camouflage_owner and camouflage_owner.has_method("clear_environment_prop_paint_buffers"):
		camouflage_owner.call("clear_environment_prop_paint_buffers")
	if camouflage_system and camouflage_system.has_method("activate_skill"):
		camouflage_system.call("activate_skill")
	_set_owner_locked(true)


func _commit_selected_prop() -> void:
	if _selected_preset.is_empty():
		deactivate()
		return
	var final_preset := _selected_preset.duplicate(true)
	var profile := _current_paint_profile()
	if bool(profile.get("has_sampled_color", false)):
		final_preset["paint_color"] = profile.get("color", Color.WHITE)
		final_preset["paint_roughness"] = float(profile.get("roughness", 0.72))
		final_preset["paint_metallic"] = float(profile.get("metallic", 0.0))
		final_preset["paint_specular"] = float(profile.get("specular", 0.45))
		final_preset["color"] = profile.get("color", final_preset.get("color", Color.WHITE))
	if camouflage_owner and camouflage_owner.has_method("capture_environment_prop_paint_payload"):
		var paint_payload = camouflage_owner.call("capture_environment_prop_paint_payload", _preview_node)
		if paint_payload is Dictionary and not (paint_payload as Dictionary).is_empty():
			final_preset["paint_payload"] = paint_payload
	final_preset["environment_blend_source"] = "preset_prop_library"
	_preview_generation += 1
	_hide_wheel()
	_hide_capture_overlay()
	if camouflage_system and camouflage_system.has_method("deactivate_skill"):
		camouflage_system.call("deactivate_skill")
	_clear_preview()
	_set_owner_preview_visual(false)
	_set_owner_locked(false)
	_set_state(STATE_INACTIVE)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if camouflage_owner and camouflage_owner.has_method("request_environment_prop_disguise"):
		camouflage_owner.call("request_environment_prop_disguise", final_preset)


func _begin_cloud_capture() -> void:
	_hide_wheel()
	_set_state(STATE_CLOUD_CAPTURE)
	_set_owner_locked(true)
	_set_owner_preview_visual(false)
	_show_capture_overlay()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _submit_cloud_capture() -> void:
	_ensure_cloud_service()
	var image := _capture_viewport_image()
	if not image:
		_begin_cloud_fallback("No viewport image was available.")
		return
	if not _cloud_service.is_configured():
		_begin_cloud_fallback("Hunyuan 3D is not configured.")
		return
	_set_state(STATE_CLOUD_PENDING)
	_show_capture_overlay("Generating 3D prop...")
	var submitted := _cloud_service.submit_capture(image)
	if not submitted:
		_begin_cloud_fallback(_cloud_service.last_error)


func _on_cloud_ready(result: Dictionary) -> void:
	var preset := ChameleonPropCatalog.build_cloud_placeholder_preset("Generated White Model")
	preset["environment_blend_source"] = "hunyuan_3d"
	preset["cloud_result"] = result
	var local_model_path := str(result.get("local_model_path", ""))
	if not local_model_path.is_empty() and str(result.get("local_model_type", "")).to_upper() == "GLB":
		preset["mesh"] = "runtime_gltf"
		preset["runtime_model_path"] = local_model_path
	_begin_prop_preview(preset)


func _on_cloud_failed(message: String) -> void:
	_begin_cloud_fallback(message)


func _begin_cloud_fallback(reason: String) -> void:
	var preset := ChameleonPropCatalog.build_cloud_placeholder_preset("Cloud White Model")
	preset["environment_blend_source"] = "cloud_fallback"
	preset["cloud_error"] = reason
	_begin_prop_preview(preset)


func _capture_viewport_image() -> Image:
	var viewport := get_viewport()
	if not viewport or not viewport.get_texture():
		return null
	return viewport.get_texture().get_image()


func _refresh_hand() -> void:
	if not _hand.is_empty():
		return
	var owner_id := camouflage_owner.get_multiplayer_authority() if camouflage_owner else 0
	_hand = ChameleonPropCatalog.random_hand_for_player(owner_id, session_seed, ChameleonPropCatalog.get_hand_size())


func _refresh_options() -> void:
	_refresh_hand()
	_options.clear()
	_options.append({
		"id": "paint_self",
		"type": "paint_self",
		"name": "Spray Self"
	})
	for preset in _hand:
		var clean := (preset as Dictionary).duplicate(true)
		_options.append({
			"id": "preset_%s" % str(clean.get("id", "")),
			"type": "preset_prop",
			"name": str(clean.get("name", "Prop")),
			"preset_id": str(clean.get("id", "")),
			"preset": clean,
		})
	_options.append({
		"id": "cloud_3d",
		"type": "cloud_3d",
		"name": "Cloud 3D"
	})


func _spawn_preview_node(preset: Dictionary) -> void:
	_clear_preview()
	var node := _create_preview_node(preset)
	if not node or not camouflage_owner:
		return
	node.name = "EnvironmentBlendPreview"
	node.top_level = true
	camouflage_owner.add_child(node)
	node.global_position = camouflage_owner.global_position
	node.global_rotation = Vector3.ZERO
	_preview_node = node


func _create_preview_node(preset: Dictionary) -> Node3D:
	if camouflage_owner and camouflage_owner.has_method("create_environment_prop_preview_node"):
		var created = camouflage_owner.call("create_environment_prop_preview_node", preset)
		if created is Node3D:
			return created as Node3D
	var holder := Node3D.new()
	holder.position = preset.get("offset", Vector3.ZERO)
	var mesh_type := str(preset.get("mesh", "box"))
	if mesh_type == "runtime_gltf":
		var runtime_node := _instantiate_runtime_gltf(str(preset.get("runtime_model_path", "")))
		if runtime_node:
			runtime_node.scale = preset.get("scale", Vector3.ONE)
			holder.add_child(runtime_node)
			return holder
		mesh_type = str(preset.get("fallback_mesh", "box"))
	if mesh_type == "scene":
		var scene := load(str(preset.get("scene_path", "")))
		if scene is PackedScene:
			var scene_node := (scene as PackedScene).instantiate() as Node3D
			if scene_node:
				scene_node.scale = preset.get("scale", Vector3.ONE)
				holder.add_child(scene_node)
				return holder
		mesh_type = str(preset.get("fallback_mesh", "box"))
	var mesh_instance := MeshInstance3D.new()
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
	mesh_instance.scale = preset.get("size", Vector3.ONE)
	var material := StandardMaterial3D.new()
	material.albedo_color = preset.get("color", Color.WHITE)
	material.roughness = 0.72
	mesh_instance.material_override = material
	holder.add_child(mesh_instance)
	return holder


func _instantiate_runtime_gltf(model_path: String) -> Node3D:
	if model_path.is_empty():
		return null
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var err := document.append_from_file(model_path, state)
	if err != OK:
		push_warning("Could not load runtime GLTF model: %s" % model_path)
		return null
	var scene := document.generate_scene(state)
	return scene as Node3D if scene is Node3D else null


func _clear_preview() -> void:
	if _preview_node and is_instance_valid(_preview_node):
		_preview_node.queue_free()
	_preview_node = null


func _apply_white_model_material(root: Node) -> void:
	if not root:
		return
	var material := _get_white_material()
	_apply_material_recursive(root, material)


func _apply_material_recursive(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var count := mesh_instance.mesh.get_surface_count() if mesh_instance.mesh else 0
		if count <= 0:
			mesh_instance.material_override = material
		else:
			for surface in range(count):
				mesh_instance.set_surface_override_material(surface, material)
	for child in node.get_children():
		_apply_material_recursive(child, material)


func _get_white_material() -> StandardMaterial3D:
	if _white_material:
		return _white_material
	_white_material = StandardMaterial3D.new()
	_white_material.resource_local_to_scene = true
	_white_material.albedo_color = Color(0.96, 0.94, 0.9, 1.0)
	_white_material.roughness = 0.86
	_white_material.metallic = 0.0
	return _white_material


func _current_paint_profile() -> Dictionary:
	if camouflage_system and camouflage_system.has_method("get_current_paint_profile"):
		var profile = camouflage_system.call("get_current_paint_profile")
		if profile is Dictionary:
			return profile as Dictionary
	return {
		"has_sampled_color": false,
		"color": Color.WHITE,
		"roughness": 0.72,
		"metallic": 0.0,
		"specular": 0.45,
	}


func _show_wheel() -> void:
	_hide_wheel()
	var viewport := get_viewport()
	if not viewport:
		return
	_wheel_layer = CanvasLayer.new()
	_wheel_layer.name = "EnvironmentBlendWheelLayer"
	_wheel_layer.layer = 65
	add_child(_wheel_layer)
	var root := Control.new()
	root.name = "WheelRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wheel_layer.add_child(root)
	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.025, 0.03, 0.42)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(scrim)
	var center := viewport.get_visible_rect().size * 0.5
	for i in range(_options.size()):
		var option := _options[i] as Dictionary
		var angle := -PI * 0.5 + TAU * float(i) / maxf(float(_options.size()), 1.0)
		var button := Button.new()
		button.text = "%d %s" % [i + 1, str(option.get("name", "Option"))]
		button.tooltip_text = str(option.get("name", "Option"))
		button.custom_minimum_size = Vector2(132, 46)
		button.position = center + Vector2(cos(angle), sin(angle)) * WHEEL_RADIUS - button.custom_minimum_size * 0.5
		var captured_index := i
		button.pressed.connect(func():
			select_option(captured_index)
		)
		root.add_child(button)
	var hint := Label.new()
	hint.text = "C / Esc"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = center + Vector2(-80, -18)
	hint.size = Vector2(160, 36)
	root.add_child(hint)


func _hide_wheel() -> void:
	if _wheel_layer and is_instance_valid(_wheel_layer):
		_wheel_layer.queue_free()
	_wheel_layer = null


func _show_capture_overlay(message: String = "Left click to capture") -> void:
	_hide_capture_overlay()
	_capture_layer = CanvasLayer.new()
	_capture_layer.name = "EnvironmentBlendCaptureLayer"
	_capture_layer.layer = 66
	add_child(_capture_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_capture_layer.add_child(root)
	var frame := Panel.new()
	frame.anchor_left = 0.18
	frame.anchor_top = 0.16
	frame.anchor_right = 0.82
	frame.anchor_bottom = 0.84
	root.add_child(frame)
	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.anchor_left = 0.18
	label.anchor_top = 0.84
	label.anchor_right = 0.82
	label.anchor_bottom = 0.92
	root.add_child(label)


func _hide_capture_overlay() -> void:
	if _capture_layer and is_instance_valid(_capture_layer):
		_capture_layer.queue_free()
	_capture_layer = null


func _ensure_cloud_service() -> void:
	if _cloud_service:
		return
	_cloud_service = Hunyuan3DService.new()
	_cloud_service.name = "Hunyuan3DService"
	add_child(_cloud_service)
	_cloud_service.generation_ready.connect(_on_cloud_ready)
	_cloud_service.generation_failed.connect(_on_cloud_failed)


func _set_owner_locked(locked: bool) -> void:
	if camouflage_owner and camouflage_owner.has_method("set_camouflage_brush_locked"):
		camouflage_owner.call("set_camouflage_brush_locked", locked)


func _set_owner_preview_visual(active: bool) -> void:
	if camouflage_owner and camouflage_owner.has_method("set_environment_blend_preview_active"):
		camouflage_owner.call("set_environment_blend_preview_active", active)


func _set_state(next_state: String) -> void:
	_state = next_state


func _is_escape(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE


func _is_accept(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER)


func _number_key_to_index(keycode: Key) -> int:
	if keycode >= KEY_1 and keycode <= KEY_9:
		return int(keycode - KEY_1)
	return -1


func _duplicate_array(source: Array) -> Array:
	var result := []
	for item in source:
		result.append((item as Dictionary).duplicate(true) if item is Dictionary else item)
	return result
