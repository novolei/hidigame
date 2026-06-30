extends SceneTree
# Headless test for the redone AK47 bullet VFX (tracer + muzzle flash + impact).
# Run: godot --headless tests/bullet_vfx_test.gd

const TracerScript := preload("res://scripts/effects/bullet_tracer_effect.gd")
const ImpactScript := preload("res://scripts/effects/bullet_impact_effect.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_tracer_builds()
	await _test_impact_builds()
	_test_weapon_source_invariants()

	if failures.is_empty():
		print("[BulletVfxTest] PASS")
		quit(0)
	else:
		for failure: String in failures:
			push_error("[BulletVfxTest] " + failure)
		quit(1)


func _test_tracer_builds() -> void:
	var tracer = TracerScript.spawn(root, Vector3.ZERO, Vector3(0.0, 0.0, -10.0))
	_expect(tracer != null, "Bullet tracer should spawn")
	await process_frame

	if tracer != null and is_instance_valid(tracer):
		_expect(tracer.get_node_or_null("BeamCore") is MeshInstance3D, "Tracer should build a hot beam core")
		_expect(tracer.get_node_or_null("BeamGlow") != null, "Tracer should build an outer glow sheath")
		_expect(tracer.get_node_or_null("Core") != null, "Tracer should build a streaking bullet core")
		var flash := tracer.get_node_or_null("MuzzleFlash") as MeshInstance3D
		_expect(flash != null, "Tracer should build a muzzle flash")
		if flash and flash.material_override is StandardMaterial3D:
			var mat := flash.material_override as StandardMaterial3D
			_expect(mat.blend_mode == BaseMaterial3D.BLEND_MODE_ADD, "Muzzle flash should be additive")
			_expect(mat.billboard_mode == BaseMaterial3D.BILLBOARD_ENABLED, "Muzzle flash should face the camera")

	await create_timer(0.3).timeout
	_expect(not is_instance_valid(tracer), "Tracer should self-free quickly")


func _test_impact_builds() -> void:
	var impact = ImpactScript.spawn(root, Vector3(0.0, 1.0, 0.0), Vector3.UP, Vector3(0.0, -1.0, 0.0))
	_expect(impact != null, "Bullet impact should spawn")
	await process_frame
	await process_frame

	if impact != null and is_instance_valid(impact):
		_expect(impact.get_node_or_null("Flash") != null, "Impact should build a flash")
		_expect(impact.get_node_or_null("ShockRing") != null, "Impact should build a shockwave ring")
		_expect(impact.get_node_or_null("Sparks") is GPUParticles3D, "Impact should build a spark particle spray")
		_expect(impact.get_node_or_null("Smoke0") != null, "Impact should build drifting smoke")
		_expect(impact.get_node_or_null("Scorch") != null, "Impact should build a scorch mark")
		impact.queue_free()
	await process_frame


func _test_weapon_source_invariants() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/weapon_system.gd")
	_expect(src.contains("BulletTracerEffectScript.spawn"), "WeaponSystem should spawn the new tracer effect")
	_expect(src.contains("_broadcast_bullet_impact"), "WeaponSystem should broadcast surface impacts")
	_expect(src.contains("BulletImpactEffectScript.spawn"), "WeaponSystem should instantiate the impact effect")
	_expect(not src.contains("ImmediateMesh"), "Old ImmediateMesh tracer line should be removed")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
