extends Node3D
class_name StalkerGrappleSystem

const RANGE := 45.0
const COOLDOWN := 45.0
const PULL_DURATION := 0.28
const TARGET_BACKOFF := 0.95
const TARGET_UP_OFFSET := 0.18
const VISUAL_DURATION := 0.24
const HOOK_SCENE: PackedScene = preload("res://scenes/effects/stalker_grapple_hook.tscn")
const ROPE_SCENE: PackedScene = preload("res://scenes/effects/stalker_grapple_rope.tscn")

var stalker_owner: CharacterBody3D = null
var owner_camera: Camera3D = null
var cooldown_remaining := 0.0
var pulling := false

var _pull_elapsed := 0.0
var _pull_start := Vector3.ZERO
var _pull_target := Vector3.ZERO
var _hook_visual: Node3D = null
var _rope_visual: Node3D = null


func initialize(owner_node: CharacterBody3D, camera_node: Camera3D = null) -> void:
	stalker_owner = owner_node
	owner_camera = camera_node
	set_multiplayer_authority(stalker_owner.get_multiplayer_authority() if stalker_owner else 1)


func _process(delta: float) -> void:
	if cooldown_remaining > 0.0:
		cooldown_remaining = maxf(0.0, cooldown_remaining - delta)


func _physics_process(delta: float) -> void:
	if not pulling or not stalker_owner or not stalker_owner.is_multiplayer_authority():
		return
	_pull_elapsed = minf(PULL_DURATION, _pull_elapsed + delta)
	var ratio := clampf(_pull_elapsed / PULL_DURATION, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - ratio, 3.0)
	stalker_owner.global_position = _pull_start.lerp(_pull_target, eased)
	stalker_owner.velocity = Vector3.ZERO
	if ratio >= 1.0:
		pulling = false
		stalker_owner.global_position = _pull_target


func request_grapple() -> bool:
	if not stalker_owner or not stalker_owner.is_multiplayer_authority():
		return false
	if cooldown_remaining > 0.0 or pulling:
		return false
	var hit := _find_grapple_hit()
	if hit.is_empty():
		return false
	var hit_position: Vector3 = hit.get("position", Vector3.ZERO)
	var hit_normal: Vector3 = hit.get("normal", Vector3.UP)
	var origin := _ray_origin()
	var direction := (hit_position - origin).normalized()
	var target := hit_position - direction * TARGET_BACKOFF + hit_normal.normalized() * TARGET_UP_OFFSET
	_start_pull(target)
	if multiplayer.has_multiplayer_peer():
		_show_grapple_effect.rpc(origin, hit_position)
	else:
		_show_grapple_effect(origin, hit_position)
	cooldown_remaining = COOLDOWN
	return true


func get_cooldown_remaining() -> float:
	return cooldown_remaining


func is_grappling() -> bool:
	return pulling


func _find_grapple_hit() -> Dictionary:
	if not stalker_owner or not stalker_owner.get_world_3d():
		return {}
	var space := stalker_owner.get_world_3d().direct_space_state
	var origin := _ray_origin()
	var direction := _ray_direction()
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * RANGE)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [stalker_owner.get_rid()]
	query.collision_mask = 0x7FFFFFFF
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return {}
	var collider = hit.get("collider", null)
	if collider == stalker_owner:
		return {}
	return hit


func _start_pull(target: Vector3) -> void:
	pulling = true
	_pull_elapsed = 0.0
	_pull_start = stalker_owner.global_position
	_pull_target = target
	stalker_owner.velocity = Vector3.ZERO
	if stalker_owner.has_method("_play_body_jump"):
		stalker_owner.call("_play_body_jump", "Jump")


func _ray_origin() -> Vector3:
	if owner_camera:
		return owner_camera.global_position
	if stalker_owner:
		return stalker_owner.global_position + Vector3.UP * 1.35
	return global_position


func _ray_direction() -> Vector3:
	if owner_camera:
		return -owner_camera.global_transform.basis.z.normalized()
	if stalker_owner:
		return -stalker_owner.global_transform.basis.z.normalized()
	return -global_transform.basis.z.normalized()


@rpc("any_peer", "call_local", "reliable")
func _show_grapple_effect(origin: Vector3, target: Vector3) -> void:
	_clear_visuals()
	_hook_visual = HOOK_SCENE.instantiate()
	_rope_visual = ROPE_SCENE.instantiate()
	add_child(_hook_visual)
	add_child(_rope_visual)
	_hook_visual.global_position = target
	var dir := (target - origin).normalized()
	if dir.length_squared() > 0.001:
		_hook_visual.look_at(target + dir, Vector3.UP)
	_place_rope(origin, target)
	var tween := create_tween()
	tween.tween_interval(VISUAL_DURATION)
	tween.tween_callback(_clear_visuals)


func _place_rope(origin: Vector3, target: Vector3) -> void:
	if not _rope_visual:
		return
	var midpoint := origin.lerp(target, 0.5)
	var delta := target - origin
	var length := maxf(delta.length(), 0.01)
	_rope_visual.global_position = midpoint
	_rope_visual.scale = Vector3(1.0, length, 1.0)
	_rope_visual.look_at(target, Vector3.UP)
	_rope_visual.rotate_object_local(Vector3.RIGHT, PI * 0.5)


func _clear_visuals() -> void:
	if _hook_visual and is_instance_valid(_hook_visual):
		_hook_visual.queue_free()
	if _rope_visual and is_instance_valid(_rope_visual):
		_rope_visual.queue_free()
	_hook_visual = null
	_rope_visual = null
