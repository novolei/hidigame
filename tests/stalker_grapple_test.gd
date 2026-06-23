extends Node3D

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var wall := StaticBody3D.new()
	wall.name = "GrappleWall"
	wall.position = Vector3(0.0, 1.2, -40.0)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5.0, 4.0, 0.5)
	collision.shape = box
	wall.add_child(collision)
	add_child(wall)

	var owner := CharacterBody3D.new()
	owner.name = "1"
	owner.set_multiplayer_authority(1)
	owner.position = Vector3.ZERO
	add_child(owner)

	var camera := Camera3D.new()
	camera.name = "ProbeCamera"
	camera.position = Vector3(0.0, 1.3, 0.0)
	owner.add_child(camera)
	camera.current = true

	var grapple := preload("res://scripts/stalker_grapple_system.gd").new()
	grapple.name = "StalkerGrappleSystem"
	owner.add_child(grapple)
	grapple.initialize(owner, camera)
	await get_tree().physics_frame

	var start_z := owner.global_position.z
	_expect(grapple.request_grapple(), "Stalker grapple should fire when a solid surface is under the crosshair")
	_expect(grapple.get_cooldown_remaining() > 44.0, "Stalker grapple should start a 45 second cooldown after a successful hit")
	_expect(not grapple.request_grapple(), "Stalker grapple should not fire again during cooldown")
	for i in range(24):
		grapple._physics_process(1.0 / 60.0)
	_expect(owner.global_position.z < start_z - 30.0, "Stalker grapple should pull the owner toward a long-range hit surface")
	grapple._process(45.1)
	_expect(is_zero_approx(grapple.get_cooldown_remaining()), "Stalker grapple cooldown should expire after 45 seconds")

	owner.queue_free()
	wall.queue_free()
	await get_tree().process_frame

	if failures.is_empty():
		print("[StalkerGrappleTest] PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("[StalkerGrappleTest] " + failure)
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
