extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var player_scene := load("res://scenes/level/player.tscn")
	if not player_scene is PackedScene:
		failures.append("Player scene did not load as PackedScene")
	else:
		var floor := StaticBody3D.new()
		floor.name = "PhysicsTestFloor"
		floor.collision_layer = 2
		floor.collision_mask = 3
		var floor_collision := CollisionShape3D.new()
		var floor_shape := BoxShape3D.new()
		floor_shape.size = Vector3(12.0, 0.2, 12.0)
		floor_collision.shape = floor_shape
		floor_collision.position.y = -0.1
		floor.add_child(floor_collision)
		add_child(floor)
		var wall := StaticBody3D.new()
		wall.name = "PhysicsTestWall"
		wall.collision_layer = 2
		wall.collision_mask = 4
		var wall_collision := CollisionShape3D.new()
		var wall_shape := BoxShape3D.new()
		wall_shape.size = Vector3(0.35, 4.0, 12.0)
		wall_collision.shape = wall_shape
		wall_collision.position = Vector3(4.0, 2.0, 0.0)
		wall.add_child(wall_collision)
		add_child(wall)

		var player := (player_scene as PackedScene).instantiate()
		player.name = "1"
		add_child(player)
		await get_tree().process_frame

		var preset := ShapeShiftSystem.PRESET_LIBRARY[0]
		player.apply_prop_disguise(preset)
		await get_tree().process_frame
		if not player.has_method("is_disguised") or not player.is_disguised():
			failures.append("Player did not enter prop disguise state")
		if not player.get_node_or_null("3DGodotRobot/PropDisguise"):
			failures.append("Prop disguise visual node was not created")
		var player_collision := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if not player_collision or not player_collision.shape is CylinderShape3D:
			failures.append("Prop disguise should switch the player movement collider to a prop cylinder")

		player.clear_prop_disguise()
		await get_tree().process_frame
		if player.is_disguised():
			failures.append("Player did not clear prop disguise state")
		if player.get_node_or_null("3DGodotRobot/PropDisguise"):
			failures.append("Prop disguise visual node remained after clearing")
		if not player_collision or not player_collision.shape is CapsuleShape3D:
			failures.append("Clearing prop disguise should restore the default player capsule collider")

		if FruitPropCatalog.all().size() < 40:
			failures.append("Map prop catalog should include the food prefab families")
		var catalog_entry := FruitPropCatalog.by_id("apple")
		if not load(str(catalog_entry.get("scene", ""))) is PackedScene:
			failures.append("Catalog apple prefab did not load as PackedScene")

		var prop := FruitProp.new()
		add_child(prop)
		prop.apply_data({
			"id": "apple",
			"name": "Apple",
			"category": "fruit",
			"scene": "res://Prefabs/Fruits/apple.tscn",
			"material": "res://Materials/M_fruit.tres",
			"scale": Vector3.ONE * 4.8,
			"radius": 0.22,
			"position": player.global_position + Vector3(1.0, 0.0, 0.0),
			"rotation_y": 0.0,
		})
		await get_tree().process_frame
		if prop.collision_layer != 4:
			failures.append("Map props should use the dedicated prop physics layer")
		if prop.collision_mask != 2:
			failures.append("Map props should solve rigid-body physics against world geometry only")
		if not (prop is RigidBody3D):
			failures.append("Map props should be rigid bodies so player impacts can move them")
		var map_collision := _find_collision_shape(prop)
		if not map_collision or not map_collision.shape:
			failures.append("Map prop should build a collision footprint")
		elif not map_collision.position.is_zero_approx():
			failures.append("Map prop collision should be centered on the rigid body origin")
		if prop.visual_bounds.position.y < -prop.collision_height * 0.5 - 0.02:
			failures.append("Map prop visuals should stay above the physical floor contact")
		player.global_position = Vector3(0.0, 3.25, 0.0)
		player.velocity = Vector3(0.0, -3.0, 0.0)
		player.apply_prop_disguise(prop.get_disguise_preset())
		var drop_disguise := player.get_node_or_null("3DGodotRobot/PropDisguise") as Node3D
		if absf(player.global_position.y) > 0.05:
			failures.append("Replicating a nearby prop should snap the player body back to the floor")
		if player._prop_disguise_tween == null or not player._prop_disguise_tween.is_valid():
			failures.append("Prop disguise should create the landing squash/stretch tween")
		if drop_disguise and drop_disguise.position.y <= player._prop_disguise_base_position.y:
			failures.append("Prop disguise landing animation should start above the grounded final position")
		if drop_disguise:
			var animated_position := drop_disguise.position
			var animated_scale := drop_disguise.scale
			drop_disguise.position = player._prop_disguise_base_position
			drop_disguise.scale = Vector3.ONE
			var grounded_bounds: AABB = player._calculate_prop_disguise_bounds_in_body_space()
			if absf(grounded_bounds.position.y) > 0.05:
				failures.append("Prop disguise final visual bottom should be aligned with the floor")
			var expected_prop_height := prop.visual_bounds.size.y
			if absf(grounded_bounds.size.y - expected_prop_height) > 0.08:
				failures.append("Prop disguise final visual height should match the replicated prop height (visual=%.3f expected=%.3f)" % [grounded_bounds.size.y, expected_prop_height])
			drop_disguise.position = animated_position
			drop_disguise.scale = animated_scale
		var disguise_collision := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if disguise_collision and disguise_collision.shape is CylinderShape3D:
			var disguise_height := (disguise_collision.shape as CylinderShape3D).height
			var expected_collision_height := minf(prop.visual_bounds.size.y, player.PROP_COLLISION_MAX_HEIGHT)
			if disguise_height < expected_collision_height - 0.05:
				failures.append("Prop disguise collider should preserve the replicated prop height (collider=%.3f expected=%.3f)" % [disguise_height, expected_collision_height])
		player.clear_prop_disguise()
		await get_tree().process_frame
		player.global_position = Vector3.ZERO
		player.velocity = Vector3.ZERO
		prop.global_position = Vector3(0.74, prop.collision_height * 0.5 + 0.035, 0.0)
		await get_tree().physics_frame
		var motion_collision: KinematicCollision3D = player.move_and_collide(Vector3(1.2, 0.0, 0.0), true)
		if motion_collision and motion_collision.get_collider() == prop:
			failures.append("Player movement should not be solved directly against round prop bodies")
		prop.linear_velocity = Vector3.ZERO
		prop.angular_velocity = Vector3.ZERO
		prop.sleeping = true
		player.global_position = Vector3.ZERO
		player.velocity = Vector3(7.0, 0.0, 0.0)
		await get_tree().physics_frame
		player.move_and_slide()
		var applied_impact: bool = player._apply_prop_collision_impacts(Vector3(7.0, 0.0, 0.0))
		await get_tree().physics_frame
		if not applied_impact:
			failures.append("Player proximity impact should detect nearby movable props")
		if prop.linear_velocity.length() < 0.05 and prop.angular_velocity.length() < 0.05:
			failures.append("Player impact should apply movement or rolling velocity to map props")
		if player.velocity.y > 0.05:
			failures.append("Player impact against movable props should not inject upward velocity")

		var watermelon_entry := FruitPropCatalog.by_id("watermelon")
		var watermelon := FruitProp.new()
		add_child(watermelon)
		watermelon.apply_data({
			"id": "watermelon",
			"name": "Watermelon",
			"category": "fruit",
			"scene": str(watermelon_entry.get("scene", "res://Prefabs/Fruits/watermelon.tscn")),
			"material": str(watermelon_entry.get("material", "res://Materials/M_fruit.tres")),
			"scale": Vector3.ONE * 5.0,
			"radius": 0.26,
			"position": Vector3(3.0, 0.0, 0.0),
			"rotation_y": 0.0,
		})
		await get_tree().physics_frame
		if watermelon.visual_bounds.position.y < -watermelon.collision_height * 0.5 - 0.02:
			failures.append("Watermelon visual should not sink below the floor contact after physics spawn")
		var watermelon_collision := _find_collision_shape(watermelon)
		if not watermelon_collision or not watermelon_collision.shape is SphereShape3D:
			failures.append("Watermelon should use a sphere collider for weighted rolling")
		if watermelon.mass <= prop.mass:
			failures.append("Large round props should be heavier than small baseline props")
		watermelon.global_position = Vector3(3.2, watermelon.collision_half_height + 0.045, 0.0)
		watermelon.linear_velocity = Vector3(18.0, 0.0, 0.0)
		watermelon.angular_velocity = Vector3(0.0, 0.0, 16.0)
		watermelon.sleeping = false
		for _i in range(16):
			await get_tree().physics_frame
		if watermelon.global_position.x > 3.95:
			failures.append("Fast round props should collide with fixed blockers instead of tunneling")
		if watermelon.linear_velocity.length() > 7.2 or watermelon.angular_velocity.length() > 7.8:
			failures.append("Prop velocities should be clamped for grounded heavy physics")

		var pineapple_entry := FruitPropCatalog.by_id("pineapple")
		var pineapple := FruitProp.new()
		add_child(pineapple)
		pineapple.apply_data({
			"id": "pineapple",
			"name": "Pineapple",
			"category": "fruit",
			"scene": str(pineapple_entry.get("scene", "res://Prefabs/Fruits/pineapple.tscn")),
			"material": str(pineapple_entry.get("material", "res://Materials/M_fruit.tres")),
			"scale": Vector3.ONE * 5.0,
			"radius": 0.28,
			"position": Vector3(-3.0, 0.0, 0.0),
			"rotation_y": 0.0,
		})
		await get_tree().physics_frame
		if pineapple.collision_kind != "tall":
			failures.append("Pineapple should use a tall collider profile")
		if pineapple.center_of_mass.y >= 0.0:
			failures.append("Tall irregular props should have a lower center of mass to settle naturally")
		if pineapple.visual_bounds.position.y < -pineapple.collision_half_height - 0.02:
			failures.append("Pineapple visual should not clip below its ground contact when spawned")

		var shape_system := ShapeShiftSystem.new()
		player.add_child(shape_system)
		shape_system.initialize(player)
		if not shape_system.has_nearby_replicable_prop():
			failures.append("Nearby replicable prop was not detected")
		elif not shape_system.try_replicate_nearby_prop():
			failures.append("Nearby prop replica did not start")
		else:
			await get_tree().process_frame
			if not player.is_disguised():
				failures.append("Player did not enter map prop disguise state")
			var visual := player.get_node_or_null("3DGodotRobot/PropDisguise/ScenePropVisual")
			if not visual:
				failures.append("Map prop disguise visual scene was not attached")
			elif not (visual as Node3D).scale.is_equal_approx(Vector3.ONE * 4.8):
				failures.append("Map prop disguise did not copy the spawned prop scale")
			if prop.collision_radius > 0.9:
				failures.append("Map prop collision radius should stay controlled even when visuals are large")
			if not player_collision or not player_collision.shape is CylinderShape3D:
				failures.append("Map prop disguise should keep the player collider in prop mode")

			var disguise_node := player.get_node_or_null("3DGodotRobot/PropDisguise") as Node3D
			if disguise_node:
				var base_y: float = player._prop_disguise_base_position.y
				player._adjust_prop_disguise_height(0.24)
				await get_tree().process_frame
				if absf(disguise_node.position.y - (base_y + 0.24)) > 0.01:
					failures.append("Prop disguise height adjustment did not move the disguise node")
				player.clear_prop_disguise()
				await get_tree().process_frame
				player.apply_prop_disguise(prop.get_disguise_preset())
				await get_tree().process_frame
				disguise_node = player.get_node_or_null("3DGodotRobot/PropDisguise") as Node3D
				if disguise_node and absf(player._prop_disguise_height_offset) > 0.01:
					failures.append("Prop disguise height did not reset after clearing disguise")

		prop.queue_free()
		watermelon.queue_free()
		pineapple.queue_free()
		player.queue_free()
		floor.queue_free()
		wall.queue_free()

	if failures.is_empty():
		print("[ShapeCombatPocTest] PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("[ShapeCombatPocTest] " + failure)
		get_tree().quit(1)


func _find_collision_shape(node: Node) -> CollisionShape3D:
	if node is CollisionShape3D:
		return node as CollisionShape3D
	for child in node.get_children():
		var found := _find_collision_shape(child)
		if found:
			return found
	return null
