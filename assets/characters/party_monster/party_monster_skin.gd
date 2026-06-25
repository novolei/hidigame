@tool
extends Node3D
class_name PartyMonsterSkin

const MODEL_SCENE_PATH := "res://assets/characters/party_monster/source/PartyMonsterRumblePBR/Mesh/DefaultCharacterMesh.fbx"
const MANIFEST_PATH := "res://assets/characters/party_monster/party_monster_manifest.json"
const AccessoryCatalog := preload("res://scripts/party_monster_accessory_catalog.gd")
const DEFAULT_PBR_SHADER_PATH := "res://assets/characters/party_monster/party_monster_default_pbr.gdshader"
const MASK_TINT_SHADER_PATH := "res://assets/characters/party_monster/party_monster_mask_tint.gdshader"
const DEFAULT_PBR_TEXTURES := {
	"01": {
		"albedo": "res://assets/characters/party_monster/source/PartyMonsterRumblePBR/Texture/DefaultPBR/DefaultPBR01_Albedo.png",
		"metallic_smoothness": "res://assets/characters/party_monster/source/PartyMonsterRumblePBR/Texture/DefaultPBR/DefaultPBR01_MetallicSmoothness.png",
		"ao": "res://assets/characters/party_monster/source/PartyMonsterRumblePBR/Texture/DefaultPBR/DefaultPBR01_AO.png",
	},
	"02": {
		"albedo": "res://assets/characters/party_monster/source/PartyMonsterRumblePBR/Texture/DefaultPBR/DefaultPBR02_Albedo.png",
		"metallic_smoothness": "res://assets/characters/party_monster/source/PartyMonsterRumblePBR/Texture/DefaultPBR/DefaultPBR02_MetallicSmoothness.png",
		"ao": "res://assets/characters/party_monster/source/PartyMonsterRumblePBR/Texture/DefaultPBR/DefaultPBR02_AO.png",
	},
}
const MASK_TINT_TEXTURES := {
	"01": {
		"albedo": "res://assets/characters/party_monster/source/PartyMonsterRumblePBR/Texture/MaskTintPBR/Albedo01.png",
		"sam": "res://assets/characters/party_monster/source/PartyMonsterRumblePBR/Texture/MaskTintPBR/SAM01.png",
		"mask_01": "res://assets/characters/party_monster/source/PartyMonsterRumblePBR/Texture/MaskTintPBR/Set01_Mask01.png",
		"mask_02": "res://assets/characters/party_monster/source/PartyMonsterRumblePBR/Texture/MaskTintPBR/Set01_Mask02.png",
		"mask_03": "res://assets/characters/party_monster/source/PartyMonsterRumblePBR/Texture/MaskTintPBR/Set01_Mask03.png",
	},
	"02": {
		"albedo": "res://assets/characters/party_monster/source/PartyMonsterRumblePBR/Texture/MaskTintPBR/Albedo02.png",
		"sam": "res://assets/characters/party_monster/source/PartyMonsterRumblePBR/Texture/MaskTintPBR/SAM02.png",
		"mask_01": "res://assets/characters/party_monster/source/PartyMonsterRumblePBR/Texture/MaskTintPBR/Set02_Mask01.png",
		"mask_02": "res://assets/characters/party_monster/source/PartyMonsterRumblePBR/Texture/MaskTintPBR/Set02_Mask02.png",
		"mask_03": "res://assets/characters/party_monster/source/PartyMonsterRumblePBR/Texture/MaskTintPBR/Set02_Mask03.png",
	},
}
const ANIMATION_ROOT := "res://assets/characters/party_monster/source/PartyMonsterRumblePBR/Animation"
const ANIMATION_SOURCES := {
	"attack_01": ANIMATION_ROOT + "/Attack01.fbx",
	"attack_02": ANIMATION_ROOT + "/Attack02.fbx",
	"attack_03": ANIMATION_ROOT + "/Attack03.fbx",
	"dance_01": ANIMATION_ROOT + "/Dance01.fbx",
	"dance_02": ANIMATION_ROOT + "/Dance02.fbx",
	"defense": ANIMATION_ROOT + "/Defense.fbx",
	"defense_hit": ANIMATION_ROOT + "/DefenseHit.fbx",
	"die_01": ANIMATION_ROOT + "/Die01.fbx",
	"die_01_recover": ANIMATION_ROOT + "/Die01Recover.fbx",
	"die_02": ANIMATION_ROOT + "/Die02.fbx",
	"dizzy": ANIMATION_ROOT + "/Dizzy.fbx",
	"anim_layer_run_01_bwd": ANIMATION_ROOT + "/ForAnimationLayer/Run01BWD_AnimLayer.fbx",
	"anim_layer_run_01_fwd": ANIMATION_ROOT + "/ForAnimationLayer/Run01FWD_AnimLayer.fbx",
	"anim_layer_run_01_left": ANIMATION_ROOT + "/ForAnimationLayer/Run01Left_AnimLayer.fbx",
	"anim_layer_run_01_right": ANIMATION_ROOT + "/ForAnimationLayer/Run01Right_AnimLayer.fbx",
	"anim_layer_run_02": ANIMATION_ROOT + "/ForAnimationLayer/Run02_AnimLayer.fbx",
	"drill_attack_01": ANIMATION_ROOT + "/ForDrill/Attack01_Drill.fbx",
	"drill_attack_02": ANIMATION_ROOT + "/ForDrill/Attack02_Drill.fbx",
	"drill_attack_03": ANIMATION_ROOT + "/ForDrill/Attack03_Drill.fbx",
	"drill_push": ANIMATION_ROOT + "/ForDrill/Push_Drill.fbx",
	"drill_slide": ANIMATION_ROOT + "/ForDrill/Slide_Drill.fbx",
	"drill_slide_rm": ANIMATION_ROOT + "/ForDrill/SlideRM_Drill.fbx",
	"saw_attack_01": ANIMATION_ROOT + "/ForSaw/Attack01_Saw.fbx",
	"saw_attack_02": ANIMATION_ROOT + "/ForSaw/Attack02_Saw.fbx",
	"saw_attack_03": ANIMATION_ROOT + "/ForSaw/Attack03_Saw.fbx",
	"saw_push": ANIMATION_ROOT + "/ForSaw/Push_Saw.fbx",
	"saw_slide": ANIMATION_ROOT + "/ForSaw/Slide_Saw.fbx",
	"saw_slide_rm": ANIMATION_ROOT + "/ForSaw/SlideRM_Saw.fbx",
	"shark_attack_01": ANIMATION_ROOT + "/ForShark/Attack01_Shark.fbx",
	"shark_attack_02": ANIMATION_ROOT + "/ForShark/Attack02_Shark.fbx",
	"shark_attack_03": ANIMATION_ROOT + "/ForShark/Attack03_Shark.fbx",
	"shark_push": ANIMATION_ROOT + "/ForShark/Push_Shark.fbx",
	"shark_slide": ANIMATION_ROOT + "/ForShark/Slide_Shark.fbx",
	"shark_slide_rm": ANIMATION_ROOT + "/ForShark/SlideRM_Shark.fbx",
	"get_hit": ANIMATION_ROOT + "/GetHit.fbx",
	"grab": ANIMATION_ROOT + "/Grab.fbx",
	"grab_idle": ANIMATION_ROOT + "/GrabIdle.fbx",
	"idle_01": ANIMATION_ROOT + "/Idle01.fbx",
	"idle_02": ANIMATION_ROOT + "/Idle02.fbx",
	"idle_03": ANIMATION_ROOT + "/Idle03.fbx",
	"jump_air": ANIMATION_ROOT + "/JumpAir.fbx",
	"jump_end": ANIMATION_ROOT + "/JumpEnd.fbx",
	"jump_one_take": ANIMATION_ROOT + "/JumpOneTake.fbx",
	"jump_start": ANIMATION_ROOT + "/JumpStart.fbx",
	"push": ANIMATION_ROOT + "/Push.fbx",
	"rm_run_01_bwd_anim_layer": ANIMATION_ROOT + "/RootMotion/Run01BWD_AnimLayer_RM.fbx",
	"rm_run_01_bwd": ANIMATION_ROOT + "/RootMotion/Run01BWD_RM.fbx",
	"rm_run_01_fwd_anim_layer": ANIMATION_ROOT + "/RootMotion/Run01FWD_AnimLayer_RM.fbx",
	"rm_run_01_fwd": ANIMATION_ROOT + "/RootMotion/Run01FWD_RM.fbx",
	"rm_run_01_left_anim_layer": ANIMATION_ROOT + "/RootMotion/Run01Left_AnimLayer_RM.fbx",
	"rm_run_01_left": ANIMATION_ROOT + "/RootMotion/Run01Left_RM.fbx",
	"rm_run_01_right_anim_layer": ANIMATION_ROOT + "/RootMotion/Run01Right_AnimLayer_RM.fbx",
	"rm_run_01_right": ANIMATION_ROOT + "/RootMotion/Run01Right_RM.fbx",
	"rm_run_02_anim_layer": ANIMATION_ROOT + "/RootMotion/Run02_AnimLayer_RM.fbx",
	"rm_run_02": ANIMATION_ROOT + "/RootMotion/Run02_RM.fbx",
	"rm_slide": ANIMATION_ROOT + "/RootMotion/Slide_RM.fbx",
	"rm_walk_bwd": ANIMATION_ROOT + "/RootMotion/WalkBWD_RM.fbx",
	"rm_walk_fwd": ANIMATION_ROOT + "/RootMotion/WalkFWD_RM.fbx",
	"rm_walk_left": ANIMATION_ROOT + "/RootMotion/WalkLeft_RM.fbx",
	"rm_walk_right": ANIMATION_ROOT + "/RootMotion/WalkRight_RM.fbx",
	"run_01_bwd": ANIMATION_ROOT + "/Run01BWD.fbx",
	"run_01_fwd": ANIMATION_ROOT + "/Run01FWD.fbx",
	"run_01_left": ANIMATION_ROOT + "/Run01Left.fbx",
	"run_01_right": ANIMATION_ROOT + "/Run01Right.fbx",
	"run_02": ANIMATION_ROOT + "/Run02.fbx",
	"slide": ANIMATION_ROOT + "/Slide.fbx",
	"throw": ANIMATION_ROOT + "/Throw.fbx",
	"victory_01": ANIMATION_ROOT + "/Victory01.fbx",
	"victory_02": ANIMATION_ROOT + "/Victory02.fbx",
	"walk_bwd": ANIMATION_ROOT + "/WalkBWD.fbx",
	"walk_fwd": ANIMATION_ROOT + "/WalkFWD.fbx",
	"walk_left": ANIMATION_ROOT + "/WalkLeft.fbx",
	"walk_right": ANIMATION_ROOT + "/WalkRight.fbx",
}
const ACTION_CLIPS := {
	"idle": ["idle_01", "idle_02", "idle_03"],
	"long_idle": ["dizzy"],
	"dizzy": ["dizzy"],
	"walk": ["walk_fwd"],
	"walk_forward": ["walk_fwd"],
	"walk_backward": ["walk_bwd"],
	"walk_left": ["walk_left"],
	"walk_right": ["walk_right"],
	"run": ["run_01_fwd", "run_02"],
	"run_forward": ["run_01_fwd", "run_02"],
	"run_backward": ["run_01_bwd"],
	"run_left": ["run_01_left"],
	"run_right": ["run_01_right"],
	"jump": ["jump_start", "jump_one_take"],
	"jump_start": ["jump_start"],
	"jump_air": ["jump_air"],
	"jump_end": ["jump_end"],
	"fall": ["jump_air"],
	"land": ["jump_end"],
	"attack": ["attack_01", "attack_02", "attack_03", "drill_attack_01", "drill_attack_02", "drill_attack_03", "saw_attack_01", "saw_attack_02", "saw_attack_03", "shark_attack_01", "shark_attack_02", "shark_attack_03"],
	"attack_drill": ["drill_attack_01", "drill_attack_02", "drill_attack_03"],
	"attack_saw": ["saw_attack_01", "saw_attack_02", "saw_attack_03"],
	"attack_shark": ["shark_attack_01", "shark_attack_02", "shark_attack_03"],
	"get_hit": ["get_hit", "defense_hit"],
	"hit": ["get_hit", "defense_hit"],
	"defense": ["defense"],
	"defense_hit": ["defense_hit"],
	"die": ["die_01", "die_02"],
	"die_recover": ["die_01_recover"],
	"dance": ["dance_01", "dance_02"],
	"victory": ["victory_01", "victory_02"],
	"grab": ["grab"],
	"grab_idle": ["grab_idle"],
	"push": ["push", "drill_push", "saw_push", "shark_push"],
	"slide": ["slide", "drill_slide", "saw_slide", "shark_slide"],
	"throw": ["throw"],
	"animation_layer_run": ["anim_layer_run_01_bwd", "anim_layer_run_01_fwd", "anim_layer_run_01_left", "anim_layer_run_01_right", "anim_layer_run_02"],
	"root_motion_run": ["rm_run_01_bwd", "rm_run_01_fwd", "rm_run_01_left", "rm_run_01_right", "rm_run_02", "rm_run_01_bwd_anim_layer", "rm_run_01_fwd_anim_layer", "rm_run_01_left_anim_layer", "rm_run_01_right_anim_layer", "rm_run_02_anim_layer"],
	"root_motion_walk": ["rm_walk_bwd", "rm_walk_fwd", "rm_walk_left", "rm_walk_right"],
	"root_motion_slide": ["rm_slide", "drill_slide_rm", "saw_slide_rm", "shark_slide_rm"],
}
const LOOPING_CLIPS := [
	"idle_01", "idle_02", "idle_03", "dizzy",
	"walk_fwd", "walk_bwd", "walk_left", "walk_right",
	"run_01_fwd", "run_01_bwd", "run_01_left", "run_01_right", "run_02",
	"anim_layer_run_01_bwd", "anim_layer_run_01_fwd", "anim_layer_run_01_left", "anim_layer_run_01_right", "anim_layer_run_02",
	"rm_run_01_bwd", "rm_run_01_fwd", "rm_run_01_left", "rm_run_01_right", "rm_run_02",
	"rm_run_01_bwd_anim_layer", "rm_run_01_fwd_anim_layer", "rm_run_01_left_anim_layer", "rm_run_01_right_anim_layer", "rm_run_02_anim_layer",
	"rm_walk_bwd", "rm_walk_fwd", "rm_walk_left", "rm_walk_right", "grab_idle",
]
const LOCOMOTION_ACTIONS := ["idle", "walk", "run", "move", "jump", "fall", "land"]
const PERFORMANCE_ACTIONS := ["dance", "victory"]
const LOCKED_REACTION_ACTIONS := ["attack", "attack_drill", "attack_saw", "attack_shark", "get_hit", "hit", "defense", "defense_hit", "die", "die_recover", "dance", "victory", "grab", "push", "slide", "throw"]
const LONG_IDLE_SECONDS := 8.0
const COMPATIBLE_ACTIONS := ["idle", "move", "walk", "run", "jump", "fall", "land", "attack", "attack_drill", "attack_saw", "attack_shark", "get_hit", "hit", "defense", "defense_hit", "die", "die_recover", "dance", "dizzy", "long_idle", "victory", "grab", "grab_idle", "push", "slide", "throw", "animation_layer_run", "root_motion_run", "root_motion_walk", "root_motion_slide"]
const VISIBLE_PREFIXES := [
	"MainBody",
	"Bodypart",
	"Tail",
	"Glove",
	"Eye",
	"Mouth",
	"Nose",
	"Hair",
	"Ear",
	"Hat",
	"Horn",
	"Comb",
	"Grass",
]
const PBR2_MESH_PREFIXES := ["Glove", "Ear", "Hair", "Hat", "Horn", "Comb", "Grass"]
const USE_SOFT_VINYL_NORMALS := false
const SOFT_NORMAL_MESH_PREFIXES := ["MainBody", "Bodypart", "Tail", "Glove", "Ear", "Hair", "Hat", "Horn", "Comb", "Grass", "Nose"]
const SOFT_NORMAL_KEY_SCALE := 350.0
const SOFT_NORMAL_MIN_FACE_AREA := 0.000001
const DEFAULT_VARIANT_ID := "party_monster_c01"

@export var character_model_id := DEFAULT_VARIANT_ID:
	set = set_character_model_id
@export_range(0.0, 1.0, 0.01) var walk_run_blending := 0.0:
	set = set_walk_run_blending

signal action_finished(action_name: String, clip_name: String)

static var _shared_animation_library: AnimationLibrary = null

var _model_root: Node3D
var _animation_player: AnimationPlayer
var _rng := RandomNumberGenerator.new()
var _current_action := ""
var _current_clip := ""
var _idle_seconds := 0.0
var _animation_paused := false
var _base_position := Vector3.ZERO
var _last_clip_by_action: Dictionary = {}
var _manifest: Dictionary = {}
var _variant: Dictionary = {}
var _visible_names := {}
var _accessory_loadout: Dictionary = {}
var _preview_accessory_id := ""
var _pbr_material_cache: Dictionary = {}
var _texture_cache: Dictionary = {}
var _smoothed_mesh_cache: Dictionary = {}


func _ready() -> void:
	_rng.randomize()
	set_process(true)
	_build_skin()
	idle()


func _process(delta: float) -> void:
	_update_idle_animation(delta)


func set_character_model_id(model_id: String) -> void:
	character_model_id = model_id.strip_edges().to_lower()
	if character_model_id.is_empty():
		character_model_id = DEFAULT_VARIANT_ID
	_load_variant()
	_apply_variant_visibility()
	_apply_pbr_materials()
	_reground_model_root()


func set_walk_run_blending(value: float) -> void:
	walk_run_blending = clampf(value, 0.0, 1.0)


func idle() -> void:
	_play_action("idle")


func move() -> void:
	_play_action("run" if walk_run_blending >= 0.65 else "walk")


func run() -> void:
	walk_run_blending = 1.0
	_play_action("run")


func jump() -> void:
	_play_action("jump")


func fall() -> void:
	_play_action("fall")


func land() -> void:
	_play_action("land", true)


func attack() -> void:
	_play_action("attack", true)


func get_hit() -> void:
	_play_action("get_hit", true)


func die() -> void:
	_play_action("die", true)


func dance() -> void:
	_play_action("dance", true)


func dizzy() -> void:
	_play_action("dizzy", true)


func victory() -> void:
	_play_action("victory", true)


func grab() -> void:
	_play_action("grab", true)


func grab_idle() -> void:
	_play_action("grab_idle", true)


func push() -> void:
	_play_action("push", true)


func slide() -> void:
	_play_action("slide", true)


func throw() -> void:
	_play_action("throw", true)


func play_action(action_name: String) -> bool:
	return _play_action(action_name, true)


func play_clip(clip_name: String) -> bool:
	return _play_clip(clip_name, _normalize_action(clip_name), 0.12, true)


func set_animation_paused(paused: bool) -> void:
	_animation_paused = paused
	if _animation_player:
		if paused and String(_animation_player.current_animation) != "":
			_animation_player.advance(0.0)
		_animation_player.speed_scale = 0.0 if paused else 1.0


func apply_pose_now(seconds: float = 0.0) -> void:
	_build_skin()
	if _animation_player == null:
		return
	if String(_animation_player.current_animation) == "":
		idle()
	_animation_player.advance(maxf(seconds, 0.0))
	_reground_model_root()


func set_accessory_loadout(loadout: Dictionary) -> void:
	_preview_accessory_id = ""
	_accessory_loadout = AccessoryCatalog.sanitize_loadout(loadout, character_model_id)
	_rebuild_visible_name_set()
	_apply_variant_visibility()
	_reground_model_root()


func get_accessory_loadout() -> Dictionary:
	return _accessory_loadout.duplicate(true)


func set_accessory_preview_id(accessory_id: String) -> void:
	_preview_accessory_id = AccessoryCatalog.normalize_accessory_id(accessory_id)
	if not _preview_accessory_id.is_empty():
		_accessory_loadout.clear()
	_rebuild_visible_name_set()
	_apply_variant_visibility()
	_reground_model_root()


func get_accessory_preview_id() -> String:
	return _preview_accessory_id


func available_actions() -> PackedStringArray:
	_build_skin()
	return PackedStringArray(COMPATIBLE_ACTIONS)


func available_animation_clips() -> PackedStringArray:
	_build_skin()
	var names := PackedStringArray()
	for clip_name in ANIMATION_SOURCES.keys():
		names.append(str(clip_name))
	names.sort()
	return names


func animation_source_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	for source_path in ANIMATION_SOURCES.values():
		paths.append(str(source_path))
	paths.sort()
	return paths


func action_animation_clips(action_name: String) -> PackedStringArray:
	var normalized := _normalize_action(action_name)
	var clips := PackedStringArray()
	var values: Array = ACTION_CLIPS.get(normalized, []) as Array
	for clip_name in values:
		clips.append(str(clip_name))
	return clips


func animation_source_count() -> int:
	return ANIMATION_SOURCES.size()


func get_current_animation_clip() -> String:
	return _current_clip


func get_current_animation_action() -> String:
	return _current_action


func get_current_animation_length() -> float:
	if not _animation_player or _current_clip.is_empty() or not _animation_player.has_animation(_current_clip):
		return 0.0
	var animation := _animation_player.get_animation(_current_clip)
	return animation.length if animation else 0.0


func has_action(action_name: String) -> bool:
	var normalized := _normalize_action(action_name)
	return COMPATIBLE_ACTIONS.has(normalized) or ACTION_CLIPS.has(normalized) or ANIMATION_SOURCES.has(normalized)


func _build_skin() -> void:
	if _model_root:
		return
	_load_variant()

	var model_scene := load(MODEL_SCENE_PATH)
	if not model_scene is PackedScene:
		push_warning("Party Monster model could not be loaded: %s" % MODEL_SCENE_PATH)
		return

	_model_root = (model_scene as PackedScene).instantiate() as Node3D
	if not _model_root:
		push_warning("Party Monster model did not instantiate as Node3D.")
		return

	_model_root.name = "PartyMonsterVisual"
	add_child(_model_root)
	if USE_SOFT_VINYL_NORMALS:
		_apply_soft_vinyl_mesh_normals()
	_apply_variant_visibility()
	_apply_pbr_materials()
	_reground_model_root()

	_animation_player = AnimationPlayer.new()
	_animation_player.name = "AnimationPlayer"
	add_child(_animation_player)
	_animation_player.root_node = _animation_player.get_path_to(_model_root)
	_import_animation_sources()
	_configure_animation_loops()
	if not _animation_player.animation_finished.is_connected(_on_animation_finished):
		_animation_player.animation_finished.connect(_on_animation_finished)


func _load_variant() -> void:
	if _manifest.is_empty():
		_manifest = _load_manifest()
	var variants: Array = _manifest.get("variants", []) as Array
	_variant = {}
	for entry in variants:
		var item: Dictionary = entry as Dictionary
		if str(item.get("id", "")) == character_model_id:
			_variant = item
			break
	if _variant.is_empty() and not variants.is_empty():
		_variant = variants[0] as Dictionary
		character_model_id = str(_variant.get("id", DEFAULT_VARIANT_ID))
	_rebuild_visible_name_set()


func _load_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		push_warning("Party Monster manifest is missing: %s" % MANIFEST_PATH)
		return {}
	var text := FileAccess.get_file_as_string(MANIFEST_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed as Dictionary
	push_warning("Party Monster manifest could not be parsed.")
	return {}


func _rebuild_visible_name_set() -> void:
	_visible_names.clear()
	if not _preview_accessory_id.is_empty():
		_add_preview_visible_names()
		return

	var active_nodes: Array = _variant.get("active_nodes", []) as Array
	var clean_loadout: Dictionary = AccessoryCatalog.sanitize_loadout(_accessory_loadout)
	var controlled_slots := {}
	for raw_slot in clean_loadout.keys():
		controlled_slots[str(raw_slot)] = true

	for raw_name in active_nodes:
		var node_name := str(raw_name)
		if node_name.is_empty():
			continue
		var slot := AccessoryCatalog.slot_for_node_name(node_name)
		if not slot.is_empty() and controlled_slots.has(slot):
			continue
		_add_visible_name(node_name)

	for raw_accessory_id in clean_loadout.values():
		var accessory: Dictionary = AccessoryCatalog.get_accessory(str(raw_accessory_id))
		var node_name := str(accessory.get("node_name", ""))
		if not node_name.is_empty():
			_add_visible_name(node_name)


func _add_preview_visible_names() -> void:
	var accessory: Dictionary = AccessoryCatalog.get_accessory(_preview_accessory_id)
	if accessory.is_empty():
		return
	var slot := str(accessory.get("slot", ""))
	if slot == AccessoryCatalog.SLOT_EYES:
		_add_visible_name("Eyes")
	elif slot == AccessoryCatalog.SLOT_MOUTH or slot == AccessoryCatalog.SLOT_NOSE:
		_add_visible_name("MouthandNoses")
	_add_visible_name(str(accessory.get("node_name", "")))


func _add_visible_name(node_name: String) -> void:
	if node_name.is_empty():
		return
	_visible_names[node_name] = true
	_visible_names[_canonical_part_name(node_name)] = true


func _apply_variant_visibility() -> void:
	if not _model_root:
		return
	_apply_variant_visibility_recursive(_model_root)


func _apply_variant_visibility_recursive(node: Node) -> void:
	var node_name := String(node.name)
	var should_control := _is_party_monster_part_name(node_name)
	if should_control and node is Node3D:
		var visible_value := _visible_names.has(node_name) or _visible_names.has(_canonical_part_name(node_name))
		(node as Node3D).visible = visible_value
	for child in node.get_children():
		_apply_variant_visibility_recursive(child)


func _apply_pbr_materials() -> void:
	if not _model_root:
		return
	_apply_pbr_materials_recursive(_model_root)


func _apply_pbr_materials_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh:
			var material: Material = _material_for_mesh_name(String(mesh_instance.name))
			if material:
				for surface in range(mesh_instance.mesh.get_surface_count()):
					mesh_instance.set_surface_override_material(surface, material)
	for child in node.get_children():
		_apply_pbr_materials_recursive(child)


func _apply_soft_vinyl_mesh_normals() -> void:
	if not _model_root:
		return
	_apply_soft_vinyl_mesh_normals_recursive(_model_root)


func _apply_soft_vinyl_mesh_normals_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh and _should_soften_mesh_normals(String(mesh_instance.name)):
			mesh_instance.mesh = _softened_mesh_for(mesh_instance)
	for child in node.get_children():
		_apply_soft_vinyl_mesh_normals_recursive(child)


func _should_soften_mesh_normals(mesh_name: String) -> bool:
	for prefix in SOFT_NORMAL_MESH_PREFIXES:
		if mesh_name.begins_with(prefix):
			return true
	return false


func _softened_mesh_for(mesh_instance: MeshInstance3D) -> Mesh:
	var source_mesh: Mesh = mesh_instance.mesh
	if source_mesh == null or source_mesh.get_blend_shape_count() > 0:
		return source_mesh
	var cache_key := "%s:%s:%s" % [String(source_mesh.resource_path), String(source_mesh.resource_name), String(mesh_instance.name)]
	if _smoothed_mesh_cache.has(cache_key):
		return _smoothed_mesh_cache[cache_key] as Mesh
	var smoothed_mesh := ArrayMesh.new()
	smoothed_mesh.resource_name = String(source_mesh.resource_name) + "SoftVinylNormals"
	for surface_index in range(source_mesh.get_surface_count()):
		var arrays: Array = source_mesh.surface_get_arrays(surface_index)
		var softened_arrays: Array = _soften_surface_arrays(arrays)
		smoothed_mesh.add_surface_from_arrays(source_mesh.surface_get_primitive_type(surface_index), softened_arrays)
		var material: Material = source_mesh.surface_get_material(surface_index)
		if material:
			smoothed_mesh.surface_set_material(surface_index, material)
	_smoothed_mesh_cache[cache_key] = smoothed_mesh
	return smoothed_mesh


func _soften_surface_arrays(arrays: Array) -> Array:
	var vertices := PackedVector3Array()
	if arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
		vertices = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	if vertices.is_empty():
		return arrays
	var indices := PackedInt32Array()
	if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
		indices = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	var normal_sum: Dictionary = {}
	var triangle_count: int = floori(float(indices.size()) / 3.0) if not indices.is_empty() else floori(float(vertices.size()) / 3.0)
	for triangle_index in range(triangle_count):
		var i0 := indices[triangle_index * 3] if not indices.is_empty() else triangle_index * 3
		var i1 := indices[(triangle_index * 3) + 1] if not indices.is_empty() else (triangle_index * 3) + 1
		var i2 := indices[(triangle_index * 3) + 2] if not indices.is_empty() else (triangle_index * 3) + 2
		if i0 < 0 or i1 < 0 or i2 < 0 or i0 >= vertices.size() or i1 >= vertices.size() or i2 >= vertices.size():
			continue
		var face_normal: Vector3 = (vertices[i1] - vertices[i0]).cross(vertices[i2] - vertices[i0])
		if face_normal.length_squared() <= SOFT_NORMAL_MIN_FACE_AREA:
			continue
		_accumulate_soft_normal(normal_sum, vertices[i0], face_normal)
		_accumulate_soft_normal(normal_sum, vertices[i1], face_normal)
		_accumulate_soft_normal(normal_sum, vertices[i2], face_normal)
	var softened_normals := PackedVector3Array()
	softened_normals.resize(vertices.size())
	for vertex_index in range(vertices.size()):
		var key := _soft_normal_key(vertices[vertex_index])
		var value: Variant = normal_sum.get(key, Vector3.UP)
		var normal := value as Vector3 if value is Vector3 else Vector3.UP
		if normal.length_squared() <= 0.000001:
			normal = Vector3.UP
		softened_normals[vertex_index] = normal.normalized()
	var softened_arrays: Array = arrays.duplicate()
	softened_arrays[Mesh.ARRAY_NORMAL] = softened_normals
	return softened_arrays


func _accumulate_soft_normal(normal_sum: Dictionary, vertex_position: Vector3, normal: Vector3) -> void:
	var key := _soft_normal_key(vertex_position)
	var value: Variant = normal_sum.get(key, Vector3.ZERO)
	var existing := value as Vector3 if value is Vector3 else Vector3.ZERO
	normal_sum[key] = existing + normal


func _soft_normal_key(vertex_position: Vector3) -> String:
	return "%d:%d:%d" % [roundi(vertex_position.x * SOFT_NORMAL_KEY_SCALE), roundi(vertex_position.y * SOFT_NORMAL_KEY_SCALE), roundi(vertex_position.z * SOFT_NORMAL_KEY_SCALE)]


func _material_for_mesh_name(mesh_name: String) -> Material:
	var pbr_slot := "02" if _is_pbr2_mesh_name(mesh_name) else "01"
	if character_model_id.begins_with("party_monster_masktint"):
		return _get_mask_tint_material(pbr_slot)
	return _get_default_pbr_material(pbr_slot)


func _is_pbr2_mesh_name(mesh_name: String) -> bool:
	for prefix in PBR2_MESH_PREFIXES:
		if mesh_name.begins_with(prefix):
			return true
	return false


func _get_default_pbr_material(pbr_slot: String) -> ShaderMaterial:
	var cache_key := "default_" + pbr_slot
	if _pbr_material_cache.has(cache_key):
		return _pbr_material_cache[cache_key] as ShaderMaterial
	var shader: Shader = load(DEFAULT_PBR_SHADER_PATH) as Shader
	if shader == null:
		push_warning("Party Monster default PBR shader could not load: %s" % DEFAULT_PBR_SHADER_PATH)
		return null
	var paths: Dictionary = DEFAULT_PBR_TEXTURES.get(pbr_slot, {}) as Dictionary
	var material := ShaderMaterial.new()
	material.resource_name = "PartyMonsterDefaultPBR" + pbr_slot
	material.resource_local_to_scene = true
	material.shader = shader
	material.set_shader_parameter("albedo_texture", _load_texture(str(paths.get("albedo", ""))))
	material.set_shader_parameter("metallic_smoothness_texture", _load_texture(str(paths.get("metallic_smoothness", ""))))
	material.set_shader_parameter("ao_texture", _load_texture(str(paths.get("ao", ""))))
	var accessory_slot := pbr_slot == "02"
	material.set_shader_parameter("metallic_strength", 0.10 if accessory_slot else 0.035)
	material.set_shader_parameter("occlusion_strength", 0.72 if accessory_slot else 0.68)
	material.set_shader_parameter("min_roughness", 0.30 if accessory_slot else 0.40)
	material.set_shader_parameter("max_roughness", 0.58 if accessory_slot else 0.68)
	material.set_shader_parameter("specular_level", 0.56 if accessory_slot else 0.46)
	material.set_shader_parameter("surface_tint", Color(1.0, 0.98, 0.94, 1.0))
	material.set_shader_parameter("pastel_blend", 0.06 if accessory_slot else 0.085)
	material.set_shader_parameter("saturation", 0.92 if accessory_slot else 0.86)
	material.set_shader_parameter("highlight_rolloff", 0.06 if accessory_slot else 0.08)
	material.set_shader_parameter("shadow_warmth", 0.025 if accessory_slot else 0.04)
	_pbr_material_cache[cache_key] = material
	return material


func _get_mask_tint_material(pbr_slot: String) -> ShaderMaterial:
	var cache_key := "mask_" + pbr_slot
	if _pbr_material_cache.has(cache_key):
		return _pbr_material_cache[cache_key] as ShaderMaterial
	var shader: Shader = load(MASK_TINT_SHADER_PATH) as Shader
	if shader == null:
		push_warning("Party Monster mask tint shader could not load: %s" % MASK_TINT_SHADER_PATH)
		return null
	var paths: Dictionary = MASK_TINT_TEXTURES.get(pbr_slot, {}) as Dictionary
	var material := ShaderMaterial.new()
	material.resource_name = "PartyMonsterMaskTintPBR" + pbr_slot
	material.resource_local_to_scene = true
	material.shader = shader
	material.set_shader_parameter("albedo_texture", _load_texture(str(paths.get("albedo", ""))))
	material.set_shader_parameter("sam_texture", _load_texture(str(paths.get("sam", ""))))
	material.set_shader_parameter("mask_01", _load_texture(str(paths.get("mask_01", ""))))
	material.set_shader_parameter("mask_02", _load_texture(str(paths.get("mask_02", ""))))
	material.set_shader_parameter("mask_03", _load_texture(str(paths.get("mask_03", ""))))
	var accessory_slot := pbr_slot == "02"
	material.set_shader_parameter("metallic_strength", 0.09 if accessory_slot else 0.03)
	material.set_shader_parameter("occlusion_strength", 0.72 if accessory_slot else 0.68)
	material.set_shader_parameter("min_roughness", 0.30 if accessory_slot else 0.40)
	material.set_shader_parameter("max_roughness", 0.60 if accessory_slot else 0.70)
	material.set_shader_parameter("specular_level", 0.56 if accessory_slot else 0.46)
	material.set_shader_parameter("surface_tint", Color(1.0, 0.98, 0.94, 1.0))
	material.set_shader_parameter("pastel_blend", 0.06 if accessory_slot else 0.08)
	material.set_shader_parameter("saturation", 0.92 if accessory_slot else 0.86)
	material.set_shader_parameter("highlight_rolloff", 0.06 if accessory_slot else 0.08)
	material.set_shader_parameter("shadow_warmth", 0.025 if accessory_slot else 0.04)
	_set_mask_tint_parameters(material, pbr_slot)
	_pbr_material_cache[cache_key] = material
	return material


func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _texture_cache.has(path):
		return _texture_cache[path] as Texture2D
	var texture: Texture2D = load(path) as Texture2D
	if texture == null:
		push_warning("Party Monster texture could not load: %s" % path)
	_texture_cache[path] = texture
	return texture


func _set_mask_tint_parameters(material: ShaderMaterial, pbr_slot: String) -> void:
	var colors: Array[Color] = _mask_tint_colors(pbr_slot)
	for index in range(colors.size()):
		var suffix: String = str(index + 1).pad_zeros(2)
		material.set_shader_parameter("color_" + suffix, colors[index])
		material.set_shader_parameter("color_" + suffix + "_power", 2.15)


func _mask_tint_colors(pbr_slot: String) -> Array[Color]:
	if pbr_slot == "02":
		return [
			Color(1.0, 0.66279554, 0.0, 1.0),
			Color(0.45162567, 0.30113026, 0.9528302, 1.0),
			Color(0.11439507, 0.46226418, 0.054512277, 1.0),
			Color(0.43870044, 0.5283019, 0.11213957, 1.0),
			Color(0.08050018, 0.32681012, 0.6320754, 1.0),
			Color(0.32527587, 0.1484959, 0.6698113, 1.0),
			Color(0.7264151, 0.34928828, 0.0, 1.0),
			Color(0.36030072, 0.5943396, 0.08130119, 1.0),
		]
	return [
		Color(1.0, 0.66279554, 0.0, 1.0),
		Color(0.45162567, 0.30113026, 0.9528302, 1.0),
		Color(0.31706855, 0.4716981, 0.0, 1.0),
		Color(0.43870044, 0.5283019, 0.11213957, 1.0),
		Color(0.08050018, 0.32681012, 0.6320754, 1.0),
		Color(0.53775966, 0.5660378, 0.07208972, 1.0),
		Color(0.7169812, 0.35370097, 0.01690993, 1.0),
		Color(0.36030072, 0.5943396, 0.08130119, 1.0),
	]


func _is_party_monster_part_name(node_name: String) -> bool:
	for prefix in VISIBLE_PREFIXES:
		if node_name.begins_with(prefix):
			return true
	return false


func _canonical_part_name(node_name: String) -> String:
	for prefix in VISIBLE_PREFIXES:
		if not node_name.begins_with(prefix):
			continue
		var suffix := node_name.substr(prefix.length())
		if suffix.is_valid_int():
			return prefix + str(int(suffix))
	return node_name


func _import_animation_sources() -> void:
	if not _animation_player:
		return
	if _shared_animation_library == null:
		_shared_animation_library = AnimationLibrary.new()
		for target_name in ANIMATION_SOURCES.keys():
			var source_path: String = ANIMATION_SOURCES[target_name]
			var animation := _load_first_animation(source_path)
			if animation:
				_shared_animation_library.add_animation(str(target_name), animation)
	if _animation_player.has_animation_library(""):
		_animation_player.remove_animation_library("")
	_animation_player.add_animation_library("", _shared_animation_library)


func _load_first_animation(path: String) -> Animation:
	var scene := load(path)
	if not scene is PackedScene:
		push_warning("Party Monster animation scene could not load: %s" % path)
		return null
	var node := (scene as PackedScene).instantiate()
	if not node:
		return null
	var player := _find_animation_player(node)
	var animation: Animation = null
	if player:
		var names := player.get_animation_list()
		if not names.is_empty():
			animation = player.get_animation(names[0]).duplicate(true)
	node.free()
	return animation


func _configure_animation_loops() -> void:
	if not _animation_player:
		return
	for raw_clip_name in LOOPING_CLIPS:
		var clip_name := str(raw_clip_name)
		if not _animation_player.has_animation(clip_name):
			continue
		var animation := _animation_player.get_animation(clip_name)
		if animation:
			animation.loop_mode = Animation.LOOP_LINEAR


func _update_idle_animation(delta: float) -> void:
	if _animation_paused or not visible or not _animation_player:
		return
	if _current_action == "idle":
		_idle_seconds += delta
		if _idle_seconds >= LONG_IDLE_SECONDS:
			_play_action("long_idle", true)
	elif _current_action != "long_idle":
		_idle_seconds = 0.0


func _play_action(action_name: String, force: bool = false) -> bool:
	_build_skin()
	if not _animation_player or _animation_paused:
		return false
	var normalized := _normalize_action(action_name)
	if _should_keep_current_action(normalized, force):
		return true
	if ANIMATION_SOURCES.has(normalized):
		return _play_clip(normalized, normalized, 0.12, force)
	var candidates: Array = ACTION_CLIPS.get(normalized, []) as Array
	if candidates.is_empty():
		return false
	var clip_name := _select_clip_for_action(normalized, candidates)
	return _play_clip(clip_name, normalized, 0.12, force)


func _play_clip(clip_name: String, action_name: String = "", blend: float = 0.12, force: bool = false) -> bool:
	_build_skin()
	if not _animation_player or _animation_paused:
		return false
	var normalized_clip := clip_name.strip_edges()
	if normalized_clip.is_empty() or not _animation_player.has_animation(normalized_clip):
		return false
	var normalized_action := _normalize_action(action_name if not action_name.is_empty() else normalized_clip)
	if not force and _current_clip == normalized_clip and _animation_player.is_playing():
		return true
	_current_action = normalized_action
	_current_clip = normalized_clip
	if normalized_action != "long_idle":
		_idle_seconds = 0.0
	_animation_player.play(normalized_clip, blend)
	_animation_player.advance(0.0)
	return true


func _select_clip_for_action(action_name: String, candidates: Array) -> String:
	var available: Array[String] = []
	for raw_clip_name in candidates:
		var clip_name := str(raw_clip_name)
		if _animation_player and _animation_player.has_animation(clip_name):
			available.append(clip_name)
	if available.is_empty():
		return ""
	var last_clip := str(_last_clip_by_action.get(action_name, ""))
	if available.size() > 1 and available.has(last_clip):
		available.erase(last_clip)
	var selected := available[_rng.randi_range(0, available.size() - 1)]
	_last_clip_by_action[action_name] = selected
	return selected


func _should_keep_current_action(incoming_action: String, force: bool) -> bool:
	if force or not _animation_player or not _animation_player.is_playing():
		return false
	if _current_action == "long_idle" and incoming_action == "idle":
		return true
	if PERFORMANCE_ACTIONS.has(_current_action):
		return incoming_action == "idle" or incoming_action == _current_action
	if LOCKED_REACTION_ACTIONS.has(_current_action) and LOCOMOTION_ACTIONS.has(incoming_action):
		return true
	return _current_action == incoming_action


func _normalize_action(action_name: String) -> String:
	var normalized := action_name.strip_edges().to_lower().replace("-", "_").replace(" ", "_")
	match normalized:
		"move":
			return "run" if walk_run_blending >= 0.65 else "walk"
		"gethit", "hurt", "damaged":
			return "get_hit"
		"death", "dead":
			return "die"
		"idle_long":
			return "long_idle"
		"jump_fall":
			return "fall"
		_:
			return normalized


func _on_animation_finished(_animation_name: StringName) -> void:
	var finished_action := _current_action
	var finished_clip := _current_clip
	action_finished.emit(finished_action, finished_clip)
	if finished_action == "die":
		return
	if LOCKED_REACTION_ACTIONS.has(finished_action) or finished_action == "long_idle":
		idle()


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null


func _reground_model_root() -> void:
	if not _model_root:
		return
	_model_root.position = Vector3.ZERO
	_ground_model_root()
	_base_position = _model_root.position


func _ground_model_root() -> void:
	if not _model_root:
		return
	var bounds := _calculate_bounds(_model_root)
	if bounds.size == Vector3.ZERO:
		return
	_model_root.position.y -= bounds.position.y


func _calculate_bounds(node: Node) -> AABB:
	return _calculate_bounds_with_transform(node, Transform3D.IDENTITY)


func _calculate_bounds_with_transform(node: Node, parent_transform: Transform3D) -> AABB:
	var local_transform := parent_transform
	if node is Node3D:
		local_transform = parent_transform * (node as Node3D).transform
	var initialized := false
	var bounds := AABB()
	if node is MeshInstance3D and (node as MeshInstance3D).mesh and (node as MeshInstance3D).visible:
		bounds = _transformed_aabb(local_transform, (node as MeshInstance3D).mesh.get_aabb())
		initialized = true
	for child in node.get_children():
		var child_bounds := _calculate_bounds_with_transform(child, local_transform)
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
