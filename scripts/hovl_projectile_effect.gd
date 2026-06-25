extends Node3D
class_name HovlProjectileEffect

const TEXTURE_ROOT := "res://assets/effects/hovl_projectiles/textures/"
const DEFAULT_EFFECT_ID := "projectile_04_fire"

const PRESETS := {
	"projectile_01_nature": {
		"display_name": "Projectile 1 Nature",
		"source_prefab": "Projectile 1 nature.prefab",
		"hit_prefab": "Hit 1.prefab",
		"flash_prefab": "Flash 1.prefab",
		"source_refs": ["Trail59bcg.mat"],
		"textures": ["Trail59.png", "Leaf2.png", "Point12.png"],
		"color": Color(0.34, 1.0, 0.28, 0.72),
		"accent": Color(0.88, 1.0, 0.32, 1.0),
		"speed": 18.0,
		"motif": "leaf"
	},
	"projectile_02_blood": {
		"display_name": "Projectile 2 Blood",
		"source_prefab": "Projectile 2 bloow.prefab",
		"hit_prefab": "Hit 2.prefab",
		"flash_prefab": "Flash 2.prefab",
		"source_refs": ["Romb3bcg.mat"],
		"textures": ["Romb3.png", "BloodAnim2.png", "Trail22.png"],
		"color": Color(1.0, 0.08, 0.06, 0.78),
		"accent": Color(0.45, 0.0, 0.02, 1.0),
		"speed": 21.0,
		"motif": "shard"
	},
	"projectile_03_electro": {
		"display_name": "Projectile 3 Electro",
		"source_prefab": "Projectile 3 electro.prefab",
		"hit_prefab": "Hit 3.prefab",
		"flash_prefab": "Flash 3.prefab",
		"source_refs": ["Trail55bcg.mat"],
		"textures": ["Trail55.png", "HandPaintedLightning2.png", "Point5.png"],
		"color": Color(0.46, 0.68, 1.0, 0.78),
		"accent": Color(0.98, 1.0, 0.28, 1.0),
		"speed": 24.0,
		"motif": "bolt"
	},
	"projectile_04_fire": {
		"display_name": "Projectile 4 Fire",
		"source_prefab": "Projectile 4 fire.prefab",
		"hit_prefab": "Hit 4.prefab",
		"flash_prefab": "Flash 4.prefab",
		"source_refs": ["Snow4cg.mat", "Mask46bcg.mat", "Smoke21bcg.mat", "TrailPart4cg.mat", "Trail26bcg.mat"],
		"textures": ["TrailPart4.png", "Mask46.png", "Smoke21.png"],
		"color": Color(1.0, 0.34, 0.08, 0.82),
		"accent": Color(1.0, 0.9, 0.16, 1.0),
		"speed": 25.0,
		"motif": "flame"
	},
	"projectile_05_ice": {
		"display_name": "Projectile 5 Ice",
		"source_prefab": "Projectile 5 ice.prefab",
		"hit_prefab": "Hit 5.prefab",
		"flash_prefab": "Flash 5.prefab",
		"source_refs": ["Smoke21bcg.mat", "Point11cg.mat", "Snow4bcg.mat", "Snow5cg.mat", "Ice2lbg.mat", "HOVLCrystalPiese.fbx"],
		"textures": ["Ice2.png", "Snow5.png", "Point11.png"],
		"color": Color(0.42, 0.9, 1.0, 0.72),
		"accent": Color(0.9, 1.0, 1.0, 1.0),
		"speed": 20.0,
		"motif": "crystal"
	},
	"projectile_06_magic": {
		"display_name": "Projectile 6 Magic",
		"source_prefab": "Projectile 6 magic.prefab",
		"hit_prefab": "Hit 6.prefab",
		"flash_prefab": "Flash 6.prefab",
		"source_refs": ["Point11cg.mat", "Trail60bcg.mat"],
		"textures": ["Trail60.png", "Point11.png", "Gradient14.png"],
		"color": Color(0.78, 0.36, 1.0, 0.76),
		"accent": Color(0.25, 0.84, 1.0, 1.0),
		"speed": 18.0,
		"motif": "arcane"
	},
	"projectile_07_wind": {
		"display_name": "Projectile 7 Wind",
		"source_prefab": "Projectile 7 wind.prefab",
		"hit_prefab": "Hit 7.prefab",
		"flash_prefab": "Flash 7.prefab",
		"source_refs": ["Smoke3cg.mat", "Twist.fbx", "Noise35tcg.mat", "ShellQuad.fbx", "Romb3bcg.mat"],
		"textures": ["Smoke3.png", "Noise35t.png", "Romb3.png"],
		"color": Color(0.72, 1.0, 0.88, 0.48),
		"accent": Color(0.22, 0.95, 0.74, 1.0),
		"speed": 22.0,
		"motif": "spiral"
	},
	"projectile_08_energy": {
		"display_name": "Projectile 8 Energy",
		"source_prefab": "Projectile 8 energy.prefab",
		"hit_prefab": "Hit 8.prefab",
		"flash_prefab": "Flash 8.prefab",
		"source_refs": ["TwoSides18.mat", "Point11bcg.mat", "Smoke3cg.mat", "Noise35tbcg.mat", "Waves21cg2.mat", "QuadToCircle.fbx"],
		"textures": ["Waves21.png", "Noise35t.png", "Point11.png"],
		"color": Color(0.14, 0.96, 1.0, 0.7),
		"accent": Color(0.08, 0.34, 1.0, 1.0),
		"speed": 23.0,
		"motif": "wave"
	},
	"projectile_09_trails": {
		"display_name": "Projectile 9 Trails",
		"source_prefab": "Projectile 9 trails.prefab",
		"hit_prefab": "Hit 9.prefab",
		"flash_prefab": "Flash 9.prefab",
		"source_refs": ["Point11cg.mat", "Debris2bcg.mat", "Trail21cg2.mat"],
		"textures": ["Trail21.png", "TrailGradient21.png", "Debris2.png"],
		"color": Color(1.0, 0.78, 0.32, 0.72),
		"accent": Color(0.24, 0.92, 1.0, 1.0),
		"speed": 24.0,
		"motif": "comet"
	},
	"projectile_10_acid": {
		"display_name": "Projectile 10 Acid",
		"source_prefab": "Projectile 10 acid.prefab",
		"hit_prefab": "Hit 10.prefab",
		"flash_prefab": "Flash 10.prefab",
		"source_refs": ["Smoke21bcg.mat", "Smoke23bcg.mat"],
		"textures": ["Smoke21.png", "Smoke23.png", "Point5.png"],
		"color": Color(0.44, 1.0, 0.06, 0.7),
		"accent": Color(0.95, 1.0, 0.2, 1.0),
		"speed": 19.0,
		"motif": "acid"
	},
	"projectile_11_bubbles": {
		"display_name": "Projectile 11 Bubbles",
		"source_prefab": "Projectile 11 bubbles.prefab",
		"hit_prefab": "Hit 11.prefab",
		"flash_prefab": "Flash 11.prefab",
		"source_refs": ["Flare6cg.mat", "Circle96cg.mat"],
		"textures": ["Circle96.png", "Flare6.png", "Water2.png"],
		"color": Color(0.42, 0.86, 1.0, 0.54),
		"accent": Color(0.86, 1.0, 1.0, 1.0),
		"speed": 16.0,
		"motif": "bubbles"
	},
	"projectile_12_cuts": {
		"display_name": "Projectile 12 Cuts",
		"source_prefab": "Projectile 12 cuts.prefab",
		"hit_prefab": "Hit 12.prefab",
		"flash_prefab": "Flash 12.prefab",
		"source_refs": ["Trail59bcg.mat"],
		"textures": ["Trail59.png", "Line3.png", "Flash5.png"],
		"color": Color(1.0, 1.0, 0.9, 0.8),
		"accent": Color(0.42, 0.92, 1.0, 1.0),
		"speed": 27.0,
		"motif": "slash"
	},
	"projectile_13_lightning": {
		"display_name": "Projectile 13 Lightning",
		"source_prefab": "Projectile 13 lightning.prefab",
		"hit_prefab": "Hit 13.prefab",
		"flash_prefab": "Flash 13.prefab",
		"source_refs": ["Trail55bcg.mat"],
		"textures": ["HandPaintedLightning2.png", "Trail55.png", "Point19.png"],
		"color": Color(0.55, 0.62, 1.0, 0.78),
		"accent": Color(1.0, 1.0, 0.36, 1.0),
		"speed": 28.0,
		"motif": "bolt"
	},
	"projectile_14_water": {
		"display_name": "Projectile 14 Water",
		"source_prefab": "Projectile 14 water.prefab",
		"hit_prefab": "Hit 14.prefab",
		"flash_prefab": "Flash 14.prefab",
		"source_refs": ["Snow4cg.mat", "Water2cg.mat", "Circle96cg.mat"],
		"textures": ["Water2.png", "Circle96.png", "Snow4.png"],
		"color": Color(0.08, 0.62, 1.0, 0.64),
		"accent": Color(0.8, 1.0, 1.0, 1.0),
		"speed": 22.0,
		"motif": "wave"
	},
	"projectile_15_shuriken": {
		"display_name": "Projectile 15 Shuriken",
		"source_prefab": "Projectile 15 shuriken.prefab",
		"hit_prefab": "Hit 15.prefab",
		"flash_prefab": "",
		"source_refs": ["Circle98bcg.mat", "SmokeBCG2.mat", "CylinderFromCenter2.fbx", "Point12cg.mat", "Shuriken10bcg.mat"],
		"textures": ["Shuriken10.png", "Circle98.png", "Point12.png"],
		"color": Color(0.96, 0.96, 1.0, 0.82),
		"accent": Color(0.18, 0.56, 1.0, 1.0),
		"speed": 30.0,
		"motif": "shuriken"
	},
	"projectile_16_star": {
		"display_name": "Projectile 16 Star",
		"source_prefab": "Projectile 16 star.prefab",
		"hit_prefab": "Hit 16.prefab",
		"flash_prefab": "Flash 16.prefab",
		"source_refs": ["Flare2cg.mat", "Point12cg.mat", "Twist.fbx", "Trail61.mat", "BeamMesh.fbx"],
		"textures": ["Flare2.png", "Point12.png", "Trail61.png"],
		"color": Color(1.0, 0.86, 0.2, 0.78),
		"accent": Color(1.0, 1.0, 0.76, 1.0),
		"speed": 24.0,
		"motif": "star"
	},
	"projectile_17_heal": {
		"display_name": "Projectile 17 Heal",
		"source_prefab": "Projectile 17 heal.prefab",
		"hit_prefab": "Hit 17.prefab",
		"flash_prefab": "",
		"source_refs": ["Smoke3cg.mat", "Flash23cg.mat", "Fresnel2.mat", "Heart.fbx"],
		"textures": ["Flash23.png", "Heart.fbx", "Point11.png"],
		"color": Color(0.18, 1.0, 0.58, 0.72),
		"accent": Color(1.0, 0.28, 0.5, 1.0),
		"speed": 17.0,
		"motif": "heart"
	},
	"projectile_18_arrow": {
		"display_name": "Projectile 18 Arrow",
		"source_prefab": "Projectile 18 arrow.prefab",
		"hit_prefab": "Hit 18.prefab",
		"flash_prefab": "Flash 18.prefab",
		"source_refs": ["Arrow7bcg.mat", "BeamMesh.fbx"],
		"textures": ["Arrow8.png", "Trail48.png", "Line3.png"],
		"color": Color(1.0, 0.92, 0.42, 0.82),
		"accent": Color(1.0, 0.42, 0.12, 1.0),
		"speed": 31.0,
		"motif": "arrow"
	},
	"projectile_19_sun": {
		"display_name": "Projectile 19 Sun",
		"source_prefab": "Projectile 19 sun.prefab",
		"hit_prefab": "Hit 19.prefab",
		"flash_prefab": "",
		"source_refs": ["Snow4cg.mat", "Electricity1be.mat", "Smoke23bcg.mat", "FlashGroundCG.mat", "HPL2cg.mat", "Point5cg.mat", "Point19bcg2.mat", "Circle93bcg.mat"],
		"textures": ["Circle93.png", "HandPaintedLightning2.png", "Point19.png"],
		"color": Color(1.0, 0.72, 0.12, 0.82),
		"accent": Color(1.0, 1.0, 0.25, 1.0),
		"speed": 20.0,
		"motif": "sun"
	},
	"projectile_20_black": {
		"display_name": "Projectile 20 Black",
		"source_prefab": "Projectile 20 black.prefab",
		"hit_prefab": "Hit 20.prefab",
		"flash_prefab": "Flash 20.prefab",
		"source_refs": ["Trail55bcg.mat", "Smoke23bcg.mat", "TwoSides23.mat", "ShellQuad3.fbx", "Snow4bcg.mat", "Point11bcg.mat", "Point5cg.mat", "Waves21cg2.mat", "QuadToCircle.fbx"],
		"textures": ["Waves21.png", "Smoke23.png", "Point5.png"],
		"color": Color(0.2, 0.08, 0.34, 0.76),
		"accent": Color(0.78, 0.24, 1.0, 1.0),
		"speed": 19.0,
		"motif": "void"
	},
	"projectile_21_green": {
		"display_name": "Projectile 21 Green",
		"source_prefab": "Projectile 21 green.prefab",
		"hit_prefab": "Hit 21.prefab",
		"flash_prefab": "Flash 21.prefab",
		"source_refs": ["Trail48cg.mat", "Trail55bcg.mat", "Point19bcg2.mat", "TwoSides29.mat", "CylinderFromCenter2.fbx", "QuadToCircle2.fbx", "FlashGroundCG.mat"],
		"textures": ["Trail48.png", "Point19.png", "Circle41.png"],
		"color": Color(0.1, 1.0, 0.36, 0.74),
		"accent": Color(0.76, 1.0, 0.2, 1.0),
		"speed": 21.0,
		"motif": "ring"
	},
	"projectile_22_star_sky": {
		"display_name": "Projectile 22 Star Sky",
		"source_prefab": "Projectile 22 star sky.prefab",
		"hit_prefab": "Hit 22.prefab",
		"flash_prefab": "Flash 22.prefab",
		"source_refs": ["Flare6cg.mat", "Trail21cg2.mat", "Point11cg.mat", "Point12cg.mat"],
		"textures": ["Trail21.png", "Point12.png", "Flare6.png"],
		"color": Color(0.36, 0.28, 1.0, 0.74),
		"accent": Color(1.0, 0.92, 0.42, 1.0),
		"speed": 22.0,
		"motif": "stars"
	},
	"projectile_23_green_alt": {
		"display_name": "Projectile 23 Green Alt",
		"source_prefab": "Projectile 23 green.prefab",
		"hit_prefab": "Hit 23.prefab",
		"flash_prefab": "Flash 23.prefab",
		"source_refs": ["Circle38cg.mat", "Point11cg.mat", "Point19bcg2.mat", "Circle17cg.mat", "Point12cg.mat", "TrailShader3.mat"],
		"textures": ["Circle38.png", "Circle17.png", "Trail44.png"],
		"color": Color(0.0, 0.85, 0.32, 0.76),
		"accent": Color(0.36, 1.0, 0.82, 1.0),
		"speed": 22.0,
		"motif": "ring"
	},
	"projectile_24_honey": {
		"display_name": "Projectile 24 Honey",
		"source_prefab": "Projectile 24 honey.prefab",
		"hit_prefab": "Hit 24.prefab",
		"flash_prefab": "Flash 24.prefab",
		"source_refs": ["Flare6cg.mat", "TwoSides30.mat"],
		"textures": ["Gold2.png", "Noise41.png", "Flare6.png"],
		"color": Color(1.0, 0.62, 0.08, 0.82),
		"accent": Color(1.0, 0.92, 0.28, 1.0),
		"speed": 16.0,
		"motif": "honey"
	},
	"projectile_25_yellow": {
		"display_name": "Projectile 25 Yellow",
		"source_prefab": "Projectile 25 yellow.prefab",
		"hit_prefab": "Hit 25.prefab",
		"flash_prefab": "Flash 25.prefab",
		"source_refs": ["Trail48cg.mat"],
		"textures": ["Trail48.png", "Flash5.png", "Point5.png"],
		"color": Color(1.0, 0.86, 0.08, 0.8),
		"accent": Color(1.0, 1.0, 0.46, 1.0),
		"speed": 25.0,
		"motif": "spark"
	}
}

@export var effect_id: String = DEFAULT_EFFECT_ID
@export_range(0.5, 30.0, 0.1) var travel_distance := 6.0
@export_range(0.1, 3.0, 0.05) var travel_seconds := 0.65
@export var autoplay := true
@export var loop_preview := true
@export var spawn_hit_on_complete := true

var _visual_root: Node3D = null
var _motion_tween: Tween = null
var _spin_speed := 3.2


static func effect_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in PRESETS.keys():
		ids.append(String(key))
	ids.sort()
	return ids


static func has_effect(id: String) -> bool:
	return PRESETS.has(id)


static func preset_for(id: String) -> Dictionary:
	return PRESETS.get(id, PRESETS[DEFAULT_EFFECT_ID]).duplicate(true)


static func display_name_for(id: String) -> String:
	var preset: Dictionary = preset_for(id)
	return str(preset.get("display_name", id))


func _ready() -> void:
	rebuild()
	if autoplay:
		call_deferred("play_preview")


func _process(delta: float) -> void:
	if _visual_root:
		_visual_root.rotate_z(delta * _spin_speed)


func configure(next_effect_id: String, next_travel_distance: float = -1.0, next_travel_seconds: float = -1.0) -> void:
	effect_id = next_effect_id if PRESETS.has(next_effect_id) else DEFAULT_EFFECT_ID
	if next_travel_distance > 0.0:
		travel_distance = next_travel_distance
	if next_travel_seconds > 0.0:
		travel_seconds = next_travel_seconds
	rebuild()


func rebuild() -> void:
	_clear_generated_children()
	var preset: Dictionary = preset_for(effect_id)
	var color: Color = preset.get("color", Color.WHITE)
	var accent: Color = preset.get("accent", Color.WHITE)
	_spin_speed = _motif_spin_speed(str(preset.get("motif", "")))

	_visual_root = Node3D.new()
	_visual_root.name = "ProjectileVisuals"
	add_child(_visual_root)

	_add_trail(_visual_root, color, accent)
	_add_core(_visual_root, color, accent)
	_add_texture_cards(_visual_root, preset, color, accent)
	_add_motif_geometry(_visual_root, preset, color, accent)
	_add_light(_visual_root, accent)


func play_preview() -> void:
	if not _visual_root:
		rebuild()
	if _motion_tween:
		_motion_tween.kill()
	_visual_root.position = Vector3.ZERO
	_motion_tween = create_tween()
	_motion_tween.tween_property(_visual_root, "position", Vector3(0.0, 0.0, -travel_distance), travel_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if spawn_hit_on_complete:
		_motion_tween.tween_callback(_spawn_preview_hit)
	if loop_preview:
		_motion_tween.tween_interval(0.25)
		_motion_tween.tween_callback(play_preview)
	else:
		_motion_tween.tween_callback(queue_free)


func launch(start: Vector3, end: Vector3, free_on_finish: bool = true) -> void:
	var direction: Vector3 = end - start
	var length: float = direction.length()
	if length <= 0.001:
		return
	loop_preview = false
	spawn_hit_on_complete = true
	travel_distance = length
	global_position = start
	global_transform.basis = _basis_from_negative_z(direction.normalized())
	play_preview()
	if free_on_finish:
		var cleanup: Tween = create_tween()
		cleanup.tween_interval(travel_seconds + 1.1)
		cleanup.tween_callback(queue_free)


func source_summary() -> Dictionary:
	var preset: Dictionary = preset_for(effect_id)
	return {
		"id": effect_id,
		"display_name": preset.get("display_name", effect_id),
		"source_prefab": preset.get("source_prefab", ""),
		"hit_prefab": preset.get("hit_prefab", ""),
		"flash_prefab": preset.get("flash_prefab", ""),
		"source_refs": preset.get("source_refs", []),
		"textures": preset.get("textures", [])
	}


func _clear_generated_children() -> void:
	if _motion_tween:
		_motion_tween.kill()
		_motion_tween = null
	for child in get_children():
		if child.name.begins_with("Projectile") or child.name.begins_with("HitBurst"):
			child.queue_free()


func _add_trail(parent: Node3D, color: Color, accent: Color) -> void:
	var trail := MeshInstance3D.new()
	trail.name = "ProjectileTrail"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.12, 0.12, 1.8)
	trail.mesh = mesh
	trail.position.z = 0.85
	trail.material_override = _make_emissive_material(color, color.lerp(accent, 0.35), 2.1)
	parent.add_child(trail)


func _add_core(parent: Node3D, color: Color, accent: Color) -> void:
	var core := MeshInstance3D.new()
	core.name = "ProjectileCore"
	var sphere := SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	core.mesh = sphere
	core.material_override = _make_emissive_material(accent, accent, 3.2)
	parent.add_child(core)

	var halo := MeshInstance3D.new()
	halo.name = "ProjectileHalo"
	var halo_mesh := SphereMesh.new()
	halo_mesh.radius = 0.34
	halo_mesh.height = 0.68
	halo.mesh = halo_mesh
	halo.material_override = _make_emissive_material(Color(color.r, color.g, color.b, 0.22), accent, 1.7)
	parent.add_child(halo)


func _add_texture_cards(parent: Node3D, preset: Dictionary, color: Color, accent: Color) -> void:
	var textures: Array = preset.get("textures", [])
	var index := 0
	for texture_name_value in textures:
		var texture_name := str(texture_name_value)
		if not texture_name.ends_with(".png"):
			continue
		var tint: Color = accent if index == 0 else color
		var size: float = 0.54 + float(index) * 0.18
		var card := _make_texture_card("ProjectileTexture%d" % index, texture_name, size, tint, 2.6 - float(index) * 0.3)
		card.position = Vector3(0.0, 0.0, -0.12 + float(index) * 0.18)
		card.rotation.z = float(index) * PI * 0.28
		parent.add_child(card)
		index += 1


func _add_motif_geometry(parent: Node3D, preset: Dictionary, color: Color, accent: Color) -> void:
	var motif := str(preset.get("motif", "spark"))
	var count := 4
	if motif in ["bubbles", "stars", "spark"]:
		count = 7
	elif motif in ["arrow", "slash", "bolt"]:
		count = 3
	for index in range(count):
		var mote := MeshInstance3D.new()
		mote.name = "ProjectileMote%d" % index
		var sphere := SphereMesh.new()
		sphere.radius = 0.035 + float(index % 3) * 0.018
		sphere.height = sphere.radius * 2.0
		mote.mesh = sphere
		var phase: float = float(index) / float(max(count, 1))
		var radius: float = 0.22 + phase * 0.18
		mote.position = Vector3(cos(phase * TAU) * radius, sin(phase * TAU) * radius, -phase * 0.9)
		mote.material_override = _make_emissive_material(accent.lerp(color, phase), accent, 2.4)
		parent.add_child(mote)


func _add_light(parent: Node3D, color: Color) -> void:
	var light := OmniLight3D.new()
	light.name = "ProjectileLight"
	light.light_color = color
	light.light_energy = 1.35
	light.omni_range = 3.0
	light.shadow_enabled = false
	parent.add_child(light)


func _spawn_preview_hit() -> void:
	_spawn_hit_burst(Vector3(0.0, 0.0, -travel_distance))


func _spawn_hit_burst(local_position: Vector3) -> void:
	var preset: Dictionary = preset_for(effect_id)
	var color: Color = preset.get("color", Color.WHITE)
	var accent: Color = preset.get("accent", Color.WHITE)
	var hit := Node3D.new()
	hit.name = "HitBurst"
	hit.position = local_position
	add_child(hit)

	var flash := MeshInstance3D.new()
	flash.name = "HitBurstFlash"
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.22
	flash_mesh.height = 0.44
	flash.mesh = flash_mesh
	flash.material_override = _make_emissive_material(Color(accent.r, accent.g, accent.b, 0.42), accent, 3.0)
	hit.add_child(flash)

	var ring := _make_texture_card("HitBurstRing", str((preset.get("textures", ["Flash5.png"]) as Array)[0]), 1.35, color, 2.0)
	hit.add_child(ring)

	var light := OmniLight3D.new()
	light.name = "HitBurstLight"
	light.light_color = accent
	light.light_energy = 2.4
	light.omni_range = 4.0
	light.shadow_enabled = false
	hit.add_child(light)

	var tween := hit.create_tween()
	tween.parallel().tween_property(hit, "scale", Vector3.ONE * 2.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(light, "light_energy", 0.0, 0.45)
	tween.tween_callback(hit.queue_free)


func _make_texture_card(node_name: String, texture_name: String, size: float, tint: Color, emission_energy: float) -> MeshInstance3D:
	var card := MeshInstance3D.new()
	card.name = node_name
	var mesh := QuadMesh.new()
	mesh.size = Vector2(size, size)
	card.mesh = mesh
	var material := _make_emissive_material(tint, tint, emission_energy)
	var texture := load(TEXTURE_ROOT + texture_name)
	if texture is Texture2D:
		material.albedo_texture = texture
	card.material_override = material
	return card


func _make_emissive_material(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_local_to_scene = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = albedo
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	material.disable_receive_shadows = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _motif_spin_speed(motif: String) -> float:
	match motif:
		"shuriken", "slash", "bolt", "spark":
			return 7.0
		"wind", "spiral", "wave":
			return 4.8
		"bubbles", "heart", "honey":
			return 1.8
		_:
			return 3.2


func _basis_from_negative_z(direction: Vector3) -> Basis:
	var z := -direction.normalized()
	var x := Vector3.UP.cross(z)
	if x.length_squared() <= 0.0001:
		x = Vector3.RIGHT.cross(z)
	x = x.normalized()
	var y := z.cross(x).normalized()
	return Basis(x, y, z)
