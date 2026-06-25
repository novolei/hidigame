@tool
extends RefCounted

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		var new_root: Node3D = Node3D.new()
		new_root.name = "AutoTurretHovlWeaponPreview"
		ctx.set_scene_root(new_root)
		root = new_root
		ctx.log("Created auto turret Hovl weapon preview scene")
	else:
		ctx.clear_children(root)
		ctx.log("Rebuilt existing preview scene")

	var root3d: Node3D = root as Node3D
	if root3d == null:
		ctx.error("Preview root is not Node3D")
		return

	var metal: StandardMaterial3D = _material(Color(0.18, 0.22, 0.26, 1.0), Color(0.0, 0.12, 0.16, 1.0), 0.45, false)
	var dark: StandardMaterial3D = _material(Color(0.035, 0.04, 0.045, 1.0), Color(0.0, 0.0, 0.0, 1.0), 0.7, false)
	var cyan: StandardMaterial3D = _material(Color(0.12, 0.95, 1.0, 0.56), Color(0.04, 0.9, 1.0, 1.0), 0.0, true)
	var orange: StandardMaterial3D = _material(Color(1.0, 0.45, 0.08, 0.72), Color(1.0, 0.34, 0.04, 1.0), 0.0, true)

	var rig: Node3D = Node3D.new()
	rig.name = "HoverAutoTurretWeaponRig"
	rig.position = Vector3(-1.1, 1.15, 0.0)
	root3d.add_child(rig)
	ctx.own(rig)

	var body: MeshInstance3D = MeshInstance3D.new()
	body.name = "HoverDroneBodySilhouette"
	var body_mesh: SphereMesh = SphereMesh.new()
	body_mesh.radius = 0.48
	body_mesh.height = 0.42
	body_mesh.radial_segments = 32
	body_mesh.rings = 12
	body.mesh = body_mesh
	body.scale = Vector3(1.35, 0.42, 0.72)
	body.material_override = metal
	rig.add_child(body)
	ctx.own(body)

	var weapon: Node3D = Node3D.new()
	weapon.name = "WeaponMount"
	weapon.position = Vector3(0.34, -0.02, -0.48)
	rig.add_child(weapon)
	ctx.own(weapon)

	var barrel: MeshInstance3D = MeshInstance3D.new()
	barrel.name = "AutoMachineGunBarrel"
	var barrel_mesh: CylinderMesh = CylinderMesh.new()
	barrel_mesh.top_radius = 0.07
	barrel_mesh.bottom_radius = 0.09
	barrel_mesh.height = 1.35
	barrel_mesh.radial_segments = 16
	barrel.mesh = barrel_mesh
	barrel.rotation_degrees.x = 90.0
	barrel.position = Vector3(0.0, 0.0, -0.54)
	barrel.material_override = dark
	weapon.add_child(barrel)
	ctx.own(barrel)

	var muzzle: MeshInstance3D = MeshInstance3D.new()
	muzzle.name = "MuzzleFlashPreview"
	var muzzle_mesh: SphereMesh = SphereMesh.new()
	muzzle_mesh.radius = 0.16
	muzzle_mesh.height = 0.32
	muzzle_mesh.radial_segments = 18
	muzzle_mesh.rings = 8
	muzzle.mesh = muzzle_mesh
	muzzle.position = Vector3(0.0, 0.0, -1.24)
	muzzle.scale = Vector3(1.0, 0.7, 1.45)
	muzzle.material_override = orange
	weapon.add_child(muzzle)
	ctx.own(muzzle)

	var tracer: MeshInstance3D = MeshInstance3D.new()
	tracer.name = "MachineGunEnergyTracerPreview"
	var tracer_mesh: CylinderMesh = CylinderMesh.new()
	tracer_mesh.top_radius = 0.028
	tracer_mesh.bottom_radius = 0.028
	tracer_mesh.height = 3.2
	tracer_mesh.radial_segments = 12
	tracer.mesh = tracer_mesh
	tracer.rotation_degrees.x = 90.0
	tracer.position = Vector3(0.0, 0.0, -2.9)
	tracer.material_override = cyan
	weapon.add_child(tracer)
	ctx.own(tracer)

	var hovl_script: Script = load("res://scripts/hovl_projectile_effect.gd") as Script
	if hovl_script == null:
		ctx.error("Unable to load Hovl projectile script")
		return
	var hovl: Node3D = hovl_script.new() as Node3D
	if hovl == null:
		ctx.error("Unable to instantiate Hovl projectile effect")
		return
	hovl.name = "AutoTurretHovlProjectileEnergyPreview"
	hovl.position = Vector3(0.0, 0.0, -1.42)
	hovl.scale = Vector3.ONE * 0.48
	weapon.add_child(hovl)
	ctx.own(hovl)
	if hovl.has_method("configure"):
		hovl.call("configure", "projectile_08_energy", 4.2, 0.16)
	_own_raw_children(ctx, hovl)

	var hit: MeshInstance3D = MeshInstance3D.new()
	hit.name = "EnergyHitMarkerPreview"
	var hit_mesh: SphereMesh = SphereMesh.new()
	hit_mesh.radius = 0.22
	hit_mesh.height = 0.44
	hit_mesh.radial_segments = 18
	hit_mesh.rings = 8
	hit.mesh = hit_mesh
	hit.position = Vector3(0.0, 0.0, -4.75)
	hit.scale = Vector3(1.0, 1.0, 0.35)
	hit.material_override = cyan
	weapon.add_child(hit)
	ctx.own(hit)

	var light: OmniLight3D = OmniLight3D.new()
	light.name = "EnergyMuzzleLight"
	light.position = Vector3(-0.7, 1.2, -1.7)
	light.light_color = Color(0.12, 0.92, 1.0, 1.0)
	light.light_energy = 3.2
	light.omni_range = 5.0
	root3d.add_child(light)
	ctx.own(light)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "PreviewKeyLight"
	sun.rotation_degrees = Vector3(-42.0, 38.0, 0.0)
	sun.light_energy = 1.1
	root3d.add_child(sun)
	ctx.own(sun)

	var camera: Camera3D = Camera3D.new()
	camera.name = "PreviewCamera"
	camera.current = true
	camera.fov = 45.0
	root3d.add_child(camera)
	ctx.own(camera)
	camera.look_at_from_position(Vector3(1.6, 2.35, 4.8), Vector3(-0.35, 0.9, -2.15), Vector3.UP)

	ctx.mark_modified()
	ctx.log("Preview uses projectile_08_energy on the auto turret weapon muzzle")

func _material(albedo: Color, emission: Color, roughness: float, transparent: bool) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = roughness
	mat.emission_enabled = true
	mat.emission = emission
	mat.emission_energy_multiplier = 2.4 if transparent else 0.55
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

func _own_raw_children(ctx, node: Node) -> void:
	for child in node.get_children():
		var child_node: Node = child as Node
		if child_node == null:
			continue
		ctx.own(child_node)
		_own_raw_children(ctx, child_node)
