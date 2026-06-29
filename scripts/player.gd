extends CharacterBody3D
class_name Character

# =============================================================================
# Character 鈥?Prop Hunt 鐜╁绫?v0.3.3)
#
# 瑙掕壊绯荤粺:
#   - 閫氳繃 Network.Role 鏋氫妇璇嗗埆瑙掕壊
#   - 鍑嗗闃舵:Hunter 琚攣瀹?涓嶈兘绉诲姩
#   - 鎴樻枟闃舵:鎵€鏈夎鑹叉寜鍚勮嚜閫昏緫杩愪綔
# =============================================================================

const WALK_SPEED = 5.4
const RUN_SPEED = 11.0
const NORMAL_SPEED = WALK_SPEED
const SPRINT_SPEED = RUN_SPEED
const JUMP_VELOCITY = 8.2
# Asymmetric gravity: fall faster than you rise so the jump feels snappy instead of a floaty
# "balloon" descent, without changing jump height or the rise. Applied when velocity.y < 0.
const FALL_GRAVITY_MULTIPLIER := 1.9
const JUMP_SUPPRESS_AFTER_STAND_UP_SECONDS := 0.35
const PlayerStandUpSystem := preload("res://scripts/player/player_stand_up_system.gd")
const GROUND_ACCELERATION := 20.0
const GROUND_DECELERATION := 24.0
const AIR_ACCELERATION := 7.0
const AIR_DECELERATION := 2.4
const TURN_INPUT_DEADZONE := 0.05
const SCULPT_FREE_FLY_ACCELERATION := 26.0
const SCULPT_FREE_FLY_DECELERATION := 30.0
const SCULPT_FREE_FLY_VERTICAL_SPEED_FACTOR := 0.72
const FOOTSTEP_WALK_INTERVAL := 0.48
const FOOTSTEP_SPRINT_INTERVAL := 0.24
const FOOTSTEP_MIN_SPEED := 0.6
const FOOTSTEP_WALK_AUDIBLE := false
const FOOTSTEP_WALK_VOLUME_DB := -18.0
const FOOTSTEP_SPRINT_VOLUME_DB := -10.5
const FOOTSTEP_WALK_PITCH_MIN := 0.88
const FOOTSTEP_WALK_PITCH_MAX := 0.98
const FOOTSTEP_SPRINT_PITCH_MIN := 1.02
const FOOTSTEP_SPRINT_PITCH_MAX := 1.12
const PROP_DISGUISE_HEIGHT_SPEED := 1.4
const PROP_DISGUISE_MIN_HEIGHT_OFFSET := -1.5
const PROP_DISGUISE_MAX_HEIGHT_OFFSET := 3.0
const PROP_DISGUISE_DROP_MIN_HEIGHT := 1.1
const PROP_DISGUISE_DROP_MAX_HEIGHT := 3.0
const PROP_COLLISION_MIN_RADIUS := 0.30
const PROP_COLLISION_MAX_RADIUS := 1.30
const PROP_COLLISION_MIN_HEIGHT := 0.42
const PROP_COLLISION_MAX_HEIGHT := 3.20
const PROP_PUSH_CONTACT_PADDING := 0.24
const PROP_PUSH_FORWARD_REACH := 0.34
const PROP_PUSH_QUERY_MAX_RESULTS := 8
const PROP_PUSH_QUERY_RADIUS_PADDING := 0.08
const PROP_PUSH_QUERY_INTERVAL_MSEC := 50
const PROP_PUSH_ASSIST_MIN_SPEED := 2.6
const WORLD_COLLISION_MASK := 2
const HOLOGRAM_FLAG_ACTION := "place_hologram_flag"
const MAP_PING_RANGE := 220.0  # middle-click world ping reach
const HOLOGRAM_FLAG_PLACEMENT_RANGE := 14.0
const HOLOGRAM_FLAG_FALLBACK_DISTANCE := 4.5
const HOLOGRAM_FLAG_GROUND_RAY_UP := 2.0
const HOLOGRAM_FLAG_GROUND_RAY_DOWN := 10.0
const UNSTUCK_ACTION := "unstuck"
const UNSTUCK_RAY_UP := 12.0
const UNSTUCK_RAY_DOWN := 36.0
const UNSTUCK_CLEARANCE := 0.12
const UNSTUCK_OVERHEAD_CHECK := 1.8
const PROP_DISGUISE_GROUND_SNAP_UP := 2.5
const PROP_DISGUISE_GROUND_SNAP_DOWN := 8.0
const HUNTER_PROP_SENSE_GLOW_RANGE := 4.8
const HUNTER_PROP_SENSE_AUDIO_RANGE := 32.0
const HUNTER_PROP_SENSE_BEEP_SAMPLE_RATE := 22050
const HUNTER_PROP_SENSE_BEEP_SECONDS := 0.24
const HUNTER_PROP_SENSE_PING_TOP_EXTRA := 0.95
const HUNTER_PROP_SENSE_PING_MIN_HEIGHT := 2.4
const HUNTER_PROP_SENSE_PING_RING_SPACING := 0.46
const HUNTER_PROP_SENSE_PING_MIN_RINGS := 4
const HUNTER_PROP_SENSE_PING_MAX_RINGS := 9
const HUNTER_PROP_SENSE_PING_EXPANSION_MULTIPLIER := 2.5
const PARTY_MONSTER_BOUNTY_GLOW_RANGE := 5.8
const PARTY_MONSTER_BOUNTY_LABEL_MIN_HEIGHT := 2.7
const LOCAL_FEEDBACK_TRANSFORM_INTERVAL := 0.08
const PROP_TOMBSTONE_SCENE_PATH := "res://assets/hunter_auto_turret/tombstone/hunter_auto_turret_tombstone.fbx"
const DEATH_DISSOLVE_SECONDS := 2.4
const DEATH_DISSOLVE_NOISE_SCALE := 1.65
const DEATH_DISSOLVE_EDGE_WIDTH := 0.055
const DEATH_DISSOLVE_VISUAL_CULL_RANGE := 42.0
const DEATH_DISSOLVE_VISUAL_CULL_MARGIN := 6.0
const PARTY_MONSTER_TRIP_MIN_SPEED := RUN_SPEED * 0.55
const PARTY_MONSTER_TRIP_COOLDOWN_SECONDS := 2.6
const PARTY_MONSTER_TRIP_REACTION_LOCK_SECONDS := 0.95
const PARTY_MONSTER_TRIP_FALLBACK_LOCK_SECONDS := 1.25
const PARTY_MONSTER_TRIP_MIN_SURFACE_HEIGHT_RATIO := 0.5
const PARTY_MONSTER_TRIP_HEIGHT_MARGIN := 0.08
const PARTY_MONSTER_TRIP_UNKNOWN_TOP_Y := -1000000.0
const PARTY_MONSTER_TRIP_COLLISION_NORMAL_MAX_Y := 0.55
const PARTY_MONSTER_TRIP_MIN_COLLISION_OPPOSITION := 0.20
const PARTY_MONSTER_TRIP_GROUND_CONTACT_HEIGHT := 2.25
const PARTY_MONSTER_TRIP_SENSOR_FORWARD_OFFSET := 0.48
const PARTY_MONSTER_TRIP_SENSOR_DISTANCE := 1.25
const PARTY_MONSTER_TRIP_REWIND_RADIUS := 2.4
# Number of distinct knockdown poses (trip_01 face-down / trip_02 on-back). The server picks one
# and broadcasts the index so every peer plays the SAME pose; without this each side randomizes
# independently and the downed player and observers can see different poses.
const PARTY_MONSTER_TRIP_VARIANT_COUNT := 2
const DEAD_FREE_CAM_NORMAL_SPEED := 8.0
const DEAD_FREE_CAM_SPRINT_SPEED := 18.0
const DEAD_FREE_CAM_ACCELERATION := 32.0
const DEAD_FREE_CAM_DECELERATION := 42.0
const DEAD_FREE_CAM_VERTICAL_SPEED_FACTOR := 0.78
const DEAD_FREE_CAM_SPRING_LENGTH := 0.25
const DEAD_FREE_CAM_FOV := 72.0
const REMOTE_VISUAL_SAMPLE_MAX_AGE_MSEC := 260
const REMOTE_MOVE_SPEED_THRESHOLD := 0.45
const REMOTE_RUN_SPEED_THRESHOLD := RUN_SPEED * 0.55
const REMOTE_VERTICAL_ACTION_SPEED := 0.75
const REMOTE_MOVE_HOLD_SECONDS := 0.18
# Low-pass rate for the velocity that drives the remote animation FALLBACK path; damps
# per-sample network noise so the action (idle/walk/run/jump/fall) does not flicker.
const REMOTE_VISUAL_VELOCITY_SMOOTH_RATE := 16.0
# After an authoritative teleport (e.g. prep-room release), drive movement directly for a
# short window instead of via netfox rollback. The rollback history still holds the stale
# pre-teleport position; re-simulating from it fights the teleport and the player jitters /
# loops a jump for peers. During this window legacy movement settles the body and the motor
# keeps re-capturing the settled position into the rollback history, so prediction resumes clean.
const ROLLBACK_TELEPORT_SETTLE_SECONDS := 0.4
const REMOTE_VISUAL_PROCESS_INTERVAL := 1.0 / 30.0
const REMOTE_WALK_BLEND := 0.25
const REMOTE_RUN_BLEND := 1.0
const NETWORK_VISUAL_STATE_MAX_AGE_MSEC := 360
const NETWORK_VISUAL_YAW_LERP_SPEED := 36.0
const NETWORK_VISUAL_ACTION_MAX_LENGTH := 32
const NETWORK_VISUAL_LOCOMOTION_ACTIONS := ["idle", "long_idle", "move", "walk", "run", "jump", "fall", "land"]
const NETWORK_VISUAL_RECOVERY_ACTIONS := ["idle", "move", "walk", "run"]
const NETWORK_VISUAL_INTERRUPTABLE_ACTIONS := ["jump", "fall", "land", "trip", "get_hit", "hit", "die_recover"]
# Discrete transitions that MUST reach every peer even if the throttled/unreliable visual
# state stream drops a packet — also published over the reliable action bus (deduped on apply),
# so falling/landing/dizzy/trip/getup are never lost to throttling.
const NETWORK_VISUAL_RELIABLE_ACTIONS := ["fall", "land", "trip", "dizzy", "long_idle", "get_hit", "hit", "getup", "die"]
# Idle variants (the long-idle "dizzy" pose) read as locomotion but must still be exported and
# played on peers — they were being collapsed to plain idle so others never saw the dizzy anim.
const NETWORK_VISUAL_IDLE_VARIANT_ACTIONS := ["long_idle", "dizzy"]
const DEATH_DISSOLVE_SHADER := preload("res://shaders/death_dissolve.gdshader")
const CardDecoyTargetScript := preload("res://scripts/card_decoy_target.gd")
const PlayerCardEffectControllerScript := preload("res://scripts/player_card_effect_controller.gd")
const RemoteMotionSamplerScript := preload("res://scripts/remote_motion_sampler.gd")
const PlayerInputStateScript := preload("res://scripts/network/player_input_state.gd")
const PlayerActionBusScript := preload("res://scripts/network/player_action_bus.gd")
const PartyMonsterAccessoryCatalogScript := preload("res://scripts/party_monster_accessory_catalog.gd")
const PROP_TOMBSTONE_TARGET_HEIGHT := 1.18
const CAMOUFLAGE_PAINT_LAYER_SHADER := preload("res://shaders/camouflage_paint_layer.gdshader")
const CHAMELEON_GPU_PBR_OVERLAY_SHADER := preload("res://shaders/chameleon_gpu_pbr_overlay.gdshader")
const CAMOUFLAGE_GPU_OVERLAY_LAYER := 20
const CAMOUFLAGE_GPU_ATLAS_SIZE := 2048
const CAMOUFLAGE_GPU_DEFAULT_LIGHTMAP_HINT := Vector2i(512, 512)
const CAMOUFLAGE_GPU_BRUSH_TIME := 0.035
const CAMOUFLAGE_GPU_MAX_QUEUED_STROKES := 96
const CAMOUFLAGE_PAINT_RPC_MAX_STAMPS := 16
const CAMOUFLAGE_PAINT_RPC_MAX_BYTES := 4096
const CAMOUFLAGE_PAINT_RPC_BASE_BYTES := 120
const CAMOUFLAGE_PAINT_RPC_BYTES_PER_STAMP := 28
const CAMOUFLAGE_PAINT_RPC_BYTES_PER_WORLD_POSITION := 24
const CAMOUFLAGE_PAINT_RPC_BYTES_PER_CLIP_UV := 8
const CAMOUFLAGE_PAINT_RPC_BYTES_PER_FOOTPRINT_VALUE := 4
const CAMOUFLAGE_PAINT_APPLIED_EVENT_LIMIT := 256
const CAMOUFLAGE_PAINT_EVENT_LOG_LIMIT := 384
const STALKER_VISIBILITY_SYNC_MIN_DELTA := 0.015
const ENVIRONMENT_PROP_PAINT_SYNC_SIZE := 512
const ENVIRONMENT_PROP_PAINT_MAX_SURFACES := 16
const ENVIRONMENT_PROP_PAINT_MAX_BYTES_PER_SURFACE := 524288
const ENVIRONMENT_PROP_PAINT_MAX_TOTAL_BYTES := 2097152
const SCULPT_TOOL_ADD := "add"
const SCULPT_TOOL_REMOVE := "remove"
const SCULPT_TOOL_SMOOTH := "smooth"
const SCULPT_TOOL_STRETCH := "stretch"
const SCULPT_TOOL_FLATTEN := "flatten"
const SCULPT_TOOL_SMART := "smart"
const SCULPT_MIN_WORLD_RADIUS := 0.08
const SCULPT_MAX_WORLD_RADIUS := 0.46
const SCULPT_COUNTERPLAY_MAX_WORLD_RADIUS := SCULPT_MAX_WORLD_RADIUS * 1.6
const SCULPT_DEFAULT_WORLD_RADIUS := 0.22
const SKIN_PERFORMANCE_ACTIONS := ["dance", "victory"]
const SKIN_PERFORMANCE_MUSIC_PATHS: PackedStringArray = [
	"res://assets/audio/performance/performance_victory_folk.mp3",
	"res://assets/audio/performance/performance_victory_strings.mp3",
	"res://assets/audio/performance/performance_victory_8bit.mp3",
]
const SKIN_PERFORMANCE_MUSIC_VOLUME_DB := -7.0
const SKIN_PERFORMANCE_CAMERA_RETURN_DELAY := 1.0
const SKIN_PERFORMANCE_CAMERA_FRONT_YAW_OFFSET := 0.0
const SKIN_PERFORMANCE_CAMERA_PITCH := deg_to_rad(-3.0)
const SKIN_PERFORMANCE_CAMERA_SPRING_LENGTH := 5.2
const SKIN_PERFORMANCE_CAMERA_FOV := 58.0
const SKIN_PERFORMANCE_DISCO_LIGHT_COUNT := 3
const SKIN_PERFORMANCE_DISCO_LIGHT_RANGE := 4.8
const SKIN_PERFORMANCE_DISCO_LIGHT_ENERGY := 4.2
const SKIN_PERFORMANCE_INPUT_START_BLOCK_SECONDS := 0.35
const SKIN_PERFORMANCE_WHEEL_CHARGE_STEP := 0.34
const SKIN_PERFORMANCE_WHEEL_OPPOSITE_DRAIN := 0.18
const SKIN_PERFORMANCE_WHEEL_DECAY_PER_SECOND := 0.85
const SKIN_PERFORMANCE_WHEEL_BAR_IDLE_SECONDS := 0.85
const SKIN_PERFORMANCE_WHEEL_BAR_SEGMENT_HEIGHT := 0.38
const SKIN_PERFORMANCE_CONFETTI_COUNT := 32
const SKIN_PERFORMANCE_CONFETTI_COLORS := [
	Color(1.0, 0.18, 0.36, 1.0),
	Color(0.20, 0.76, 1.0, 1.0),
	Color(1.0, 0.86, 0.18, 1.0),
	Color(0.42, 1.0, 0.46, 1.0),
	Color(0.94, 0.35, 1.0, 1.0),
]

enum SkinColor { BLUE, YELLOW, GREEN, RED }

# -----------------------------------------------------------------------------
# 瑙掕壊(浠?Network 鍚屾杩囨潵)
# -----------------------------------------------------------------------------
var role: int = Network.Role.NONE

# 鍑嗗闃舵閿佸畾鐘舵€?server 鎺у埗)
var prep_phase_locked: bool = false
var match_intro_locked: bool = false
# Set by the debug console while it owns the keyboard. Pure input gate (no camera
# / skin side effects) so toggling the console restores control cleanly.
var console_input_locked: bool = false

@onready var nickname: Label3D = $PlayerNick/Nickname

var player_inventory: PlayerInventory

@export_category("Objects")
@export var _body: Node3D = null
@export var _spring_arm_offset: Node3D = null

@export_category("Skin Colors")
@export var blue_texture : CompressedTexture2D
@export var yellow_texture : CompressedTexture2D
@export var green_texture : CompressedTexture2D
@export var red_texture : CompressedTexture2D

@onready var _bottom_mesh: MeshInstance3D = get_node("3DGodotRobot/RobotArmature/Skeleton3D/Bottom")
@onready var _chest_mesh: MeshInstance3D = get_node("3DGodotRobot/RobotArmature/Skeleton3D/Chest")
@onready var _face_mesh: MeshInstance3D = get_node("3DGodotRobot/RobotArmature/Skeleton3D/Face")
@onready var _limbs_head_mesh: MeshInstance3D = get_node("3DGodotRobot/RobotArmature/Skeleton3D/Llimbs and head")
@onready var _collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")

var character_model_id := CharacterSkinCatalog.DEFAULT_ID
var _active_skin_node: Node3D = null
var _robot_visual_root: Node3D = null
var _robot_animation_player: AnimationPlayer = null
var _prop_disguise_node: Node3D = null
var _prop_disguise_tween: Tween = null
var _is_prop_disguised := false
var _current_disguise_name := ""
var _prop_disguise_is_q_scene_replica := false
var _prop_disguise_base_position := Vector3.ZERO
var _prop_disguise_height_offset := 0.0
var _prop_death_visual_hidden := false
var _is_dead := false
var _death_effect_played := false
var _dead_free_camera_active := false
var _death_dissolve_tween: Tween = null
var _death_dissolve_root: Node3D = null
var _death_dissolve_material: ShaderMaterial = null
var _party_monster_trip_cooldown := 0.0
var _party_monster_trip_reaction_lock_remaining := 0.0
var _party_monster_trip_action_locked := false
var _stand_up_system := PlayerStandUpSystem.new()
var _jump_suppress_remaining := 0.0
var _dead_weapon_visual_hidden := false
var _jump_audio: AudioStreamPlayer3D = null
var _land_audio: AudioStreamPlayer3D = null
var _step_audio: AudioStreamPlayer3D = null
var _disguise_audio: AudioStreamPlayer3D = null
var _step_sounds: Array[AudioStream] = []
var _footstep_timer: float = 0.0
var _last_footstep_sprinting: bool = false
var _default_collision_shape: Shape3D = null
var _default_collision_transform: Transform3D = Transform3D.IDENTITY
var _remote_visual_process_elapsed: float = 0.0
var _rollback_sync_state_properties_cache: Array[String] = []
var _rollback_sync_input_properties_cache: Array[String] = []
var _rollback_sync_policy_cached: bool = false
var _rollback_sync_runtime_enabled: bool = true

var _current_speed: float
var _respawn_point: Vector3 = Vector3(0, 5, 0)
var _last_safe_ground_position: Vector3 = Vector3.ZERO
var _last_safe_ground_valid: bool = false
var _next_prop_push_query_msec: int = 0
var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))

var can_double_jump: bool = true
var has_double_jumped: bool = false
# Role-based hitpoints. Hunters are tankier than props per GDD (HP balance).
# Props (Chameleon / Stalker) share the same pool. max_health is derived from
# role via _max_health_for_role() and resynced whenever the role changes.
const HUNTER_MAX_HEALTH := 250.0
const PROP_MAX_HEALTH := 200.0
const DEFAULT_MAX_HEALTH := 200.0
# Fraction of max restored by the prop emergency-conceal / revival cards. Ported
# from the legacy flat 65-on-100 value so card balance scales with the new pools.
const CARD_RESCUE_HEALTH_RATIO := 0.65
var max_health: float = DEFAULT_MAX_HEALTH
var health: float = DEFAULT_MAX_HEALTH
var _card_effect_controller: PlayerCardEffectController = null
var _card_effect_timers: Dictionary = {}
var _card_speed_multiplier: float = 1.0
var _card_damage_immunity_remaining: float = 0.0
var _card_hunter_skill_immunity_remaining: float = 0.0
var _card_silent_steps_remaining: float = 0.0
var _card_stasis_remaining: float = 0.0
var _card_original_scale: Vector3 = Vector3.ONE
var _card_scale_effect_active: bool = false
var _card_screen_impairment_remaining: float = 0.0
var _card_screen_impairment_layer: CanvasLayer = null
var _card_screen_impairment_rect: ColorRect = null
var _card_screen_impairment_label: Label = null
var _card_screen_impairment_material: ShaderMaterial = null
var _card_screen_impairment_tween: Tween = null
var _camouflage_brush_locked := false
var _camouflage_paint_texture: Texture2D = null
var _camouflage_paint_textures: Dictionary = {}
var _camouflage_surface_materials: Dictionary = {}
var _camouflage_paint_layer_materials: Dictionary = {}
var _camouflage_source_material_infos: Dictionary = {}
var _camouflage_brush_base_color := Color(0.42, 0.95, 0.72, 1.0)
var _camouflage_paint_exact_color_match := false
var _camouflage_paint_roughness := 1.0
var _camouflage_paint_metallic := 0.0
var _camouflage_paint_specular := 0.5
var _camouflage_paint_normal_texture: Texture2D = null
var _camouflage_paint_normal_scale := 1.0
var _camouflage_paint_sequence := 0
var _applied_camouflage_paint_event_keys: Array[String] = []
var _camouflage_paint_event_log: Array[Dictionary] = []
var _camouflage_replaying_paint_events := false
var _camouflage_gpu_atlas_manager: Node3D = null
var _camouflage_gpu_camera_brush: Node3D = null
var _camouflage_gpu_stroke_queue: Array[Dictionary] = []
var _camouflage_gpu_draw_timer := 0.0
var _camouflage_gpu_unavailable := false
var _camouflage_paused_animation_players: Dictionary = {}
var _chameleon_sculpt_shell_active := false
var _last_sculpt_batch_msec := 0
var _remote_visual_position := Vector3.ZERO
var _remote_visual_position_initialized := false
var _remote_visual_move_hold := 0.0
var _remote_visual_velocity_smoothed := Vector3.ZERO
var _remote_locomotion_action_key := ""
var _network_visual_action := "idle"
var _network_visual_yaw := 0.0
var _network_visual_grounded := true
var _network_visual_move_speed := 0.0
var _network_visual_move_intent := Vector3.ZERO
var _network_visual_sprinting := false
var _network_visual_state_msec := 0
var _network_visual_action_sequence := 0
var _network_visual_action_tick := 0
var _network_visual_export_action := "idle"
var _network_visual_applied_action_sequence := -1
var _remote_motion_sampler: RemoteMotionSampler = RemoteMotionSamplerScript.new()
var _netfox_transform_sync: NetfoxPlayerTransformSync = null
var _player_input_state: PlayerInputState = null
var _player_action_bus: PlayerActionBus = null
var _player_movement_motor: PlayerMovementMotor = null
var _rollback_movement_jump_sequence: int = -1
var _rollback_movement_previous_grounded: bool = true
var _rollback_teleport_settle_remaining: float = 0.0
var _skin_performance_camera_active := false
var _skin_performance_camera_state: Dictionary = {}
var _skin_performance_previous_current_camera: Camera3D = null
var _skin_performance_camera_token := 0
var _skin_performance_camera_action := ""
var _skin_performance_input_block_remaining := 0.0
# Server-authoritative count of livestream performances used this match. The
# first is free; further uses cost escalating HP (2nd -40%, 3rd fatal) to deter
# players spamming the camera-hijacking emote to grief others.
var _skin_performance_use_count: int = 0
var _skin_performance_wheel_dance_charge := 0.0
var _skin_performance_wheel_victory_charge := 0.0
var _skin_performance_wheel_bar_idle_remaining := 0.0
var _skin_performance_wheel_bar_root: Node3D = null
var _skin_performance_wheel_dance_fill: MeshInstance3D = null
var _skin_performance_wheel_victory_fill: MeshInstance3D = null
var _skin_performance_effect_root: Node3D = null
var _skin_performance_effect_tween: Tween = null
var _skin_performance_music_player: AudioStreamPlayer = null

signal health_changed(value: float)
signal max_health_changed(value: float)


func _has_runtime_multiplayer_peer() -> bool:
	return RuntimeMode.has_multiplayer_peer(multiplayer)


func _local_peer_id() -> int:
	if _has_runtime_multiplayer_peer():
		return multiplayer.get_unique_id()
	if Network.players.has(1):
		return 1
	var authority: int = get_multiplayer_authority()
	return authority if authority > 0 else 1


func _is_local_authority() -> bool:
	var authority: int = get_multiplayer_authority()
	if authority <= 0:
		return true
	if _has_runtime_multiplayer_peer():
		return authority == multiplayer.get_unique_id()
	if Network.players.has(1):
		return authority == 1
	return true


func _is_runtime_multiplayer_server() -> bool:
	return RuntimeMode.is_multiplayer_server(multiplayer)


func _refresh_runtime_process_policy() -> void:
	var is_local_player: bool = _is_local_authority()
	var should_process_visuals: bool = is_local_player or not _is_dedicated_public_server_runtime()
	set_process(should_process_visuals)
	set_physics_process(is_local_player)
	call_deferred("_refresh_runtime_netfox_policy")


func _refresh_runtime_netfox_policy() -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	var use_local_rollback: bool = _is_local_authority()
	var rollback_sync: Node = get_node_or_null("RollbackSynchronizer")
	if rollback_sync != null:
		_configure_rollback_synchronizer_runtime_policy(rollback_sync, use_local_rollback)
	var tick_interpolator: Node = get_node_or_null("MovementTickInterpolator")
	if tick_interpolator != null:
		tick_interpolator.set("enabled", use_local_rollback)
		tick_interpolator.set_process(use_local_rollback)


func _configure_rollback_synchronizer_runtime_policy(rollback_sync: Node, use_local_rollback: bool) -> void:
	if not _rollback_sync_policy_cached:
		var state_value: Variant = rollback_sync.get("state_properties")
		if state_value is Array:
			_rollback_sync_state_properties_cache.clear()
			for property_path: Variant in state_value as Array:
				_rollback_sync_state_properties_cache.append(str(property_path))
		var input_value: Variant = rollback_sync.get("input_properties")
		if input_value is Array:
			_rollback_sync_input_properties_cache.clear()
			for property_path: Variant in input_value as Array:
				_rollback_sync_input_properties_cache.append(str(property_path))
		_rollback_sync_policy_cached = true
	if _rollback_sync_runtime_enabled == use_local_rollback and _rollback_sync_policy_matches(rollback_sync, use_local_rollback):
		return
	_rollback_sync_runtime_enabled = use_local_rollback
	rollback_sync.set("enable_prediction", use_local_rollback)
	if use_local_rollback:
		rollback_sync.set("state_properties", _rollback_sync_state_properties_cache.duplicate())
		rollback_sync.set("input_properties", _rollback_sync_input_properties_cache.duplicate())
	else:
		var empty_state_properties: Array[String] = []
		var empty_input_properties: Array[String] = []
		rollback_sync.set("state_properties", empty_state_properties)
		rollback_sync.set("input_properties", empty_input_properties)
		if rollback_sync.has_method("_disconnect_signals"):
			rollback_sync.call("_disconnect_signals")
			rollback_sync.call_deferred("_disconnect_signals")
	if rollback_sync.has_method("process_settings") and _has_runtime_multiplayer_peer():
		rollback_sync.call_deferred("process_settings")


func _rollback_sync_policy_matches(rollback_sync: Node, use_local_rollback: bool) -> bool:
	var state_value: Variant = rollback_sync.get("state_properties")
	var input_value: Variant = rollback_sync.get("input_properties")
	var state_size: int = (state_value as Array).size() if state_value is Array else 0
	var input_size: int = (input_value as Array).size() if input_value is Array else 0
	if use_local_rollback:
		return state_size == _rollback_sync_state_properties_cache.size() and input_size == _rollback_sync_input_properties_cache.size()
	return state_size == 0 and input_size == 0


func _enter_tree():
	set_multiplayer_authority(str(name).to_int())
	$SpringArmOffset/SpringArm3D/Camera3D.current = _is_local_authority()
	add_to_group("players")
	_refresh_runtime_process_policy()

func _ready():
	var is_local_player: bool = _is_local_authority()
	_refresh_runtime_process_policy()
	var local_client_id: int = _local_peer_id()
	_robot_visual_root = get_node_or_null("3DGodotRobot/RobotArmature")
	_robot_animation_player = get_node_or_null("3DGodotRobot/AnimationPlayer") as AnimationPlayer
	_netfox_transform_sync = get_node_or_null("NetfoxTransformSync") as NetfoxPlayerTransformSync
	_player_input_state = get_node_or_null("PlayerInputState") as PlayerInputState
	_player_action_bus = get_node_or_null("PlayerActionBus") as PlayerActionBus
	_player_movement_motor = get_node_or_null("MovementMotor") as PlayerMovementMotor
	_apply_remote_visual_performance_policy(_robot_visual_root)
	_sync_character_visual_animation_activity()
	_cache_default_collision_shape()
	_setup_player_audio()

	# 浠?Network 鍚屾瑙掕壊
	_sync_role_from_network()
	_sync_character_model_from_network()
	_sync_party_monster_accessories_from_network()

	# 鐩戝惉瑙掕壊鍙樺寲
	if Network.player_role_changed.connect(_on_role_changed) != OK:
		pass  # 宸茶繛鎺?

	if Network.player_party_monster_accessories_changed.connect(_on_party_monster_accessories_changed) != OK:
		pass

	if _should_log_runtime_debug():
		print("Debug: Player ", name, " ready - authority: ", get_multiplayer_authority(),
			", local client: ", local_client_id, ", is_local: ", is_local_player,
			", role: ", Network.role_to_string(role))

	# Hunter 鐜╁:鏈湴绔礋璐ｈ緭鍏?瑙嗚,鏈嶅姟鍣ㄧ璐熻矗鏉冨▉寮硅嵂/鍛戒腑鐘舵€併€?
	if is_hunter():
		_setup_hunter_systems()
	elif is_stalker():
		_setup_stalker_systems()
	else:
		# 瑙掕壊鍚庡垎閰?寤跺悗鎸傝浇
		call_deferred("_check_role_after_assignment")

	if is_local_player:
		player_inventory = PlayerInventory.new()
		_add_starting_items()
	elif _is_runtime_multiplayer_server():
		player_inventory = PlayerInventory.new()
		_add_starting_items()
	else:
		if get_multiplayer_authority() == local_client_id:
			request_inventory_sync.rpc_id(1)


func set_global_position_immediate(next_position: Vector3) -> void:
	global_position = next_position
	velocity = Vector3.ZERO
	if is_inside_tree():
		reset_physics_interpolation()
	_remote_visual_position = next_position
	_remote_visual_position_initialized = true
	_remote_motion_sampler.reset(next_position, true)
	_remote_visual_velocity_smoothed = Vector3.ZERO
	# Briefly drive movement directly (not via rollback) so the body settles at the teleport
	# target without the stale rollback history snapping it back. See the const comment.
	_rollback_teleport_settle_remaining = ROLLBACK_TELEPORT_SETTLE_SECONDS
	# Re-anchor the rollback movement simulation to the teleport target so the next
	# rollback tick does not overwrite the new position with the stale prep-room
	# simulated_position (which causes the released Hunter to jitter / jump forever).
	var movement_motor: PlayerMovementMotor = _resolve_player_movement_motor()
	if movement_motor != null:
		movement_motor.teleport_to(next_position)
	# Tell the netfox interpolator to snap to the new state instead of smoothly gliding
	# the visual from the old (prep-room) position across the map to the teleport target.
	var tick_interpolator: Node = get_node_or_null("MovementTickInterpolator")
	if tick_interpolator != null and tick_interpolator.has_method("teleport"):
		tick_interpolator.call("teleport")


func _check_role_after_assignment() -> void:
	_sync_role_from_network()
	if is_hunter():
		_setup_hunter_systems()
	elif is_chameleon() and _is_local_authority() and not has_node("CamouflageSystem"):
		_setup_chameleon_systems()
	elif is_stalker() and not has_node("ShadowVisibilitySystem"):
		_setup_stalker_systems()


# =============================================================================
# 钘忓尶鑰呯郴缁熷垵濮嬪寲(PoC-3)
# =============================================================================

var shape_system: ShapeShiftSystem = null
var camouflage_system: CamouflageSystem = null
var chameleon_sculpt_system: Node = null
var chameleon_environment_blend_system: Node = null
var shadow_visibility = null
var stalker_grapple_system = null
var hunter_flashlight_system = null
var hunter_prop_sense_system = null
var hunter_auto_turret_system = null
var _stalker_original_material_overrides := {}
var _stalker_original_shadow_casting := {}
var _stalker_original_visibility := {}
var _stalker_ghost_material: ShaderMaterial = null
var _stalker_ghost_material_key := ""
var _stalker_glass_material: ShaderMaterial = null
var _stalker_glass_material_key := ""
var _stalker_visual_mode := "normal"
var _stalker_visual_alpha := -1.0
var _stalker_synced_visibility_alpha := 1.0
var _stalker_synced_shadow_level := 0
var _stalker_synced_blocked_rays := 0
var _hunter_prop_sense_revealed := false
var _hunter_prop_sense_visual_active := false
var _hunter_prop_sense_intensity := 0.0
var _hunter_prop_sense_beep_interval := 1.0
var _hunter_prop_sense_beep_timer := 0.0
var _hunter_prop_sense_feedback_elapsed := LOCAL_FEEDBACK_TRANSFORM_INTERVAL
var _hunter_prop_sense_outline_material: ShaderMaterial = null
var _hunter_prop_sense_outline_nodes := {}
var _hunter_prop_sense_glow_light: OmniLight3D = null
var _hunter_prop_sense_audio: AudioStreamPlayer3D = null
var _hunter_prop_sense_beep_stream: AudioStreamWAV = null
var _hunter_prop_sense_ping_spawned := false
var _hunter_prop_sense_ping_marker: Node3D = null
var _hunter_prop_sense_ping_tween: Tween = null
var _party_monster_accessory_loadout: Dictionary = {}
var _party_monster_bounty_marked := false
var _party_monster_bounty_accessory_ids: Array = []
var _party_monster_bounty_label := ""
var _party_monster_bounty_outline_nodes := {}
var _party_monster_bounty_glow_light: OmniLight3D = null
var _party_monster_bounty_marker_label: Label3D = null
var _party_monster_bounty_feedback_elapsed := LOCAL_FEEDBACK_TRANSFORM_INTERVAL

func _setup_chameleon_systems() -> void:
	if not is_chameleon() or not _is_local_authority():
		return

	# 环境取色伪装系统(Godot 4.7 DrawableTexture2D)
	if not has_node("CamouflageSystem"):
		var cs = preload("res://scripts/camouflage_system.gd").new()
		cs.name = "CamouflageSystem"
		add_child(cs)
		var camera_node = $SpringArmOffset/SpringArm3D/Camera3D
		cs.initialize(self, camera_node)
		camouflage_system = cs
	else:
		camouflage_system = get_node_or_null("CamouflageSystem") as CamouflageSystem

	if not has_node("ChameleonEnvironmentBlendSystem"):
		var blend := preload("res://scripts/chameleon_environment_blend_system.gd").new()
		blend.name = "ChameleonEnvironmentBlendSystem"
		add_child(blend)
		var blend_camera = $SpringArmOffset/SpringArm3D/Camera3D
		blend.initialize(self, blend_camera, camouflage_system)
		chameleon_environment_blend_system = blend
	else:
		chameleon_environment_blend_system = get_node_or_null("ChameleonEnvironmentBlendSystem")

	if camouflage_system and chameleon_environment_blend_system and camouflage_system.has_method("set_environment_blend_system"):
		camouflage_system.call("set_environment_blend_system", chameleon_environment_blend_system)

	# 鍙樺舰绯荤粺
	if not has_node("ShapeShiftSystem"):
		var ss = preload("res://scripts/shape_shift_system.gd").new()
		ss.name = "ShapeShiftSystem"
		add_child(ss)
		ss.initialize(self)
		shape_system = ss

	if _should_log_runtime_debug():
		print("[Player] Chameleon systems initialized")


func _setup_stalker_systems() -> void:
	if not is_stalker():
		return

	var should_compute_visibility := _should_compute_stalker_visibility()
	if not has_node("ShadowVisibilitySystem"):
		var system := preload("res://scripts/shadow_visibility_system.gd").new()
		system.name = "ShadowVisibilitySystem"
		add_child(system)

	shadow_visibility = get_node_or_null("ShadowVisibilitySystem")
	if shadow_visibility:
		shadow_visibility.set_process(should_compute_visibility)
		if should_compute_visibility:
			if not shadow_visibility.visibility_changed.is_connected(_on_stalker_visibility_changed):
				shadow_visibility.visibility_changed.connect(_on_stalker_visibility_changed)
			shadow_visibility.initialize(self)
		elif shadow_visibility.visibility_changed.is_connected(_on_stalker_visibility_changed):
			shadow_visibility.visibility_changed.disconnect(_on_stalker_visibility_changed)
	var camera := $SpringArmOffset/SpringArm3D/Camera3D if has_node("SpringArmOffset/SpringArm3D/Camera3D") else null
	if not has_node("StalkerGrappleSystem"):
		var grapple := preload("res://scripts/stalker_grapple_system.gd").new()
		grapple.name = "StalkerGrappleSystem"
		add_child(grapple)
	stalker_grapple_system = get_node_or_null("StalkerGrappleSystem")
	if stalker_grapple_system:
		stalker_grapple_system.initialize(self, camera if _is_local_authority() else null)
	_refresh_stalker_visibility_view(true)


func _teardown_stalker_systems() -> void:
	_restore_stalker_materials()
	if shadow_visibility and is_instance_valid(shadow_visibility):
		shadow_visibility.queue_free()
	shadow_visibility = null
	if stalker_grapple_system and is_instance_valid(stalker_grapple_system):
		stalker_grapple_system.queue_free()
	stalker_grapple_system = null
	_stalker_visual_mode = "normal"
	_stalker_visual_alpha = -1.0


func _should_compute_stalker_visibility() -> bool:
	if not is_stalker():
		return false
	if not _has_active_camouflage_multiplayer_peer():
		return true
	if _is_local_authority():
		return true
	if _is_runtime_multiplayer_server():
		var owner_id := get_multiplayer_authority()
		# Local scene tests can simulate a remote owner without connecting that peer.
		if owner_id != 1 and not multiplayer.get_peers().has(owner_id):
			return true
	return false


func _get_effective_stalker_visibility_alpha() -> float:
	if _should_compute_stalker_visibility() and shadow_visibility and shadow_visibility.has_method("get_visibility_alpha"):
		return clampf(float(shadow_visibility.get_visibility_alpha()), 0.0, 1.0)
	return clampf(_stalker_synced_visibility_alpha, 0.0, 1.0)


func _on_stalker_visibility_changed(level: int, alpha: float, blocked_rays: int) -> void:
	var clean_alpha := clampf(alpha, 0.0, 1.0)
	var clean_level := clampi(level, 0, 3)
	var clean_blocked_rays := clampi(blocked_rays, 0, 16)
	if absf(clean_alpha - _stalker_synced_visibility_alpha) > STALKER_VISIBILITY_SYNC_MIN_DELTA or clean_level != _stalker_synced_shadow_level or clean_blocked_rays != _stalker_synced_blocked_rays:
		_stalker_synced_visibility_alpha = clean_alpha
		_stalker_synced_shadow_level = clean_level
		_stalker_synced_blocked_rays = clean_blocked_rays
		_publish_stalker_visibility_state(clean_level, clean_alpha, clean_blocked_rays)
	_refresh_stalker_visibility_view(true)


func _publish_stalker_visibility_state(level: int, alpha: float, blocked_rays: int) -> void:
	if not _should_compute_stalker_visibility():
		return
	if not _has_active_camouflage_multiplayer_peer():
		return
	if _is_runtime_multiplayer_server():
		_apply_stalker_visibility_state.rpc(get_multiplayer_authority(), level, alpha, blocked_rays)
	else:
		_request_stalker_visibility_state.rpc_id(1, level, alpha, blocked_rays)


@rpc("any_peer", "call_local", "unreliable_ordered")
func _request_stalker_visibility_state(level: int, alpha: float, blocked_rays: int) -> void:
	if not _is_runtime_multiplayer_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	if not is_stalker():
		return
	_apply_stalker_visibility_state.rpc(get_multiplayer_authority(), clampi(level, 0, 3), clampf(alpha, 0.0, 1.0), clampi(blocked_rays, 0, 16))


@rpc("any_peer", "call_local", "unreliable_ordered")
func _apply_stalker_visibility_state(peer_id: int, level: int, alpha: float, blocked_rays: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if _is_runtime_multiplayer_server():
		if sender != 0:
			return
	elif sender != 0 and sender != 1:
		return
	if peer_id != get_multiplayer_authority() or not is_stalker():
		return
	_stalker_synced_visibility_alpha = clampf(alpha, 0.0, 1.0)
	_stalker_synced_shadow_level = clampi(level, 0, 3)
	_stalker_synced_blocked_rays = clampi(blocked_rays, 0, 16)
	_refresh_stalker_visibility_view(true)


func get_stalker_visual_mode() -> String:
	return _stalker_visual_mode


func get_stalker_visibility_alpha() -> float:
	return _get_effective_stalker_visibility_alpha()


func _refresh_stalker_visibility_view(force: bool = false) -> void:
	if not is_stalker():
		return
	if not shadow_visibility:
		shadow_visibility = get_node_or_null("ShadowVisibilitySystem")

	var shadow_alpha: float = _get_effective_stalker_visibility_alpha()
	var next_mode := _get_stalker_visual_mode_for_viewer(shadow_alpha)
	var next_material: Material = null
	match next_mode:
		"ghost":
			var ghost_profile: String = _stalker_ghost_profile_for_viewer()
			next_material = _get_stalker_ghost_material(_ghost_alpha_from_shadow(shadow_alpha, ghost_profile), ghost_profile)
		"glass":
			var glass_profile: String = _stalker_glass_profile_for_viewer()
			next_material = _get_stalker_glass_material(_glass_alpha_from_shadow(shadow_alpha, glass_profile), glass_profile)
	if not force and next_mode == _stalker_visual_mode and is_equal_approx(shadow_alpha, _stalker_visual_alpha):
		if next_mode == "normal" or _stalker_visual_meshes_have_material(next_material):
			return

	_stalker_visual_mode = next_mode
	_stalker_visual_alpha = shadow_alpha

	match next_mode:
		"ghost":
			_apply_stalker_material(next_material)
		"glass":
			_apply_stalker_material(next_material)
		_:
			_restore_stalker_materials()

	_update_stalker_nickname_visibility(shadow_alpha)


func _get_stalker_visual_mode_for_viewer(shadow_alpha: float) -> String:
	if _party_monster_bounty_marked:
		return "normal"
	if shadow_alpha >= 0.99:
		return "normal"
	if _is_local_authority():
		return "glass" if _stalker_glass_material_mode() == "liquid_glass" else "ghost"

	var viewer_role := _get_local_viewer_role()
	if viewer_role == Network.Role.HUNTER:
		return "glass"
	if viewer_role == Network.Role.CHAMELEON and _stalker_glass_material_mode() == "liquid_glass":
		return "glass"
	return "ghost"


func _get_local_viewer_role() -> int:
	var local_id: int = _local_peer_id()
	if Network.players.has(local_id):
		return int(Network.players[local_id].get("role", Network.Role.NONE))
	return Network.Role.NONE


func _stalker_ghost_profile_for_viewer() -> String:
	if _is_local_authority():
		return "self"
	var viewer_role: int = _get_local_viewer_role()
	if viewer_role == Network.Role.CHAMELEON:
		return "prop"
	return "self"


func _stalker_glass_profile_for_viewer() -> String:
	if _is_local_authority():
		return "self"
	var viewer_role: int = _get_local_viewer_role()
	if viewer_role == Network.Role.CHAMELEON:
		return "prop"
	if viewer_role == Network.Role.HUNTER:
		return "hunter"
	return "self"


func _ghost_alpha_from_shadow(shadow_alpha: float, profile: String = "prop") -> float:
	if profile == "self":
		return clampf(lerpf(0.095, 0.26, shadow_alpha), 0.095, 0.26)
	return clampf(lerpf(0.24, 0.72, shadow_alpha), 0.24, 0.72)


func _glass_alpha_from_shadow(shadow_alpha: float, profile: String = "hunter") -> float:
	var ceiling: float = _stalker_glass_alpha_ceiling(profile)
	var floor_alpha: float = minf(0.018, ceiling * 0.22)
	var reveal_alpha: float = minf(ceiling * 0.52, 0.065)
	match profile:
		"self":
			floor_alpha = minf(0.038, ceiling * 0.30)
			reveal_alpha = minf(0.095, ceiling * 0.66)
		"prop":
			floor_alpha = minf(0.085, ceiling * 0.62)
			reveal_alpha = minf(0.200, ceiling * 0.92)
	return clampf(lerpf(floor_alpha, reveal_alpha, shadow_alpha), floor_alpha, reveal_alpha)


func _stalker_glass_alpha_ceiling(profile: String = "hunter") -> float:
	var base_ceiling: float = clampf(float(Network.lobby_config.get("stalker_glass_alpha_max", 0.125)), 0.04, 0.24)
	match profile:
		"self":
			return clampf(base_ceiling * 1.18, 0.09, 0.18)
		"prop":
			return clampf(base_ceiling * 1.65, 0.08, 0.35)
	return base_ceiling


func _apply_stalker_material(material: Material) -> void:
	var meshes := _get_stalker_visual_meshes(true)
	for mesh in meshes:
		var id := mesh.get_instance_id()
		if not _stalker_original_material_overrides.has(id):
			_stalker_original_material_overrides[id] = mesh.material_override
		if not _stalker_original_shadow_casting.has(id):
			_stalker_original_shadow_casting[id] = mesh.cast_shadow
		if not _stalker_original_visibility.has(id):
			_stalker_original_visibility[id] = mesh.visible
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if _is_stalker_invisibility_feature_mesh(mesh):
			mesh.visible = false
			continue
		mesh.visible = bool(_stalker_original_visibility.get(id, true))
		mesh.material_override = material


func _restore_stalker_materials() -> void:
	var meshes := _get_stalker_visual_meshes(true)
	for mesh in meshes:
		var id := mesh.get_instance_id()
		if _stalker_original_material_overrides.has(id):
			mesh.material_override = _stalker_original_material_overrides[id]
		else:
			mesh.material_override = null
		if _stalker_original_shadow_casting.has(id):
			mesh.cast_shadow = int(_stalker_original_shadow_casting[id]) as GeometryInstance3D.ShadowCastingSetting
		else:
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if _stalker_original_visibility.has(id):
			mesh.visible = bool(_stalker_original_visibility[id])
	_apply_remote_visual_performance_policy(self)
	_refresh_nickname_visibility()


func _stalker_visual_meshes_have_material(material: Material) -> bool:
	if not material:
		return true
	var meshes := _get_stalker_visual_meshes(true)
	if meshes.is_empty():
		return false
	var shell_mesh_count := 0
	for mesh in meshes:
		var id := mesh.get_instance_id()
		var expected_visible: bool = bool(_stalker_original_visibility.get(id, mesh.visible))
		if _is_stalker_invisibility_feature_mesh(mesh):
			if mesh.visible:
				return false
			if mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				return false
			continue
		if mesh.visible != expected_visible:
			return false
		if not mesh.visible:
			continue
		shell_mesh_count += 1
		if mesh.material_override != material:
			return false
		if mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			return false
	return shell_mesh_count > 0


func _is_stalker_invisibility_feature_mesh(mesh: MeshInstance3D) -> bool:
	var node: Node = mesh
	while node:
		var name_lower: String = String(node.name).to_lower()
		if name_lower.contains("eye") or name_lower.contains("face") or name_lower.contains("mouth") or name_lower.contains("smile") or name_lower.contains("pupil") or name_lower.contains("iris") or name_lower.contains("teeth") or name_lower.contains("tooth") or name_lower.contains("tongue") or name_lower.contains("nose"):
			return true
		node = node.get_parent()
	return false


func _get_stalker_visual_meshes(include_hidden: bool = false) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	if _prop_disguise_node and is_instance_valid(_prop_disguise_node) and (include_hidden or _prop_disguise_node.visible):
		if include_hidden:
			_find_meshes(_prop_disguise_node, meshes)
		else:
			_find_visible_meshes(_prop_disguise_node, meshes)
	elif _active_skin_node and is_instance_valid(_active_skin_node) and (include_hidden or _active_skin_node.visible):
		if include_hidden:
			_find_meshes(_active_skin_node, meshes)
		else:
			_find_visible_meshes(_active_skin_node, meshes)
	elif _robot_visual_root and (include_hidden or _robot_visual_root.visible):
		if include_hidden:
			_find_meshes(_robot_visual_root, meshes)
		else:
			_find_visible_meshes(_robot_visual_root, meshes)
	elif _body:
		if include_hidden:
			_find_meshes(_body, meshes)
		else:
			_find_visible_meshes(_body, meshes)
	return meshes


func _find_visible_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is Node3D and not (node as Node3D).visible:
		return
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		_find_visible_meshes(child, result)


func get_chameleon_sculpt_source_meshes() -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	if _active_skin_node and is_instance_valid(_active_skin_node):
		_find_meshes(_active_skin_node, meshes)
	elif _robot_visual_root:
		_find_meshes(_robot_visual_root, meshes)
	return meshes


func get_chameleon_sculpt_model_id() -> String:
	return character_model_id


func _update_stalker_nickname_visibility(shadow_alpha: float) -> void:
	_refresh_nickname_visibility(shadow_alpha)


func _refresh_nickname_visibility(stalker_shadow_alpha: float = -1.0) -> void:
	if not nickname:
		return
	# When the screen-space WorldNameplateHUD owns overhead text, keep the
	# world Label3D hidden so names aren't drawn twice.
	if _screen_nameplate_active:
		nickname.visible = false
		return
	nickname.visible = _should_show_nickname_for_local_viewer(stalker_shadow_alpha)


func _should_show_nickname_for_local_viewer(stalker_shadow_alpha: float = -1.0) -> bool:
	var local_id: int = _local_peer_id()
	if get_multiplayer_authority() == local_id:
		return true
	if _party_monster_bounty_marked:
		return true
	var viewer_role := _get_local_viewer_role()
	if _is_cross_team_nameplate_hidden(viewer_role, role):
		return false
	if role == Network.Role.STALKER and viewer_role == Network.Role.HUNTER:
		var effective_shadow_alpha := stalker_shadow_alpha
		if effective_shadow_alpha < 0.0:
			effective_shadow_alpha = _get_effective_stalker_visibility_alpha()
		return effective_shadow_alpha >= 0.99
	return true


func _is_cross_team_nameplate_hidden(viewer_role: int, target_role: int) -> bool:
	if viewer_role == Network.Role.HUNTER:
		return target_role == Network.Role.CHAMELEON or target_role == Network.Role.STALKER
	if target_role == Network.Role.HUNTER:
		return viewer_role == Network.Role.CHAMELEON or viewer_role == Network.Role.STALKER
	return false


func _get_stalker_ghost_material(alpha: float, profile: String = "prop") -> ShaderMaterial:
	var cache_key: String = "classic_ghost:%s" % profile
	if not _stalker_ghost_material or _stalker_ghost_material_key != cache_key:
		var shader := Shader.new()
		shader.code = """
shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back, specular_schlick_ggx;

uniform vec4 tint : source_color = vec4(0.55, 0.82, 1.0, 1.0);
uniform float alpha = 0.35;
uniform float alpha_ceiling = 0.90;
uniform float fresnel_alpha_boost = 0.20;
uniform float veil_strength = 0.08;
uniform float veil_alpha = 0.03;
uniform float emission_strength = 0.12;
uniform float roughness_power = 0.18;
uniform float specular_power = 0.75;

void fragment() {
	float view_dot = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - view_dot, 2.0);
	float veil_wave = sin(UV.y * 28.0 + TIME * 0.72 + sin(UV.x * 13.0 + TIME * 0.31)) * 0.5 + 0.5;
	float veil = pow(veil_wave, 3.4) * veil_strength;
	ALBEDO = tint.rgb * (0.10 + fresnel * 0.26 + veil * 0.18);
	ALPHA = clamp(alpha + fresnel * fresnel_alpha_boost + veil * veil_alpha, 0.006, alpha_ceiling);
	EMISSION = tint.rgb * emission_strength * (0.25 + fresnel * 0.55 + veil * 0.35);
	ROUGHNESS = roughness_power;
	METALLIC = 0.0;
	SPECULAR = specular_power;
	RIM = 0.06;
}
"""
		_stalker_ghost_material = ShaderMaterial.new()
		_stalker_ghost_material.resource_local_to_scene = true
		_stalker_ghost_material.resource_name = "StalkerClassicShimmerSelf" if profile == "self" else "StalkerClassicShimmerProp"
		_stalker_ghost_material.shader = shader
		_stalker_ghost_material_key = cache_key
		_configure_stalker_ghost_material(_stalker_ghost_material, profile)
	_stalker_ghost_material.set_shader_parameter("alpha", alpha)
	return _stalker_ghost_material


func _configure_stalker_ghost_material(material: ShaderMaterial, profile: String = "prop") -> void:
	if profile == "self":
		material.set_shader_parameter("tint", Color(0.42, 0.50, 0.46, 1.0))
		material.set_shader_parameter("alpha_ceiling", 0.34)
		material.set_shader_parameter("fresnel_alpha_boost", 0.055)
		material.set_shader_parameter("veil_strength", 0.18)
		material.set_shader_parameter("veil_alpha", 0.018)
		material.set_shader_parameter("emission_strength", 0.025)
		material.set_shader_parameter("roughness_power", 0.08)
		material.set_shader_parameter("specular_power", 0.62)
		return
	material.set_shader_parameter("tint", Color(0.55, 0.82, 1.0, 1.0))
	material.set_shader_parameter("alpha_ceiling", 0.90)
	material.set_shader_parameter("fresnel_alpha_boost", 0.20)
	material.set_shader_parameter("veil_strength", 0.08)
	material.set_shader_parameter("veil_alpha", 0.03)
	material.set_shader_parameter("emission_strength", 0.12)
	material.set_shader_parameter("roughness_power", 0.18)
	material.set_shader_parameter("specular_power", 0.75)


func _get_stalker_glass_material(alpha: float, profile: String = "hunter") -> ShaderMaterial:
	var material_key: String = _stalker_glass_material_mode()
	var cache_key: String = "%s:%s" % [material_key, profile]
	if not _stalker_glass_material or _stalker_glass_material_key != cache_key:
		_stalker_glass_material = ShaderMaterial.new()
		_stalker_glass_material.resource_local_to_scene = true
		_stalker_glass_material.resource_name = _stalker_glass_resource_name(material_key, profile)
		_stalker_glass_material.shader = _build_stalker_glass_shader(material_key)
		_stalker_glass_material_key = cache_key
		_configure_stalker_glass_material(_stalker_glass_material, material_key, profile)
	_stalker_glass_material.set_shader_parameter("alpha", alpha)
	_stalker_glass_material.set_shader_parameter("visibility_ceiling", _stalker_glass_alpha_ceiling(profile))
	return _stalker_glass_material


func _stalker_glass_material_mode() -> String:
	var configured: String = str(Network.lobby_config.get("stalker_glass_material", "classic"))
	return "liquid_glass" if configured == "liquid_glass" else "classic"


func _stalker_glass_resource_name(material_key: String, profile: String) -> String:
	if material_key != "liquid_glass":
		return "StalkerClassicShimmer"
	match profile:
		"self":
			return "StalkerLiquidGlassSelf"
		"prop":
			return "StalkerLiquidGlassProp"
	return "StalkerLiquidGlassHunter"


func _build_stalker_glass_shader(material_key: String) -> Shader:
	var shader := Shader.new()
	if material_key == "liquid_glass":
		shader.code = """
shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back, specular_schlick_ggx;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec3 tint : source_color = vec3(0.82, 0.94, 1.0);
uniform float alpha = 0.025;
uniform float visibility_ceiling = 0.125;
uniform float refraction_strength = 0.052;
uniform float fresnel_power = 1.15;
uniform float emission_power = 0.20;
uniform float specular_power = 1.0;
uniform float roughness_power = 0.055;
uniform float rim_power = 0.16;
uniform float blur = 0.0;
uniform float screen_color_bleed = 0.06;
uniform float glass_highlight = 0.24;
uniform float luminance_refraction = 1.05;
uniform float rim_alpha_boost = 0.035;
uniform float refracted_mix = 0.04;
uniform float refracted_alpha_boost = 0.045;

void fragment() {
	vec3 view_normal = normalize(vec3(NORMAL.xy, 0.0));
	float view_dot = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - view_dot, fresnel_power);
	float edge_glint = pow(fresnel, 1.35);
	vec2 liquid_wave = vec2(
		sin((SCREEN_UV.y + TIME * 0.07) * 38.0),
		cos((SCREEN_UV.x - TIME * 0.06) * 43.0)
	) * refraction_strength * 0.18;
	vec2 offset = view_normal.xy * refraction_strength * fresnel + liquid_wave * (0.25 + fresnel);
	vec3 refracted = texture(screen_texture, SCREEN_UV + offset, blur).rgb;
	vec3 base_screen = texture(screen_texture, SCREEN_UV, blur).rgb;
	vec3 raw_delta = abs(refracted - base_screen);
	vec3 distortion_delta = clamp(raw_delta, vec3(0.0), vec3(screen_color_bleed));
	float distortion_luma = min(dot(distortion_delta, vec3(0.299, 0.587, 0.114)), screen_color_bleed);
	float contrast_guard = 1.0 - smoothstep(0.18, 0.55, length(raw_delta));
	float liquid_glint = pow(sin((SCREEN_UV.x * 77.0 - SCREEN_UV.y * 41.0 + TIME * 0.9)) * 0.5 + 0.5, 5.0) * edge_glint;
	vec3 cloak_tint = tint * (0.035 + edge_glint * 0.16);
	vec3 refractive_highlight = tint * distortion_luma * luminance_refraction * contrast_guard;
	vec3 rim_highlight = tint * glass_highlight * (edge_glint + liquid_glint * 0.45);
	vec3 safe_albedo = cloak_tint + refractive_highlight + rim_highlight;
	float direct_refracted = step(0.90, refracted_mix);
	vec3 blended_albedo = mix(safe_albedo, refracted, clamp(refracted_mix, 0.0, 1.0));
	ALBEDO = mix(blended_albedo, refracted, direct_refracted);
	ALPHA = clamp(alpha + edge_glint * min(rim_alpha_boost, visibility_ceiling * 0.42) + distortion_luma * 0.12 + direct_refracted * refracted_alpha_boost, 0.003, visibility_ceiling);
	EMISSION = tint * emission_power * (0.08 + edge_glint * 0.55 + liquid_glint * 0.28 + distortion_luma * 1.2 * contrast_guard);
	ROUGHNESS = roughness_power;
	METALLIC = 0.0;
	SPECULAR = specular_power;
	RIM = rim_power;
}
"""
		return shader
	shader.code = """
shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back, specular_schlick_ggx;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec4 edge_tint : source_color = vec4(0.50, 0.58, 0.62, 1.0);
uniform float alpha = 0.025;
uniform float visibility_ceiling = 0.125;
uniform float refraction_strength = 0.015;
uniform float shimmer_strength = 0.006;
uniform float screen_color_bleed = 0.022;
uniform float highlight_strength = 0.13;

void fragment() {
	float view_dot = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - view_dot, 4.0);
	float shimmer = sin((SCREEN_UV.x * 1.3 + SCREEN_UV.y * 1.7 + TIME * 0.08) * 95.0) * 0.5 + 0.5;
	vec2 normal_warp = normalize(NORMAL.xy + vec2(0.0001, 0.0001));
	vec2 heat_warp = vec2(sin(SCREEN_UV.y * 120.0 + TIME * 1.2), cos(SCREEN_UV.x * 105.0 - TIME)) * shimmer_strength;
	vec2 wobble = normal_warp * refraction_strength * (0.12 + fresnel * 0.85) + heat_warp * (0.25 + fresnel);
	vec3 refracted = texture(screen_texture, SCREEN_UV + wobble).rgb;
	vec3 base_screen = texture(screen_texture, SCREEN_UV).rgb;
	vec3 raw_delta = abs(refracted - base_screen);
	vec3 distortion_delta = clamp(raw_delta, vec3(0.0), vec3(screen_color_bleed));
	float distortion_luma = min(dot(distortion_delta, vec3(0.299, 0.587, 0.114)), screen_color_bleed);
	float contrast_guard = 1.0 - smoothstep(0.10, 0.35, length(raw_delta));
	float shimmer_glint = pow(shimmer, 5.0) * fresnel;
	vec3 cloak_tint = edge_tint.rgb * (0.035 + fresnel * 0.18 + shimmer * 0.012);
	vec3 shimmer_highlight = edge_tint.rgb * (distortion_luma * 1.35 * contrast_guard + shimmer_glint * highlight_strength);
	ALBEDO = cloak_tint + shimmer_highlight;
	ALPHA = clamp(alpha + fresnel * 0.035 + distortion_luma * 0.18 + shimmer_glint * 0.012, 0.004, visibility_ceiling);
	EMISSION = edge_tint.rgb * (fresnel * 0.018 + shimmer_glint * 0.035);
	ROUGHNESS = 0.035;
	METALLIC = 0.0;
	SPECULAR = 0.62;
	RIM = 0.08;
}
"""
	return shader


func _configure_stalker_glass_material(material: ShaderMaterial, material_key: String, profile: String = "hunter") -> void:
	if material_key == "liquid_glass":
		var tint: Color = Color(0.82, 0.94, 1.0, 1.0)
		var refraction_strength: float = 0.052
		var fresnel_power: float = 1.15
		var emission_power: float = 0.20
		var specular_power: float = 1.0
		var roughness_power: float = 0.055
		var rim_power: float = 0.16
		var screen_color_bleed: float = 0.035
		var glass_highlight: float = 0.24
		var luminance_refraction: float = 1.05
		var rim_alpha_boost: float = 0.035
		var refracted_mix: float = 0.04
		var refracted_alpha_boost: float = 0.045
		match profile:
			"self":
				tint = Color(0.42, 0.52, 0.48, 1.0)
				refraction_strength = 0.090
				fresnel_power = 0.95
				emission_power = 0.12
				specular_power = 1.20
				roughness_power = 0.034
				rim_power = 0.16
				screen_color_bleed = 0.058
				glass_highlight = 0.20
				luminance_refraction = 1.22
				rim_alpha_boost = 0.044
				refracted_mix = 0.95
				refracted_alpha_boost = 0.018
			"prop":
				tint = Color(0.58, 0.90, 1.0, 1.0)
				refraction_strength = 0.067
				fresnel_power = 0.92
				emission_power = 0.36
				specular_power = 1.15
				roughness_power = 0.032
				rim_power = 0.30
				screen_color_bleed = 0.052
				glass_highlight = 0.46
				luminance_refraction = 1.45
				rim_alpha_boost = 0.065
				refracted_mix = 1.0
		material.set_shader_parameter("tint", tint)
		material.set_shader_parameter("refraction_strength", refraction_strength)
		material.set_shader_parameter("fresnel_power", fresnel_power)
		material.set_shader_parameter("emission_power", emission_power)
		material.set_shader_parameter("specular_power", specular_power)
		material.set_shader_parameter("roughness_power", roughness_power)
		material.set_shader_parameter("rim_power", rim_power)
		material.set_shader_parameter("blur", 0.0)
		material.set_shader_parameter("screen_color_bleed", screen_color_bleed)
		material.set_shader_parameter("glass_highlight", glass_highlight)
		material.set_shader_parameter("luminance_refraction", luminance_refraction)
		material.set_shader_parameter("rim_alpha_boost", rim_alpha_boost)
		material.set_shader_parameter("refracted_mix", refracted_mix)
		material.set_shader_parameter("refracted_alpha_boost", refracted_alpha_boost)
		return
	material.set_shader_parameter("edge_tint", Color(0.50, 0.58, 0.62, 1.0))
	material.set_shader_parameter("refraction_strength", 0.015)
	material.set_shader_parameter("shimmer_strength", 0.006)
	material.set_shader_parameter("screen_color_bleed", 0.022)
	material.set_shader_parameter("highlight_strength", 0.13)


# =============================================================================
# Hunter 姝﹀櫒鍒濆鍖?
# =============================================================================

func _setup_hunter_systems() -> void:
	if not is_hunter():
		return
	if _is_local_authority() or _is_runtime_multiplayer_server():
		_setup_hunter_weapon()
	_setup_hunter_flashlight()
	_setup_hunter_prop_sense()
	_setup_hunter_auto_turret()


func _setup_hunter_weapon() -> void:
	var is_local_player = _is_local_authority()
	var camera = $SpringArmOffset/SpringArm3D/Camera3D

	# 鍔犺浇 AK47 妯″瀷(浠呮湰鍦拌瑙?
	if is_local_player:
		var ak47_scene = preload("res://scenes/weapons/ak47.tscn")
		if not camera.has_node("WeaponVisual"):
			var visual = ak47_scene.instantiate()
			visual.name = "WeaponVisual"
			# 鎸傚湪 Camera3D 涓?浣滀负鏈湴绗竴/涓変汉绉拌瑙?
			camera.add_child(visual)
			visual.position = Vector3(0.3, -0.3, -0.5)
			visual.rotation = Vector3(0, 0, 0)

	# 鍔犺浇 WeaponSystem(缃戠粶鏉冨▉)
	if not has_node("WeaponSystem"):
		var weapon = preload("res://scripts/weapon_system.gd").new()
		weapon.name = "WeaponSystem"
		add_child(weapon)
		weapon.initialize(self, camera if is_local_player else null)

	# 娉ㄥ唽寮硅嵂鍙樺寲淇″彿
	var weapon = get_node_or_null("WeaponSystem")
	if weapon:
		if not weapon.ammo_changed.is_connected(_on_ammo_changed):
			weapon.ammo_changed.connect(_on_ammo_changed)


func _setup_hunter_flashlight() -> void:
	var camera := $SpringArmOffset/SpringArm3D/Camera3D if has_node("SpringArmOffset/SpringArm3D/Camera3D") else null
	if not has_node("HunterFlashlightSystem"):
		var flashlight := preload("res://scripts/hunter_flashlight_system.gd").new()
		flashlight.name = "HunterFlashlightSystem"
		add_child(flashlight)
	hunter_flashlight_system = get_node_or_null("HunterFlashlightSystem")
	if hunter_flashlight_system:
		hunter_flashlight_system.initialize(self, camera if _is_local_authority() else null)


func _teardown_hunter_flashlight() -> void:
	if hunter_flashlight_system and is_instance_valid(hunter_flashlight_system):
		hunter_flashlight_system.queue_free()
	hunter_flashlight_system = null


func _setup_hunter_prop_sense() -> void:
	if not is_hunter() or not _is_local_authority():
		return
	if not has_node("HunterPropSenseSystem"):
		var sense := preload("res://scripts/hunter_prop_sense_system.gd").new()
		sense.name = "HunterPropSenseSystem"
		add_child(sense)
	hunter_prop_sense_system = get_node_or_null("HunterPropSenseSystem")
	if hunter_prop_sense_system:
		hunter_prop_sense_system.initialize(self)


func _teardown_hunter_prop_sense() -> void:
	if hunter_prop_sense_system and is_instance_valid(hunter_prop_sense_system):
		hunter_prop_sense_system.queue_free()
	hunter_prop_sense_system = null


func _setup_hunter_auto_turret() -> void:
	if not is_hunter():
		return
	if not bool(Network.lobby_config.get("hunter_auto_turret_enabled", false)):
		_teardown_hunter_auto_turret()
		return
	if not has_node("HunterAutoTurretSystem"):
		var turret := preload("res://scripts/hunter_auto_turret_system.gd").new()
		turret.name = "HunterAutoTurretSystem"
		add_child(turret)
	hunter_auto_turret_system = get_node_or_null("HunterAutoTurretSystem")
	if hunter_auto_turret_system:
		hunter_auto_turret_system.initialize(self)


func _teardown_hunter_auto_turret() -> void:
	if hunter_auto_turret_system and is_instance_valid(hunter_auto_turret_system):
		hunter_auto_turret_system.queue_free()
	hunter_auto_turret_system = null


func _on_ammo_changed(current_magazine: int, total_ammo: int) -> void:
	# TODO: 鏇存柊 HUD 寮硅嵂鏄剧ず
	pass


# =============================================================================
# Hunter 杈撳叆澶勭悊
# =============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if not _is_local_authority():
		return
	if _is_dead:
		_handle_dead_spectator_input(event)
		return
	if event.is_action_pressed(UNSTUCK_ACTION):
		_request_unstuck()
		get_viewport().set_input_as_handled()
		return
	if match_intro_locked:
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(HOLOGRAM_FLAG_ACTION):
		if _request_hologram_flag_placement():
			get_viewport().set_input_as_handled()
		return
	# Middle-click world ping (all factions). Only while the game owns the cursor
	# so it doesn't fire over menus / the console / a radial wheel.
	if event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_MIDDLE \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_request_map_ping()
		get_viewport().set_input_as_handled()
		return

	# Hunter 杈撳叆
	if is_hunter():
		_handle_hunter_input(event)

	# Chameleon 杈撳叆
	if is_chameleon():
		_handle_chameleon_input(event)

	if is_stalker():
		_handle_stalker_input(event)


func _handle_dead_spectator_input(event: InputEvent) -> void:
	var blocked_actions := [
		UNSTUCK_ACTION,
		HOLOGRAM_FLAG_ACTION,
		"shoot",
		"reload",
		"paint_trigger",
		"flashlight",
		"camouflage_absorb",
		"shape_shift",
		"stalker_grapple"
	]
	for action in blocked_actions:
		if not InputMap.has_action(action):
			continue
		if event.is_action_pressed(action) or event.is_action_released(action):
			get_viewport().set_input_as_handled()
			return


func _handle_hunter_input(event: InputEvent) -> void:
	# 鍑嗗闃舵閿佸畾涓嶈兘寮€鏋?
	if prep_phase_locked:
		return

	if event.is_action_pressed("flashlight") and hunter_flashlight_system:
		hunter_flashlight_system.request_toggle()
		get_viewport().set_input_as_handled()

	var weapon = get_node_or_null("WeaponSystem")
	if not weapon:
		return

	# 寮€鐏?
	if event.is_action_pressed("shoot"):
		weapon.request_fire()
	# 鎹㈠脊
	if event.is_action_pressed("reload"):
		weapon.request_reload()
	if event.is_action_pressed("paint_trigger") and weapon.has_method("request_scan"):
		weapon.request_scan()


func _handle_chameleon_input(event: InputEvent) -> void:
	if not camouflage_system and not shape_system:
		return

	if camouflage_system and camouflage_system.is_brush_mode():
		if camouflage_system.handle_brush_input(event):
			get_viewport().set_input_as_handled()
		return

	# Environment blend: C toggles the paintable camouflage tool.
	if event.is_action_pressed("camouflage_absorb") and camouflage_system:
		camouflage_system.toggle_skill()
		get_viewport().set_input_as_handled()
		return

	# 鍙樺舰杞洏:Q 鍒囨崲寮€/鍏?
	if event.is_action_pressed("shape_shift") and shape_system:
		if shape_system.has_method("has_nearby_replicable_prop") and shape_system.has_nearby_replicable_prop():
			shape_system.try_replicate_nearby_prop()
			return
		var wheel = _get_shape_wheel()
		if wheel and not wheel.visible:
			wheel.show_wheel(shape_system)
			# Lock movement while the wheel is up.
			shape_system.open_wheel()
		return
	if event.is_action_released("shape_shift") and shape_system:
		var wheel = _get_shape_wheel()
		if wheel and wheel.visible:
			wheel.release_select()
		return


func _handle_stalker_input(event: InputEvent) -> void:
	if prep_phase_locked:
		return
	if event.is_action_pressed("stalker_grapple") and stalker_grapple_system:
		if stalker_grapple_system.request_grapple():
			get_viewport().set_input_as_handled()


func _request_hologram_flag_placement() -> bool:
	if _is_dead:
		return true
	var level := get_tree().get_current_scene() if get_tree() else null
	if not level or not level.has_method("request_place_hologram_flag"):
		return false
	var owner_id := get_multiplayer_authority()
	var flag_transform := _get_hologram_flag_placement_transform()
	var accessories := get_party_monster_accessory_loadout()
	level.call(
		"request_place_hologram_flag",
		owner_id,
		flag_transform,
		character_model_id,
		accessories,
		_get_hologram_skin_color(),
		_get_hologram_player_height(),
		get_network_input_tick(),
		allocate_network_intent_sequence()
	)
	return true


func _get_hologram_flag_placement_transform() -> Transform3D:
	var camera := get_node_or_null("SpringArmOffset/SpringArm3D/Camera3D") as Camera3D
	var ray_origin := global_position + Vector3.UP * 1.45
	var forward := -global_transform.basis.z.normalized()
	if camera:
		ray_origin = camera.global_position
		forward = -camera.global_transform.basis.z.normalized()
	var target := ray_origin + forward * HOLOGRAM_FLAG_FALLBACK_DISTANCE
	var world := get_world_3d()
	if world:
		var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + forward * HOLOGRAM_FLAG_PLACEMENT_RANGE, WORLD_COLLISION_MASK)
		query.exclude = [get_rid()]
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var hit := world.direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			target = hit.get("position", target)
		target = _resolve_hologram_flag_ground_position(target)
	var to_camera := ray_origin - target
	to_camera.y = 0.0
	if to_camera.length_squared() <= 0.001:
		to_camera = -forward
		to_camera.y = 0.0
	if to_camera.length_squared() <= 0.001:
		to_camera = Vector3.FORWARD
	to_camera = to_camera.normalized()
	var yaw := atan2(-to_camera.x, -to_camera.z)
	return Transform3D(Basis(Vector3.UP, yaw), target)


# Raycast from the camera and broadcast a world ping at the hit point.
func _request_map_ping() -> void:
	var camera := get_node_or_null("SpringArmOffset/SpringArm3D/Camera3D") as Camera3D
	var ray_origin := global_position + Vector3.UP * 1.45
	var forward := -global_transform.basis.z.normalized()
	if camera:
		ray_origin = camera.global_position
		forward = -camera.global_transform.basis.z.normalized()
	var target := ray_origin + forward * MAP_PING_RANGE
	var world := get_world_3d()
	if world:
		var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + forward * MAP_PING_RANGE, WORLD_COLLISION_MASK)
		query.exclude = [get_rid()]
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var hit := world.direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			target = hit.get("position", target)
	_map_ping.rpc(target)


# Cosmetic map ping. Runs on every peer; only the pinger and same-team viewers
# render it (so it doesn't hand enemies free intel).
@rpc("any_peer", "call_local", "reliable")
func _map_ping(world_pos: Vector3) -> void:
	if int(str(name)) != _local_peer_id() and not is_ally_of_local_viewer():
		return
	get_tree().call_group("map_ping_hud", "register_ping", world_pos)


func _resolve_hologram_flag_ground_position(position: Vector3) -> Vector3:
	var world := get_world_3d()
	if not world:
		return position
	var query := PhysicsRayQueryParameters3D.create(
		position + Vector3.UP * HOLOGRAM_FLAG_GROUND_RAY_UP,
		position + Vector3.DOWN * HOLOGRAM_FLAG_GROUND_RAY_DOWN,
		WORLD_COLLISION_MASK
	)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return position
	return hit.get("position", position)


func _get_hologram_skin_color() -> int:
	var owner_id := get_multiplayer_authority()
	if Network.players.has(owner_id):
		return int(Network.players[owner_id].get("skin", Network.SKIN_BLUE))
	if Network.players.has(str(owner_id)):
		return int(Network.players[str(owner_id)].get("skin", Network.SKIN_BLUE))
	return Network.SKIN_BLUE


func _get_hologram_player_height() -> float:
	if _body and is_instance_valid(_body):
		var bounds := _calculate_node_bounds(_body)
		if bounds.size.y > 0.1:
			return clampf(bounds.size.y, 0.8, 4.0)
	if _collision_shape and _collision_shape.shape:
		if _collision_shape.shape is CapsuleShape3D:
			var capsule := _collision_shape.shape as CapsuleShape3D
			return clampf(capsule.height + capsule.radius * 2.0, 0.8, 4.0)
		if _collision_shape.shape is BoxShape3D:
			return clampf((_collision_shape.shape as BoxShape3D).size.y, 0.8, 4.0)
	return 2.0


func _resolve_player_input_state() -> PlayerInputState:
	if _player_input_state and is_instance_valid(_player_input_state):
		return _player_input_state
	_player_input_state = get_node_or_null("PlayerInputState") as PlayerInputState
	return _player_input_state


func _has_fresh_player_input_state(max_age_ticks: int = -1) -> bool:
	var input_state: PlayerInputState = _resolve_player_input_state()
	return input_state != null and input_state.has_fresh_sample(max_age_ticks)


func _movement_input_vector() -> Vector2:
	var input_state: PlayerInputState = _resolve_player_input_state()
	if input_state != null and input_state.has_fresh_sample():
		return input_state.move_axis
	return Input.get_vector("move_left", "move_right", "move_forward", "move_backward")


func _input_action_just_pressed(action: String) -> bool:
	if not _is_local_authority():
		return false
	var input_state: PlayerInputState = _resolve_player_input_state()
	if input_state != null and input_state.has_fresh_sample():
		return input_state.is_action_just_pressed(action)
	return InputMap.has_action(action) and Input.is_action_just_pressed(action)


func _input_action_held(action: String) -> bool:
	if not _is_local_authority():
		return false
	var input_state: PlayerInputState = _resolve_player_input_state()
	if input_state != null and input_state.has_fresh_sample():
		return input_state.is_action_held(action)
	return InputMap.has_action(action) and Input.is_action_pressed(action)


func get_network_input_tick() -> int:
	var input_state: PlayerInputState = _resolve_player_input_state()
	if input_state != null and input_state.tick >= 0:
		return input_state.tick
	return NetworkTime.tick


func allocate_network_intent_sequence() -> int:
	var input_state: PlayerInputState = _resolve_player_input_state()
	if input_state != null:
		return input_state.allocate_intent_sequence()
	return int(Time.get_ticks_msec() & 0x7fffffff)


func _resolve_player_action_bus() -> PlayerActionBus:
	if _player_action_bus and is_instance_valid(_player_action_bus):
		return _player_action_bus
	_player_action_bus = get_node_or_null("PlayerActionBus") as PlayerActionBus
	return _player_action_bus


func _resolve_player_movement_motor() -> PlayerMovementMotor:
	if _player_movement_motor and is_instance_valid(_player_movement_motor):
		return _player_movement_motor
	_player_movement_motor = get_node_or_null("MovementMotor") as PlayerMovementMotor
	return _player_movement_motor


func get_rollback_movement_config() -> Dictionary:
	return {
		"walk_speed": NORMAL_SPEED,
		"run_speed": SPRINT_SPEED,
		"jump_velocity": JUMP_VELOCITY,
		"gravity": gravity,
		"ground_acceleration": GROUND_ACCELERATION,
		"ground_deceleration": GROUND_DECELERATION,
		"air_acceleration": AIR_ACCELERATION,
		"air_deceleration": AIR_DECELERATION,
		"speed_multiplier": _card_speed_multiplier,
		"fall_gravity_multiplier": FALL_GRAVITY_MULTIPLIER,
		"jump_locked": _jump_suppress_remaining > 0.0,
	}


func allows_rollback_movement_drive() -> bool:
	if not _is_local_authority():
		return false
	if _rollback_teleport_settle_remaining > 0.0:
		return false
	if _is_dead or match_intro_locked:
		return false
	if _card_stasis_remaining > 0.0:
		return false
	if _party_monster_trip_action_locked:
		return false
	if _camouflage_brush_locked:
		return false
	var current_scene: Node = get_tree().get_current_scene()
	if current_scene and is_on_floor():
		if current_scene.has_method("is_chat_visible") and current_scene.is_chat_visible():
			return false
		if current_scene.has_method("is_inventory_visible") and current_scene.is_inventory_visible():
			return false
	return true


func _is_rollback_movement_active() -> bool:
	var movement_motor: PlayerMovementMotor = _resolve_player_movement_motor()
	return movement_motor != null and movement_motor.apply_simulation_to_player_root and allows_rollback_movement_drive()


func _on_rollback_movement_jump(jump_type: String, input_sequence: int, _tick: int) -> void:
	if not _is_local_authority():
		return
	if input_sequence <= 0 or input_sequence == _rollback_movement_jump_sequence:
		return
	_rollback_movement_jump_sequence = input_sequence
	_play_body_jump(jump_type)


func publish_network_action(action_name: String, payload: Dictionary = {}) -> Dictionary:
	if not _is_local_authority():
		return {}
	var action_bus: PlayerActionBus = _resolve_player_action_bus()
	if action_bus == null:
		return {}
	return action_bus.publish_action(action_name, payload)


func apply_network_action_event(event: Dictionary) -> void:
	if int(event.get("source_peer_id", 0)) == _local_peer_id():
		return
	var raw_payload: Variant = event.get("payload", {})
	var payload: Dictionary = {}
	if raw_payload is Dictionary:
		payload = raw_payload
	match str(event.get("action", "")):
		"jump":
			_apply_network_jump_action(payload)
		"land":
			_apply_network_land_action()
		"skin_performance":
			_apply_network_skin_performance_action(payload)
		"party_monster_trip":
			_apply_network_party_monster_trip_action(payload)
		"flashlight_exposure":
			_apply_network_flashlight_exposure_action(payload)
		"visual_action":
			_apply_network_visual_action_event(payload)
		"stand_up":
			_apply_network_stand_up_action()
		_:
			pass


func _apply_network_visual_action_event(payload: Dictionary) -> void:
	# Reliable mirror of an important visual action (fall/land/dizzy/trip/getup). Apply only
	# when newer than what we have shown so a late reliable packet can't replay a stale action.
	if _is_local_authority():
		return
	var action: String = _normalize_network_visual_action(str(payload.get("action", "")))
	if action.is_empty():
		return
	var seq: int = int(payload.get("seq", 0))
	if seq > 0 and seq <= _network_visual_applied_action_sequence:
		return
	_network_visual_action = action
	if seq > 0:
		_network_visual_action_sequence = seq
		_network_visual_applied_action_sequence = -1
	_network_visual_state_msec = Time.get_ticks_msec()
	# A knockdown must HOLD on peers: lock so the velocity-fallback locomotion (driven by the
	# trip's knockback motion) can't override the trip pose before the owner stands up.
	if action == "trip" and not _party_monster_trip_action_locked:
		_begin_party_monster_trip_lock()
	_play_synced_network_visual_action(action)


func _apply_network_jump_action(payload: Dictionary) -> void:
	var jump_type: String = str(payload.get("jump_type", "Jump"))
	_play_audio(_jump_audio)
	if _active_skin_node:
		_play_skin_action("jump")
	elif _body and _body.has_method("play_jump_animation"):
		_body.play_jump_animation(jump_type)


func _apply_network_land_action() -> void:
	_play_audio(_land_audio)
	if _active_skin_node:
		_play_skin_action("land")


func _apply_network_skin_performance_action(payload: Dictionary) -> void:
	var action: String = _normalize_skin_performance_action(str(payload.get("action", "")))
	if action.is_empty():
		return
	if _skin_performance_camera_active and _skin_performance_camera_action == action:
		return
	_apply_skin_performance_action_rpc(action)


func _apply_network_party_monster_trip_action(payload: Dictionary) -> void:
	var direction: Vector3 = Vector3.ZERO
	var raw_direction: Variant = payload.get("direction", Vector3.ZERO)
	if raw_direction is Vector3:
		direction = raw_direction
	if _party_monster_trip_action_locked:
		return
	_play_party_monster_trip_reaction(_sanitize_party_monster_trip_direction(direction))


func _apply_network_flashlight_exposure_action(payload: Dictionary) -> void:
	if not is_stalker():
		return
	var sample_seconds: float = clampf(float(payload.get("sample_seconds", 0.0)), 0.0, 0.5)
	if sample_seconds <= 0.0:
		return
	if shadow_visibility and is_instance_valid(shadow_visibility) and shadow_visibility.has_method("apply_hunter_flashlight_rewind_exposure"):
		shadow_visibility.call("apply_hunter_flashlight_rewind_exposure", sample_seconds)
		_refresh_stalker_visibility_view(true)


func _process_input_held():
	# 鍦?_process 涓寔缁娴?shoot / paint 鎸変綇鐘舵€?
	if not _is_local_authority():
		return
	if _is_dead:
		return
	if match_intro_locked:
		return
	if _party_monster_trip_action_locked:
		return

	# Hunter 鎸佺画寮€鐏?
	if is_hunter():
		if prep_phase_locked:
			return
		var weapon = get_node_or_null("WeaponSystem")
		if weapon and _input_action_held("shoot"):
			weapon.request_fire()

	# Chameleon 鎸佺画鍠锋秱
	if is_chameleon():
		if camouflage_system and camouflage_system.is_brush_mode():
			return


# 鏌ユ壘 level 涓殑鍙樺舰杞洏 UI
func _get_shape_wheel() -> ShapeShiftWheelUI:
	var level = get_tree().get_current_scene() if get_tree() else null
	if not level:
		return null
	var wheel = level.get_node_or_null("ShapeShiftWheelUI")
	if wheel and wheel is ShapeShiftWheelUI:
		return wheel
	return null


func _sync_role_from_network() -> void:
	var my_id = str(name).to_int()
	if Network.players.has(my_id):
		role = Network.players[my_id].get("role", Network.Role.NONE)
	else:
		role = Network.Role.NONE
	_apply_role_max_health()


func _sync_character_model_from_network() -> void:
	var my_id = str(name).to_int()
	if Network.players.has(my_id):
		set_character_model(str(Network.players[my_id].get("character_model", CharacterSkinCatalog.DEFAULT_ID)))
	else:
		set_character_model(CharacterSkinCatalog.DEFAULT_ID)


func _sync_party_monster_accessories_from_network() -> void:
	var my_id = str(name).to_int()
	if Network.players.has(my_id):
		set_party_monster_accessory_loadout(Network.players[my_id].get("party_monster_accessories", {}))
	else:
		set_party_monster_accessory_loadout({})


func _on_party_monster_accessories_changed(peer_id: int, loadout: Dictionary) -> void:
	if peer_id == str(name).to_int():
		set_party_monster_accessory_loadout(loadout)


func _on_role_changed(peer_id: int, new_role: int) -> void:
	if peer_id == str(name).to_int():
		role = new_role
		_apply_role_max_health()
		_sync_character_model_from_network()
		_sync_party_monster_accessories_from_network()
		if _should_log_runtime_debug():
			print("[Player ", name, "] Role updated to ", Network.role_to_string(new_role))
		if new_role != Network.Role.STALKER and shadow_visibility:
			_teardown_stalker_systems()
		if new_role != Network.Role.HUNTER and hunter_flashlight_system:
			_teardown_hunter_flashlight()
		if new_role != Network.Role.HUNTER and hunter_prop_sense_system:
			_teardown_hunter_prop_sense()
		if new_role != Network.Role.HUNTER and hunter_auto_turret_system:
			_teardown_hunter_auto_turret()
		# 濡傛灉鏄?Hunter 涓旇繕娌℃寕姝﹀櫒,琛ユ寕
		if new_role == Network.Role.HUNTER:
			_setup_hunter_systems()
		elif new_role == Network.Role.CHAMELEON and _is_local_authority() and not has_node("CamouflageSystem"):
			_setup_chameleon_systems()
		elif new_role == Network.Role.STALKER:
			_setup_stalker_systems()


# =============================================================================
# 瑙掕壊 helper
# =============================================================================
func is_chameleon() -> bool:
	return role == Network.Role.CHAMELEON

func is_stalker() -> bool:
	return role == Network.Role.STALKER

func is_hunter() -> bool:
	return role == Network.Role.HUNTER

func is_prop() -> bool:
	return role == Network.Role.CHAMELEON or role == Network.Role.STALKER


# =============================================================================
# 鍑嗗闃舵閿佸畾(鏈嶅姟鍣ㄦ帶鍒?Hunter 涓嶈兘绉诲姩)
# =============================================================================
func set_prep_locked(locked: bool) -> void:
	prep_phase_locked = locked
	_skin_performance_input_block_remaining = maxf(_skin_performance_input_block_remaining, SKIN_PERFORMANCE_INPUT_START_BLOCK_SECONDS)
	if locked:
		_restore_skin_performance_camera_now()
		# Ready-room PREP suppresses hunter tools, but movement stays enabled.
		_set_player_tint(Color(1, 1, 1))
		return
	if locked:
		# 鍋滄浠讳綍绉诲姩
		velocity = Vector3.ZERO
		_current_speed = 0.0
		# 瑙嗚鎻愮ず(3D 鑺傜偣娌℃湁 modulate,鏀圭敤 mesh material albedo_color)
		_set_player_tint(Color(0.5, 0.5, 0.5))
	else:
		_set_player_tint(Color(1, 1, 1))


func set_match_intro_locked(locked: bool) -> void:
	match_intro_locked = locked
	_skin_performance_input_block_remaining = maxf(_skin_performance_input_block_remaining, SKIN_PERFORMANCE_INPUT_START_BLOCK_SECONDS)
	if locked:
		_restore_skin_performance_camera_now()
		velocity = Vector3.ZERO
		_current_speed = 0.0


func _set_player_tint(color: Color) -> void:
	# 閬嶅巻鎵€鏈?MeshInstance3D,鏀?albedo_color(3D 鐗?modulate)
	var meshes: Array[MeshInstance3D] = []
	_find_meshes(self, meshes)
	for mesh_inst in meshes:
		for i in range(_get_mesh_surface_count(mesh_inst)):
			var source_material := _get_mesh_surface_material(mesh_inst, i)
			if not source_material is StandardMaterial3D:
				continue
			var material := source_material as StandardMaterial3D
			if not bool(material.get_meta("player_tint_unique", false)):
				material = material.duplicate()
				material.resource_local_to_scene = true
				material.set_meta("player_tint_unique", true)
				mesh_inst.set_surface_override_material(i, material)
			material.albedo_color = color


func _find_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		_find_meshes(child, result)


func _set_active_skin_animation_paused(paused: bool) -> void:
	if paused:
		if not _active_skin_node or not is_instance_valid(_active_skin_node):
			return
		if _active_skin_node.has_method("set_animation_paused"):
			_active_skin_node.call("set_animation_paused", true)
		var players: Array[AnimationPlayer] = []
		_find_animation_players(_active_skin_node, players)
		for animation_player in players:
			var key := animation_player.get_instance_id()
			if not _camouflage_paused_animation_players.has(key):
				_camouflage_paused_animation_players[key] = {
					"player": animation_player,
					"speed_scale": animation_player.speed_scale,
				}
			animation_player.speed_scale = 0.0
		return

	for key in _camouflage_paused_animation_players.keys():
		var pause_info := _camouflage_paused_animation_players[key] as Dictionary
		var animation_player := pause_info.get("player", null) as AnimationPlayer
		if animation_player and is_instance_valid(animation_player):
			animation_player.speed_scale = float(pause_info.get("speed_scale", 1.0))
	_camouflage_paused_animation_players.clear()
	if _active_skin_node and is_instance_valid(_active_skin_node) and _active_skin_node.has_method("set_animation_paused"):
		_active_skin_node.call("set_animation_paused", false)


func _find_animation_players(node: Node, result: Array[AnimationPlayer]) -> void:
	if node is AnimationPlayer:
		result.append(node as AnimationPlayer)
	for child in node.get_children():
		_find_animation_players(child, result)


func _force_active_skin_skeleton_update() -> void:
	if _active_skin_node and is_instance_valid(_active_skin_node):
		_force_skeleton_update_recursive(_active_skin_node)
	_force_skeleton_update_recursive(_body)


func _force_skeleton_update_recursive(node: Node) -> void:
	if not node:
		return
	if node is Skeleton3D:
		(node as Skeleton3D).force_update_all_bone_transforms()
	for child in node.get_children():
		_force_skeleton_update_recursive(child)

func _physics_process_rollback_movement(delta: float) -> void:
	var movement_motor: PlayerMovementMotor = _resolve_player_movement_motor()
	var was_on_floor: bool = _rollback_movement_previous_grounded
	if movement_motor != null:
		can_double_jump = movement_motor.simulated_can_double_jump
		has_double_jumped = movement_motor.simulated_has_double_jumped
		_current_speed = movement_motor.simulated_current_speed
	else:
		_current_speed = Vector2(velocity.x, velocity.z).length()
	var impact_velocity: Vector3 = velocity
	if not _try_party_monster_trip_from_slide_collisions(impact_velocity, was_on_floor):
		_try_party_monster_trip_from_forward_sensor(impact_velocity, was_on_floor)
	if _apply_prop_collision_impacts(impact_velocity) and impact_velocity.y <= 0.1:
		velocity.y = minf(velocity.y, 0.0)
		if movement_motor != null:
			movement_motor.simulated_velocity = velocity
	_update_safe_ground_position()
	_animate_body(velocity)
	_update_movement_audio(delta, was_on_floor)
	_rollback_movement_previous_grounded = is_on_floor()


func _physics_process(delta):
	if not _is_local_authority(): return

	if _rollback_teleport_settle_remaining > 0.0:
		_rollback_teleport_settle_remaining = maxf(0.0, _rollback_teleport_settle_remaining - delta)
	if _jump_suppress_remaining > 0.0:
		_jump_suppress_remaining = maxf(0.0, _jump_suppress_remaining - delta)

	# Knockdown hard-locks movement (and handles the stand-up key) BEFORE any movement path runs,
	# so a downed player can never move via the rollback motor or the legacy fall-through.
	if _party_monster_trip_action_locked:
		if not (_stand_up_system.is_awaiting() and _input_action_just_pressed("jump") and _stand_up_system.consume()):
			var trip_was_on_floor := is_on_floor()
			velocity.x = 0.0
			velocity.z = 0.0
			if not is_on_floor():
				velocity.y -= gravity * delta
			else:
				velocity.y = minf(velocity.y, 0.0)
			_current_speed = 0.0
			_animate_body(Vector3.ZERO)
			move_and_slide()
			_update_safe_ground_position()
			_update_movement_audio(delta, trip_was_on_floor)
			return
		_perform_stand_up()

	if _is_rollback_movement_active():
		_physics_process_rollback_movement(delta)
		return

	if _is_dead:
		_process_dead_free_camera(delta)
		move_and_slide()
		return

	if match_intro_locked:
		velocity = Vector3.ZERO
		_current_speed = 0.0
		_animate_body(Vector3.ZERO)
		move_and_slide()
		return

	if _card_stasis_remaining > 0.0:
		velocity = Vector3.ZERO
		_current_speed = 0.0
		_animate_body(Vector3.ZERO)
		move_and_slide()
		return

	if _camouflage_brush_locked and _chameleon_sculpt_shell_active:
		_process_sculpt_free_fly(delta)
		move_and_slide()
		return

	if _camouflage_brush_locked:
		freeze()
		move_and_slide()
		return

	# 鍑嗗闃舵 Hunter 閿佸畾(涓嶈兘绉诲姩)
	if is_hunter() and prep_phase_locked:
		pass

	var current_scene = get_tree().get_current_scene()
	if current_scene and is_on_floor():
		var should_freeze = false
		if current_scene.has_method("is_chat_visible") and current_scene.is_chat_visible():
			should_freeze = true
		elif current_scene.has_method("is_inventory_visible") and current_scene.is_inventory_visible():
			should_freeze = true

		if should_freeze:
			freeze()
			return

	var was_on_floor := is_on_floor()
	var jump_allowed := _jump_suppress_remaining <= 0.0
	if is_on_floor():
		can_double_jump = true
		has_double_jumped = false

		if jump_allowed and _input_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
			can_double_jump = true
			_play_body_jump("Jump")
	else:
		if jump_allowed and can_double_jump and not has_double_jumped and _input_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
			has_double_jumped = true
			can_double_jump = false
			_play_body_jump("Jump2")

	velocity.y -= gravity * (FALL_GRAVITY_MULTIPLIER if velocity.y < 0.0 else 1.0) * delta

	_move(delta)
	var impact_velocity := velocity
	move_and_slide()
	if not _try_party_monster_trip_from_slide_collisions(impact_velocity, was_on_floor):
		_try_party_monster_trip_from_forward_sensor(impact_velocity, was_on_floor)
	if _apply_prop_collision_impacts(impact_velocity) and impact_velocity.y <= 0.1:
		velocity.y = minf(velocity.y, 0.0)
	_update_safe_ground_position()
	_animate_body(velocity)
	_update_movement_audio(delta, was_on_floor)

func _process(delta: float) -> void:
	var is_local_player: bool = _is_local_authority()
	if not is_local_player:
		if _is_dedicated_public_server_runtime():
			return
		# Drive the remote skin animation EVERY frame so it is as smooth as the
		# netfox-interpolated position. Previously animation only advanced on the
		# 30Hz throttled tick, so it stuttered while movement stayed smooth.
		_animate_remote_skin_from_network_motion(delta)
		# Throttle only the heavier per-remote bookkeeping (cards / feedback / GPU).
		_remote_visual_process_elapsed += maxf(delta, 0.0)
		if _remote_visual_process_elapsed < REMOTE_VISUAL_PROCESS_INTERVAL:
			return
		var remote_visual_delta: float = _remote_visual_process_elapsed
		_remote_visual_process_elapsed = 0.0
		_process_remote_visual_frame(remote_visual_delta)
		return
	_process_card_effects(delta)
	if _should_run_camouflage_gpu_painter():
		_process_camouflage_gpu_painter(delta)
	else:
		_clear_camouflage_gpu_runtime_work()
	_process_shared_visual_feedback_frame(delta, true)
	_process_skin_performance_wheel_bar(delta)
	_check_fall_and_respawn()
	# Hunter 鎸佺画寮€鐏娴?
	_process_input_held()
	_process_prop_disguise_height(delta)

func _process_remote_visual_frame(delta: float) -> void:
	# Animation is now driven every frame in _process; this throttled path only
	# handles the heavier per-remote bookkeeping.
	_process_card_effects(delta)
	if not _camouflage_gpu_stroke_queue.is_empty() or _camouflage_gpu_draw_timer > 0.0:
		_clear_camouflage_gpu_runtime_work()
	_process_shared_visual_feedback_frame(delta, false)


func _process_shared_visual_feedback_frame(delta: float, is_local_player: bool) -> void:
	if _skin_performance_input_block_remaining > 0.0:
		_skin_performance_input_block_remaining = maxf(0.0, _skin_performance_input_block_remaining - delta)
	if _party_monster_trip_cooldown > 0.0:
		_party_monster_trip_cooldown = maxf(0.0, _party_monster_trip_cooldown - delta)
	if _party_monster_trip_reaction_lock_remaining > 0.0:
		_party_monster_trip_reaction_lock_remaining = maxf(0.0, _party_monster_trip_reaction_lock_remaining - delta)
		if _party_monster_trip_action_locked and _party_monster_trip_reaction_lock_remaining <= 0.0:
			# Trip animation finished: stay down and wait for the player to stand up (press jump)
			# instead of auto-recovering. Movement stays locked while _party_monster_trip_action_locked.
			_stand_up_system.begin()
	# Safety: the owner auto-stands after a long hold so a missed input can never strand them.
	if _stand_up_system.tick(delta, _is_local_authority()):
		_perform_stand_up()
	if is_stalker():
		if is_local_player:
			_refresh_stalker_visibility_view(false)
		else:
			_refresh_nickname_visibility(_stalker_synced_visibility_alpha)
	else:
		_refresh_nickname_visibility()
	_process_party_monster_bounty_feedback(delta)
	_process_hunter_prop_sense_feedback(delta)


func freeze():
	velocity.x = 0
	velocity.z = 0
	_current_speed = 0
	_animate_body(Vector3.ZERO)

func _move(delta: float) -> void:
	var _input_direction: Vector2 = _movement_input_vector() if _is_local_authority() else Vector2.ZERO

	var camera_basis := _spring_arm_offset.global_transform.basis if _spring_arm_offset else global_transform.basis
	var camera_forward := -camera_basis.z
	camera_forward.y = 0.0
	camera_forward = camera_forward.normalized()
	var camera_right := camera_basis.x
	camera_right.y = 0.0
	camera_right = camera_right.normalized()
	var _direction := (camera_right * _input_direction.x + camera_forward * -_input_direction.y)
	if _direction.length_squared() > 1.0:
		_direction = _direction.normalized()

	is_running()
	_current_speed *= _card_speed_multiplier
	var has_move_input := _direction.length_squared() > TURN_INPUT_DEADZONE * TURN_INPUT_DEADZONE
	var target_horizontal_velocity := Vector3.ZERO
	if has_move_input:
		target_horizontal_velocity = _direction.normalized() * _current_speed

	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var acceleration := GROUND_ACCELERATION if has_move_input else GROUND_DECELERATION
	if not is_on_floor():
		acceleration = AIR_ACCELERATION if has_move_input else AIR_DECELERATION
	horizontal_velocity = horizontal_velocity.move_toward(target_horizontal_velocity, acceleration * delta)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	if has_move_input:
		_apply_body_rotation(velocity)


func _process_sculpt_free_fly(delta: float) -> void:
	var input_direction: Vector2 = _movement_input_vector()
	var camera_basis := _spring_arm_offset.global_transform.basis if _spring_arm_offset else global_transform.basis
	var forward := -camera_basis.z.normalized()
	var right := camera_basis.x.normalized()
	var direction := right * input_direction.x + forward * -input_direction.y
	if _input_action_held("jump"):
		direction += Vector3.UP * SCULPT_FREE_FLY_VERTICAL_SPEED_FACTOR
	if Input.is_physical_key_pressed(KEY_CTRL):
		direction -= Vector3.UP * SCULPT_FREE_FLY_VERTICAL_SPEED_FACTOR
	if direction.length_squared() > 1.0:
		direction = direction.normalized()
	var speed := SPRINT_SPEED if _input_action_held("shift") else NORMAL_SPEED
	var target_velocity := direction * speed
	var acceleration := SCULPT_FREE_FLY_ACCELERATION if direction.length_squared() > TURN_INPUT_DEADZONE * TURN_INPUT_DEADZONE else SCULPT_FREE_FLY_DECELERATION
	velocity = velocity.move_toward(target_velocity, acceleration * delta)
	_current_speed = velocity.length()


func _process_dead_free_camera(delta: float) -> void:
	_ensure_dead_free_spectator()
	var input_direction: Vector2 = _movement_input_vector()
	var camera_basis: Basis = _spring_arm_offset.global_transform.basis if _spring_arm_offset else global_transform.basis
	var forward: Vector3 = -camera_basis.z.normalized()
	var right: Vector3 = camera_basis.x.normalized()
	var direction: Vector3 = right * input_direction.x + forward * -input_direction.y
	if _input_action_held("jump"):
		direction += Vector3.UP * DEAD_FREE_CAM_VERTICAL_SPEED_FACTOR
	if Input.is_physical_key_pressed(KEY_CTRL):
		direction -= Vector3.UP * DEAD_FREE_CAM_VERTICAL_SPEED_FACTOR
	if direction.length_squared() > 1.0:
		direction = direction.normalized()
	var speed: float = DEAD_FREE_CAM_SPRINT_SPEED if _input_action_held("shift") else DEAD_FREE_CAM_NORMAL_SPEED
	var target_velocity: Vector3 = direction * speed
	var has_input: bool = direction.length_squared() > TURN_INPUT_DEADZONE * TURN_INPUT_DEADZONE
	var acceleration: float = DEAD_FREE_CAM_ACCELERATION if has_input else DEAD_FREE_CAM_DECELERATION
	velocity = velocity.move_toward(target_velocity, acceleration * delta)
	_current_speed = velocity.length()


func _ensure_dead_free_spectator() -> void:
	if _dead_free_camera_active:
		return
	_dead_free_camera_active = true
	_set_dead_collision_enabled(false)
	_hide_dead_tool_visuals()
	_reset_skin_performance_wheel_bar()
	_restore_skin_performance_camera_now()
	can_double_jump = false
	has_double_jumped = true
	velocity = Vector3.ZERO
	_current_speed = 0.0
	if _spring_arm_offset and _spring_arm_offset.has_method("set_camera_rig_pose"):
		var current_yaw: float = _spring_arm_offset.rotation.y
		var spring_arm := _spring_arm_offset.get_node_or_null("SpringArm3D") as SpringArm3D
		var current_pitch: float = spring_arm.rotation.x if spring_arm else deg_to_rad(-6.0)
		_spring_arm_offset.call("set_camera_rig_pose", current_yaw, current_pitch, DEAD_FREE_CAM_SPRING_LENGTH, DEAD_FREE_CAM_FOV, true)
	var camera := get_node_or_null("SpringArmOffset/SpringArm3D/Camera3D") as Camera3D
	if camera:
		camera.current = true
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _exit_dead_free_spectator() -> void:
	_dead_free_camera_active = false
	_set_dead_collision_enabled(true)
	_restore_dead_tool_visuals()
	can_double_jump = true
	has_double_jumped = false
	velocity = Vector3.ZERO
	_current_speed = 0.0


func _set_dead_collision_enabled(enabled: bool) -> void:
	if _collision_shape and is_instance_valid(_collision_shape):
		_collision_shape.set_deferred("disabled", not enabled)
		_collision_shape.disabled = not enabled


func _hide_dead_tool_visuals() -> void:
	var weapon_visual := get_node_or_null("SpringArmOffset/SpringArm3D/Camera3D/WeaponVisual") as Node3D
	if weapon_visual and weapon_visual.visible:
		weapon_visual.visible = false
		_dead_weapon_visual_hidden = true
	if hunter_flashlight_system and is_instance_valid(hunter_flashlight_system):
		if hunter_flashlight_system.has_method("_apply_flashlight_state"):
			hunter_flashlight_system.call("_apply_flashlight_state", false, 0.0, 0.0)
	var wheel := _get_shape_wheel()
	if wheel and wheel.visible:
		wheel.hide_wheel()
	if camouflage_system and camouflage_system.has_method("is_brush_mode") and camouflage_system.call("is_brush_mode"):
		if camouflage_system.has_method("toggle_skill"):
			camouflage_system.call("toggle_skill")
	_camouflage_brush_locked = false


func _restore_dead_tool_visuals() -> void:
	var weapon_visual := get_node_or_null("SpringArmOffset/SpringArm3D/Camera3D/WeaponVisual") as Node3D
	if weapon_visual and _dead_weapon_visual_hidden and is_hunter():
		weapon_visual.visible = true
	_dead_weapon_visual_hidden = false


func _apply_prop_collision_impacts(impact_velocity: Vector3) -> bool:
	var horizontal_speed := Vector2(impact_velocity.x, impact_velocity.z).length()
	if horizontal_speed < 1.0:
		return false
	var impacted: Dictionary = {}
	var did_impact := false
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		if not collision:
			continue
		var collider := collision.get_collider()
		if not collider or not collider.has_method("apply_player_impact"):
			continue
		var collider_id := collider.get_instance_id()
		if impacted.has(collider_id):
			continue
		impacted[collider_id] = true
		collider.apply_player_impact(impact_velocity, collision.get_position(), collision.get_normal(), _is_prop_disguised, get_network_input_tick())
		did_impact = true
	did_impact = _apply_nearby_prop_impacts(impact_velocity, impacted) or did_impact
	return did_impact


func _try_party_monster_trip_from_slide_collisions(impact_velocity: Vector3, was_on_floor: bool) -> bool:
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		if not collision:
			continue
		if _try_party_monster_trip_from_collision(impact_velocity, collision, was_on_floor):
			return true
	return false


func _try_party_monster_trip_from_collision(impact_velocity: Vector3, collision: KinematicCollision3D, was_on_floor: bool) -> bool:
	if not _can_party_monster_trip_from_collision(impact_velocity, collision, was_on_floor):
		return false
	var collision_normal: Vector3 = collision.get_normal()
	var trip_direction := _sanitize_party_monster_trip_direction(collision_normal, impact_velocity)
	_submit_party_monster_trip_reaction(trip_direction, collision.get_position(), get_network_input_tick())
	return true


func _try_party_monster_trip_from_forward_sensor(impact_velocity: Vector3, was_on_floor: bool) -> bool:
	if not _can_party_monster_trip_now(impact_velocity, was_on_floor):
		return false
	var world: World3D = get_world_3d()
	if world == null:
		return false
	var horizontal_velocity: Vector3 = _best_party_monster_trip_horizontal_velocity(impact_velocity)
	var sensor_direction: Vector3 = horizontal_velocity.normalized()
	var sensor_height: float = _get_party_monster_trip_min_obstacle_height()
	var sensor_origin: Vector3 = global_position + Vector3.UP * sensor_height + sensor_direction * PARTY_MONSTER_TRIP_SENSOR_FORWARD_OFFSET
	var sensor_target: Vector3 = sensor_origin + sensor_direction * PARTY_MONSTER_TRIP_SENSOR_DISTANCE
	var query_mask := int(collision_mask)
	if query_mask == 0:
		query_mask = WORLD_COLLISION_MASK
	var excluded: Array[RID] = []
	excluded.append(get_rid())
	var query := PhysicsRayQueryParameters3D.create(sensor_origin, sensor_target, query_mask, excluded)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	if not _can_party_monster_trip_from_sensor_hit(hit, sensor_direction):
		return false
	var hit_normal: Vector3 = hit.get("normal", -sensor_direction)
	var hit_position: Vector3 = hit.get("position", global_position + sensor_direction * PARTY_MONSTER_TRIP_SENSOR_DISTANCE)
	var trip_direction := _sanitize_party_monster_trip_direction(hit_normal, horizontal_velocity)
	_submit_party_monster_trip_reaction(trip_direction, hit_position, get_network_input_tick())
	return true


func _can_party_monster_trip_now(impact_velocity: Vector3, was_on_floor: bool) -> bool:
	if _party_monster_trip_action_locked or _party_monster_trip_cooldown > 0.0 or _is_dead or _is_prop_disguised:
		return false
	if not was_on_floor and not is_on_floor():
		return false
	if not CharacterSkinCatalog.is_party_monster(character_model_id):
		return false
	if not _active_skin_node or not is_instance_valid(_active_skin_node):
		return false
	if not _active_skin_node.has_method("trip") and not _active_skin_node.has_method("play_action"):
		return false
	return _is_party_monster_running_for_trip(impact_velocity)


func _is_party_monster_running_for_trip(impact_velocity: Vector3) -> bool:
	var horizontal_speed: float = _best_party_monster_trip_horizontal_velocity(impact_velocity).length()
	if horizontal_speed < PARTY_MONSTER_TRIP_MIN_SPEED:
		return false
	return _input_action_held("shift") or horizontal_speed >= RUN_SPEED * 0.75


func _best_party_monster_trip_horizontal_velocity(impact_velocity: Vector3) -> Vector3:
	var horizontal_velocity := Vector3(impact_velocity.x, 0.0, impact_velocity.z)
	var real_velocity := get_real_velocity()
	var real_horizontal_velocity := Vector3(real_velocity.x, 0.0, real_velocity.z)
	if real_horizontal_velocity.length() > horizontal_velocity.length():
		horizontal_velocity = real_horizontal_velocity
	return horizontal_velocity


func _can_party_monster_trip_from_collision(impact_velocity: Vector3, collision: KinematicCollision3D, was_on_floor: bool) -> bool:
	if not _can_party_monster_trip_now(impact_velocity, was_on_floor):
		return false
	var horizontal_velocity := _best_party_monster_trip_horizontal_velocity(impact_velocity)
	var collision_normal: Vector3 = collision.get_normal()
	if collision_normal.y > PARTY_MONSTER_TRIP_COLLISION_NORMAL_MAX_Y or collision_normal.y < -0.5:
		return false
	var flat_normal := Vector3(collision_normal.x, 0.0, collision_normal.z)
	if flat_normal.length_squared() > 0.0001:
		var opposition := -flat_normal.normalized().dot(horizontal_velocity.normalized())
		if opposition < PARTY_MONSTER_TRIP_MIN_COLLISION_OPPOSITION:
			return false
	var collider: Object = collision.get_collider()
	if collider == self:
		return false
	if collider is Node and (collider as Node).is_in_group("players"):
		return false
	var contact_position: Vector3 = collision.get_position()
	if contact_position.y > global_position.y + PARTY_MONSTER_TRIP_GROUND_CONTACT_HEIGHT:
		return false
	if not _is_party_monster_trip_surface_high_enough(collider, contact_position):
		return false
	return true


func _can_party_monster_trip_from_sensor_hit(hit: Dictionary, sensor_direction: Vector3) -> bool:
	var collider: Object = hit.get("collider", null)
	if collider == self:
		return false
	if collider is Node and (collider as Node).is_in_group("players"):
		return false
	var hit_position: Vector3 = hit.get("position", global_position)
	if hit_position.y > global_position.y + PARTY_MONSTER_TRIP_GROUND_CONTACT_HEIGHT:
		return false
	if not _is_party_monster_trip_surface_high_enough(collider, hit_position):
		return false
	var hit_normal: Vector3 = hit.get("normal", Vector3.ZERO)
	if hit_normal.y > PARTY_MONSTER_TRIP_COLLISION_NORMAL_MAX_Y or hit_normal.y < -0.5:
		return false
	var flat_normal := Vector3(hit_normal.x, 0.0, hit_normal.z)
	if flat_normal.length_squared() > 0.0001:
		var opposition := -flat_normal.normalized().dot(sensor_direction.normalized())
		if opposition < PARTY_MONSTER_TRIP_MIN_COLLISION_OPPOSITION:
			return false
	return true


func _get_party_monster_trip_min_obstacle_height() -> float:
	return maxf(_get_hologram_player_height() * PARTY_MONSTER_TRIP_MIN_SURFACE_HEIGHT_RATIO, 0.6)


func _is_party_monster_trip_surface_high_enough(collider: Object, contact_position: Vector3) -> bool:
	var required_top_y: float = global_position.y + _get_party_monster_trip_min_obstacle_height() - PARTY_MONSTER_TRIP_HEIGHT_MARGIN
	var obstacle_top_y: float = _get_party_monster_trip_obstacle_top_y(collider)
	if obstacle_top_y > PARTY_MONSTER_TRIP_UNKNOWN_TOP_Y:
		return obstacle_top_y >= required_top_y
	return contact_position.y >= required_top_y


func _get_party_monster_trip_obstacle_top_y(collider: Object) -> float:
	if not collider is Node3D:
		return PARTY_MONSTER_TRIP_UNKNOWN_TOP_Y
	var obstacle_node := collider as Node3D
	var top_y := PARTY_MONSTER_TRIP_UNKNOWN_TOP_Y
	var mesh_bounds: AABB = _calculate_node_bounds(obstacle_node)
	if mesh_bounds.size != Vector3.ZERO:
		var world_mesh_bounds: AABB = _transform_aabb(obstacle_node.global_transform, mesh_bounds)
		top_y = maxf(top_y, world_mesh_bounds.position.y + world_mesh_bounds.size.y)
	top_y = maxf(top_y, _get_collision_shapes_world_top_y(obstacle_node))
	return top_y


func _get_collision_shapes_world_top_y(node: Node) -> float:
	var top_y := PARTY_MONSTER_TRIP_UNKNOWN_TOP_Y
	if node is CollisionShape3D:
		top_y = maxf(top_y, _get_collision_shape_world_top_y(node as CollisionShape3D))
	for child in node.get_children():
		top_y = maxf(top_y, _get_collision_shapes_world_top_y(child))
	return top_y


func _get_collision_shape_world_top_y(collision_shape: CollisionShape3D) -> float:
	if not collision_shape.shape:
		return PARTY_MONSTER_TRIP_UNKNOWN_TOP_Y
	var local_bounds: AABB = _shape_local_aabb(collision_shape.shape)
	if local_bounds.size == Vector3.ZERO:
		return PARTY_MONSTER_TRIP_UNKNOWN_TOP_Y
	var world_bounds: AABB = _transform_aabb(collision_shape.global_transform, local_bounds)
	return world_bounds.position.y + world_bounds.size.y


func _shape_local_aabb(shape: Shape3D) -> AABB:
	if shape is BoxShape3D:
		var size: Vector3 = (shape as BoxShape3D).size
		return AABB(size * -0.5, size)
	if shape is CapsuleShape3D:
		var capsule := shape as CapsuleShape3D
		var radius: float = capsule.radius
		var height: float = maxf(capsule.height + radius * 2.0, radius * 2.0)
		return AABB(Vector3(-radius, height * -0.5, -radius), Vector3(radius * 2.0, height, radius * 2.0))
	if shape is CylinderShape3D:
		var cylinder := shape as CylinderShape3D
		var radius: float = cylinder.radius
		var height: float = maxf(cylinder.height, 0.0)
		return AABB(Vector3(-radius, height * -0.5, -radius), Vector3(radius * 2.0, height, radius * 2.0))
	if shape is SphereShape3D:
		var radius: float = (shape as SphereShape3D).radius
		var size := Vector3.ONE * radius * 2.0
		return AABB(size * -0.5, size)
	return AABB()


func _sanitize_party_monster_trip_direction(world_direction: Vector3, fallback_velocity: Vector3 = Vector3.ZERO) -> Vector3:
	var direction := world_direction
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		direction = -Vector3(fallback_velocity.x, 0.0, fallback_velocity.z)
	if direction.length_squared() < 0.0001:
		direction = -global_transform.basis.z
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return Vector3(0.0, 0.0, -1.0)
	return direction.normalized()


func _submit_party_monster_trip_reaction(world_direction: Vector3, contact_point: Vector3 = Vector3.ZERO, query_tick: int = -1) -> void:
	var clean_direction := _sanitize_party_monster_trip_direction(world_direction)
	var clean_contact_point: Vector3 = contact_point if contact_point != Vector3.ZERO else global_position
	var clean_query_tick: int = query_tick if query_tick >= 0 else get_network_input_tick()
	_party_monster_trip_cooldown = PARTY_MONSTER_TRIP_COOLDOWN_SECONDS
	_play_party_monster_trip_reaction(clean_direction)
	publish_network_action("party_monster_trip", {
		"direction": clean_direction,
		"contact_point": clean_contact_point,
		"query_tick": clean_query_tick,
	})
	if not _has_active_skin_visual_peer():
		return
	elif _is_runtime_multiplayer_server():
		_apply_party_monster_trip_reaction_rpc.rpc(clean_direction, _pick_party_monster_trip_variant())
	else:
		_request_party_monster_trip_reaction_rpc.rpc_id(1, clean_direction, clean_contact_point, clean_query_tick)


func _has_active_skin_visual_peer() -> bool:
	var peer := multiplayer.multiplayer_peer
	if peer == null:
		return false
	if peer is OfflineMultiplayerPeer:
		return false
	return peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED


@rpc("any_peer", "call_local", "reliable")
func _request_party_monster_trip_reaction_rpc(world_direction: Vector3, contact_point: Vector3 = Vector3.ZERO, query_tick: int = -1) -> void:
	if not _is_runtime_multiplayer_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		push_warning("Client " + str(sender) + " tried to trip player " + str(get_multiplayer_authority()))
		return
	if _is_dead or _is_prop_disguised or not CharacterSkinCatalog.is_party_monster(character_model_id):
		return
	if sender != 0 and not _server_party_monster_trip_contact_is_valid(sender, contact_point, query_tick):
		return
	_apply_party_monster_trip_reaction_rpc.rpc(_sanitize_party_monster_trip_direction(world_direction), _pick_party_monster_trip_variant())


func _server_party_monster_trip_contact_is_valid(sender_id: int, contact_point: Vector3, query_tick: int) -> bool:
	var check_position: Vector3 = contact_point if contact_point != Vector3.ZERO else global_position
	var history: NetworkRewindHistory = NetworkRewindHistory.find_in_tree(get_tree()) if is_inside_tree() else null
	if history != null and query_tick >= 0:
		return history.player_was_in_radius(sender_id, check_position, PARTY_MONSTER_TRIP_REWIND_RADIUS, query_tick)
	return global_position.distance_to(check_position) <= PARTY_MONSTER_TRIP_REWIND_RADIUS


@rpc("any_peer", "call_local", "reliable")
func _apply_party_monster_trip_reaction_rpc(world_direction: Vector3, trip_variant: int = 0) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1:
		return
	if _party_monster_trip_action_locked:
		return
	_play_party_monster_trip_reaction(world_direction, trip_variant)


# Server-authoritative knockdown pose pick. Broadcast in the trip RPC so every peer (and the
# owner) plays the SAME trip clip; the skin would otherwise randomize the clip on each side.
func _pick_party_monster_trip_variant() -> int:
	return randi() % PARTY_MONSTER_TRIP_VARIANT_COUNT


func _play_party_monster_trip_reaction(_world_direction: Vector3, trip_variant: int = 0) -> void:
	if _is_dead or _is_prop_disguised or not CharacterSkinCatalog.is_party_monster(character_model_id):
		return
	if not _active_skin_node or not is_instance_valid(_active_skin_node):
		return
	var did_play := false
	# Prefer the explicit-variant entry so the broadcast pose index is honoured identically on
	# every peer. Fall back to the legacy random trip() only if the skin predates trip_variant().
	if _active_skin_node.has_method("trip_variant"):
		did_play = bool(_active_skin_node.call("trip_variant", trip_variant))
	elif _active_skin_node.has_method("trip"):
		_active_skin_node.call("trip")
		did_play = true
	elif _active_skin_node.has_method("play_action"):
		did_play = bool(_active_skin_node.call("play_action", "trip"))
	if did_play:
		_begin_party_monster_trip_lock()


func _begin_party_monster_trip_lock() -> void:
	_party_monster_trip_action_locked = true
	_party_monster_trip_cooldown = PARTY_MONSTER_TRIP_COOLDOWN_SECONDS
	var animation_length: float = _get_active_skin_current_animation_length()
	_party_monster_trip_reaction_lock_remaining = maxf(maxf(animation_length, PARTY_MONSTER_TRIP_FALLBACK_LOCK_SECONDS), PARTY_MONSTER_TRIP_REACTION_LOCK_SECONDS)
	velocity.x = 0.0
	velocity.z = 0.0
	_current_speed = 0.0


func _finish_party_monster_trip_lock() -> void:
	_party_monster_trip_action_locked = false
	_party_monster_trip_reaction_lock_remaining = 0.0
	velocity.x = 0.0
	velocity.z = 0.0
	_current_speed = 0.0


# Stand the player up from a knockdown: unlock movement, play a recovery animation, and (on the
# owner) broadcast it so peers recover in step. See PlayerStandUpSystem.
func _perform_stand_up() -> void:
	_stand_up_system.cancel()
	_finish_party_monster_trip_lock()
	# Swallow the jump for a moment so the same key press that stood the player up does not also
	# fire a jump the instant the movement lock clears.
	_jump_suppress_remaining = JUMP_SUPPRESS_AFTER_STAND_UP_SECONDS
	_play_skin_action("die_recover")
	if _is_local_authority():
		publish_network_action("stand_up", {})


func _apply_network_stand_up_action() -> void:
	_stand_up_system.cancel()
	if _party_monster_trip_action_locked:
		_finish_party_monster_trip_lock()
	_play_skin_action("die_recover")


func _apply_nearby_prop_impacts(impact_velocity: Vector3, impacted: Dictionary) -> bool:
	if not is_inside_tree():
		return false
	var horizontal_velocity := Vector3(impact_velocity.x, 0.0, impact_velocity.z)
	if horizontal_velocity.length() < PROP_PUSH_ASSIST_MIN_SPEED:
		return false
	var now_msec: int = Time.get_ticks_msec()
	if now_msec < _next_prop_push_query_msec:
		return false
	_next_prop_push_query_msec = now_msec + PROP_PUSH_QUERY_INTERVAL_MSEC
	var world: World3D = get_world_3d()
	if world == null:
		return false
	var space_state: PhysicsDirectSpaceState3D = world.direct_space_state
	if space_state == null:
		return false
	var move_direction := horizontal_velocity.normalized()
	var player_radius := _get_active_collision_radius()
	var query_shape := SphereShape3D.new()
	query_shape.radius = player_radius + PROP_COLLISION_MAX_RADIUS + PROP_PUSH_CONTACT_PADDING + PROP_PUSH_FORWARD_REACH + PROP_PUSH_QUERY_RADIUS_PADDING
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = query_shape
	query.transform = Transform3D(Basis.IDENTITY, global_position + move_direction * (PROP_PUSH_FORWARD_REACH * 0.5))
	query.collision_mask = FruitProp.PHYSICS_LAYER_PROP
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	var results: Array[Dictionary] = space_state.intersect_shape(query, PROP_PUSH_QUERY_MAX_RESULTS)
	var did_impact := false
	for result: Dictionary in results:
		var raw_collider: Variant = result.get("collider")
		if not raw_collider is Node3D:
			continue
		var node: Node3D = raw_collider as Node3D
		if not node.has_method("apply_player_impact"):
			continue
		var node_id := node.get_instance_id()
		if impacted.has(node_id):
			continue
		var prop_position := node.global_position
		var to_prop := prop_position - global_position
		to_prop.y = 0.0
		var distance := to_prop.length()
		var prop_radius := 0.45
		var radius_value: Variant = node.get("collision_radius")
		if radius_value != null:
			prop_radius = float(radius_value)
		var contact_distance := player_radius + prop_radius + PROP_PUSH_CONTACT_PADDING
		var forward_distance := to_prop.dot(move_direction)
		if forward_distance < -0.05 or forward_distance > contact_distance + PROP_PUSH_FORWARD_REACH:
			continue
		if distance > contact_distance:
			continue
		var normal := Vector3.ZERO
		if distance > 0.001:
			normal = -to_prop.normalized()
		node.apply_player_impact(impact_velocity, prop_position, normal, _is_prop_disguised, get_network_input_tick())
		impacted[node_id] = true
		did_impact = true
	return did_impact


func _get_active_collision_radius() -> float:
	if not _collision_shape or not _collision_shape.shape:
		return 0.42
	var shape := _collision_shape.shape
	if shape is CapsuleShape3D:
		return (shape as CapsuleShape3D).radius
	if shape is CylinderShape3D:
		return (shape as CylinderShape3D).radius
	if shape is SphereShape3D:
		return (shape as SphereShape3D).radius
	if shape is BoxShape3D:
		var size := (shape as BoxShape3D).size
		return maxf(size.x, size.z) * 0.5
	return 0.42

func is_running() -> bool:
	if _input_action_held("shift"):
		_current_speed = SPRINT_SPEED
		return true
	else:
		_current_speed = NORMAL_SPEED
		return false

func _check_fall_and_respawn():
	if _is_dead:
		return
	if global_transform.origin.y < -15.0:
		_respawn()

func _respawn():
	_finish_party_monster_trip_lock()
	set_global_position_immediate(_find_safe_ground_position(_respawn_point))
	velocity = Vector3.ZERO
	clear_prop_disguise()
	_update_safe_ground_position(true)


func _request_unstuck() -> void:
	_finish_party_monster_trip_lock()
	set_global_position_immediate(_find_safe_ground_position(global_position))
	velocity = Vector3.ZERO
	_update_safe_ground_position(true)


func _update_safe_ground_position(force: bool = false) -> void:
	if _is_dead:
		return
	if not force and not is_on_floor():
		return
	if global_position.y < -14.0:
		return
	var hit := _ground_hit_for(global_position)
	if hit.is_empty():
		return
	var hit_position: Vector3 = hit.get("position", global_position)
	_last_safe_ground_position = hit_position + Vector3.UP * UNSTUCK_CLEARANCE
	_last_safe_ground_valid = true


func _find_safe_ground_position(anchor_position: Vector3) -> Vector3:
	var candidates: Array[Vector3] = [anchor_position]
	if _last_safe_ground_valid:
		candidates.append(_last_safe_ground_position)
	candidates.append(_respawn_point)
	for radius in [1.5, 3.0, 5.0, 8.0]:
		for index in range(8):
			var angle: float = TAU * float(index) / 8.0
			candidates.append(anchor_position + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))

	for candidate in candidates:
		var hit := _ground_hit_for(candidate)
		if hit.is_empty():
			continue
		var hit_position: Vector3 = hit.get("position", candidate)
		var safe_position := hit_position + Vector3.UP * UNSTUCK_CLEARANCE
		if _safe_position_has_overhead_clearance(safe_position):
			return safe_position
	return _respawn_point + Vector3.UP * UNSTUCK_CLEARANCE


func _ground_hit_for(candidate: Vector3) -> Dictionary:
	if not is_inside_tree() or not get_world_3d():
		return {}
	var from := candidate + Vector3.UP * UNSTUCK_RAY_UP
	var to := candidate + Vector3.DOWN * UNSTUCK_RAY_DOWN
	var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_COLLISION_MASK)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return get_world_3d().direct_space_state.intersect_ray(query)


func _safe_position_has_overhead_clearance(candidate: Vector3) -> bool:
	if not is_inside_tree() or not get_world_3d():
		return true
	var space_state := get_world_3d().direct_space_state
	var offsets: Array[Vector3] = [Vector3.ZERO, Vector3(0.34, 0.0, 0.0), Vector3(-0.34, 0.0, 0.0), Vector3(0.0, 0.0, 0.34), Vector3(0.0, 0.0, -0.34)]
	for offset in offsets:
		var from := candidate + offset + Vector3.UP * 0.18
		var to := candidate + offset + Vector3.UP * UNSTUCK_OVERHEAD_CHECK
		var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_COLLISION_MASK)
		query.exclude = [get_rid()]
		query.collide_with_areas = false
		query.collide_with_bodies = true
		if not space_state.intersect_ray(query).is_empty():
			return false
	return true


func apply_card_effect(card_id: String) -> void:
	_get_card_effect_controller().apply_card_effect(card_id)


func _get_card_effect_controller() -> PlayerCardEffectController:
	if _card_effect_controller == null:
		_card_effect_controller = PlayerCardEffectControllerScript.new() as PlayerCardEffectController
		_card_effect_controller.initialize(self)
	return _card_effect_controller


func _card_apply_emergency_conceal(duration: float) -> void:
	health = maxf(health, max_health * CARD_RESCUE_HEALTH_RATIO)
	_sync_health.rpc(health)
	_card_apply_status("damage_immunity", maxf(duration, 5.0))
	_card_apply_stasis(maxf(duration, 5.0))


func apply_card_status(status_id: String, duration: float, multiplier: float = 1.0) -> void:
	_card_apply_status(status_id, duration, multiplier)


func has_card_damage_immunity() -> bool:
	return _card_damage_immunity_remaining > 0.0


func has_card_hunter_skill_immunity() -> bool:
	return _card_hunter_skill_immunity_remaining > 0.0


func has_card_stasis() -> bool:
	return _card_stasis_remaining > 0.0


func get_card_screen_impairment_remaining() -> float:
	return _card_screen_impairment_remaining


func get_card_speed_multiplier_for_test() -> float:
	return _card_speed_multiplier


func get_walk_speed_for_test() -> float:
	return WALK_SPEED


func get_run_speed_for_test() -> float:
	return RUN_SPEED


func get_footstep_interval_for_test(sprinting: bool) -> float:
	return _footstep_interval_for_mode(sprinting)


func get_footstep_volume_db_for_test(sprinting: bool) -> float:
	return _footstep_volume_for_mode(sprinting)


func is_footstep_audible_for_test(sprinting: bool) -> bool:
	return _footstep_is_audible_for_mode(sprinting)


func has_card_screen_impairment_overlay_for_test() -> bool:
	return _card_screen_impairment_rect != null and is_instance_valid(_card_screen_impairment_rect) and _card_screen_impairment_rect.visible


func _process_card_effects(delta: float) -> void:
	if _card_damage_immunity_remaining > 0.0:
		_card_damage_immunity_remaining = maxf(0.0, _card_damage_immunity_remaining - delta)
	if _card_hunter_skill_immunity_remaining > 0.0:
		_card_hunter_skill_immunity_remaining = maxf(0.0, _card_hunter_skill_immunity_remaining - delta)
	if _card_silent_steps_remaining > 0.0:
		_card_silent_steps_remaining = maxf(0.0, _card_silent_steps_remaining - delta)
	if _card_stasis_remaining > 0.0:
		_card_stasis_remaining = maxf(0.0, _card_stasis_remaining - delta)
		if is_zero_approx(_card_stasis_remaining):
			_set_player_tint(Color(1, 1, 1))
	if _card_screen_impairment_remaining > 0.0:
		_card_screen_impairment_remaining = maxf(0.0, _card_screen_impairment_remaining - delta)
	for key in _card_effect_timers.keys():
		_card_effect_timers[key] = float(_card_effect_timers[key]) - delta
		if float(_card_effect_timers[key]) > 0.0:
			continue
		_card_effect_timers.erase(key)
		match str(key):
			"visual":
				if not _is_dead:
					_set_character_visual_visible(true)
			"scale":
				if _card_scale_effect_active:
					scale = _card_original_scale
					_card_scale_effect_active = false
			"tint":
				_set_player_tint(Color(1, 1, 1))
			"speed":
				_card_speed_multiplier = 1.0


func _card_apply_status(status_id: String, duration: float, multiplier: float = 1.0) -> void:
	match status_id:
		"damage_immunity":
			_card_damage_immunity_remaining = maxf(_card_damage_immunity_remaining, duration)
		"hunter_skill_immunity":
			_card_hunter_skill_immunity_remaining = maxf(_card_hunter_skill_immunity_remaining, duration)
		"silent_steps":
			_card_silent_steps_remaining = maxf(_card_silent_steps_remaining, duration)
		"stasis":
			_card_apply_stasis(duration)
		"speed_multiplier_1_2":
			_card_speed_multiplier = maxf(_card_speed_multiplier, 1.2)
			_card_effect_timers["speed"] = maxf(float(_card_effect_timers.get("speed", 0.0)), duration)
		"speed_multiplier_1_45":
			_card_speed_multiplier = maxf(_card_speed_multiplier, 1.45)
			_card_effect_timers["speed"] = maxf(float(_card_effect_timers.get("speed", 0.0)), duration)
		"speed_multiplier":
			_card_speed_multiplier = minf(_card_speed_multiplier, multiplier)
			_card_effect_timers["speed"] = maxf(float(_card_effect_timers.get("speed", 0.0)), duration)


func _card_apply_stealth(duration: float) -> void:
	_set_character_visual_visible(false)
	_card_effect_timers["visual"] = duration
	_card_feedback_to_owner("INVISIBLE", Color(0.62, 0.92, 1.0, 1.0), 0.65)


func _card_apply_scale(multiplier: float, duration: float) -> void:
	if not _card_scale_effect_active:
		_card_original_scale = scale
	_card_scale_effect_active = true
	scale = _card_original_scale * multiplier
	_card_effect_timers["scale"] = duration
	_card_feedback_to_owner("MICRO FORM", Color(0.72, 1.0, 0.82, 1.0), 0.8)


func _card_apply_stasis(duration: float) -> void:
	_card_stasis_remaining = maxf(_card_stasis_remaining, duration)
	velocity = Vector3.ZERO
	_current_speed = 0.0
	_card_tint_for_duration(Color(0.42, 0.44, 0.46, 1.0), duration)
	_card_feedback_to_owner("STONE STASIS", Color(0.74, 0.78, 0.80, 1.0), 0.9)


func _card_apply_role_scale(target_role: int, radius: float, multiplier: float, duration: float) -> void:
	for player in _card_players_in_radius(radius):
		if int(player.role) == target_role and not player._card_blocks_hunter_skill_effect():
			player._card_apply_scale(multiplier, duration)


func _card_apply_visible_hunter_scale(radius: float, multiplier: float, duration: float) -> void:
	var affected := 0
	for player in _card_players_in_radius(radius):
		if not player.is_hunter():
			continue
		if not _card_has_line_of_sight_to_player(player, radius, 58.0):
			continue
		player._card_apply_scale(multiplier, duration)
		affected += 1
	_card_feedback_to_owner("SENSE %d" % affected, Color(0.72, 1.0, 0.82, 1.0), 0.8)


func _card_apply_role_speed_multiplier(target_role: int, radius: float, multiplier: float, duration: float) -> void:
	for player in _card_players_in_radius(radius):
		if int(player.role) == target_role and not player._card_blocks_hunter_skill_effect():
			player.apply_card_status("speed_multiplier", duration, multiplier)
			player._card_feedback_to_owner("SLOWED", Color(0.65, 0.78, 1.0, 1.0), 0.7)


func _card_apply_prop_aura_status(status_id: String, radius: float, duration: float) -> void:
	for player in _card_players_in_radius(radius):
		if player.is_prop():
			player.apply_card_status(status_id, duration)
			player._card_tint_for_duration(Color(0.55, 0.98, 0.82, 1.0), duration)


func _card_apply_vision_impairment_to_role(target_role: int, radius: float, duration: float, label: String) -> void:
	for player in _card_players_in_radius(radius):
		if int(player.role) == target_role and not player._card_blocks_hunter_skill_effect():
			player._card_feedback_to_owner(label, Color(1.0, 0.96, 0.72, 1.0), maxf(duration, 0.75))
			player._card_tint_for_duration(Color(1.0, 0.96, 0.72, 1.0), minf(maxf(duration, 0.75), 2.0))
			player._card_apply_screen_impairment(label, maxf(duration, 0.75))


func _card_blocks_hunter_skill_effect() -> bool:
	return is_prop() and _card_hunter_skill_immunity_remaining > 0.0


func _card_spawn_decoy(duration: float, local_offset: Vector3) -> void:
	var scene_root := get_tree().get_current_scene() if get_tree() else null
	if not scene_root:
		scene_root = self
	var decoy := CardDecoyTargetScript.new() as CardDecoyTarget
	decoy.name = "CardDecoyEcho"
	decoy.top_level = true
	scene_root.add_child(decoy)
	decoy.configure(self, duration, local_offset, false, 45.0)
	_card_feedback_to_owner("DECOY", Color(0.62, 0.92, 1.0, 1.0), 0.65)


func _card_spawn_mist_clones(duration: float) -> void:
	_card_spawn_following_decoy(duration, Vector3(1.4, 0.0, 0.6))
	_card_spawn_following_decoy(duration, Vector3(-1.2, 0.0, -0.8))
	_card_feedback_to_owner("CLONES", Color(0.62, 0.92, 1.0, 1.0), 0.75)


func _card_spawn_following_decoy(duration: float, local_offset: Vector3) -> void:
	var scene_root := get_tree().get_current_scene() if get_tree() else null
	if not scene_root:
		scene_root = self
	var decoy := CardDecoyTargetScript.new() as CardDecoyTarget
	decoy.name = "CardMistClone"
	decoy.top_level = true
	scene_root.add_child(decoy)
	decoy.configure(self, duration, local_offset, true, 30.0)


func _card_portal_step() -> void:
	if not _is_runtime_multiplayer_server() and multiplayer.multiplayer_peer:
		return
	var angle := randf() * TAU
	var distance := randf_range(40.0, 50.0)
	var destination := _card_grounded_position(global_position + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance))
	_card_spawn_decoy(1.25, Vector3.ZERO)
	set_global_position_immediate(destination)
	velocity = Vector3.ZERO
	_card_feedback_to_owner("PORTAL", Color(0.72, 0.86, 1.0, 1.0), 0.75)


func _card_reveal_props(radius: float, duration: float) -> void:
	for player in _card_players_in_radius(radius):
		if player.is_prop():
			player.set_hunter_prop_sense_revealed(true, 1.0, 0.42, true)
			player._card_feedback_to_owner("REVEALED", Color(1.0, 0.32, 0.18, 1.0), 0.75)
			player._card_clear_reveal_after(duration)


func _card_mark_nearest_prop(radius: float, duration: float) -> void:
	var nearest: Character = null
	var nearest_distance := INF
	for player in _card_players_in_radius(radius):
		if not player.is_prop():
			continue
		var distance := global_position.distance_to(player.global_position)
		if distance < nearest_distance:
			nearest = player
			nearest_distance = distance
	if nearest:
		nearest.set_hunter_prop_sense_revealed(true, 1.0, 0.36, true)
		nearest._card_clear_reveal_after(duration)
		_card_feedback_to_owner("ECHO %.1fm" % nearest_distance, Color(0.65, 0.78, 1.0, 1.0), 0.9)
	else:
		_card_feedback_to_owner("ECHO CLEAR", Color(0.75, 0.78, 0.86, 1.0), 0.7)


func _card_clear_reveal_after(duration: float) -> void:
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(self):
		set_hunter_prop_sense_revealed(false)


func _card_clear_hunter_ammo() -> void:
	for node in get_tree().get_nodes_in_group("players"):
		if not node is Character:
			continue
		var player := node as Character
		if not player.is_hunter():
			continue
		var weapon := player.get_node_or_null("WeaponSystem")
		if weapon:
			weapon.current_magazine = 0
			weapon.total_ammo = 0
			if weapon.has_signal("ammo_changed"):
				weapon.ammo_changed.emit(0, 0)
			if weapon.has_method("_sync_ammo_to_owner"):
				weapon.call("_sync_ammo_to_owner")
			player._card_feedback_to_owner("AMMO EMPTY", Color(1.0, 0.72, 0.25, 1.0), 0.9)
		var turret := player.get_node_or_null("HunterAutoTurretSystem")
		if turret and turret.has_method("drain_by_card"):
			turret.call("drain_by_card", 8.0)


func _card_refill_weapon(amount: int) -> void:
	var weapon := get_node_or_null("WeaponSystem")
	if weapon and weapon.has_method("server_add_ammo"):
		if _is_runtime_multiplayer_server() or not multiplayer.multiplayer_peer:
			weapon.server_add_ammo(amount)
	_card_feedback_to_owner("AMMO", Color(1.0, 0.86, 0.25, 1.0), 0.75)


func _card_overdrive_turret(duration: float) -> void:
	var turret := get_node_or_null("HunterAutoTurretSystem")
	if turret:
		turret.set("overheat_cooldown", 0.0)
		turret.set_meta("card_overdrive_until_msec", Time.get_ticks_msec() + int(duration * 1000.0))
	_card_feedback_to_owner("TURRET OVERDRIVE", Color(1.0, 0.86, 0.25, 1.0), 0.8)


func _card_tint_for_duration(color: Color, duration: float) -> void:
	_set_player_tint(color)
	_card_effect_timers["tint"] = maxf(float(_card_effect_timers.get("tint", 0.0)), duration)


func _card_players_in_radius(radius: float) -> Array[Character]:
	var result: Array[Character] = []
	if not is_inside_tree():
		return result
	for node in get_tree().get_nodes_in_group("players"):
		if not node is Character:
			continue
		var player := node as Character
		if player == self:
			result.append(player)
			continue
		if global_position.distance_to(player.global_position) <= radius:
			result.append(player)
	return result


func _card_has_line_of_sight_to_player(player: Character, radius: float, half_angle_degrees: float) -> bool:
	if not player or not is_instance_valid(player):
		return false
	var origin := global_position + Vector3.UP * 1.1
	var target := player.global_position + Vector3.UP * 1.0
	var to_target := target - origin
	if to_target.length() > radius:
		return false
	var forward := -global_transform.basis.z
	if _spring_arm_offset:
		forward = -_spring_arm_offset.global_transform.basis.z
	forward.y = 0.0
	var flat_to_target := to_target
	flat_to_target.y = 0.0
	if forward.length_squared() > 0.0001 and flat_to_target.length_squared() > 0.0001:
		var angle := rad_to_deg(acos(clampf(forward.normalized().dot(flat_to_target.normalized()), -1.0, 1.0)))
		if angle > half_angle_degrees:
			return false
	if not get_world_3d():
		return true
	var query := PhysicsRayQueryParameters3D.create(origin, target, 0xFFFFFFFF)
	query.exclude = [get_rid(), player.get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty()


func _card_grounded_position(candidate: Vector3) -> Vector3:
	if not get_world_3d():
		return candidate
	var query := PhysicsRayQueryParameters3D.create(candidate + Vector3.UP * 8.0, candidate + Vector3.DOWN * 24.0, WORLD_COLLISION_MASK)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return candidate
	return hit.get("position", candidate) + Vector3.UP * 0.08


@rpc("authority", "call_local", "reliable")
func _client_card_feedback(text: String, color: Color, duration: float) -> void:
	var level = get_tree().get_current_scene()
	if level and level.has_method("show_combat_feedback"):
		level.show_combat_feedback(text, color, duration)


func _card_feedback_to_owner(text: String, color: Color, duration: float = 0.75) -> void:
	var owner_id := get_multiplayer_authority()
	if multiplayer == null:
		return
	if _card_can_rpc_to_owner(owner_id):
		_client_card_feedback.rpc_id(owner_id, text, color, duration)
	elif owner_id == _local_peer_id() or not _has_runtime_multiplayer_peer():
		_client_card_feedback(text, color, duration)


func _card_apply_screen_impairment(label: String, duration: float) -> void:
	var owner_id := get_multiplayer_authority()
	if _card_can_rpc_to_owner(owner_id):
		_client_card_screen_impairment.rpc_id(owner_id, label, duration)
	elif owner_id == _local_peer_id() or not _has_runtime_multiplayer_peer():
		_client_card_screen_impairment(label, duration)


func _card_can_rpc_to_owner(owner_id: int) -> bool:
	if owner_id == _local_peer_id():
		return false
	if not _is_runtime_multiplayer_server() or not _has_runtime_multiplayer_peer():
		return false
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return false
	return multiplayer.get_peers().has(owner_id)


@rpc("authority", "call_local", "reliable")
func _client_card_screen_impairment(label: String, duration: float) -> void:
	if not _is_local_authority() and multiplayer.multiplayer_peer:
		return
	_card_screen_impairment_remaining = maxf(_card_screen_impairment_remaining, duration)
	_ensure_card_screen_impairment_layer()
	if not _card_screen_impairment_rect:
		return
	var mode := label.to_upper()
	var tint := Color(1.0, 1.0, 1.0, 0.82)
	var blur_strength := 0.0
	var noise_strength := 0.0
	if mode == "PAINT":
		tint = Color(0.86, 0.68, 1.0, 0.42)
		blur_strength = 4.5
		noise_strength = 0.16
	elif mode == "JAMMED":
		tint = Color(0.48, 0.78, 1.0, 0.34)
		blur_strength = 2.0
		noise_strength = 0.22
	else:
		tint = Color(1.0, 1.0, 1.0, 0.86)
		blur_strength = 0.75
		noise_strength = 0.04
	_card_screen_impairment_rect.visible = true
	_card_screen_impairment_rect.modulate = Color.WHITE
	if _card_screen_impairment_material:
		_card_screen_impairment_material.set_shader_parameter("tint", tint)
		_card_screen_impairment_material.set_shader_parameter("blur_strength", blur_strength)
		_card_screen_impairment_material.set_shader_parameter("noise_strength", noise_strength)
		_card_screen_impairment_material.set_shader_parameter("duration_alpha", 1.0)
	if _card_screen_impairment_label:
		_card_screen_impairment_label.text = mode
		_card_screen_impairment_label.visible = true
	if _card_screen_impairment_tween and _card_screen_impairment_tween.is_valid():
		_card_screen_impairment_tween.kill()
	_card_screen_impairment_tween = create_tween()
	_card_screen_impairment_tween.tween_interval(maxf(duration - 0.45, 0.08))
	if _card_screen_impairment_material:
		_card_screen_impairment_tween.tween_property(_card_screen_impairment_material, "shader_parameter/duration_alpha", 0.0, 0.45)
	else:
		_card_screen_impairment_tween.tween_property(_card_screen_impairment_rect, "modulate:a", 0.0, 0.45)
	_card_screen_impairment_tween.tween_callback(_hide_card_screen_impairment)


func _ensure_card_screen_impairment_layer() -> void:
	if _card_screen_impairment_layer and is_instance_valid(_card_screen_impairment_layer):
		return
	_card_screen_impairment_layer = CanvasLayer.new()
	_card_screen_impairment_layer.name = "CardScreenImpairmentLayer"
	_card_screen_impairment_layer.layer = 96
	add_child(_card_screen_impairment_layer)
	_card_screen_impairment_rect = ColorRect.new()
	_card_screen_impairment_rect.name = "CardScreenImpairment"
	_card_screen_impairment_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_screen_impairment_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card_screen_impairment_rect.visible = false
	_card_screen_impairment_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 0.75);
uniform float blur_strength = 2.0;
uniform float noise_strength = 0.08;
uniform float duration_alpha = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 pixel = SCREEN_PIXEL_SIZE * blur_strength;
	vec4 color = texture(screen_texture, SCREEN_UV) * 0.34;
	color += texture(screen_texture, SCREEN_UV + vec2(pixel.x, 0.0)) * 0.14;
	color += texture(screen_texture, SCREEN_UV - vec2(pixel.x, 0.0)) * 0.14;
	color += texture(screen_texture, SCREEN_UV + vec2(0.0, pixel.y)) * 0.14;
	color += texture(screen_texture, SCREEN_UV - vec2(0.0, pixel.y)) * 0.14;
	color += texture(screen_texture, SCREEN_UV + vec2(pixel.x, pixel.y)) * 0.05;
	color += texture(screen_texture, SCREEN_UV - vec2(pixel.x, pixel.y)) * 0.05;
	float grain = (hash(UV * vec2(211.0, 163.0) + TIME * 13.0) - 0.5) * noise_strength;
	COLOR = mix(color, tint, tint.a) + vec4(vec3(grain), 0.0);
	COLOR.a = clamp(duration_alpha, 0.0, 1.0);
}
"""
	_card_screen_impairment_material.shader = shader
	_card_screen_impairment_rect.material = _card_screen_impairment_material
	_card_screen_impairment_layer.add_child(_card_screen_impairment_rect)
	_card_screen_impairment_label = Label.new()
	_card_screen_impairment_label.name = "CardScreenImpairmentLabel"
	_card_screen_impairment_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_screen_impairment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_screen_impairment_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card_screen_impairment_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_card_screen_impairment_label.position = Vector2(-130.0, 72.0)
	_card_screen_impairment_label.size = Vector2(260.0, 44.0)
	_card_screen_impairment_label.add_theme_font_size_override("font_size", 28)
	_card_screen_impairment_label.add_theme_color_override("font_color", Color(0.04, 0.05, 0.06, 0.76))
	_card_screen_impairment_label.visible = false
	_card_screen_impairment_layer.add_child(_card_screen_impairment_label)


func _hide_card_screen_impairment() -> void:
	_card_screen_impairment_remaining = 0.0
	if _card_screen_impairment_rect and is_instance_valid(_card_screen_impairment_rect):
		_card_screen_impairment_rect.visible = false
	if _card_screen_impairment_label and is_instance_valid(_card_screen_impairment_label):
		_card_screen_impairment_label.visible = false

@rpc("any_peer", "reliable")
func change_nick(new_nick: String):
	if nickname:
		nickname.text = new_nick

func get_texture_from_name(skin_color: SkinColor) -> CompressedTexture2D:
	match skin_color:
		SkinColor.BLUE: return blue_texture
		SkinColor.GREEN: return green_texture
		SkinColor.RED: return red_texture
		SkinColor.YELLOW: return yellow_texture
		_: return blue_texture

@rpc("any_peer", "reliable")
func set_player_skin(skin_name: SkinColor) -> void:
	var texture = get_texture_from_name(skin_name)

	set_mesh_texture(_bottom_mesh, texture)
	set_mesh_texture(_chest_mesh, texture)
	set_mesh_texture(_face_mesh, texture)
	set_mesh_texture(_limbs_head_mesh, texture)


func submit_camouflage_palette(palette: Array, confidence: float) -> void:
	var clean_palette := _sanitize_camouflage_palette(palette)
	var clean_confidence := clampf(confidence, 0.0, 1.0)
	if _is_runtime_multiplayer_server():
		_apply_camouflage_palette.rpc(clean_palette, clean_confidence)
	else:
		_request_camouflage_palette.rpc_id(1, clean_palette, clean_confidence)


@rpc("any_peer", "call_local", "reliable")
func _request_camouflage_palette(palette: Array, confidence: float) -> void:
	if not _is_runtime_multiplayer_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		push_warning("Client " + str(sender) + " tried to camouflage player " + str(get_multiplayer_authority()))
		return
	if not is_chameleon():
		return
	_apply_camouflage_palette.rpc(_sanitize_camouflage_palette(palette), clampf(confidence, 0.0, 1.0))


@rpc("any_peer", "call_local", "reliable")
func _apply_camouflage_palette(palette: Array, confidence: float) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1 and not _is_runtime_multiplayer_server():
		return
	var clean_palette := _sanitize_camouflage_palette(palette)
	var texture := CamouflageSystem.create_camouflage_texture(clean_palette, get_instance_id())
	_apply_camouflage_texture_to_character(texture, clean_palette[0], confidence)
	var level = get_tree().get_current_scene() if get_tree() else null
	if level and _is_local_authority() and level.has_method("show_combat_feedback"):
		level.show_combat_feedback("环境融合 %d%%" % int(round(confidence * 100.0)), clean_palette[0], 0.9)


func set_camouflage_brush_locked(locked: bool) -> void:
	_camouflage_brush_locked = locked
	_set_active_skin_animation_paused(locked)
	if locked:
		_force_active_skin_skeleton_update()
	if locked:
		freeze()


func deactivate_camouflage_skill() -> void:
	if camouflage_system:
		camouflage_system.deactivate_skill()


func set_environment_blend_preview_active(active: bool) -> void:
	_set_character_visual_visible(not active)


func create_environment_prop_preview_node(preset: Dictionary) -> Node3D:
	var clean := ChameleonPropCatalog.normalize_preset(preset)
	var preview := _build_prop_disguise_node(clean)
	if preview:
		_disable_prop_collisions(preview)
	return preview


func capture_environment_prop_paint_payload(preview_root: Node3D) -> Dictionary:
	if not preview_root or not is_instance_valid(preview_root):
		return {}
	var surfaces := []
	var total_bytes := 0
	var meshes: Array[MeshInstance3D] = []
	_find_meshes(preview_root, meshes)
	for mesh_instance in meshes:
		if surfaces.size() >= ENVIRONMENT_PROP_PAINT_MAX_SURFACES:
			break
		var relative_path := str(preview_root.get_path_to(mesh_instance))
		var surface_count := _get_mesh_surface_count(mesh_instance)
		for surface in range(surface_count):
			if surfaces.size() >= ENVIRONMENT_PROP_PAINT_MAX_SURFACES:
				break
			var key := _camouflage_texture_key(str(get_path_to(mesh_instance)), surface)
			if not _camouflage_paint_textures.has(key):
				continue
			var texture := _camouflage_paint_textures[key] as Texture2D
			var image := texture.get_image() if texture else null
			if not image or image.is_empty() or not _image_has_visible_alpha(image):
				continue
			var sync_image := image.duplicate()
			if sync_image.get_width() != ENVIRONMENT_PROP_PAINT_SYNC_SIZE or sync_image.get_height() != ENVIRONMENT_PROP_PAINT_SYNC_SIZE:
				sync_image.resize(ENVIRONMENT_PROP_PAINT_SYNC_SIZE, ENVIRONMENT_PROP_PAINT_SYNC_SIZE, Image.INTERPOLATE_LANCZOS)
			var png_bytes: PackedByteArray = sync_image.save_png_to_buffer()
			if png_bytes.is_empty() or png_bytes.size() > ENVIRONMENT_PROP_PAINT_MAX_BYTES_PER_SURFACE:
				continue
			if total_bytes + png_bytes.size() > ENVIRONMENT_PROP_PAINT_MAX_TOTAL_BYTES:
				break
			total_bytes += png_bytes.size()
			surfaces.append({
				"mesh_path": relative_path,
				"surface": surface,
				"png": png_bytes,
			})
	if surfaces.is_empty():
		return {}
	return {
		"version": 1,
		"texture_size": ENVIRONMENT_PROP_PAINT_SYNC_SIZE,
		"base_color": Color(0.96, 0.94, 0.9, 1.0),
		"roughness": _camouflage_paint_roughness,
		"metallic": _camouflage_paint_metallic,
		"specular": _camouflage_paint_specular,
		"surfaces": surfaces,
	}


func clear_environment_prop_paint_buffers() -> void:
	for key in _camouflage_paint_textures.keys():
		if _is_environment_prop_preview_mesh_path(str(key)):
			_camouflage_paint_textures.erase(key)
	for key in _camouflage_paint_layer_materials.keys():
		if _is_environment_prop_preview_mesh_path(str(key)):
			_camouflage_paint_layer_materials.erase(key)
	for key in _camouflage_source_material_infos.keys():
		if _is_environment_prop_preview_mesh_path(str(key)):
			_camouflage_source_material_infos.erase(key)


func request_environment_prop_disguise(preset: Dictionary) -> void:
	if not is_chameleon():
		return
	var clean := ChameleonPropCatalog.normalize_preset(preset)
	clean = _sanitize_environment_prop_disguise_preset(clean)
	if _has_active_camouflage_multiplayer_peer():
		apply_prop_disguise.rpc(clean)
	else:
		apply_prop_disguise(clean)


func set_chameleon_sculpt_shell_active(active: bool, restore_transform: Transform3D = Transform3D.IDENTITY) -> void:
	_chameleon_sculpt_shell_active = active
	if active:
		_set_character_visual_visible(false)
		if _collision_shape:
			_collision_shape.disabled = true
		freeze()
		return
	if restore_transform != Transform3D.IDENTITY:
		set_global_position_immediate(restore_transform.origin)
	velocity = Vector3.ZERO
	if _collision_shape:
		_collision_shape.disabled = false
	_set_character_visual_visible(true)
	_force_active_skin_skeleton_update()


func submit_chameleon_sculpt_shell_state(active: bool, anchor: Vector3, normal: Vector3) -> void:
	if not is_chameleon():
		return
	var clean_normal := normal.normalized() if normal.length_squared() > 0.001 else Vector3.UP
	if _is_runtime_multiplayer_server() and _has_active_camouflage_multiplayer_peer():
		_apply_chameleon_sculpt_shell_state.rpc(active, anchor, clean_normal)
	elif _should_apply_camouflage_brush_without_server_peer():
		_apply_chameleon_sculpt_shell_state(active, anchor, clean_normal)
	else:
		_request_chameleon_sculpt_shell_state.rpc_id(1, active, anchor, clean_normal)


func submit_sculpt_stroke_batch(
	tool_names: PackedStringArray,
	world_positions: PackedVector3Array,
	radii: PackedFloat32Array,
	strengths: PackedFloat32Array = PackedFloat32Array()
) -> void:
	if not is_chameleon():
		return
	var clean := _sanitize_sculpt_stroke_batch(tool_names, world_positions, radii, strengths)
	if clean.is_empty():
		return
	var clean_tools: PackedStringArray = clean.get("tools", PackedStringArray())
	var clean_positions: PackedVector3Array = clean.get("positions", PackedVector3Array())
	var clean_radii: PackedFloat32Array = clean.get("radii", PackedFloat32Array())
	var clean_strengths: PackedFloat32Array = clean.get("strengths", PackedFloat32Array())
	if _is_runtime_multiplayer_server() and _has_active_camouflage_multiplayer_peer():
		_apply_sculpt_stroke_batch.rpc(clean_tools, clean_positions, clean_radii, clean_strengths)
	elif _should_apply_camouflage_brush_without_server_peer():
		_apply_sculpt_stroke_batch(clean_tools, clean_positions, clean_radii, clean_strengths)
	else:
		_request_sculpt_stroke_batch.rpc_id(1, clean_tools, clean_positions, clean_radii, clean_strengths)


func apply_chameleon_sculpt_counterplay_reset(world_position: Vector3, world_radius: float, amount: float = 0.35) -> void:
	if not is_chameleon():
		return
	var clean_radius := clampf(world_radius, SCULPT_MIN_WORLD_RADIUS, SCULPT_COUNTERPLAY_MAX_WORLD_RADIUS)
	var clean_amount := clampf(amount, 0.0, 1.0)
	if _is_runtime_multiplayer_server() and _has_active_camouflage_multiplayer_peer():
		_apply_chameleon_sculpt_counterplay_reset.rpc(world_position, clean_radius, clean_amount)
	elif _should_apply_camouflage_brush_without_server_peer():
		_apply_chameleon_sculpt_counterplay_reset(world_position, clean_radius, clean_amount)


@rpc("any_peer", "call_local", "reliable")
func _request_chameleon_sculpt_shell_state(active: bool, anchor: Vector3, normal: Vector3) -> void:
	if not _is_runtime_multiplayer_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	if not is_chameleon():
		return
	_apply_chameleon_sculpt_shell_state.rpc(active, anchor, normal.normalized() if normal.length_squared() > 0.001 else Vector3.UP)


@rpc("any_peer", "call_local", "reliable")
func _apply_chameleon_sculpt_shell_state(active: bool, anchor: Vector3, normal: Vector3) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1 and not _is_runtime_multiplayer_server():
		return
	_ensure_chameleon_sculpt_system_for_replication()
	if not chameleon_sculpt_system:
		return
	if active:
		if chameleon_sculpt_system.has_method("activate"):
			chameleon_sculpt_system.call("activate")
		chameleon_sculpt_system.set("anchor_position", anchor)
		chameleon_sculpt_system.set("anchor_normal", normal.normalized() if normal.length_squared() > 0.001 else Vector3.UP)
		chameleon_sculpt_system.call("_place_shell_at_anchor")
	else:
		if chameleon_sculpt_system.has_method("restore_real_body"):
			chameleon_sculpt_system.call("restore_real_body")


@rpc("any_peer", "call_local", "unreliable_ordered")
func _request_sculpt_stroke_batch(
	tool_names: PackedStringArray,
	world_positions: PackedVector3Array,
	radii: PackedFloat32Array,
	strengths: PackedFloat32Array = PackedFloat32Array()
) -> void:
	if not _is_runtime_multiplayer_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	if not is_chameleon():
		return
	var now := Time.get_ticks_msec()
	if now - _last_sculpt_batch_msec < 20:
		return
	_last_sculpt_batch_msec = now
	var clean := _sanitize_sculpt_stroke_batch(tool_names, world_positions, radii, strengths)
	if clean.is_empty():
		return
	_apply_sculpt_stroke_batch.rpc(
		clean.get("tools", PackedStringArray()),
		clean.get("positions", PackedVector3Array()),
		clean.get("radii", PackedFloat32Array()),
		clean.get("strengths", PackedFloat32Array())
	)


@rpc("any_peer", "call_local", "unreliable_ordered")
func _apply_sculpt_stroke_batch(
	tool_names: PackedStringArray,
	world_positions: PackedVector3Array,
	radii: PackedFloat32Array,
	strengths: PackedFloat32Array = PackedFloat32Array()
) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1 and not _is_runtime_multiplayer_server():
		return
	if not is_chameleon():
		return
	_ensure_chameleon_sculpt_system_for_replication()
	if not chameleon_sculpt_system:
		return
	if not chameleon_sculpt_system.has_method("validate_sculpt_stroke_batch") or not bool(chameleon_sculpt_system.call("validate_sculpt_stroke_batch", tool_names, world_positions, radii)):
		return
	chameleon_sculpt_system.call("apply_sculpt_stroke_batch", tool_names, world_positions, radii, strengths)


@rpc("authority", "call_local", "reliable")
func _apply_chameleon_sculpt_counterplay_reset(world_position: Vector3, world_radius: float, amount: float = 0.35) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1 and not _is_runtime_multiplayer_server():
		return
	if not is_chameleon():
		return
	var system: Node = _ensure_chameleon_sculpt_system_for_replication()
	if system and system.has_method("apply_counterplay_soft_reset"):
		system.call(
			"apply_counterplay_soft_reset",
			world_position,
			clampf(world_radius, SCULPT_MIN_WORLD_RADIUS, SCULPT_COUNTERPLAY_MAX_WORLD_RADIUS),
			clampf(amount, 0.0, 1.0)
		)


func _sanitize_sculpt_stroke_batch(
	tool_names: PackedStringArray,
	world_positions: PackedVector3Array,
	radii: PackedFloat32Array,
	strengths: PackedFloat32Array = PackedFloat32Array()
) -> Dictionary:
	var count := mini(tool_names.size(), world_positions.size())
	if count <= 0 or count > 16:
		return {}
	var clean_tools := PackedStringArray()
	var clean_positions := PackedVector3Array()
	var clean_radii := PackedFloat32Array()
	var clean_strengths := PackedFloat32Array()
	for i in range(count):
		var tool_name := _normalize_sculpt_tool_name(tool_names[i])
		if tool_name.is_empty():
			return {}
		var radius: float = SCULPT_DEFAULT_WORLD_RADIUS
		if i < radii.size():
			radius = radii[i]
		if radius < SCULPT_MIN_WORLD_RADIUS or radius > SCULPT_MAX_WORLD_RADIUS:
			return {}
		clean_tools.append(tool_name)
		clean_positions.append(world_positions[i])
		clean_radii.append(radius)
		clean_strengths.append(clampf(strengths[i] if i < strengths.size() else 1.0, 0.0, 2.0))
	var system: Node = _ensure_chameleon_sculpt_system_for_replication()
	if system and (not system.has_method("validate_sculpt_stroke_batch") or not bool(system.call("validate_sculpt_stroke_batch", clean_tools, clean_positions, clean_radii))):
		return {}
	return {
		"tools": clean_tools,
		"positions": clean_positions,
		"radii": clean_radii,
		"strengths": clean_strengths,
	}


func _normalize_sculpt_tool_name(tool_name: String) -> String:
	match str(tool_name).to_lower():
		SCULPT_TOOL_FLATTEN, "flat", "press", "plane":
			return SCULPT_TOOL_FLATTEN
		SCULPT_TOOL_REMOVE, "erase", "cut", "carve":
			return SCULPT_TOOL_REMOVE
		SCULPT_TOOL_SMART, SCULPT_TOOL_ADD, SCULPT_TOOL_SMOOTH, SCULPT_TOOL_STRETCH, "auto", "polish", "shape", "push", "pull", "grab":
			return SCULPT_TOOL_SMART
	return ""


func _ensure_chameleon_sculpt_system_for_replication() -> Node:
	if chameleon_sculpt_system and is_instance_valid(chameleon_sculpt_system):
		return chameleon_sculpt_system
	var existing: Node = get_node_or_null("ChameleonSculptSystem")
	if existing:
		chameleon_sculpt_system = existing
		return chameleon_sculpt_system
	var sculpt := preload("res://scripts/chameleon_sculpt_system.gd").new()
	sculpt.name = "ChameleonSculptSystem"
	add_child(sculpt)
	var camera_node := $SpringArmOffset/SpringArm3D/Camera3D if has_node("SpringArmOffset/SpringArm3D/Camera3D") else null
	sculpt.initialize(self, camera_node if _is_local_authority() else null)
	chameleon_sculpt_system = sculpt
	if camouflage_system and camouflage_system.has_method("set_sculpt_system"):
		camouflage_system.call("set_sculpt_system", chameleon_sculpt_system)
	return chameleon_sculpt_system


func is_camouflage_brushing() -> bool:
	return _camouflage_brush_locked


func adjust_camouflage_brush_rotation(delta_yaw: float) -> void:
	if not _camouflage_brush_locked or not _body:
		return
	_body.rotation.y = wrapf(_body.rotation.y + delta_yaw, -PI, PI)


func adjust_camouflage_camera_orbit(relative: Vector2) -> void:
	if not _camouflage_brush_locked or not _spring_arm_offset:
		return
	if _spring_arm_offset.has_method("orbit_camera"):
		_spring_arm_offset.call("orbit_camera", relative)


func adjust_camouflage_camera_zoom(step_count: float) -> void:
	if not _camouflage_brush_locked or not _spring_arm_offset:
		return
	if _spring_arm_offset.has_method("zoom_camera_for_camouflage"):
		_spring_arm_offset.call("zoom_camera_for_camouflage", step_count)
		return
	if _spring_arm_offset.has_method("zoom_camera"):
		_spring_arm_offset.call("zoom_camera", step_count)


func set_camouflage_paint_material_controls(exact_color_match: bool, roughness: float, metallic: float, specular: float = 0.5) -> void:
	_camouflage_paint_exact_color_match = exact_color_match
	_camouflage_paint_roughness = clampf(roughness, 0.0, 1.0)
	_camouflage_paint_metallic = clampf(metallic, 0.0, 1.0)
	_camouflage_paint_specular = clampf(specular, 0.0, 1.0)
	for material in _camouflage_paint_layer_materials.values():
		if material is ShaderMaterial and is_instance_valid(material):
			_configure_camouflage_paint_layer_controls(material as ShaderMaterial)
	for material in _camouflage_surface_materials.values():
		if material is StandardMaterial3D and is_instance_valid(material):
			_configure_camouflage_display_material(material as StandardMaterial3D)
	_configure_camouflage_gpu_overlay_materials()


func set_camouflage_paint_material_profile(profile: Dictionary) -> void:
	_camouflage_paint_roughness = clampf(float(profile.get("roughness", _camouflage_paint_roughness)), 0.0, 1.0)
	_camouflage_paint_metallic = clampf(float(profile.get("metallic", _camouflage_paint_metallic)), 0.0, 1.0)
	_camouflage_paint_specular = clampf(float(profile.get("specular", _camouflage_paint_specular)), 0.0, 1.0)
	_camouflage_paint_normal_texture = profile.get("normal_texture", null) as Texture2D
	_camouflage_paint_normal_scale = clampf(float(profile.get("normal_scale", _camouflage_paint_normal_scale)), 0.0, 2.0)
	for material in _camouflage_paint_layer_materials.values():
		if material is ShaderMaterial and is_instance_valid(material):
			_configure_camouflage_paint_layer_controls(material as ShaderMaterial)
	for material in _camouflage_surface_materials.values():
		if material is StandardMaterial3D and is_instance_valid(material):
			_configure_camouflage_display_material(material as StandardMaterial3D)
	_configure_camouflage_gpu_overlay_materials()


func submit_camouflage_brush_start(base_color: Color) -> void:
	base_color.a = 1.0
	var source_peer_id: int = _camouflage_source_peer_id()
	var paint_sequence: int = _next_camouflage_paint_sequence()
	if _is_runtime_multiplayer_server() and _has_active_camouflage_multiplayer_peer():
		Network.record_rpc_event("chameleon.paint_start", maxi(multiplayer.get_peers().size(), 1), 24)
		_start_camouflage_brush_visual.rpc(base_color, source_peer_id, paint_sequence)
	elif _should_apply_camouflage_brush_without_server_peer():
		_start_camouflage_brush_visual(base_color, source_peer_id, paint_sequence)
	else:
		_start_camouflage_brush_visual(base_color, source_peer_id, paint_sequence)
		Network.record_rpc_event("chameleon.paint_start_request", 1, 24)
		_request_camouflage_brush_start.rpc_id(1, base_color, paint_sequence)


func submit_camouflage_brush_stroke(
	uv: Vector2,
	color: Color,
	brush_radius: float,
	angle: float,
	world_position: Vector3 = Vector3.ZERO,
	world_normal: Vector3 = Vector3.UP,
	target_mesh_path: String = "",
	target_surface: int = 0,
	material_roughness: float = -1.0,
	material_metallic: float = -1.0,
	material_specular: float = -1.0
) -> void:
	color.a = 1.0
	var clean_uv := Vector2(clampf(uv.x, 0.0, 1.0), clampf(uv.y, 0.0, 1.0))
	var clean_radius := _sanitize_camouflage_brush_radius(brush_radius)
	var clean_normal := world_normal.normalized() if world_normal.length_squared() > 0.001 else Vector3.UP
	var source_peer_id: int = _camouflage_source_peer_id()
	var paint_sequence: int = _next_camouflage_paint_sequence()
	_apply_camouflage_material_scalars(material_roughness, material_metallic, material_specular)
	if _is_runtime_multiplayer_server() and _has_active_camouflage_multiplayer_peer():
		Network.record_rpc_event("chameleon.paint_stroke", maxi(multiplayer.get_peers().size(), 1), 104)
		_apply_camouflage_brush_stroke.rpc(clean_uv, color, clean_radius, angle, world_position, clean_normal, target_mesh_path, target_surface, _camouflage_paint_roughness, _camouflage_paint_metallic, _camouflage_paint_specular, source_peer_id, paint_sequence)
	elif _should_apply_camouflage_brush_without_server_peer():
		_apply_camouflage_brush_stroke(clean_uv, color, clean_radius, angle, world_position, clean_normal, target_mesh_path, target_surface, _camouflage_paint_roughness, _camouflage_paint_metallic, _camouflage_paint_specular, source_peer_id, paint_sequence)
	else:
		_apply_camouflage_brush_stroke(clean_uv, color, clean_radius, angle, world_position, clean_normal, target_mesh_path, target_surface, _camouflage_paint_roughness, _camouflage_paint_metallic, _camouflage_paint_specular, source_peer_id, paint_sequence)
		Network.record_rpc_event("chameleon.paint_stroke_request", 1, 104)
		_request_camouflage_brush_stroke.rpc_id(1, clean_uv, color, clean_radius, angle, world_position, clean_normal, target_mesh_path, target_surface, _camouflage_paint_roughness, _camouflage_paint_metallic, _camouflage_paint_specular, paint_sequence)


func submit_camouflage_brush_stroke_batch(
	uvs: PackedVector2Array,
	color: Color,
	brush_radius: float,
	angle: float,
	world_positions: PackedVector3Array = PackedVector3Array(),
	world_normal: Vector3 = Vector3.UP,
	target_mesh_path: String = "",
	target_surface: int = 0,
	brush_radii: PackedFloat32Array = PackedFloat32Array(),
	uv_clip_triangles: PackedVector2Array = PackedVector2Array(),
	uv_clip_triangle_counts: PackedInt32Array = PackedInt32Array(),
	uv_footprint_metrics: PackedFloat32Array = PackedFloat32Array(),
	material_roughness: float = -1.0,
	material_metallic: float = -1.0,
	material_specular: float = -1.0
) -> void:
	if uvs.is_empty():
		return
	color.a = 1.0
	var clean_uvs := PackedVector2Array()
	for uv in uvs:
		clean_uvs.append(Vector2(clampf(uv.x, 0.0, 1.0), clampf(uv.y, 0.0, 1.0)))
	var clean_radius := _sanitize_camouflage_brush_radius(brush_radius)
	var clean_radii := _sanitize_camouflage_brush_radii(brush_radii, clean_uvs.size(), clean_radius)
	var clean_uv_clip := _sanitize_camouflage_uv_clip_data(uv_clip_triangles, uv_clip_triangle_counts, clean_uvs.size())
	var clean_uv_footprint_metrics := _sanitize_camouflage_uv_footprint_metrics(uv_footprint_metrics, clean_uvs.size())
	var clean_normal := world_normal.normalized() if world_normal.length_squared() > 0.001 else Vector3.UP
	_apply_camouflage_material_scalars(material_roughness, material_metallic, material_specular)
	var clip_triangles: PackedVector2Array = clean_uv_clip.get("triangles", PackedVector2Array())
	var clip_counts: PackedInt32Array = clean_uv_clip.get("counts", PackedInt32Array())
	Network.record_perf_event("skill.chameleon.paint_points", clean_uvs.size())
	_dispatch_camouflage_brush_stroke_batch(
		clean_uvs,
		color,
		clean_radius,
		angle,
		world_positions,
		clean_normal,
		target_mesh_path,
		target_surface,
		clean_radii,
		clip_triangles,
		clip_counts,
		clean_uv_footprint_metrics,
		_camouflage_paint_roughness,
		_camouflage_paint_metallic,
		_camouflage_paint_specular,
		false,
		_camouflage_source_peer_id(),
		_next_camouflage_paint_sequence(),
		0
	)


func _dispatch_camouflage_brush_stroke_batch(
	uvs: PackedVector2Array,
	color: Color,
	brush_radius: float,
	angle: float,
	world_positions: PackedVector3Array,
	world_normal: Vector3,
	target_mesh_path: String,
	target_surface: int,
	brush_radii: PackedFloat32Array,
	uv_clip_triangles: PackedVector2Array,
	uv_clip_triangle_counts: PackedInt32Array,
	uv_footprint_metrics: PackedFloat32Array,
	material_roughness: float,
	material_metallic: float,
	material_specular: float,
	server_forward_only: bool = false,
	source_peer_id: int = 0,
	paint_sequence: int = 0,
	base_chunk_index: int = 0
) -> void:
	var event_source_peer_id: int = source_peer_id if source_peer_id > 0 else _camouflage_source_peer_id()
	var event_paint_sequence: int = paint_sequence if paint_sequence > 0 else _next_camouflage_paint_sequence()
	var chunks: Array[Dictionary] = _make_camouflage_paint_batch_chunks(
		uvs,
		world_positions,
		brush_radii,
		uv_clip_triangles,
		uv_clip_triangle_counts,
		uv_footprint_metrics
	)
	if chunks.is_empty():
		return
	if chunks.size() > 1:
		Network.record_perf_event("skill.chameleon.paint_rpc_chunks", chunks.size())
	var chunk_offset := 0
	for raw_chunk in chunks:
		var event_chunk_index := maxi(base_chunk_index + chunk_offset, 0)
		chunk_offset += 1
		var chunk: Dictionary = raw_chunk
		var chunk_uvs: PackedVector2Array = chunk.get("uvs", PackedVector2Array())
		var chunk_world_positions: PackedVector3Array = chunk.get("world_positions", PackedVector3Array())
		var chunk_brush_radii: PackedFloat32Array = chunk.get("brush_radii", PackedFloat32Array())
		var chunk_clip_triangles: PackedVector2Array = chunk.get("uv_clip_triangles", PackedVector2Array())
		var chunk_clip_counts: PackedInt32Array = chunk.get("uv_clip_triangle_counts", PackedInt32Array())
		var chunk_footprint_metrics: PackedFloat32Array = chunk.get("uv_footprint_metrics", PackedFloat32Array())
		var approx_batch_bytes: int = _camouflage_paint_batch_approx_bytes(
			chunk_uvs.size(),
			chunk_world_positions.size(),
			chunk_clip_triangles.size(),
			chunk_footprint_metrics.size()
		) + 12
		if _is_runtime_multiplayer_server():
			if _has_active_camouflage_multiplayer_peer():
				Network.record_rpc_event("chameleon.paint_batch", maxi(multiplayer.get_peers().size(), 1), approx_batch_bytes)
				_apply_camouflage_brush_stroke_batch.rpc(
					chunk_uvs,
					color,
					brush_radius,
					angle,
					chunk_world_positions,
					world_normal,
					target_mesh_path,
					target_surface,
					chunk_brush_radii,
					chunk_clip_triangles,
					chunk_clip_counts,
					chunk_footprint_metrics,
					material_roughness,
					material_metallic,
					material_specular,
					event_source_peer_id,
					event_paint_sequence,
					event_chunk_index
				)
			else:
				_apply_camouflage_brush_stroke_batch(
					chunk_uvs,
					color,
					brush_radius,
					angle,
					chunk_world_positions,
					world_normal,
					target_mesh_path,
					target_surface,
					chunk_brush_radii,
					chunk_clip_triangles,
					chunk_clip_counts,
					chunk_footprint_metrics,
					material_roughness,
					material_metallic,
					material_specular,
					event_source_peer_id,
					event_paint_sequence,
					event_chunk_index
				)
		elif _should_apply_camouflage_brush_without_server_peer():
			_apply_camouflage_brush_stroke_batch(
				chunk_uvs,
				color,
				brush_radius,
				angle,
				chunk_world_positions,
				world_normal,
				target_mesh_path,
				target_surface,
				chunk_brush_radii,
				chunk_clip_triangles,
				chunk_clip_counts,
				chunk_footprint_metrics,
				material_roughness,
				material_metallic,
				material_specular,
				event_source_peer_id,
				event_paint_sequence,
				event_chunk_index
			)
		elif not server_forward_only:
			_apply_camouflage_brush_stroke_batch(
				chunk_uvs,
				color,
				brush_radius,
				angle,
				chunk_world_positions,
				world_normal,
				target_mesh_path,
				target_surface,
				chunk_brush_radii,
				chunk_clip_triangles,
				chunk_clip_counts,
				chunk_footprint_metrics,
				material_roughness,
				material_metallic,
				material_specular,
				event_source_peer_id,
				event_paint_sequence,
				event_chunk_index
			)
			Network.record_rpc_event("chameleon.paint_batch_request", 1, approx_batch_bytes)
			_request_camouflage_brush_stroke_batch.rpc_id(
				1,
				chunk_uvs,
				color,
				brush_radius,
				angle,
				chunk_world_positions,
				world_normal,
				target_mesh_path,
				target_surface,
				chunk_brush_radii,
				chunk_clip_triangles,
				chunk_clip_counts,
				chunk_footprint_metrics,
				material_roughness,
				material_metallic,
				material_specular,
				event_paint_sequence,
				event_chunk_index
			)


func _make_camouflage_paint_batch_chunks(
	uvs: PackedVector2Array,
	world_positions: PackedVector3Array,
	brush_radii: PackedFloat32Array,
	uv_clip_triangles: PackedVector2Array,
	uv_clip_triangle_counts: PackedInt32Array,
	uv_footprint_metrics: PackedFloat32Array
) -> Array[Dictionary]:
	var chunks: Array[Dictionary] = []
	if uvs.is_empty():
		return chunks
	var use_radii: bool = brush_radii.size() == uvs.size()
	var use_clip_counts: bool = uv_clip_triangle_counts.size() == uvs.size()
	var use_footprint_metrics: bool = uv_footprint_metrics.size() == uvs.size() * 3
	var clip_read_index: int = 0
	var current_uvs: PackedVector2Array = PackedVector2Array()
	var current_world_positions: PackedVector3Array = PackedVector3Array()
	var current_brush_radii: PackedFloat32Array = PackedFloat32Array()
	var current_clip_triangles: PackedVector2Array = PackedVector2Array()
	var current_clip_counts: PackedInt32Array = PackedInt32Array()
	var current_footprint_metrics: PackedFloat32Array = PackedFloat32Array()

	for index in range(uvs.size()):
		var stamp_clip_triangles: PackedVector2Array = PackedVector2Array()
		var stamp_clip_count: int = 0
		if use_clip_counts:
			stamp_clip_count = clampi(int(uv_clip_triangle_counts[index]), 0, CamouflageSystem.BRUSH_UV_CLIP_MAX_TRIANGLES)
			var stamp_clip_uv_count: int = stamp_clip_count * 3
			for clip_offset in range(stamp_clip_uv_count):
				if clip_read_index + clip_offset < uv_clip_triangles.size():
					stamp_clip_triangles.append(uv_clip_triangles[clip_read_index + clip_offset])
			clip_read_index += stamp_clip_uv_count
		var stamp_world_count: int = 1 if index < world_positions.size() else 0
		var stamp_footprint_count: int = 3 if use_footprint_metrics else 0
		var projected_bytes: int = _camouflage_paint_batch_approx_bytes(
			current_uvs.size() + 1,
			current_world_positions.size() + stamp_world_count,
			current_clip_triangles.size() + stamp_clip_triangles.size(),
			current_footprint_metrics.size() + stamp_footprint_count
		)
		var should_flush: bool = not current_uvs.is_empty() and (
			current_uvs.size() >= CAMOUFLAGE_PAINT_RPC_MAX_STAMPS
			or projected_bytes > CAMOUFLAGE_PAINT_RPC_MAX_BYTES
		)
		if should_flush:
			_append_camouflage_paint_batch_chunk(chunks, current_uvs, current_world_positions, current_brush_radii, current_clip_triangles, current_clip_counts, current_footprint_metrics)
			current_uvs = PackedVector2Array()
			current_world_positions = PackedVector3Array()
			current_brush_radii = PackedFloat32Array()
			current_clip_triangles = PackedVector2Array()
			current_clip_counts = PackedInt32Array()
			current_footprint_metrics = PackedFloat32Array()
		current_uvs.append(uvs[index])
		if index < world_positions.size():
			current_world_positions.append(world_positions[index])
		if use_radii:
			current_brush_radii.append(brush_radii[index])
		if use_clip_counts:
			current_clip_counts.append(stamp_clip_count)
			current_clip_triangles.append_array(stamp_clip_triangles)
		if use_footprint_metrics:
			var metric_offset: int = index * 3
			current_footprint_metrics.append(uv_footprint_metrics[metric_offset])
			current_footprint_metrics.append(uv_footprint_metrics[metric_offset + 1])
			current_footprint_metrics.append(uv_footprint_metrics[metric_offset + 2])
	_append_camouflage_paint_batch_chunk(chunks, current_uvs, current_world_positions, current_brush_radii, current_clip_triangles, current_clip_counts, current_footprint_metrics)
	return chunks


func _append_camouflage_paint_batch_chunk(
	chunks: Array[Dictionary],
	uvs: PackedVector2Array,
	world_positions: PackedVector3Array,
	brush_radii: PackedFloat32Array,
	uv_clip_triangles: PackedVector2Array,
	uv_clip_triangle_counts: PackedInt32Array,
	uv_footprint_metrics: PackedFloat32Array
) -> void:
	if uvs.is_empty():
		return
	chunks.append({
		"uvs": uvs,
		"world_positions": world_positions,
		"brush_radii": brush_radii,
		"uv_clip_triangles": uv_clip_triangles,
		"uv_clip_triangle_counts": uv_clip_triangle_counts,
		"uv_footprint_metrics": uv_footprint_metrics,
	})


func _camouflage_paint_batch_approx_bytes(
	stamp_count: int,
	world_position_count: int,
	clip_uv_count: int,
	footprint_value_count: int
) -> int:
	return (
		CAMOUFLAGE_PAINT_RPC_BASE_BYTES
		+ stamp_count * CAMOUFLAGE_PAINT_RPC_BYTES_PER_STAMP
		+ world_position_count * CAMOUFLAGE_PAINT_RPC_BYTES_PER_WORLD_POSITION
		+ clip_uv_count * CAMOUFLAGE_PAINT_RPC_BYTES_PER_CLIP_UV
		+ footprint_value_count * CAMOUFLAGE_PAINT_RPC_BYTES_PER_FOOTPRINT_VALUE
	)


func _should_apply_camouflage_brush_without_server_peer() -> bool:
	return not _has_active_camouflage_multiplayer_peer()


func _camouflage_source_peer_id() -> int:
	var authority: int = get_multiplayer_authority()
	if authority > 0:
		return authority
	return _local_peer_id()


func _next_camouflage_paint_sequence() -> int:
	_camouflage_paint_sequence += 1
	if _camouflage_paint_sequence > 2147480000:
		_camouflage_paint_sequence = 1
	return _camouflage_paint_sequence


func _camouflage_paint_event_key(source_peer_id: int, paint_sequence: int, chunk_index: int) -> String:
	if source_peer_id <= 0 or paint_sequence <= 0:
		return ""
	return "%d:%d:%d" % [source_peer_id, paint_sequence, chunk_index]


func _remember_camouflage_paint_event(source_peer_id: int, paint_sequence: int, chunk_index: int) -> bool:
	var key: String = _camouflage_paint_event_key(source_peer_id, paint_sequence, chunk_index)
	if key.is_empty():
		return false
	if _applied_camouflage_paint_event_keys.has(key):
		Network.record_perf_event("skill.chameleon.paint_event_duplicate")
		return true
	_applied_camouflage_paint_event_keys.append(key)
	while _applied_camouflage_paint_event_keys.size() > CAMOUFLAGE_PAINT_APPLIED_EVENT_LIMIT:
		_applied_camouflage_paint_event_keys.pop_front()
	return false


func _record_camouflage_paint_event(event_type: String, source_peer_id: int, paint_sequence: int, chunk_index: int, payload: Dictionary) -> void:
	if _camouflage_replaying_paint_events:
		return
	var event: Dictionary = {
		"type": event_type,
		"source_peer_id": source_peer_id,
		"paint_sequence": paint_sequence,
		"chunk_index": chunk_index,
		"tick": NetworkTime.tick,
		"payload": payload.duplicate(true),
	}
	_camouflage_paint_event_log.append(event)
	while _camouflage_paint_event_log.size() > CAMOUFLAGE_PAINT_EVENT_LOG_LIMIT:
		_camouflage_paint_event_log.pop_front()


func get_camouflage_paint_event_log() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for event: Dictionary in _camouflage_paint_event_log:
		events.append(event.duplicate(true))
	return events


func clear_camouflage_paint_event_log() -> void:
	_camouflage_paint_event_log.clear()


func replay_camouflage_paint_event_log(reset_render_cache: bool = true) -> int:
	var replayed_count: int = 0
	if reset_render_cache:
		_clear_camouflage_paint_render_cache()
	_camouflage_replaying_paint_events = true
	for event: Dictionary in _camouflage_paint_event_log:
		if _replay_camouflage_paint_event(event):
			replayed_count += 1
	_camouflage_replaying_paint_events = false
	return replayed_count


func _replay_camouflage_paint_event(event: Dictionary) -> bool:
	var payload: Dictionary = event.get("payload", {})
	match str(event.get("type", "")):
		"start":
			_start_camouflage_brush_visual(payload.get("base_color", Color.WHITE), 0, 0)
			return true
		"stroke":
			_apply_camouflage_brush_stroke(
				payload.get("uv", Vector2.ZERO),
				payload.get("color", Color.WHITE),
				float(payload.get("brush_radius", 0.0)),
				float(payload.get("angle", 0.0)),
				payload.get("world_position", Vector3.ZERO),
				payload.get("world_normal", Vector3.UP),
				str(payload.get("target_mesh_path", "")),
				int(payload.get("target_surface", 0)),
				float(payload.get("material_roughness", -1.0)),
				float(payload.get("material_metallic", -1.0)),
				float(payload.get("material_specular", -1.0)),
				0,
				0
			)
			return true
		"stroke_batch":
			_apply_camouflage_brush_stroke_batch(
				payload.get("uvs", PackedVector2Array()),
				payload.get("color", Color.WHITE),
				float(payload.get("brush_radius", 0.0)),
				float(payload.get("angle", 0.0)),
				payload.get("world_positions", PackedVector3Array()),
				payload.get("world_normal", Vector3.UP),
				str(payload.get("target_mesh_path", "")),
				int(payload.get("target_surface", 0)),
				payload.get("brush_radii", PackedFloat32Array()),
				payload.get("uv_clip_triangles", PackedVector2Array()),
				payload.get("uv_clip_triangle_counts", PackedInt32Array()),
				payload.get("uv_footprint_metrics", PackedFloat32Array()),
				float(payload.get("material_roughness", -1.0)),
				float(payload.get("material_metallic", -1.0)),
				float(payload.get("material_specular", -1.0)),
				0,
				0,
				0
			)
			return true
		_:
			return false


func _has_active_camouflage_multiplayer_peer() -> bool:
	var peer := multiplayer.multiplayer_peer
	if peer == null:
		return false
	if peer is OfflineMultiplayerPeer:
		return false
	return peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED


func _should_skip_camouflage_paint_rendering() -> bool:
	return _is_dedicated_public_server_runtime()


func _clear_camouflage_paint_render_cache() -> void:
	_camouflage_paint_texture = null
	_camouflage_paint_textures.clear()
	_camouflage_surface_materials.clear()
	_camouflage_paint_layer_materials.clear()
	_camouflage_source_material_infos.clear()
	_clear_camouflage_gpu_runtime_work()


@rpc("any_peer", "call_local", "reliable")
func _request_camouflage_brush_start(base_color: Color, paint_sequence: int = 0) -> void:
	if not _is_runtime_multiplayer_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	if not is_chameleon():
		return
	base_color.a = 1.0
	_start_camouflage_brush_visual.rpc(base_color, sender, maxi(paint_sequence, 0))


@rpc("any_peer", "call_local", "unreliable_ordered")
func _request_camouflage_brush_stroke(
	uv: Vector2,
	color: Color,
	brush_radius: float,
	angle: float,
	world_position: Vector3 = Vector3.ZERO,
	world_normal: Vector3 = Vector3.UP,
	target_mesh_path: String = "",
	target_surface: int = 0,
	material_roughness: float = -1.0,
	material_metallic: float = -1.0,
	material_specular: float = -1.0,
	paint_sequence: int = 0
) -> void:
	if not _is_runtime_multiplayer_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	color.a = 1.0
	var clean_normal := world_normal.normalized() if world_normal.length_squared() > 0.001 else Vector3.UP
	_apply_camouflage_material_scalars(material_roughness, material_metallic, material_specular)
	_apply_camouflage_brush_stroke.rpc(
		Vector2(clampf(uv.x, 0.0, 1.0), clampf(uv.y, 0.0, 1.0)),
		color,
		_sanitize_camouflage_brush_radius(brush_radius),
		angle,
		world_position,
		clean_normal,
		target_mesh_path,
		target_surface,
		_camouflage_paint_roughness,
		_camouflage_paint_metallic,
		_camouflage_paint_specular,
		sender,
		maxi(paint_sequence, 0)
	)


@rpc("any_peer", "call_local", "unreliable_ordered")
func _request_camouflage_brush_stroke_batch(
	uvs: PackedVector2Array,
	color: Color,
	brush_radius: float,
	angle: float,
	world_positions: PackedVector3Array = PackedVector3Array(),
	world_normal: Vector3 = Vector3.UP,
	target_mesh_path: String = "",
	target_surface: int = 0,
	brush_radii: PackedFloat32Array = PackedFloat32Array(),
	uv_clip_triangles: PackedVector2Array = PackedVector2Array(),
	uv_clip_triangle_counts: PackedInt32Array = PackedInt32Array(),
	uv_footprint_metrics: PackedFloat32Array = PackedFloat32Array(),
	material_roughness: float = -1.0,
	material_metallic: float = -1.0,
	material_specular: float = -1.0,
	paint_sequence: int = 0,
	chunk_index: int = 0
) -> void:
	if not _is_runtime_multiplayer_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		return
	color.a = 1.0
	var clean_uvs := PackedVector2Array()
	for uv in uvs:
		clean_uvs.append(Vector2(clampf(uv.x, 0.0, 1.0), clampf(uv.y, 0.0, 1.0)))
	var clean_radius := _sanitize_camouflage_brush_radius(brush_radius)
	var clean_radii := _sanitize_camouflage_brush_radii(brush_radii, clean_uvs.size(), clean_radius)
	var clean_uv_clip := _sanitize_camouflage_uv_clip_data(uv_clip_triangles, uv_clip_triangle_counts, clean_uvs.size())
	var clean_uv_footprint_metrics := _sanitize_camouflage_uv_footprint_metrics(uv_footprint_metrics, clean_uvs.size())
	var clean_normal := world_normal.normalized() if world_normal.length_squared() > 0.001 else Vector3.UP
	_apply_camouflage_material_scalars(material_roughness, material_metallic, material_specular)
	_dispatch_camouflage_brush_stroke_batch(
		clean_uvs,
		color,
		clean_radius,
		angle,
		world_positions,
		clean_normal,
		target_mesh_path,
		target_surface,
		clean_radii,
		clean_uv_clip.get("triangles", PackedVector2Array()),
		clean_uv_clip.get("counts", PackedInt32Array()),
		clean_uv_footprint_metrics,
		_camouflage_paint_roughness,
		_camouflage_paint_metallic,
		_camouflage_paint_specular,
		true,
		sender,
		maxi(paint_sequence, 0),
		maxi(chunk_index, 0)
	)


@rpc("any_peer", "call_local", "reliable")
func _start_camouflage_brush_visual(base_color: Color, source_peer_id: int = 0, paint_sequence: int = 0) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1 and not _is_runtime_multiplayer_server():
		return
	if _remember_camouflage_paint_event(source_peer_id, paint_sequence, -1):
		return
	base_color.a = 1.0
	_record_camouflage_paint_event("start", source_peer_id, paint_sequence, -1, {
		"base_color": base_color,
	})
	if _should_skip_camouflage_paint_rendering():
		_clear_camouflage_paint_render_cache()
		return
	_camouflage_brush_base_color = base_color
	_camouflage_paint_textures.clear()
	_camouflage_surface_materials.clear()
	_camouflage_paint_layer_materials.clear()
	_camouflage_source_material_infos.clear()
	_camouflage_paint_texture = CamouflageSystem.create_brush_canvas(base_color)
	_camouflage_gpu_stroke_queue.clear()
	_camouflage_gpu_draw_timer = 0.0


@rpc("any_peer", "call_local", "unreliable_ordered")
func _apply_camouflage_brush_stroke(
	uv: Vector2,
	color: Color,
	brush_radius: float,
	angle: float,
	world_position: Vector3 = Vector3.ZERO,
	world_normal: Vector3 = Vector3.UP,
	target_mesh_path: String = "",
	target_surface: int = 0,
	material_roughness: float = -1.0,
	material_metallic: float = -1.0,
	material_specular: float = -1.0,
	source_peer_id: int = 0,
	paint_sequence: int = 0
) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1 and not _is_runtime_multiplayer_server():
		return
	if _remember_camouflage_paint_event(source_peer_id, paint_sequence, 0):
		return
	color.a = 1.0
	_apply_camouflage_material_scalars(material_roughness, material_metallic, material_specular)
	_record_camouflage_paint_event("stroke", source_peer_id, paint_sequence, 0, {
		"uv": uv,
		"color": color,
		"brush_radius": brush_radius,
		"angle": angle,
		"world_position": world_position,
		"world_normal": world_normal,
		"target_mesh_path": target_mesh_path,
		"target_surface": target_surface,
		"material_roughness": _camouflage_paint_roughness,
		"material_metallic": _camouflage_paint_metallic,
		"material_specular": _camouflage_paint_specular,
	})
	if _should_skip_camouflage_paint_rendering():
		_clear_camouflage_paint_render_cache()
		return
	if not _camouflage_paint_texture:
		_camouflage_paint_texture = CamouflageSystem.create_brush_canvas(color.darkened(0.24))
	_queue_camouflage_gpu_brush_stroke(world_position, world_normal, color, brush_radius)
	if target_mesh_path.is_empty():
		var global_painted := CamouflageSystem.paint_brush_on_texture(_camouflage_paint_texture, uv, color, brush_radius, angle)
		if global_painted != _camouflage_paint_texture:
			_camouflage_paint_texture = global_painted
		_apply_camouflage_texture_to_character(_camouflage_paint_texture, color, 1.0)
		return
	var mesh_instance := get_node_or_null(target_mesh_path) as MeshInstance3D
	if not mesh_instance:
		return
	var surface := _normalize_camouflage_target_surface(mesh_instance, target_surface)
	var target_texture := _get_camouflage_target_texture(target_mesh_path, surface)
	var painted := CamouflageSystem.paint_brush_on_texture(target_texture, uv, color, brush_radius, angle)
	_camouflage_paint_textures[_camouflage_texture_key(target_mesh_path, surface)] = painted
	_apply_camouflage_texture_to_mesh_surface(target_mesh_path, surface, painted, color, 1.0)


@rpc("any_peer", "call_local", "unreliable_ordered")
func _apply_camouflage_brush_stroke_batch(
	uvs: PackedVector2Array,
	color: Color,
	brush_radius: float,
	angle: float,
	world_positions: PackedVector3Array = PackedVector3Array(),
	world_normal: Vector3 = Vector3.UP,
	target_mesh_path: String = "",
	target_surface: int = 0,
	brush_radii: PackedFloat32Array = PackedFloat32Array(),
	uv_clip_triangles: PackedVector2Array = PackedVector2Array(),
	uv_clip_triangle_counts: PackedInt32Array = PackedInt32Array(),
	uv_footprint_metrics: PackedFloat32Array = PackedFloat32Array(),
	material_roughness: float = -1.0,
	material_metallic: float = -1.0,
	material_specular: float = -1.0,
	source_peer_id: int = 0,
	paint_sequence: int = 0,
	chunk_index: int = 0
) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1 and not _is_runtime_multiplayer_server():
		return
	if uvs.is_empty():
		return
	if _remember_camouflage_paint_event(source_peer_id, paint_sequence, chunk_index):
		return
	color.a = 1.0
	_apply_camouflage_material_scalars(material_roughness, material_metallic, material_specular)
	var clean_radii := _sanitize_camouflage_brush_radii(brush_radii, uvs.size(), brush_radius)
	var clean_normal := world_normal.normalized() if world_normal.length_squared() > 0.001 else Vector3.UP
	var clean_uv_clip := _sanitize_camouflage_uv_clip_data(uv_clip_triangles, uv_clip_triangle_counts, uvs.size())
	var clean_uv_footprint_metrics := _sanitize_camouflage_uv_footprint_metrics(uv_footprint_metrics, uvs.size())
	_record_camouflage_paint_event("stroke_batch", source_peer_id, paint_sequence, chunk_index, {
		"uvs": uvs.duplicate(),
		"color": color,
		"brush_radius": brush_radius,
		"angle": angle,
		"world_positions": world_positions.duplicate(),
		"world_normal": clean_normal,
		"target_mesh_path": target_mesh_path,
		"target_surface": target_surface,
		"brush_radii": clean_radii.duplicate(),
		"uv_clip_triangles": clean_uv_clip.get("triangles", PackedVector2Array()).duplicate(),
		"uv_clip_triangle_counts": clean_uv_clip.get("counts", PackedInt32Array()).duplicate(),
		"uv_footprint_metrics": clean_uv_footprint_metrics.duplicate(),
		"material_roughness": _camouflage_paint_roughness,
		"material_metallic": _camouflage_paint_metallic,
		"material_specular": _camouflage_paint_specular,
	})
	if _should_skip_camouflage_paint_rendering():
		_clear_camouflage_paint_render_cache()
		return
	if not _camouflage_paint_texture:
		_camouflage_paint_texture = CamouflageSystem.create_brush_canvas(color.darkened(0.24))
	if target_mesh_path.is_empty():
		var global_painted := CamouflageSystem.paint_brush_strokes_on_texture(_camouflage_paint_texture, uvs, color, brush_radius, angle, clean_radii, clean_uv_clip.get("triangles", PackedVector2Array()), clean_uv_clip.get("counts", PackedInt32Array()), clean_uv_footprint_metrics)
		if global_painted != _camouflage_paint_texture:
			_camouflage_paint_texture = global_painted
		_apply_camouflage_texture_to_character(_camouflage_paint_texture, color, 1.0)
		_queue_camouflage_gpu_brush_strokes(world_positions, clean_normal, color, brush_radius, clean_radii)
		return
	var mesh_instance := get_node_or_null(target_mesh_path) as MeshInstance3D
	if not mesh_instance:
		return
	var surface := _normalize_camouflage_target_surface(mesh_instance, target_surface)
	var target_texture := _get_camouflage_target_texture(target_mesh_path, surface)
	var painted := CamouflageSystem.paint_brush_strokes_on_texture(target_texture, uvs, color, brush_radius, angle, clean_radii, clean_uv_clip.get("triangles", PackedVector2Array()), clean_uv_clip.get("counts", PackedInt32Array()), clean_uv_footprint_metrics)
	_camouflage_paint_textures[_camouflage_texture_key(target_mesh_path, surface)] = painted
	_apply_camouflage_texture_to_mesh_surface(target_mesh_path, surface, painted, color, 1.0)
	_queue_camouflage_gpu_brush_strokes(world_positions, clean_normal, color, brush_radius, clean_radii)


func _get_camouflage_target_texture(target_mesh_path: String, target_surface: int) -> Texture2D:
	var key := _camouflage_texture_key(target_mesh_path, target_surface)
	if _camouflage_paint_textures.has(key):
		return _camouflage_paint_textures[key] as Texture2D
	var texture := _create_environment_prop_sync_canvas() if _is_environment_prop_preview_mesh_path(target_mesh_path) else CamouflageSystem.create_paint_layer_canvas()
	_camouflage_paint_textures[key] = texture
	return texture


func _camouflage_texture_key(target_mesh_path: String, target_surface: int) -> String:
	return "%s:%d" % [target_mesh_path, target_surface]


func _is_environment_prop_preview_mesh_path(target_mesh_path: String) -> bool:
	return target_mesh_path.find("EnvironmentBlendPreview") >= 0


func _create_environment_prop_sync_canvas() -> Texture2D:
	var image := Image.create(CamouflageSystem.TEXTURE_SIZE, CamouflageSystem.TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	return ImageTexture.create_from_image(image)


func _normalize_camouflage_target_surface(mesh_instance: MeshInstance3D, target_surface: int) -> int:
	return clampi(target_surface, 0, _get_mesh_surface_count(mesh_instance) - 1)


func _apply_camouflage_texture_to_mesh_surface(
	target_mesh_path: String,
	target_surface: int,
	texture: Texture2D,
	primary_color: Color,
	confidence: float
) -> void:
	var mesh_instance := get_node_or_null(target_mesh_path) as MeshInstance3D
	if not mesh_instance:
		return
	var surface := _normalize_camouflage_target_surface(mesh_instance, target_surface)
	var key := _camouflage_texture_key(target_mesh_path, surface)
	var source_info := _get_camouflage_surface_source_info(mesh_instance, surface, key)
	var material := _ensure_camouflage_paint_layer_material(mesh_instance, surface, key, source_info)
	_configure_camouflage_paint_layer_controls(material)
	var display_strength := clampf(confidence, 0.0, 1.0)
	var bound_texture = material.get_meta("camouflage_bound_paint_texture") if material.has_meta("camouflage_bound_paint_texture") else null
	if bound_texture != texture:
		material.set_shader_parameter("paint_texture", texture)
		material.set_meta("camouflage_bound_paint_texture", texture)
	var bound_strength := float(material.get_meta("camouflage_bound_paint_strength")) if material.has_meta("camouflage_bound_paint_strength") else -1.0
	if absf(bound_strength - display_strength) > 0.001:
		material.set_shader_parameter("paint_display_strength", display_strength)
		material.set_meta("camouflage_bound_paint_strength", display_strength)


func _apply_camouflage_texture_to_character(texture: Texture2D, primary_color: Color, confidence: float) -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect_camouflage_meshes(meshes)
	for mesh_instance in meshes:
		var surface_count := _get_mesh_surface_count(mesh_instance)
		for surface in range(surface_count):
			var material := _ensure_unique_standard_material(mesh_instance, surface)
			_configure_camouflage_display_material(material)
			material.albedo_texture = texture
			material.albedo_color = Color.WHITE


func _collect_camouflage_meshes(result: Array[MeshInstance3D]) -> void:
	for mesh in [_bottom_mesh, _chest_mesh, _face_mesh, _limbs_head_mesh]:
		if mesh and is_instance_valid(mesh):
			result.append(mesh)
	if _active_skin_node and is_instance_valid(_active_skin_node):
		_find_meshes(_active_skin_node, result)


func _configure_camouflage_display_material(material: StandardMaterial3D) -> void:
	if not material:
		return
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.disable_receive_shadows = false
	material.roughness = _camouflage_paint_roughness
	material.metallic = _camouflage_paint_metallic
	material.set("metallic_specular", _camouflage_paint_specular)
	if _camouflage_paint_normal_texture:
		material.set("normal_enabled", true)
		material.set("normal_texture", _camouflage_paint_normal_texture)
		material.set("normal_scale", _camouflage_paint_normal_scale)


func _get_mesh_surface_count(mesh_instance: MeshInstance3D) -> int:
	if not mesh_instance:
		return 0
	var count := mesh_instance.get_surface_override_material_count()
	if mesh_instance.mesh:
		count = maxi(count, mesh_instance.mesh.get_surface_count())
	return max(0, count)


func _get_mesh_surface_material(mesh_instance: MeshInstance3D, surface: int) -> Material:
	if not mesh_instance or surface < 0:
		return null
	var material: Material = null
	if surface < mesh_instance.get_surface_override_material_count():
		material = mesh_instance.get_surface_override_material(surface)
	if not material:
		material = mesh_instance.material_override
	if not material and mesh_instance.mesh and surface < mesh_instance.mesh.get_surface_count():
		material = mesh_instance.mesh.surface_get_material(surface)
	return material


func _get_material_base_color(material: Material) -> Color:
	if material is StandardMaterial3D:
		var color := (material as StandardMaterial3D).albedo_color
		color.a = 1.0
		return color
	return Color.WHITE


func _get_material_albedo_texture(material: Material) -> Texture2D:
	if material is StandardMaterial3D:
		return (material as StandardMaterial3D).albedo_texture
	return null


func _get_camouflage_surface_source_info(mesh_instance: MeshInstance3D, surface: int, key: String) -> Dictionary:
	if _camouflage_source_material_infos.has(key):
		return _camouflage_source_material_infos[key] as Dictionary
	var material := _get_mesh_surface_material(mesh_instance, surface)
	if material is ShaderMaterial and bool((material as ShaderMaterial).get_meta("camouflage_paint_layer", false)):
		var shader_material := material as ShaderMaterial
		var existing_info := {
			"base_color": shader_material.get_shader_parameter("base_color") as Color,
			"base_texture": shader_material.get_shader_parameter("base_texture") as Texture2D,
			"use_base_texture": bool(shader_material.get_shader_parameter("use_base_texture")),
		}
		_camouflage_source_material_infos[key] = existing_info
		return existing_info
	var source_texture := _get_material_albedo_texture(material)
	var source_info := {
		"base_color": _get_material_base_color(material),
		"base_texture": source_texture,
		"use_base_texture": source_texture != null,
	}
	_camouflage_source_material_infos[key] = source_info
	return source_info


func _ensure_camouflage_paint_layer_material(
	mesh_instance: MeshInstance3D,
	surface: int,
	key: String,
	source_info: Dictionary
) -> ShaderMaterial:
	if _camouflage_paint_layer_materials.has(key):
		var cached_material := _camouflage_paint_layer_materials[key] as ShaderMaterial
		if cached_material and is_instance_valid(cached_material):
			mesh_instance.set_surface_override_material(surface, cached_material)
			return cached_material

	var material := _get_mesh_surface_material(mesh_instance, surface)
	if material is ShaderMaterial and bool((material as ShaderMaterial).get_meta("camouflage_paint_layer", false)):
		_camouflage_paint_layer_materials[key] = material
		return material as ShaderMaterial

	var shader_material := ShaderMaterial.new()
	shader_material.shader = CAMOUFLAGE_PAINT_LAYER_SHADER
	shader_material.resource_local_to_scene = true
	shader_material.set_meta("camouflage_paint_layer", true)
	shader_material.set_shader_parameter("base_color", source_info.get("base_color", Color.WHITE))
	var source_texture := source_info.get("base_texture", null) as Texture2D
	if source_texture:
		shader_material.set_shader_parameter("base_texture", source_texture)
	shader_material.set_shader_parameter("use_base_texture", bool(source_info.get("use_base_texture", false)))
	_configure_camouflage_paint_layer_controls(shader_material)
	mesh_instance.set_surface_override_material(surface, shader_material)
	_camouflage_paint_layer_materials[key] = shader_material
	return shader_material


func _configure_camouflage_paint_layer_controls(material: ShaderMaterial) -> void:
	if not material:
		return
	material.set_shader_parameter("paint_exact_color_match", _camouflage_paint_exact_color_match)
	material.set_shader_parameter("paint_roughness", _camouflage_paint_roughness)
	material.set_shader_parameter("paint_metallic", _camouflage_paint_metallic)
	material.set_shader_parameter("paint_specular", _camouflage_paint_specular)
	material.set_shader_parameter("use_paint_normal_texture", _camouflage_paint_normal_texture != null)
	if _camouflage_paint_normal_texture:
		material.set_shader_parameter("paint_normal_texture", _camouflage_paint_normal_texture)
	material.set_shader_parameter("paint_normal_scale", _camouflage_paint_normal_scale)


func _apply_camouflage_material_scalars(roughness: float, metallic: float, specular: float) -> void:
	var changed := false
	if roughness >= 0.0:
		var next_roughness := clampf(roughness, 0.0, 1.0)
		changed = changed or absf(next_roughness - _camouflage_paint_roughness) > 0.001
		_camouflage_paint_roughness = next_roughness
	if metallic >= 0.0:
		var next_metallic := clampf(metallic, 0.0, 1.0)
		changed = changed or absf(next_metallic - _camouflage_paint_metallic) > 0.001
		_camouflage_paint_metallic = next_metallic
	if specular >= 0.0:
		var next_specular := clampf(specular, 0.0, 1.0)
		changed = changed or absf(next_specular - _camouflage_paint_specular) > 0.001
		_camouflage_paint_specular = next_specular
	if not changed:
		return
	for material in _camouflage_paint_layer_materials.values():
		if material is ShaderMaterial and is_instance_valid(material):
			_configure_camouflage_paint_layer_controls(material as ShaderMaterial)
	for material in _camouflage_surface_materials.values():
		if material is StandardMaterial3D and is_instance_valid(material):
			_configure_camouflage_display_material(material as StandardMaterial3D)
	_configure_camouflage_gpu_overlay_materials()


func _should_run_camouflage_gpu_painter() -> bool:
	if not _is_local_authority():
		return false
	if DisplayServer.get_name() == "headless":
		return false
	return true


func _clear_camouflage_gpu_runtime_work() -> void:
	if not _camouflage_gpu_stroke_queue.is_empty():
		_camouflage_gpu_stroke_queue.clear()
	_camouflage_gpu_draw_timer = 0.0
	if _camouflage_gpu_camera_brush and is_instance_valid(_camouflage_gpu_camera_brush):
		_camouflage_gpu_camera_brush.set("drawing", false)


func _ensure_camouflage_gpu_painter() -> bool:
	if not _should_run_camouflage_gpu_painter():
		return false
	if _camouflage_gpu_unavailable:
		return false
	if _camouflage_gpu_atlas_manager and is_instance_valid(_camouflage_gpu_atlas_manager) and _camouflage_gpu_camera_brush and is_instance_valid(_camouflage_gpu_camera_brush):
		return true

	var manager_script = load("res://addons/gpu_texture_painter/manager/overlay_atlas_manager.gd")
	var brush_script = load("res://addons/gpu_texture_painter/brush/camera_brush.gd")
	if not manager_script or not brush_script:
		_camouflage_gpu_unavailable = true
		push_warning("Chameleon GPU painter addon is unavailable; falling back to CPU camouflage paint.")
		return false

	if not _prepare_camouflage_gpu_meshes():
		_camouflage_gpu_unavailable = true
		push_warning("Chameleon GPU painter could not find or build UV2 paint meshes; falling back to CPU camouflage paint.")
		return false

	var manager = manager_script.new()
	if not manager is Node3D:
		_camouflage_gpu_unavailable = true
		return false
	manager.name = "ChameleonGPUOverlayAtlasManager"
	add_child(manager)
	_camouflage_gpu_atlas_manager = manager as Node3D
	_camouflage_gpu_atlas_manager.set("atlas_size", CAMOUFLAGE_GPU_ATLAS_SIZE)
	_camouflage_gpu_atlas_manager.set("overlay_shader", CHAMELEON_GPU_PBR_OVERLAY_SHADER)
	_camouflage_gpu_atlas_manager.set("apply_on_ready", false)

	var brush = brush_script.new()
	if not brush is Node3D:
		_camouflage_gpu_unavailable = true
		return false
	brush.name = "ChameleonGPUCameraBrush"
	add_child(brush)
	_camouflage_gpu_camera_brush = brush as Node3D
	_camouflage_gpu_camera_brush.top_level = true
	_camouflage_gpu_camera_brush.set("projection", Camera3D.PROJECTION_ORTHOGONAL)
	_camouflage_gpu_camera_brush.set("size", 0.35)
	_camouflage_gpu_camera_brush.set("max_distance", 3.0)
	_camouflage_gpu_camera_brush.set("start_distance_fade", 1.0)
	_camouflage_gpu_camera_brush.set("min_bleed", 1)
	_camouflage_gpu_camera_brush.set("max_bleed", 2)
	_camouflage_gpu_camera_brush.set("resolution", Vector2i(256, 256))
	_camouflage_gpu_camera_brush.set("draw_speed", 180.0)
	_camouflage_gpu_camera_brush.set("drawing", false)

	if _camouflage_gpu_atlas_manager.has_method("apply"):
		_camouflage_gpu_atlas_manager.call("apply")
	_configure_camouflage_gpu_overlay_materials()
	return true


func _prepare_camouflage_gpu_meshes() -> bool:
	var meshes: Array[MeshInstance3D] = []
	_collect_camouflage_meshes(meshes)
	var prepared_count := 0
	for mesh_instance in meshes:
		if not mesh_instance or not is_instance_valid(mesh_instance):
			continue
		if not _ensure_mesh_uv2_from_uv(mesh_instance):
			continue
		mesh_instance.layers |= 1 << CAMOUFLAGE_GPU_OVERLAY_LAYER
		var mesh := mesh_instance.mesh
		if mesh.lightmap_size_hint == Vector2i.ZERO:
			mesh.lightmap_size_hint = CAMOUFLAGE_GPU_DEFAULT_LIGHTMAP_HINT
		prepared_count += 1
	return prepared_count > 0


func _ensure_mesh_uv2_from_uv(mesh_instance: MeshInstance3D) -> bool:
	if not mesh_instance or not mesh_instance.mesh:
		return false
	if _mesh_has_uv2(mesh_instance.mesh):
		return true
	var source_mesh := mesh_instance.mesh
	var paint_mesh := ArrayMesh.new()
	paint_mesh.resource_local_to_scene = true
	paint_mesh.lightmap_size_hint = CAMOUFLAGE_GPU_DEFAULT_LIGHTMAP_HINT
	for surface in range(source_mesh.get_surface_count()):
		var arrays := CamouflageSystem._get_mesh_surface_arrays_static(source_mesh, surface)
		if not arrays is Array or arrays.is_empty() or arrays.size() <= Mesh.ARRAY_TEX_UV2:
			return false
		var uv_value = arrays[Mesh.ARRAY_TEX_UV]
		if not uv_value is PackedVector2Array or (uv_value as PackedVector2Array).is_empty():
			return false
		arrays[Mesh.ARRAY_TEX_UV2] = uv_value
		var primitive := Mesh.PRIMITIVE_TRIANGLES
		if source_mesh.has_method("surface_get_primitive_type"):
			primitive = int(source_mesh.call("surface_get_primitive_type", surface))
		paint_mesh.add_surface_from_arrays(primitive, arrays)
		if surface < paint_mesh.get_surface_count():
			var surface_material := source_mesh.surface_get_material(surface)
			if surface_material:
				paint_mesh.surface_set_material(surface, surface_material)
	if paint_mesh.get_surface_count() <= 0:
		return false
	mesh_instance.mesh = paint_mesh
	return _mesh_has_uv2(paint_mesh)


func _mesh_has_uv2(mesh: Mesh) -> bool:
	if not mesh:
		return false
	for surface in range(mesh.get_surface_count()):
		var arrays := []
		if mesh is PrimitiveMesh:
			arrays = (mesh as PrimitiveMesh).get_mesh_arrays()
		elif mesh.has_method("surface_get_arrays"):
			arrays = mesh.call("surface_get_arrays", surface)
		if arrays.is_empty() or arrays.size() <= Mesh.ARRAY_TEX_UV2:
			return false
		var uv2_value = arrays[Mesh.ARRAY_TEX_UV2]
		if not uv2_value is PackedVector2Array:
			return false
		var uv2s: PackedVector2Array = uv2_value
		if uv2s.is_empty():
			return false
	return true


func _configure_camouflage_gpu_overlay_materials() -> void:
	if not _should_run_camouflage_gpu_painter():
		return
	var meshes: Array[MeshInstance3D] = []
	_collect_camouflage_meshes(meshes)
	for mesh_instance in meshes:
		if not mesh_instance or not is_instance_valid(mesh_instance):
			continue
		var material := mesh_instance.material_overlay as ShaderMaterial
		if not material:
			continue
		material.set_shader_parameter("paint_display_strength", 1.0)
		material.set_shader_parameter("paint_roughness", _camouflage_paint_roughness)
		material.set_shader_parameter("paint_metallic", _camouflage_paint_metallic)
		material.set_shader_parameter("paint_specular", _camouflage_paint_specular)
		material.set_shader_parameter("use_paint_normal_texture", _camouflage_paint_normal_texture != null)
		if _camouflage_paint_normal_texture:
			material.set_shader_parameter("paint_normal_texture", _camouflage_paint_normal_texture)
		material.set_shader_parameter("paint_normal_scale", _camouflage_paint_normal_scale)


func _queue_camouflage_gpu_brush_strokes(
	world_positions: PackedVector3Array,
	world_normal: Vector3,
	color: Color,
	brush_radius: float,
	brush_radii: PackedFloat32Array = PackedFloat32Array()
) -> void:
	if world_positions.is_empty():
		return
	for index in range(world_positions.size()):
		var radius := brush_radius
		if index < brush_radii.size():
			radius = brush_radii[index]
		_queue_camouflage_gpu_brush_stroke(world_positions[index], world_normal, color, radius)


func _queue_camouflage_gpu_brush_stroke(world_position: Vector3, world_normal: Vector3, color: Color, brush_radius: float) -> void:
	if not _should_run_camouflage_gpu_painter():
		return
	if _camouflage_gpu_unavailable:
		return
	var normal := world_normal.normalized() if world_normal.length_squared() > 0.001 else Vector3.UP
	var clean_color := color
	clean_color.a = 1.0
	_camouflage_gpu_stroke_queue.append({
		"position": world_position,
		"normal": normal,
		"color": clean_color,
		"radius": _sanitize_camouflage_brush_radius(brush_radius),
		"roughness": _camouflage_paint_roughness,
		"metallic": _camouflage_paint_metallic,
		"specular": _camouflage_paint_specular,
	})
	while _camouflage_gpu_stroke_queue.size() > CAMOUFLAGE_GPU_MAX_QUEUED_STROKES:
		_camouflage_gpu_stroke_queue.pop_front()


func _process_camouflage_gpu_painter(delta: float) -> void:
	if not _should_run_camouflage_gpu_painter():
		_clear_camouflage_gpu_runtime_work()
		return
	if _camouflage_gpu_draw_timer > 0.0:
		_camouflage_gpu_draw_timer = maxf(0.0, _camouflage_gpu_draw_timer - delta)
		if _camouflage_gpu_draw_timer <= 0.0 and _camouflage_gpu_camera_brush and is_instance_valid(_camouflage_gpu_camera_brush):
			_camouflage_gpu_camera_brush.set("drawing", false)
		return
	if _camouflage_gpu_stroke_queue.is_empty():
		return
	if not _ensure_camouflage_gpu_painter():
		_camouflage_gpu_stroke_queue.clear()
		return
	var stroke: Dictionary = _camouflage_gpu_stroke_queue.pop_front()
	_apply_camouflage_material_scalars(
		float(stroke.get("roughness", _camouflage_paint_roughness)),
		float(stroke.get("metallic", _camouflage_paint_metallic)),
		float(stroke.get("specular", _camouflage_paint_specular))
	)
	_start_camouflage_gpu_brush_stroke(stroke)


func _start_camouflage_gpu_brush_stroke(stroke: Dictionary) -> void:
	if not _camouflage_gpu_camera_brush or not is_instance_valid(_camouflage_gpu_camera_brush):
		return
	var world_position: Vector3 = stroke.get("position", global_position)
	var normal: Vector3 = stroke.get("normal", Vector3.UP)
	normal = normal.normalized() if normal.length_squared() > 0.001 else Vector3.UP
	var color: Color = stroke.get("color", _camouflage_brush_base_color)
	color.a = 1.0
	var texture_radius := clampf(float(stroke.get("radius", 46.0)), 10.0, 160.0)
	var world_size := clampf(texture_radius / 120.0, 0.10, 1.85)
	var brush_distance := clampf(world_size * 1.35 + 0.30, 0.38, 3.0)
	var brush_origin := world_position + normal * brush_distance
	var up := Vector3.UP
	if absf(normal.dot(up)) > 0.92:
		up = Vector3.RIGHT

	_camouflage_gpu_camera_brush.global_position = brush_origin
	_camouflage_gpu_camera_brush.look_at(world_position, up)
	_camouflage_gpu_camera_brush.set("color", color)
	_camouflage_gpu_camera_brush.set("size", world_size)
	_camouflage_gpu_camera_brush.set("max_distance", brush_distance + world_size + 0.45)
	_camouflage_gpu_camera_brush.set("drawing", true)
	_camouflage_gpu_draw_timer = CAMOUFLAGE_GPU_BRUSH_TIME


func _ensure_unique_standard_material(mesh_instance: MeshInstance3D, surface: int) -> StandardMaterial3D:
	if not mesh_instance:
		return StandardMaterial3D.new()
	var cache_key := _camouflage_texture_key(str(get_path_to(mesh_instance)), surface) if mesh_instance.is_inside_tree() else "%d:%d" % [mesh_instance.get_instance_id(), surface]
	if _camouflage_surface_materials.has(cache_key):
		var cached_material := _camouflage_surface_materials[cache_key] as StandardMaterial3D
		if cached_material and is_instance_valid(cached_material):
			mesh_instance.set_surface_override_material(surface, cached_material)
			return cached_material

	var material := _get_mesh_surface_material(mesh_instance, surface)
	if material is StandardMaterial3D and bool((material as StandardMaterial3D).get_meta("camouflage_unique_surface", false)):
		_camouflage_surface_materials[cache_key] = material
		return material as StandardMaterial3D

	var standard: StandardMaterial3D = null
	if material is StandardMaterial3D:
		standard = (material as StandardMaterial3D).duplicate()
	else:
		standard = StandardMaterial3D.new()
	standard.resource_local_to_scene = true
	standard.set_meta("camouflage_unique_surface", true)
	mesh_instance.set_surface_override_material(surface, standard)
	_camouflage_surface_materials[cache_key] = standard
	return standard


func _sanitize_camouflage_palette(palette: Array) -> Array:
	var clean: Array[Color] = []
	for value in palette:
		if value is Color:
			var color := value as Color
			color.a = 1.0
			clean.append(color)
	if clean.is_empty():
		clean.append(Color(0.5, 0.58, 0.48, 1.0))
	while clean.size() < 4:
		var base: Color = clean[0]
		clean.append(base.lightened(0.12 * float(clean.size())))
	return clean.slice(0, 4)


func _sanitize_camouflage_brush_radii(
	brush_radii: PackedFloat32Array,
	expected_count: int,
	fallback_radius: float
) -> PackedFloat32Array:
	var clean := PackedFloat32Array()
	if brush_radii.size() != expected_count:
		return clean
	for radius in brush_radii:
		clean.append(_sanitize_camouflage_brush_radius(radius))
	return clean


func _sanitize_camouflage_uv_clip_data(
	uv_clip_triangles: PackedVector2Array,
	uv_clip_triangle_counts: PackedInt32Array,
	expected_stamp_count: int
) -> Dictionary:
	var clean_triangles := PackedVector2Array()
	var clean_counts := PackedInt32Array()
	if uv_clip_triangle_counts.size() != expected_stamp_count:
		return {"triangles": clean_triangles, "counts": clean_counts}
	var read_index := 0
	for count_value in uv_clip_triangle_counts:
		var count := clampi(int(count_value), 0, CamouflageSystem.BRUSH_UV_CLIP_MAX_TRIANGLES)
		if read_index + count * 3 > uv_clip_triangles.size():
			return {"triangles": PackedVector2Array(), "counts": PackedInt32Array()}
		clean_counts.append(count)
		for _triangle in range(count):
			for _corner in range(3):
				var uv := uv_clip_triangles[read_index]
				clean_triangles.append(Vector2(clampf(uv.x, 0.0, 1.0), clampf(uv.y, 0.0, 1.0)))
				read_index += 1
	if read_index != uv_clip_triangles.size():
		return {"triangles": PackedVector2Array(), "counts": PackedInt32Array()}
	return {"triangles": clean_triangles, "counts": clean_counts}


func _sanitize_camouflage_uv_footprint_metrics(
	uv_footprint_metrics: PackedFloat32Array,
	expected_stamp_count: int
) -> PackedFloat32Array:
	var clean := PackedFloat32Array()
	if uv_footprint_metrics.size() != expected_stamp_count * 3:
		return clean
	for value in uv_footprint_metrics:
		clean.append(clampf(value, -100000000.0, 100000000.0))
	return clean


func _sanitize_camouflage_brush_radius(radius: float) -> float:
	return clampf(radius, CamouflageSystem.BRUSH_PRECISION_SAMPLE_MIN_RADIUS, CamouflageSystem.BRUSH_MAX_RADIUS)


func _refresh_camera_collision_exclusions() -> void:
	if not _spring_arm_offset or not is_instance_valid(_spring_arm_offset):
		return
	if _spring_arm_offset.has_method("refresh_camera_collision_exclusions"):
		_spring_arm_offset.call_deferred("refresh_camera_collision_exclusions")


func set_character_model(model_id: String) -> void:
	var normalized := _resolve_character_model_for_role(model_id)
	character_model_id = normalized
	if CharacterSkinCatalog.is_party_monster(normalized):
		_party_monster_accessory_loadout = PartyMonsterAccessoryCatalogScript.sanitize_loadout(_party_monster_accessory_loadout, normalized)
	else:
		_party_monster_accessory_loadout.clear()
	_remote_visual_position_initialized = false
	_remote_motion_sampler.reset()
	if not _body:
		return

	if normalized == CharacterSkinCatalog.GODOT_ROBOT_ID:
		_restore_skin_performance_camera_now()
		if _active_skin_node and is_instance_valid(_active_skin_node):
			if _active_skin_node.get_parent():
				_active_skin_node.get_parent().remove_child(_active_skin_node)
			_active_skin_node.queue_free()
		_active_skin_node = null
		if _robot_visual_root:
			_robot_visual_root.visible = true
		_sync_character_visual_animation_activity()
		if is_stalker():
			_refresh_stalker_visibility_view(true)
			call_deferred("_refresh_stalker_visibility_view", true)
		_refresh_camera_collision_exclusions()
		return

	var scene_path := CharacterSkinCatalog.scene_path_for(normalized)
	var scene: PackedScene = load(scene_path)
	if not scene:
		push_warning("Character model scene could not be loaded: " + scene_path)
		return

	if _active_skin_node and is_instance_valid(_active_skin_node):
		_restore_skin_performance_camera_now()
		if _active_skin_node.get_parent():
			_active_skin_node.get_parent().remove_child(_active_skin_node)
		_active_skin_node.queue_free()

	_active_skin_node = scene.instantiate() as Node3D
	if not _active_skin_node:
		return

	_active_skin_node.name = "CustomCharacterSkin"
	if _active_skin_node.has_method("set_character_model_id"):
		_active_skin_node.call("set_character_model_id", normalized)
	_apply_party_monster_accessories_to_active_skin()
	var model := CharacterSkinCatalog.get_model(normalized)
	_active_skin_node.scale = model.get("scale", Vector3.ONE)
	_active_skin_node.position = model.get("offset", Vector3.ZERO)
	if _robot_visual_root:
		_robot_visual_root.visible = false
	_body.add_child(_active_skin_node)
	_refresh_camera_collision_exclusions()
	_apply_remote_visual_performance_policy(_active_skin_node)
	_connect_active_skin_animation_signals()
	_sync_character_visual_animation_activity()
	_play_skin_action("idle")
	if is_stalker():
		_refresh_stalker_visibility_view(true)
		call_deferred("_refresh_stalker_visibility_view", true)


func _resolve_character_model_for_role(model_id: String) -> String:
	var normalized := CharacterSkinCatalog.normalize(model_id)
	if role == Network.Role.HUNTER and normalized == CharacterSkinCatalog.DEFAULT_ID:
		return CharacterSkinCatalog.HUNTER_SHOOTER_ID
	if role != Network.Role.HUNTER and normalized == CharacterSkinCatalog.HUNTER_SHOOTER_ID:
		return CharacterSkinCatalog.BASIC_HUMANOID_ID
	return normalized


func set_party_monster_accessory_loadout(loadout: Dictionary) -> void:
	if not CharacterSkinCatalog.is_party_monster(character_model_id):
		_party_monster_accessory_loadout.clear()
		_apply_party_monster_accessories_to_active_skin()
		return
	_party_monster_accessory_loadout = PartyMonsterAccessoryCatalogScript.sanitize_loadout(loadout, character_model_id)
	_apply_party_monster_accessories_to_active_skin()
	if _party_monster_bounty_marked:
		_refresh_party_monster_bounty_visuals()


func get_party_monster_accessory_loadout() -> Dictionary:
	return _party_monster_accessory_loadout.duplicate(true)


func has_party_monster_accessory(accessory_id: String) -> bool:
	if not CharacterSkinCatalog.is_party_monster(character_model_id):
		return false
	return PartyMonsterAccessoryCatalogScript.loadout_has_accessory(_party_monster_accessory_loadout, accessory_id)


func _apply_party_monster_accessories_to_active_skin() -> void:
	if not _active_skin_node or not is_instance_valid(_active_skin_node):
		return
	if not _active_skin_node.has_method("set_accessory_loadout"):
		return
	_active_skin_node.call("set_accessory_loadout", _party_monster_accessory_loadout)


func send_party_monster_accessory_feedback(accessory_id: String, replaced_id: String = "") -> void:
	var label := PartyMonsterAccessoryCatalogScript.accessory_label(accessory_id)
	var replaced_label := PartyMonsterAccessoryCatalogScript.accessory_label(replaced_id) if not replaced_id.is_empty() else ""
	var message := "EQUIPPED %s" % label.to_upper()
	if not replaced_label.is_empty() and replaced_label != label:
		message = "SWAPPED %s" % label.to_upper()
	_card_feedback_to_owner(message, Color(1.0, 0.86, 0.25, 1.0), 1.0)


func set_party_monster_bounty_marked(marked: bool, accessory_ids: Array = [], label: String = "") -> void:
	var next_marked := marked and _is_prop_role() and bool(_is_network_marked_alive())
	var was_marked := _party_monster_bounty_marked
	_party_monster_bounty_marked = next_marked
	_party_monster_bounty_accessory_ids = accessory_ids.duplicate()
	_party_monster_bounty_label = label
	if _party_monster_bounty_label.is_empty():
		_party_monster_bounty_label = PartyMonsterAccessoryCatalogScript.bounty_label(_party_monster_bounty_accessory_ids)
	if not _party_monster_bounty_marked:
		_clear_party_monster_bounty_visuals()
		if was_marked:
			_card_feedback_to_owner("MARK CLEARED", Color(0.42, 1.0, 0.72, 1.0), 0.9)
	else:
		_ensure_party_monster_bounty_visuals()
		_refresh_party_monster_bounty_visuals()
		if not was_marked:
			var escape_hint := PartyMonsterAccessoryCatalogScript.bounty_escape_hint(_party_monster_accessory_loadout, _party_monster_bounty_accessory_ids)
			var feedback := "BOUNTY MARKED"
			if not escape_hint.is_empty():
				feedback = "MARKED: SWAP " + escape_hint.to_upper()
			_card_feedback_to_owner(feedback, Color(1.0, 0.30, 0.95, 1.0), 1.25)
	_refresh_nickname_visibility()
	if is_stalker():
		_refresh_stalker_visibility_view(true)
	_refresh_party_monster_accessory_pickup_beacons()


func is_party_monster_bounty_marked() -> bool:
	return _party_monster_bounty_marked


func _refresh_party_monster_accessory_pickup_beacons() -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree:
		tree.call_group("party_monster_accessory_pickups", "refresh_bounty_beacon_visibility")


func get_party_monster_bounty_accessory_ids() -> Array:
	return _party_monster_bounty_accessory_ids.duplicate()


func get_party_monster_bounty_outline_count() -> int:
	var count := 0
	for outline_id in _party_monster_bounty_outline_nodes.keys():
		var outline = _party_monster_bounty_outline_nodes[outline_id]
		if outline and is_instance_valid(outline):
			count += 1
	return count


@rpc("any_peer", "call_local", "reliable")
func apply_prop_disguise(preset: Dictionary) -> void:
	if not _body:
		push_warning("Cannot apply prop disguise without a body node.")
		return
	var mesh_type := str(preset.get("mesh", "none"))
	if mesh_type == "none":
		clear_prop_disguise()
		return

	var effective_preset := _sanitize_environment_prop_disguise_preset(preset)
	_clear_hunter_prop_sense_feedback()
	_clear_prop_disguise_node()
	_prop_disguise_node = _build_prop_disguise_node(effective_preset)
	if not _prop_disguise_node:
		return

	_prop_death_visual_hidden = false
	_prop_disguise_node.name = "PropDisguise"
	_prop_disguise_height_offset = 0.0
	_body.add_child(_prop_disguise_node)
	_apply_remote_visual_performance_policy(_prop_disguise_node)
	var visual_bounds := _align_prop_disguise_visual_to_ground()
	if visual_bounds.size != Vector3.ZERO:
		effective_preset["prop_height"] = visual_bounds.size.y
	_prop_disguise_base_position = _prop_disguise_node.position
	_set_character_visual_visible(false)
	_is_prop_disguised = true
	_current_disguise_name = str(effective_preset.get("name", "Prop"))
	_prop_disguise_is_q_scene_replica = bool(effective_preset.get("q_scene_prop_replica", false)) or str(effective_preset.get("disguise_source", "")) == "nearby_scene_prop_q"
	_apply_prop_disguise_collision(effective_preset)
	_snap_prop_disguise_to_floor()
	_play_prop_disguise_land_animation(effective_preset)
	_play_audio(_disguise_audio)
	if _should_log_runtime_debug():
		print("[ShapeShift] ", name, " disguised as ", _current_disguise_name)


@rpc("any_peer", "call_local", "reliable")
func clear_prop_disguise() -> void:
	_clear_hunter_prop_sense_feedback()
	_clear_prop_disguise_node()
	_prop_death_visual_hidden = false
	_set_character_visual_visible(true)
	_is_prop_disguised = false
	_current_disguise_name = ""
	_prop_disguise_is_q_scene_replica = false
	_prop_disguise_base_position = Vector3.ZERO
	_prop_disguise_height_offset = 0.0
	_restore_default_collision_shape()
	if _should_log_runtime_debug():
		print("[ShapeShift] ", name, " cleared disguise")


func is_disguised() -> bool:
	return _is_prop_disguised


# Revert ANY active Chameleon disguise (Q prop, committed C prop, or an in-progress
# C env-blend / paint session) back to the real model. Used to auto-uncloak before
# starting a new disguise action (Q wheel apply / C activate) or picking up a scene
# decoration with F, so the player never stacks disguises.
func auto_uncloak_disguise() -> void:
	if chameleon_environment_blend_system and is_instance_valid(chameleon_environment_blend_system) \
			and chameleon_environment_blend_system.has_method("is_active") \
			and bool(chameleon_environment_blend_system.call("is_active")):
		chameleon_environment_blend_system.call("deactivate")
	if is_disguised():
		clear_prop_disguise()
	if shape_system and shape_system.has_method("reset_to_revert_state"):
		shape_system.reset_to_revert_state()


func get_disguise_name() -> String:
	return _current_disguise_name


func is_hunter_prop_sense_target() -> bool:
	return is_chameleon() and _is_prop_disguised and _prop_disguise_is_q_scene_replica


func set_hunter_prop_sense_revealed(revealed: bool, intensity: float = 1.0, beep_interval: float = 1.0, visual_active: bool = true) -> void:
	if revealed and _card_blocks_hunter_skill_effect():
		_card_feedback_to_owner("IMMUNE", Color(0.62, 1.0, 0.74, 1.0), 0.55)
		return
	if revealed and (not is_hunter_prop_sense_target() or not _prop_disguise_node or not is_instance_valid(_prop_disguise_node)):
		revealed = false
	if not revealed:
		_clear_hunter_prop_sense_feedback()
		return
	var was_revealed := _hunter_prop_sense_revealed
	var was_visual_active := _hunter_prop_sense_visual_active
	_hunter_prop_sense_revealed = true
	_hunter_prop_sense_visual_active = visual_active
	_hunter_prop_sense_intensity = clampf(intensity, 0.0, 1.0)
	_hunter_prop_sense_beep_interval = clampf(beep_interval, 0.24, 2.1)
	if not _should_render_local_feedback():
		_clear_hunter_prop_sense_visual_feedback()
		return
	if not was_revealed or was_visual_active != visual_active or not _has_hunter_prop_sense_feedback():
		_ensure_hunter_prop_sense_feedback()
		_update_hunter_prop_sense_feedback_transform()
		_hunter_prop_sense_feedback_elapsed = 0.0
	if not was_revealed and not _hunter_prop_sense_ping_spawned:
		_spawn_hunter_prop_sense_ping_marker()


func is_hunter_prop_sense_revealed() -> bool:
	return _hunter_prop_sense_revealed


func is_hunter_prop_sense_visual_active() -> bool:
	return _hunter_prop_sense_visual_active


func get_hunter_prop_sense_outline_count() -> int:
	var count := 0
	for outline_id in _hunter_prop_sense_outline_nodes.keys():
		var outline = _hunter_prop_sense_outline_nodes[outline_id]
		if outline and is_instance_valid(outline):
			count += 1
	return count


func get_hunter_prop_sense_position() -> Vector3:
	if not _body or not _prop_disguise_node or not is_instance_valid(_prop_disguise_node):
		return global_position + Vector3.UP
	var bounds := _calculate_prop_disguise_bounds_in_body_space()
	if bounds.size == Vector3.ZERO:
		return global_position + Vector3.UP
	var center := _body.to_global(bounds.position + bounds.size * 0.5)
	return Vector3(global_position.x, center.y, global_position.z)


func get_hunter_prop_sense_ping_position() -> Vector3:
	var span := _get_hunter_prop_sense_ping_vertical_span()
	return Vector3(global_position.x, span.y, global_position.z)


func get_hunter_prop_sense_ping_base_position() -> Vector3:
	var span := _get_hunter_prop_sense_ping_vertical_span()
	return Vector3(global_position.x, span.x, global_position.z)


func _get_hunter_prop_sense_ping_vertical_span() -> Vector2:
	var bottom_y := global_position.y + 0.08
	var top_y := global_position.y + HUNTER_PROP_SENSE_PING_MIN_HEIGHT
	if _body and _prop_disguise_node and is_instance_valid(_prop_disguise_node):
		var bounds := _calculate_prop_disguise_bounds_in_body_space()
		if bounds.size != Vector3.ZERO:
			var center_x := bounds.position.x + bounds.size.x * 0.5
			var center_z := bounds.position.z + bounds.size.z * 0.5
			var bottom_center := _body.to_global(Vector3(center_x, bounds.position.y, center_z))
			var top_center := _body.to_global(Vector3(center_x, bounds.position.y + bounds.size.y, center_z))
			bottom_y = maxf(bottom_y, bottom_center.y + 0.08)
			top_y = maxf(top_y, top_center.y + HUNTER_PROP_SENSE_PING_TOP_EXTRA)
	if top_y < bottom_y + 1.2:
		top_y = bottom_y + 1.2
	return Vector2(bottom_y, top_y)


func has_hunter_prop_sense_audio() -> bool:
	return _hunter_prop_sense_audio != null and is_instance_valid(_hunter_prop_sense_audio) and _hunter_prop_sense_audio.stream != null


func has_hunter_prop_sense_ping_marker() -> bool:
	return _hunter_prop_sense_ping_marker != null and is_instance_valid(_hunter_prop_sense_ping_marker)


func get_hunter_prop_sense_ping_marker_position() -> Vector3:
	if _hunter_prop_sense_ping_marker and is_instance_valid(_hunter_prop_sense_ping_marker):
		return _hunter_prop_sense_ping_marker.global_position
	return Vector3.INF


func get_hunter_prop_sense_ping_ring_count() -> int:
	if not _hunter_prop_sense_ping_marker or not is_instance_valid(_hunter_prop_sense_ping_marker):
		return 0
	var count := 0
	for child in _hunter_prop_sense_ping_marker.get_children():
		if child is MeshInstance3D:
			count += 1
	return count


func get_hunter_prop_sense_ping_marker_bottom_y() -> float:
	if _hunter_prop_sense_ping_marker and is_instance_valid(_hunter_prop_sense_ping_marker):
		return float(_hunter_prop_sense_ping_marker.get_meta("bottom_y", INF))
	return INF


func get_hunter_prop_sense_ping_marker_top_y() -> float:
	if _hunter_prop_sense_ping_marker and is_instance_valid(_hunter_prop_sense_ping_marker):
		return float(_hunter_prop_sense_ping_marker.get_meta("top_y", -INF))
	return -INF


func get_hunter_prop_sense_ping_expansion_multiplier() -> float:
	return HUNTER_PROP_SENSE_PING_EXPANSION_MULTIPLIER


func get_hunter_prop_sense_audio_volume_db() -> float:
	if _hunter_prop_sense_audio and is_instance_valid(_hunter_prop_sense_audio):
		return _hunter_prop_sense_audio.volume_db
	return -INF


func _process_prop_disguise_height(delta: float) -> void:
	if not _is_prop_disguised:
		return
	var direction := 0.0
	if Input.is_physical_key_pressed(KEY_UP):
		direction += 1.0
	if Input.is_physical_key_pressed(KEY_DOWN):
		direction -= 1.0
	if is_zero_approx(direction):
		return
	_adjust_prop_disguise_height(direction * PROP_DISGUISE_HEIGHT_SPEED * delta)


func _adjust_prop_disguise_height(delta: float) -> void:
	if _prop_disguise_tween and _prop_disguise_tween.is_valid():
		_prop_disguise_tween.kill()
		_prop_disguise_tween = null
	if _prop_disguise_node and is_instance_valid(_prop_disguise_node):
		_prop_disguise_node.scale = Vector3.ONE
	var next_offset := clampf(
		_prop_disguise_height_offset + delta,
		PROP_DISGUISE_MIN_HEIGHT_OFFSET,
		PROP_DISGUISE_MAX_HEIGHT_OFFSET
	)
	_apply_prop_disguise_height_offset(next_offset)
	_set_prop_disguise_height_offset.rpc(next_offset)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _set_prop_disguise_height_offset(offset: float) -> void:
	_apply_prop_disguise_height_offset(offset)


func _apply_prop_disguise_height_offset(offset: float) -> void:
	_prop_disguise_height_offset = clampf(offset, PROP_DISGUISE_MIN_HEIGHT_OFFSET, PROP_DISGUISE_MAX_HEIGHT_OFFSET)
	if _prop_disguise_node and is_instance_valid(_prop_disguise_node):
		_prop_disguise_node.position = _prop_disguise_base_position + Vector3(0.0, _prop_disguise_height_offset, 0.0)


func _cache_default_collision_shape() -> void:
	if not _collision_shape or not _collision_shape.shape:
		return
	_default_collision_shape = _collision_shape.shape.duplicate()
	_default_collision_transform = _collision_shape.transform


func _apply_prop_disguise_collision(preset: Dictionary) -> void:
	if not _collision_shape:
		return
	var dimensions := _get_prop_collision_dimensions(preset)
	var radius: float = dimensions.x
	var height: float = dimensions.y
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = height
	_collision_shape.shape = cylinder
	_collision_shape.position = Vector3(0.0, height * 0.5, 0.0)
	_collision_shape.rotation = Vector3.ZERO
	_collision_shape.scale = Vector3.ONE


func _snap_prop_disguise_to_floor() -> void:
	if not is_inside_tree() or not get_world_3d():
		return
	var space_state := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * PROP_DISGUISE_GROUND_SNAP_UP
	var to := global_position + Vector3.DOWN * PROP_DISGUISE_GROUND_SNAP_DOWN
	var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_COLLISION_MASK)
	query.exclude = [get_rid()]
	query.hit_from_inside = false
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var hit_position: Vector3 = hit.get("position", global_position)
	set_global_position_immediate(Vector3(global_position.x, hit_position.y, global_position.z))
	velocity.y = 0.0


func _align_prop_disguise_visual_to_ground() -> AABB:
	if not _body or not _prop_disguise_node or not is_instance_valid(_prop_disguise_node):
		return AABB()
	var bounds := _calculate_prop_disguise_bounds_in_body_space()
	if bounds.size == Vector3.ZERO:
		return AABB()
	var ground_local_y := _body.to_local(global_position).y
	_prop_disguise_node.position.y += ground_local_y - bounds.position.y
	return _calculate_prop_disguise_bounds_in_body_space()


func _calculate_prop_disguise_bounds_in_body_space() -> AABB:
	if not _body or not _prop_disguise_node or not is_instance_valid(_prop_disguise_node):
		return AABB()
	var meshes: Array[MeshInstance3D] = []
	_find_prop_disguise_mesh_instances(_prop_disguise_node, meshes)
	var has_bounds := false
	var bounds := AABB()
	for mesh_instance in meshes:
		if not mesh_instance.mesh:
			continue
		var local_bounds := _transform_aabb(_body.global_transform.affine_inverse() * mesh_instance.global_transform, mesh_instance.get_aabb())
		if not has_bounds:
			bounds = local_bounds
			has_bounds = true
		else:
			bounds = bounds.merge(local_bounds)
	return bounds if has_bounds else AABB()


func _find_prop_disguise_mesh_instances(node: Node, result: Array[MeshInstance3D]) -> void:
	if node.name == "HunterPropSenseOutline" or node.name == "PartyMonsterBountyOutline":
		return
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		_find_prop_disguise_mesh_instances(child, result)


func _transform_aabb(transform: Transform3D, box: AABB) -> AABB:
	var min_corner := Vector3(INF, INF, INF)
	var max_corner := Vector3(-INF, -INF, -INF)
	for x in [0.0, 1.0]:
		for y in [0.0, 1.0]:
			for z in [0.0, 1.0]:
				var point := box.position + Vector3(box.size.x * x, box.size.y * y, box.size.z * z)
				var transformed := transform * point
				min_corner = min_corner.min(transformed)
				max_corner = max_corner.max(transformed)
	return AABB(min_corner, max_corner - min_corner)


func _restore_default_collision_shape() -> void:
	if not _collision_shape or not _default_collision_shape:
		return
	_collision_shape.shape = _default_collision_shape.duplicate()
	_collision_shape.transform = _default_collision_transform


func _get_prop_collision_dimensions(preset: Dictionary) -> Vector2:
	var radius := float(preset.get("collision_radius", 0.0))
	var height := float(preset.get("collision_height", 0.0))
	if radius <= 0.0 or height <= 0.0:
		var size: Vector3 = preset.get("size", Vector3.ONE)
		radius = maxf(absf(size.x), absf(size.z)) * 0.42
		height = maxf(absf(size.y) * 0.82, radius * 0.75)
	if preset.has("prop_height"):
		height = maxf(height, float(preset.get("prop_height", height)))
	radius = clampf(radius, PROP_COLLISION_MIN_RADIUS, PROP_COLLISION_MAX_RADIUS)
	height = clampf(height, PROP_COLLISION_MIN_HEIGHT, PROP_COLLISION_MAX_HEIGHT)
	return Vector2(radius, height)


func _clear_prop_disguise_node() -> void:
	if _prop_disguise_tween and _prop_disguise_tween.is_valid():
		_prop_disguise_tween.kill()
	_prop_disguise_tween = null
	if _prop_disguise_node and is_instance_valid(_prop_disguise_node):
		_prop_disguise_node.queue_free()
	_prop_disguise_node = null


func _process_party_monster_bounty_feedback(delta: float) -> void:
	if not _party_monster_bounty_marked:
		return
	if not _is_prop_role() or not _is_network_marked_alive():
		_party_monster_bounty_marked = false
		_clear_party_monster_bounty_visuals()
		return
	if not _should_render_local_feedback():
		_clear_party_monster_bounty_visuals()
		return
	if not _has_party_monster_bounty_visuals():
		_ensure_party_monster_bounty_visuals()
		_update_party_monster_bounty_feedback_transform()
		_party_monster_bounty_feedback_elapsed = 0.0
		return
	_party_monster_bounty_feedback_elapsed += delta
	if _party_monster_bounty_feedback_elapsed < LOCAL_FEEDBACK_TRANSFORM_INTERVAL:
		return
	_party_monster_bounty_feedback_elapsed = 0.0
	_update_party_monster_bounty_feedback_transform()


func _has_party_monster_bounty_visuals() -> bool:
	return _party_monster_bounty_glow_light != null and is_instance_valid(_party_monster_bounty_glow_light) and _party_monster_bounty_marker_label != null and is_instance_valid(_party_monster_bounty_marker_label)


func _ensure_party_monster_bounty_visuals() -> void:
	if not _should_render_local_feedback():
		_clear_party_monster_bounty_visuals()
		return
	if not _party_monster_bounty_outline_nodes.is_empty():
		_clear_party_monster_bounty_outlines()
	if not _party_monster_bounty_glow_light or not is_instance_valid(_party_monster_bounty_glow_light):
		_party_monster_bounty_glow_light = OmniLight3D.new()
		_party_monster_bounty_glow_light.name = "PartyMonsterBountyGlow"
		_party_monster_bounty_glow_light.light_color = Color(1.0, 0.16, 0.92, 1.0)
		_party_monster_bounty_glow_light.omni_range = PARTY_MONSTER_BOUNTY_GLOW_RANGE
		_party_monster_bounty_glow_light.shadow_enabled = false
		_party_monster_bounty_glow_light.top_level = true
		add_child(_party_monster_bounty_glow_light)
	_party_monster_bounty_glow_light.visible = true
	_party_monster_bounty_glow_light.light_energy = 2.9
	# The "BOUNTY: ..." Label3D is superseded by the bounty icon on the
	# screen-space WorldNameplateHUD; keep only the glow as world feedback.
	if _party_monster_bounty_marker_label and is_instance_valid(_party_monster_bounty_marker_label):
		_party_monster_bounty_marker_label.visible = false


func _refresh_party_monster_bounty_visuals() -> void:
	if not _party_monster_bounty_marked:
		_clear_party_monster_bounty_visuals()
		return
	if not _should_render_local_feedback():
		_clear_party_monster_bounty_visuals()
		return
	_ensure_party_monster_bounty_visuals()
	_update_party_monster_bounty_feedback_transform()


func _clear_party_monster_bounty_outlines() -> void:
	for outline_id in _party_monster_bounty_outline_nodes.keys():
		var outline = _party_monster_bounty_outline_nodes[outline_id]
		if outline and is_instance_valid(outline):
			outline.queue_free()
	_party_monster_bounty_outline_nodes.clear()


func _get_party_monster_bounty_meshes() -> Array[MeshInstance3D]:
	var raw_meshes: Array[MeshInstance3D] = _get_stalker_visual_meshes(true)
	var result: Array[MeshInstance3D] = []
	for mesh_instance in raw_meshes:
		if not mesh_instance or not is_instance_valid(mesh_instance):
			continue
		if _is_feedback_outline_mesh(mesh_instance):
			continue
		result.append(mesh_instance)
	return result


func _is_feedback_outline_mesh(mesh_instance: MeshInstance3D) -> bool:
	var node: Node = mesh_instance
	while node:
		var node_name := String(node.name)
		if node_name == "HunterPropSenseOutline" or node_name == "PartyMonsterBountyOutline":
			return true
		node = node.get_parent()
	return false


func _update_party_monster_bounty_feedback_transform() -> void:
	var anchor := _get_party_monster_bounty_position()
	if _party_monster_bounty_glow_light and is_instance_valid(_party_monster_bounty_glow_light):
		if _party_monster_bounty_glow_light.is_inside_tree():
			_party_monster_bounty_glow_light.global_position = anchor
		else:
			_party_monster_bounty_glow_light.position = anchor
		_party_monster_bounty_glow_light.light_energy = 2.4 + sin(Time.get_ticks_msec() / 1000.0 * 5.0) * 0.55
	if _party_monster_bounty_marker_label and is_instance_valid(_party_monster_bounty_marker_label):
		var label_position := _get_party_monster_bounty_label_position(anchor)
		if _party_monster_bounty_marker_label.is_inside_tree():
			_party_monster_bounty_marker_label.global_position = label_position
		else:
			_party_monster_bounty_marker_label.position = label_position


func _get_party_monster_bounty_position() -> Vector3:
	if _is_prop_disguised and _prop_disguise_node and is_instance_valid(_prop_disguise_node):
		return get_hunter_prop_sense_position()
	var meshes: Array[MeshInstance3D] = _get_party_monster_bounty_meshes()
	var bounds := _calculate_meshes_world_bounds(meshes)
	if bounds.size != Vector3.ZERO:
		return bounds.position + bounds.size * 0.5
	return _get_party_monster_bounty_base_position() + Vector3.UP * 1.35


func _get_party_monster_bounty_label_position(anchor: Vector3) -> Vector3:
	var base_position := _get_party_monster_bounty_base_position()
	var label_y := maxf(anchor.y + 1.1, base_position.y + PARTY_MONSTER_BOUNTY_LABEL_MIN_HEIGHT)
	return Vector3(base_position.x, label_y, base_position.z)


func _get_party_monster_bounty_base_position() -> Vector3:
	return global_position if is_inside_tree() else position


func _clear_party_monster_bounty_visuals() -> void:
	_clear_party_monster_bounty_outlines()
	if _party_monster_bounty_glow_light and is_instance_valid(_party_monster_bounty_glow_light):
		_party_monster_bounty_glow_light.queue_free()
	_party_monster_bounty_glow_light = null
	if _party_monster_bounty_marker_label and is_instance_valid(_party_monster_bounty_marker_label):
		_party_monster_bounty_marker_label.queue_free()
	_party_monster_bounty_marker_label = null


func _has_hunter_prop_sense_feedback() -> bool:
	var has_audio := _hunter_prop_sense_audio != null and is_instance_valid(_hunter_prop_sense_audio)
	if not _hunter_prop_sense_visual_active:
		return has_audio
	return has_audio and _hunter_prop_sense_glow_light != null and is_instance_valid(_hunter_prop_sense_glow_light)


func _ensure_hunter_prop_sense_feedback() -> void:
	if not _should_render_local_feedback():
		_clear_hunter_prop_sense_runtime_feedback_nodes()
		return
	if not _hunter_prop_sense_audio or not is_instance_valid(_hunter_prop_sense_audio):
		_hunter_prop_sense_audio = AudioStreamPlayer3D.new()
		_hunter_prop_sense_audio.name = "HunterPropSenseBeepAudio"
		_hunter_prop_sense_audio.stream = _get_hunter_prop_sense_beep_stream()
		_hunter_prop_sense_audio.volume_db = -7.5
		_hunter_prop_sense_audio.max_distance = HUNTER_PROP_SENSE_AUDIO_RANGE
		_hunter_prop_sense_audio.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		_hunter_prop_sense_audio.top_level = true
		add_child(_hunter_prop_sense_audio)
	if _hunter_prop_sense_visual_active:
		_ensure_hunter_prop_sense_visual_feedback()
	else:
		_clear_hunter_prop_sense_visual_feedback()


func _ensure_hunter_prop_sense_visual_feedback() -> void:
	_refresh_hunter_prop_sense_outlines()
	if not _hunter_prop_sense_glow_light or not is_instance_valid(_hunter_prop_sense_glow_light):
		_hunter_prop_sense_glow_light = OmniLight3D.new()
		_hunter_prop_sense_glow_light.name = "HunterPropSenseGlow"
		_hunter_prop_sense_glow_light.light_color = Color(1.0, 0.06, 0.025, 1.0)
		_hunter_prop_sense_glow_light.omni_range = HUNTER_PROP_SENSE_GLOW_RANGE
		_hunter_prop_sense_glow_light.shadow_enabled = false
		_hunter_prop_sense_glow_light.top_level = true
		add_child(_hunter_prop_sense_glow_light)
	_hunter_prop_sense_glow_light.visible = true
	_hunter_prop_sense_glow_light.light_energy = lerpf(1.2, 3.8, _hunter_prop_sense_intensity)


func _refresh_hunter_prop_sense_outlines() -> void:
	if not _prop_disguise_node or not is_instance_valid(_prop_disguise_node):
		return
	var meshes: Array[MeshInstance3D] = []
	_find_prop_disguise_mesh_instances(_prop_disguise_node, meshes)
	var seen := {}
	for mesh_instance in meshes:
		if not mesh_instance.mesh:
			continue
		var mesh_id := mesh_instance.get_instance_id()
		seen[mesh_id] = true
		var outline: MeshInstance3D = _hunter_prop_sense_outline_nodes.get(mesh_id, null)
		if not outline or not is_instance_valid(outline):
			outline = MeshInstance3D.new()
			outline.name = "HunterPropSenseOutline"
			outline.mesh = mesh_instance.mesh
			outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			outline.material_override = _get_hunter_prop_sense_outline_material()
			outline.scale = Vector3.ONE * 1.055
			outline.extra_cull_margin = 2.0
			mesh_instance.add_child(outline)
			_hunter_prop_sense_outline_nodes[mesh_id] = outline
		outline.visible = true
		outline.material_override = _get_hunter_prop_sense_outline_material()

	for mesh_id in _hunter_prop_sense_outline_nodes.keys():
		if seen.has(mesh_id):
			continue
		var stale_outline = _hunter_prop_sense_outline_nodes[mesh_id]
		if stale_outline and is_instance_valid(stale_outline):
			stale_outline.queue_free()
		_hunter_prop_sense_outline_nodes.erase(mesh_id)


func _process_hunter_prop_sense_feedback(delta: float) -> void:
	if not _hunter_prop_sense_revealed:
		return
	if not _is_prop_disguised or not _prop_disguise_node or not is_instance_valid(_prop_disguise_node):
		_clear_hunter_prop_sense_feedback()
		return
	if not _should_render_local_feedback():
		_clear_hunter_prop_sense_runtime_feedback_nodes()
		return
	if not _has_hunter_prop_sense_feedback():
		_ensure_hunter_prop_sense_feedback()
		_update_hunter_prop_sense_feedback_transform()
		_hunter_prop_sense_feedback_elapsed = 0.0
	else:
		_hunter_prop_sense_feedback_elapsed += delta
		if _hunter_prop_sense_feedback_elapsed >= LOCAL_FEEDBACK_TRANSFORM_INTERVAL:
			_hunter_prop_sense_feedback_elapsed = 0.0
			_update_hunter_prop_sense_feedback_transform()
	_hunter_prop_sense_beep_timer -= delta
	if _hunter_prop_sense_beep_timer <= 0.0:
		_play_hunter_prop_sense_beep()
		_hunter_prop_sense_beep_timer = _hunter_prop_sense_beep_interval


func _update_hunter_prop_sense_feedback_transform() -> void:
	var anchor := get_hunter_prop_sense_position()
	if _hunter_prop_sense_visual_active and _hunter_prop_sense_glow_light and is_instance_valid(_hunter_prop_sense_glow_light):
		_hunter_prop_sense_glow_light.global_position = anchor
		_hunter_prop_sense_glow_light.light_energy = lerpf(1.2, 3.8, _hunter_prop_sense_intensity)
	if _hunter_prop_sense_audio and is_instance_valid(_hunter_prop_sense_audio):
		_hunter_prop_sense_audio.global_position = anchor
		_hunter_prop_sense_audio.volume_db = lerpf(-7.5, -2.5, _hunter_prop_sense_intensity)


func _play_hunter_prop_sense_beep() -> void:
	if not _hunter_prop_sense_audio or not is_instance_valid(_hunter_prop_sense_audio):
		return
	if not _hunter_prop_sense_audio.stream:
		_hunter_prop_sense_audio.stream = _get_hunter_prop_sense_beep_stream()
	_hunter_prop_sense_audio.pitch_scale = lerpf(0.92, 1.26, _hunter_prop_sense_intensity)
	_hunter_prop_sense_audio.play()


func _clear_hunter_prop_sense_runtime_feedback_nodes() -> void:
	if _hunter_prop_sense_ping_tween and _hunter_prop_sense_ping_tween.is_valid():
		_hunter_prop_sense_ping_tween.kill()
	_hunter_prop_sense_ping_tween = null
	if _hunter_prop_sense_ping_marker and is_instance_valid(_hunter_prop_sense_ping_marker):
		_hunter_prop_sense_ping_marker.queue_free()
	_hunter_prop_sense_ping_marker = null
	_hunter_prop_sense_ping_spawned = false
	_clear_hunter_prop_sense_visual_feedback()
	if _hunter_prop_sense_audio and is_instance_valid(_hunter_prop_sense_audio):
		_hunter_prop_sense_audio.stop()
		_hunter_prop_sense_audio.queue_free()
	_hunter_prop_sense_audio = null


func _clear_hunter_prop_sense_feedback() -> void:
	_hunter_prop_sense_revealed = false
	_hunter_prop_sense_visual_active = false
	_hunter_prop_sense_intensity = 0.0
	_hunter_prop_sense_beep_timer = 0.0
	_clear_hunter_prop_sense_runtime_feedback_nodes()


func _spawn_hunter_prop_sense_ping_marker() -> void:
	_hunter_prop_sense_ping_spawned = true
	if _hunter_prop_sense_ping_tween and _hunter_prop_sense_ping_tween.is_valid():
		_hunter_prop_sense_ping_tween.kill()
	_hunter_prop_sense_ping_tween = null
	if _hunter_prop_sense_ping_marker and is_instance_valid(_hunter_prop_sense_ping_marker):
		_hunter_prop_sense_ping_marker.queue_free()
	var span := _get_hunter_prop_sense_ping_vertical_span()
	var bottom_y := span.x
	var top_y := span.y
	var vertical_height := maxf(top_y - bottom_y, 1.2)
	var marker := Node3D.new()
	marker.name = "HunterPropSenseSoundPing"
	marker.top_level = true
	marker.set_meta("bottom_y", bottom_y)
	marker.set_meta("top_y", top_y)
	add_child(marker)
	marker.global_position = Vector3(global_position.x, bottom_y, global_position.z)
	_hunter_prop_sense_ping_marker = marker

	var ring_count := clampi(int(ceil(vertical_height / HUNTER_PROP_SENSE_PING_RING_SPACING)) + 1, HUNTER_PROP_SENSE_PING_MIN_RINGS, HUNTER_PROP_SENSE_PING_MAX_RINGS)
	for i in range(ring_count):
		var height_ratio := 0.0 if ring_count <= 1 else float(i) / float(ring_count - 1)
		var ring := MeshInstance3D.new()
		ring.name = "HunterPropSenseSoundPingRing"
		var mesh := SphereMesh.new()
		mesh.radius = 0.5
		mesh.height = 1.0
		ring.mesh = mesh
		ring.position = Vector3(0.0, vertical_height * height_ratio, 0.0)
		var ground_emphasis := 1.0 - height_ratio
		ring.scale = Vector3(0.30, lerpf(0.030, 0.016, height_ratio), 0.30)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.material_override = _create_hunter_prop_sense_ping_material()
		var ring_material := ring.material_override as ShaderMaterial
		if ring_material:
			ring_material.set_shader_parameter("alpha", lerpf(0.58, 1.0, ground_emphasis))
			ring_material.set_shader_parameter("brightness", lerpf(0.82, 1.55, ground_emphasis))
		marker.add_child(ring)

	var light := OmniLight3D.new()
	light.name = "HunterPropSenseSoundPingLight"
	light.light_color = Color(1.0, 0.08, 0.025, 1.0)
	light.omni_range = 1.25
	light.light_energy = 3.4
	light.shadow_enabled = true
	light.position = Vector3(0.0, vertical_height * 0.5, 0.0)
	marker.add_child(light)
	var tween := create_tween()
	_hunter_prop_sense_ping_tween = tween
	tween.set_parallel(true)
	for child in marker.get_children():
		if not child is MeshInstance3D:
			continue
		var ring := child as MeshInstance3D
		var height_ratio := 0.0 if vertical_height <= 0.0 else clampf(ring.position.y / vertical_height, 0.0, 1.0)
		var ground_emphasis := 1.0 - height_ratio
		var delay := height_ratio * 0.18
		var expansion := lerpf(3.4, 4.5, height_ratio) * HUNTER_PROP_SENSE_PING_EXPANSION_MULTIPLIER
		var ring_thickness := lerpf(0.052, 0.026, height_ratio)
		tween.tween_property(ring, "scale", Vector3(expansion, ring_thickness, expansion), 1.0).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		var material := ring.material_override as ShaderMaterial
		if material:
			material.set_shader_parameter("alpha", lerpf(0.58, 1.0, ground_emphasis))
			material.set_shader_parameter("brightness", lerpf(0.82, 1.55, ground_emphasis))
			tween.tween_property(material, "shader_parameter/alpha", 0.0, 0.86).set_delay(delay + 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(light, "omni_range", 6.4 * HUNTER_PROP_SENSE_PING_EXPANSION_MULTIPLIER, 1.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(light, "light_energy", 0.0, 1.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func():
		if marker and is_instance_valid(marker):
			marker.queue_free()
		if _hunter_prop_sense_ping_marker == marker:
			_hunter_prop_sense_ping_marker = null
		if _hunter_prop_sense_ping_tween == tween:
			_hunter_prop_sense_ping_tween = null
	)


func _create_hunter_prop_sense_ping_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, cull_disabled;

uniform vec4 ping_color : source_color = vec4(1.0, 0.09, 0.02, 1.0);
uniform float alpha = 0.72;
uniform float brightness = 1.0;

void fragment() {
	float radial = length(UV - vec2(0.5));
	float core = smoothstep(0.34, 0.0, radial) * 0.28;
	float ring = smoothstep(0.50, 0.34, radial) * smoothstep(0.16, 0.30, radial);
	float haze = smoothstep(0.52, 0.12, radial) * 0.22;
	float pulse = core + ring + haze;
	ALBEDO = ping_color.rgb;
	EMISSION = ping_color.rgb * pulse * 3.4 * brightness;
	ALPHA = clamp(pulse * alpha * (0.82 + brightness * 0.18), 0.0, 1.0);
}
"""
	var material := ShaderMaterial.new()
	material.resource_local_to_scene = true
	material.shader = shader
	material.set_shader_parameter("alpha", 0.72)
	material.set_shader_parameter("brightness", 1.0)
	return material


func _clear_hunter_prop_sense_visual_feedback() -> void:
	for outline_id in _hunter_prop_sense_outline_nodes.keys():
		var outline = _hunter_prop_sense_outline_nodes[outline_id]
		if outline and is_instance_valid(outline):
			outline.queue_free()
	_hunter_prop_sense_outline_nodes.clear()
	if _hunter_prop_sense_glow_light and is_instance_valid(_hunter_prop_sense_glow_light):
		_hunter_prop_sense_glow_light.queue_free()
	_hunter_prop_sense_glow_light = null


func _get_hunter_prop_sense_outline_material() -> ShaderMaterial:
	if not _hunter_prop_sense_outline_material:
		var shader := Shader.new()
		shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, cull_front;

uniform vec4 glow_color : source_color = vec4(1.0, 0.035, 0.015, 1.0);
uniform float pulse_strength = 1.0;
uniform float alpha_multiplier = 1.0;

void fragment() {
	float view_dot = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - view_dot, 1.6);
	float pulse = 0.65 + sin(TIME * 7.0) * 0.18;
	ALBEDO = glow_color.rgb;
	EMISSION = glow_color.rgb * (1.6 + rim * 4.2) * pulse * pulse_strength;
	ALPHA = clamp(0.20 + rim * 0.78, 0.18, 0.92) * alpha_multiplier;
}
"""
		_hunter_prop_sense_outline_material = ShaderMaterial.new()
		_hunter_prop_sense_outline_material.resource_local_to_scene = true
		_hunter_prop_sense_outline_material.shader = shader
	_hunter_prop_sense_outline_material.set_shader_parameter("pulse_strength", lerpf(0.75, 1.45, _hunter_prop_sense_intensity))
	_hunter_prop_sense_outline_material.set_shader_parameter("alpha_multiplier", lerpf(0.32, 1.0, _hunter_prop_sense_intensity))
	return _hunter_prop_sense_outline_material


func _get_hunter_prop_sense_beep_stream() -> AudioStreamWAV:
	if _hunter_prop_sense_beep_stream:
		return _hunter_prop_sense_beep_stream
	var sample_count := int(HUNTER_PROP_SENSE_BEEP_SAMPLE_RATE * HUNTER_PROP_SENSE_BEEP_SECONDS)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in range(sample_count):
		var t := float(i) / float(HUNTER_PROP_SENSE_BEEP_SAMPLE_RATE)
		var envelope := 0.0
		if t < 0.075:
			envelope = sin((t / 0.075) * PI)
		elif t >= 0.125 and t < 0.205:
			envelope = sin(((t - 0.125) / 0.08) * PI)
		var tone := sin(TAU * 780.0 * t) * 0.72 + sin(TAU * 1170.0 * t) * 0.28
		var sample := int(clampf(tone * envelope * 0.62, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = HUNTER_PROP_SENSE_BEEP_SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	_hunter_prop_sense_beep_stream = stream
	return _hunter_prop_sense_beep_stream


func _play_prop_disguise_land_animation(preset: Dictionary) -> void:
	if not _prop_disguise_node or not is_instance_valid(_prop_disguise_node):
		return
	if _prop_disguise_tween and _prop_disguise_tween.is_valid():
		_prop_disguise_tween.kill()

	var final_position: Vector3 = _prop_disguise_base_position
	var prop_height: float = maxf(float(preset.get("prop_height", 1.0)), 0.6)
	var drop_height: float = clampf(float(preset.get("drop_height", prop_height * 0.32)), PROP_DISGUISE_DROP_MIN_HEIGHT, PROP_DISGUISE_DROP_MAX_HEIGHT)
	var bounce_height: float = clampf(prop_height * 0.045, 0.12, 0.42)

	_prop_disguise_node.position = final_position + Vector3(0.0, drop_height, 0.0)
	_prop_disguise_node.scale = Vector3(0.96, 1.04, 0.96)

	_prop_disguise_tween = create_tween()
	_prop_disguise_tween.set_parallel(false)
	_prop_disguise_tween.tween_property(_prop_disguise_node, "position", final_position, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_prop_disguise_tween.parallel().tween_property(_prop_disguise_node, "scale", Vector3(1.0, 1.0, 1.0), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_prop_disguise_tween.tween_property(_prop_disguise_node, "scale", Vector3(1.08, 0.82, 1.08), 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_prop_disguise_tween.parallel().tween_property(_prop_disguise_node, "position", final_position - Vector3(0.0, 0.035, 0.0), 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_prop_disguise_tween.tween_property(_prop_disguise_node, "scale", Vector3(0.95, 1.08, 0.95), 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_prop_disguise_tween.parallel().tween_property(_prop_disguise_node, "position", final_position + Vector3(0.0, bounce_height, 0.0), 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_prop_disguise_tween.tween_property(_prop_disguise_node, "position", final_position, 0.13).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_prop_disguise_tween.parallel().tween_property(_prop_disguise_node, "scale", Vector3.ONE, 0.13).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _set_character_visual_visible(visible_value: bool) -> void:
	if _robot_visual_root:
		_robot_visual_root.visible = visible_value and character_model_id == CharacterSkinCatalog.GODOT_ROBOT_ID
	if _active_skin_node and is_instance_valid(_active_skin_node):
		_active_skin_node.visible = visible_value and character_model_id != CharacterSkinCatalog.GODOT_ROBOT_ID
	_sync_character_visual_animation_activity()


func _sync_character_visual_animation_activity() -> void:
	var robot_visible: bool = _robot_visual_root != null and is_instance_valid(_robot_visual_root) and _robot_visual_root.visible and character_model_id == CharacterSkinCatalog.GODOT_ROBOT_ID
	_set_visual_animation_players_active(_robot_animation_player, robot_visible)
	_set_visual_animation_players_active(_robot_visual_root, robot_visible)
	var skin_visible: bool = _active_skin_node != null and is_instance_valid(_active_skin_node) and _active_skin_node.visible and character_model_id != CharacterSkinCatalog.GODOT_ROBOT_ID
	if _active_skin_node != null and is_instance_valid(_active_skin_node) and _active_skin_node.has_method("set_idle_variation_process_enabled"):
		_active_skin_node.call("set_idle_variation_process_enabled", _is_local_authority())
	_set_visual_animation_players_active(_active_skin_node, skin_visible)


func _set_visual_animation_players_active(root: Node, active: bool) -> void:
	if root == null or not is_instance_valid(root):
		return
	if root is AnimationPlayer:
		var animation_player: AnimationPlayer = root as AnimationPlayer
		animation_player.active = active
	for child: Node in root.get_children():
		_set_visual_animation_players_active(child, active)


func _apply_remote_visual_performance_policy(root: Node) -> void:
	RemoteVisualPolicy.apply_to_remote(root, _is_local_authority())


func _build_prop_disguise_node(preset: Dictionary) -> Node3D:
	var holder := Node3D.new()
	holder.position = preset.get("offset", Vector3.ZERO)
	holder.rotation = preset.get("rotation", Vector3.ZERO)
	var mesh_type := str(preset.get("mesh", "box"))
	if mesh_type == "runtime_gltf":
		var runtime_node := _instantiate_environment_runtime_gltf(str(preset.get("runtime_model_path", "")))
		if runtime_node:
			runtime_node.name = "RuntimeGeneratedPropVisual"
			runtime_node.scale = preset.get("scale", Vector3.ONE)
			holder.add_child(runtime_node)
			_apply_scene_prop_paint_profile(runtime_node, preset)
			_disable_prop_collisions(runtime_node)
			_apply_environment_prop_paint_payload(holder, preset)
			return holder
		mesh_type = str(preset.get("fallback_mesh", "box"))
	if mesh_type == "scene":
		var scene_path := str(preset.get("scene_path", ""))
		var scene := load(scene_path)
		var added_scene := false
		if scene is PackedScene:
			var scene_node := (scene as PackedScene).instantiate() as Node3D
			if scene_node:
				scene_node.name = "ScenePropVisual"
				scene_node.scale = preset.get("scale", Vector3.ONE)
				holder.add_child(scene_node)
				_apply_scene_prop_material(scene_node, str(preset.get("material_path", "")))
				_apply_scene_prop_paint_profile(scene_node, preset)
				_disable_prop_collisions(scene_node)
				added_scene = true
		if added_scene:
			_apply_environment_prop_paint_payload(holder, preset)
			return holder
		mesh_type = str(preset.get("fallback_mesh", "box"))
	match mesh_type:
		"cactus":
			_add_prop_mesh(holder, "cylinder", Vector3(0.38, 1.7, 0.38), Vector3(0, 0, 0), preset.get("color", Color.GREEN))
			_add_prop_mesh(holder, "sphere", Vector3(0.42, 0.42, 0.42), Vector3(0, 0.82, 0), preset.get("color", Color.GREEN))
			_add_prop_mesh(holder, "cylinder", Vector3(0.18, 0.72, 0.18), Vector3(0.36, 0.24, 0), preset.get("color", Color.GREEN), Vector3(0, 0, PI * 0.5))
			_add_prop_mesh(holder, "cylinder", Vector3(0.18, 0.62, 0.18), Vector3(-0.33, 0.08, 0), preset.get("color", Color.GREEN), Vector3(0, 0, PI * 0.5))
		_:
			_add_prop_mesh(holder, mesh_type, preset.get("size", Vector3.ONE), Vector3.ZERO, preset.get("color", Color.WHITE))
	_apply_environment_prop_paint_payload(holder, preset)
	return holder


func _instantiate_environment_runtime_gltf(model_path: String) -> Node3D:
	if model_path.is_empty():
		return null
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var err := document.append_from_file(model_path, state)
	if err != OK:
		push_warning("Could not load runtime environment blend GLTF model: " + model_path)
		return null
	var scene := document.generate_scene(state)
	return scene as Node3D if scene is Node3D else null


func _add_prop_mesh(parent: Node3D, mesh_type: String, mesh_size: Vector3, local_pos: Vector3, color: Color, local_rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.position = local_pos
	mesh_instance.rotation = local_rot
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
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
	mesh_instance.scale = mesh_size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.72
	mat.metallic = 0.18 if mesh_type == "cylinder" else 0.0
	mesh_instance.material_override = mat
	parent.add_child(mesh_instance)
	return mesh_instance


func _disable_prop_collisions(node: Node) -> void:
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true
	elif node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0
	for child in node.get_children():
		_disable_prop_collisions(child)


func _apply_scene_prop_material(node: Node, material_path: String) -> void:
	if material_path.is_empty():
		return
	var material_resource := load(material_path)
	if not material_resource is Material:
		return
	_apply_material_to_unassigned_prop_meshes(node, material_resource as Material)


func _apply_scene_prop_paint_profile(node: Node, preset: Dictionary) -> void:
	if not preset.has("paint_color"):
		return
	var color: Color = preset.get("paint_color", Color.WHITE)
	color.a = 1.0
	var roughness := clampf(float(preset.get("paint_roughness", 0.72)), 0.0, 1.0)
	var metallic := clampf(float(preset.get("paint_metallic", 0.0)), 0.0, 1.0)
	var specular := clampf(float(preset.get("paint_specular", 0.45)), 0.0, 1.0)
	_apply_paint_profile_to_prop_meshes(node, color, roughness, metallic, specular)


func _apply_environment_prop_paint_payload(prop_root: Node3D, preset: Dictionary) -> void:
	if not prop_root or not preset.has("paint_payload"):
		return
	var payload := _sanitize_environment_prop_paint_payload(preset.get("paint_payload", {}))
	if payload.is_empty():
		return
	var base_color: Color = payload.get("base_color", Color(0.96, 0.94, 0.9, 1.0))
	base_color.a = 1.0
	var roughness := clampf(float(payload.get("roughness", 0.72)), 0.0, 1.0)
	var metallic := clampf(float(payload.get("metallic", 0.0)), 0.0, 1.0)
	var specular := clampf(float(payload.get("specular", 0.45)), 0.0, 1.0)
	_apply_paint_profile_to_prop_meshes(prop_root, base_color, roughness, metallic, specular)
	var surfaces: Array = payload.get("surfaces", [])
	for entry in surfaces:
		if not entry is Dictionary:
			continue
		var surface_payload := entry as Dictionary
		var mesh_path := str(surface_payload.get("mesh_path", ""))
		var mesh_instance := prop_root.get_node_or_null(mesh_path) as MeshInstance3D
		if not mesh_instance:
			continue
		var surface := _normalize_camouflage_target_surface(mesh_instance, int(surface_payload.get("surface", 0)))
		var texture := _texture_from_png_bytes(surface_payload.get("png", PackedByteArray()))
		if not texture:
			continue
		var material := _create_environment_prop_paint_layer_material(base_color, texture, roughness, metallic, specular)
		mesh_instance.set_surface_override_material(surface, material)


func _create_environment_prop_paint_layer_material(
	base_color: Color,
	paint_texture: Texture2D,
	roughness: float,
	metallic: float,
	specular: float
) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = CAMOUFLAGE_PAINT_LAYER_SHADER
	material.resource_local_to_scene = true
	material.set_meta("camouflage_paint_layer", true)
	material.set_shader_parameter("base_color", base_color)
	material.set_shader_parameter("use_base_texture", false)
	material.set_shader_parameter("paint_texture", paint_texture)
	material.set_shader_parameter("paint_display_strength", 1.0)
	material.set_shader_parameter("paint_exact_color_match", false)
	material.set_shader_parameter("paint_roughness", roughness)
	material.set_shader_parameter("paint_metallic", metallic)
	material.set_shader_parameter("paint_specular", specular)
	material.set_shader_parameter("use_paint_normal_texture", false)
	material.set_shader_parameter("paint_normal_scale", 1.0)
	material.set_meta("camouflage_bound_paint_texture", paint_texture)
	material.set_meta("camouflage_bound_paint_strength", 1.0)
	return material


func _texture_from_png_bytes(value) -> Texture2D:
	if not value is PackedByteArray:
		return null
	var bytes := value as PackedByteArray
	if bytes.is_empty() or bytes.size() > ENVIRONMENT_PROP_PAINT_MAX_BYTES_PER_SURFACE:
		return null
	var image := Image.new()
	var err := image.load_png_from_buffer(bytes)
	if err != OK or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


func _apply_paint_profile_to_prop_meshes(node: Node, color: Color, roughness: float, metallic: float, specular: float) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var surface_count := _get_mesh_surface_count(mesh_instance)
		if surface_count <= 0:
			var material := _create_prop_paint_material(color, roughness, metallic, specular)
			mesh_instance.material_override = material
		else:
			for surface in range(surface_count):
				var material := _create_prop_paint_material(color, roughness, metallic, specular)
				mesh_instance.set_surface_override_material(surface, material)
	for child in node.get_children():
		_apply_paint_profile_to_prop_meshes(child, color, roughness, metallic, specular)


func _create_prop_paint_material(color: Color, roughness: float, metallic: float, specular: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_local_to_scene = true
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	material.metallic_specular = specular
	return material


func _sanitize_environment_prop_disguise_preset(preset: Dictionary) -> Dictionary:
	var clean := preset.duplicate(true)
	if clean.has("paint_payload"):
		var payload := _sanitize_environment_prop_paint_payload(clean.get("paint_payload", {}))
		if payload.is_empty():
			clean.erase("paint_payload")
		else:
			clean["paint_payload"] = payload
	return clean


func _sanitize_environment_prop_paint_payload(value) -> Dictionary:
	if not value is Dictionary:
		return {}
	var payload := value as Dictionary
	var raw_surfaces = payload.get("surfaces", [])
	if not raw_surfaces is Array:
		return {}
	var clean_surfaces := []
	var total_bytes := 0
	for raw in raw_surfaces:
		if clean_surfaces.size() >= ENVIRONMENT_PROP_PAINT_MAX_SURFACES:
			break
		if not raw is Dictionary:
			continue
		var entry := raw as Dictionary
		var mesh_path := str(entry.get("mesh_path", ""))
		if mesh_path.is_empty() or mesh_path.length() > 256 or mesh_path.begins_with("/") or mesh_path.find("..") >= 0:
			continue
		var png_bytes = entry.get("png", PackedByteArray())
		if not png_bytes is PackedByteArray:
			continue
		var bytes := png_bytes as PackedByteArray
		if bytes.is_empty() or bytes.size() > ENVIRONMENT_PROP_PAINT_MAX_BYTES_PER_SURFACE:
			continue
		if total_bytes + bytes.size() > ENVIRONMENT_PROP_PAINT_MAX_TOTAL_BYTES:
			break
		total_bytes += bytes.size()
		clean_surfaces.append({
			"mesh_path": mesh_path,
			"surface": clampi(int(entry.get("surface", 0)), 0, 31),
			"png": bytes,
		})
	if clean_surfaces.is_empty():
		return {}
	var base_color: Color = payload.get("base_color", Color(0.96, 0.94, 0.9, 1.0))
	base_color.a = 1.0
	return {
		"version": 1,
		"texture_size": clampi(int(payload.get("texture_size", ENVIRONMENT_PROP_PAINT_SYNC_SIZE)), 64, ENVIRONMENT_PROP_PAINT_SYNC_SIZE),
		"base_color": base_color,
		"roughness": clampf(float(payload.get("roughness", 0.72)), 0.0, 1.0),
		"metallic": clampf(float(payload.get("metallic", 0.0)), 0.0, 1.0),
		"specular": clampf(float(payload.get("specular", 0.45)), 0.0, 1.0),
		"surfaces": clean_surfaces,
	}


func _image_has_visible_alpha(image: Image) -> bool:
	if not image or image.is_empty():
		return false
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.01:
				return true
	return false


func _apply_material_to_unassigned_prop_meshes(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if not _prop_mesh_has_material(mesh_instance):
			mesh_instance.material_override = material
	for child in node.get_children():
		_apply_material_to_unassigned_prop_meshes(child, material)


func _prop_mesh_has_material(mesh_instance: MeshInstance3D) -> bool:
	if mesh_instance.material_override:
		return true
	var override_count := mesh_instance.get_surface_override_material_count()
	for i in range(override_count):
		if mesh_instance.get_surface_override_material(i):
			return true
	if mesh_instance.mesh:
		for i in range(mesh_instance.mesh.get_surface_count()):
			if mesh_instance.mesh.surface_get_material(i):
				return true
	return false


func _apply_body_rotation(move_velocity: Vector3) -> void:
	if _body and _body.has_method("apply_rotation"):
		_body.apply_rotation(move_velocity)


func _animate_body(move_velocity: Vector3) -> void:
	if _active_skin_node:
		if not is_on_floor():
			_play_skin_action("fall" if move_velocity.y < 0.0 else "jump")
		elif Vector2(move_velocity.x, move_velocity.z).length_squared() > 0.01:
			_play_skin_action("move")
		else:
			_play_skin_action("idle")
		return

	if _body and _body.has_method("animate"):
		_body.animate(move_velocity)


func _play_body_jump(jump_type: String = "Jump") -> void:
	publish_network_action("jump", {"jump_type": jump_type})
	_play_audio(_jump_audio)
	if _active_skin_node:
		_play_skin_action("jump")
	elif _body and _body.has_method("play_jump_animation"):
		_body.play_jump_animation(jump_type)


func _is_dedicated_public_server_runtime() -> bool:
	return RuntimeMode.is_dedicated_public_server(multiplayer, Network.lobby_config)


func _should_render_local_feedback() -> bool:
	return not _is_dedicated_public_server_runtime()


func _should_log_runtime_debug() -> bool:
	return GameSettings.should_log_runtime_debug()


func _setup_player_audio() -> void:
	if _is_dedicated_public_server_runtime():
		return
	_jump_audio = _make_audio_player("JumpAudio", "res://assets/audio/player/robot_jump.wav", -7.0)
	_land_audio = _make_audio_player("LandAudio", "res://assets/audio/player/robot_land.wav", -5.0)
	_step_audio = _make_audio_player("StepAudio", "", -12.0)
	_disguise_audio = _make_audio_player("DisguiseAudio", "res://assets/audio/player/prop_disguise.wav", -3.5, 30.0)
	_step_sounds.clear()
	for path in [
		"res://assets/audio/player/robot_step_01.wav",
		"res://assets/audio/player/robot_step_02.wav",
		"res://assets/audio/player/robot_step_03.wav",
		"res://assets/audio/player/robot_step_04.wav",
		"res://assets/audio/player/robot_step_05.wav",
	]:
		var stream := load(path)
		if stream is AudioStream:
			_step_sounds.append(stream)


func _make_audio_player(node_name: String, stream_path: String, volume_db: float, max_distance: float = 22.0) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.name = node_name
	player.volume_db = volume_db
	player.max_distance = max_distance
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	if not stream_path.is_empty():
		var stream := load(stream_path)
		if stream is AudioStream:
			player.stream = stream
	add_child(player)
	return player


func _update_movement_audio(delta: float, was_on_floor: bool) -> void:
	if is_on_floor() and not was_on_floor:
		publish_network_action("land")
		_play_audio(_land_audio)
		_footstep_timer = 0.0

	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and horizontal_speed > FOOTSTEP_MIN_SPEED:
		var sprinting := _is_sprint_footstep(horizontal_speed)
		if sprinting != _last_footstep_sprinting:
			_footstep_timer = 0.0
			_last_footstep_sprinting = sprinting
		_footstep_timer -= delta
		if _footstep_timer <= 0.0:
			if _footstep_is_audible_for_mode(sprinting):
				_play_step_audio(sprinting)
			_footstep_timer = _footstep_interval_for_mode(sprinting)
	else:
		_footstep_timer = 0.0
		_last_footstep_sprinting = false


func _is_sprint_footstep(horizontal_speed: float) -> bool:
	return _input_action_held("shift") and horizontal_speed > WALK_SPEED * 0.75


func _footstep_interval_for_mode(sprinting: bool) -> float:
	return FOOTSTEP_SPRINT_INTERVAL if sprinting else FOOTSTEP_WALK_INTERVAL


func _footstep_volume_for_mode(sprinting: bool) -> float:
	return FOOTSTEP_SPRINT_VOLUME_DB if sprinting else FOOTSTEP_WALK_VOLUME_DB


func _footstep_is_audible_for_mode(sprinting: bool) -> bool:
	return true if sprinting else FOOTSTEP_WALK_AUDIBLE


func _play_step_audio(sprinting: bool = false) -> void:
	if not _footstep_is_audible_for_mode(sprinting):
		return
	if _card_silent_steps_remaining > 0.0:
		return
	if not _step_audio or _step_sounds.is_empty():
		return
	_step_audio.stream = _step_sounds.pick_random()
	_step_audio.volume_db = _footstep_volume_for_mode(sprinting)
	var pitch_min := FOOTSTEP_SPRINT_PITCH_MIN if sprinting else FOOTSTEP_WALK_PITCH_MIN
	var pitch_max := FOOTSTEP_SPRINT_PITCH_MAX if sprinting else FOOTSTEP_WALK_PITCH_MAX
	_play_audio(_step_audio, pitch_min, pitch_max)


func _play_audio(player: AudioStreamPlayer3D, pitch_min: float = 0.94, pitch_max: float = 1.06) -> void:
	if not player or not player.stream:
		return
	player.pitch_scale = randf_range(pitch_min, pitch_max)
	player.play()


func _ensure_skin_performance_music_player() -> void:
	if _is_dedicated_public_server_runtime():
		return
	if _skin_performance_music_player and is_instance_valid(_skin_performance_music_player):
		return
	var player := AudioStreamPlayer.new()
	player.name = "SkinPerformanceMusicAudio"
	player.volume_db = SKIN_PERFORMANCE_MUSIC_VOLUME_DB
	player.bus = &"Master"
	player.max_polyphony = 1
	add_child(player)
	_skin_performance_music_player = player


func _play_skin_performance_music() -> void:
	if _is_dedicated_public_server_runtime():
		return
	if SKIN_PERFORMANCE_MUSIC_PATHS.is_empty():
		return
	_ensure_skin_performance_music_player()
	if not _skin_performance_music_player or not is_instance_valid(_skin_performance_music_player):
		return
	var stream_path := String(SKIN_PERFORMANCE_MUSIC_PATHS[randi() % SKIN_PERFORMANCE_MUSIC_PATHS.size()])
	var stream := load(stream_path)
	if not (stream is AudioStream):
		return
	_skin_performance_music_player.stop()
	_skin_performance_music_player.stream = stream
	_skin_performance_music_player.pitch_scale = randf_range(0.99, 1.01)
	_skin_performance_music_player.play()


func _stop_skin_performance_music() -> void:
	if _skin_performance_music_player and is_instance_valid(_skin_performance_music_player):
		_skin_performance_music_player.stop()


func play_skin_action(action: String) -> void:
	_play_skin_action(action)


func request_skin_performance_action(action: String) -> bool:
	var normalized := action.strip_edges().to_lower()
	if not SKIN_PERFORMANCE_ACTIONS.has(normalized):
		return false
	if _skin_performance_camera_active:
		return true
	if match_intro_locked or prep_phase_locked or _skin_performance_input_block_remaining > 0.0 or _is_dead:
		_reset_skin_performance_wheel_bar()
		return true
	if _is_prop_disguised or not _active_skin_node or not is_instance_valid(_active_skin_node):
		return true
	if _active_skin_node.has_method("has_action") and not bool(_active_skin_node.call("has_action", normalized)):
		return true
	_push_skin_performance_wheel_bar(normalized)
	return true


func _push_skin_performance_wheel_bar(action: String) -> void:
	_ensure_skin_performance_wheel_bar()
	_skin_performance_wheel_bar_idle_remaining = SKIN_PERFORMANCE_WHEEL_BAR_IDLE_SECONDS
	if action == "dance":
		_skin_performance_wheel_dance_charge = clampf(_skin_performance_wheel_dance_charge + SKIN_PERFORMANCE_WHEEL_CHARGE_STEP, 0.0, 1.0)
		_skin_performance_wheel_victory_charge = maxf(0.0, _skin_performance_wheel_victory_charge - SKIN_PERFORMANCE_WHEEL_OPPOSITE_DRAIN)
	elif action == "victory":
		_skin_performance_wheel_victory_charge = clampf(_skin_performance_wheel_victory_charge + SKIN_PERFORMANCE_WHEEL_CHARGE_STEP, 0.0, 1.0)
		_skin_performance_wheel_dance_charge = maxf(0.0, _skin_performance_wheel_dance_charge - SKIN_PERFORMANCE_WHEEL_OPPOSITE_DRAIN)
	_refresh_skin_performance_wheel_bar_visuals()
	if _skin_performance_wheel_dance_charge >= 1.0 or _skin_performance_wheel_victory_charge >= 1.0:
		var selected_action := "dance" if _skin_performance_wheel_dance_charge >= _skin_performance_wheel_victory_charge else "victory"
		_reset_skin_performance_wheel_bar()
		_submit_skin_performance_action(selected_action)


func _normalize_skin_performance_action(action: String) -> String:
	var normalized := action.strip_edges().to_lower()
	return normalized if SKIN_PERFORMANCE_ACTIONS.has(normalized) else ""


func _has_active_skin_performance_peer() -> bool:
	var peer := multiplayer.multiplayer_peer
	if peer == null:
		return false
	if peer is OfflineMultiplayerPeer:
		return false
	return peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED


func _submit_skin_performance_action(action: String) -> void:
	var normalized := _normalize_skin_performance_action(action)
	if normalized.is_empty():
		return
	_apply_skin_performance_action_rpc(normalized)
	publish_network_action("skin_performance", {"action": normalized})
	if not _has_active_skin_performance_peer():
		_apply_skin_performance_cost()
		return
	elif _is_runtime_multiplayer_server():
		_apply_skin_performance_cost()
		_apply_skin_performance_action_rpc.rpc(normalized)
	else:
		_request_skin_performance_action_rpc.rpc_id(1, normalized)


@rpc("any_peer", "call_local", "reliable")
func _request_skin_performance_action_rpc(action: String) -> void:
	if not _is_runtime_multiplayer_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != get_multiplayer_authority():
		push_warning("Client " + str(sender) + " tried to perform for player " + str(get_multiplayer_authority()))
		return
	var normalized := _normalize_skin_performance_action(action)
	if normalized.is_empty():
		return
	if _is_dead or _is_prop_disguised:
		return
	_apply_skin_performance_cost()
	_apply_skin_performance_action_rpc.rpc(normalized)


# Server-authoritative escalating cost for repeat livestream performances in one
# match: 1st free, 2nd costs 40% max HP, 3rd+ is fatal. Bypasses damage immunity
# and reactive rescue cards on purpose — this is a self-inflicted griefing
# deterrent, not combat damage.
func _apply_skin_performance_cost() -> void:
	# Authoritative side only: the server in multiplayer, or ourselves when
	# offline (no peer) so single-instance testing still shows the cost. NOTE:
	# against a live server the cost runs THERE — the server build must include
	# this logic for HP to actually change on connected clients.
	if multiplayer.has_multiplayer_peer() and not _is_runtime_multiplayer_server():
		return
	if _is_dead:
		return
	var has_peer := multiplayer.has_multiplayer_peer()
	_skin_performance_use_count += 1
	if _skin_performance_use_count <= 1:
		return
	if _skin_performance_use_count >= 3:
		if has_peer:
			_card_feedback_to_owner("PERFORMANCE OVERUSE — FATAL", Color(1.0, 0.26, 0.2, 1.0), 1.6)
			_server_die(int(str(name)))
		else:
			health = 0.0
			health_changed.emit(health)
		return
	# Second use this match: drain 40% of max HP.
	health = maxf(0.0, health - max_health * 0.40)
	if has_peer:
		_card_feedback_to_owner("PERFORMANCE COST  -40% HP", Color(1.0, 0.55, 0.2, 1.0), 1.4)
		if health <= 0.0:
			_server_die(int(str(name)))
		else:
			_sync_health.rpc(health)
	else:
		health_changed.emit(health)


@rpc("any_peer", "call_local", "reliable")
func _apply_skin_performance_action_rpc(action: String) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1:
		return
	var normalized := _normalize_skin_performance_action(action)
	if normalized.is_empty():
		return
	if _skin_performance_camera_active and _skin_performance_camera_action == normalized:
		return
	if _is_dead or _is_prop_disguised:
		return
	if not _active_skin_node or not is_instance_valid(_active_skin_node):
		return
	if _active_skin_node.has_method("has_action") and not bool(_active_skin_node.call("has_action", normalized)):
		return
	_reset_skin_performance_wheel_bar()
	_play_skin_action(normalized)


func _process_skin_performance_wheel_bar(delta: float) -> void:
	if match_intro_locked or prep_phase_locked or _is_dead or _skin_performance_camera_active:
		_reset_skin_performance_wheel_bar()
		return
	if not _skin_performance_wheel_bar_root or not is_instance_valid(_skin_performance_wheel_bar_root):
		return
	_face_skin_performance_wheel_bar_to_camera()
	if _skin_performance_wheel_bar_idle_remaining > 0.0:
		_skin_performance_wheel_bar_idle_remaining = maxf(0.0, _skin_performance_wheel_bar_idle_remaining - delta)
		return
	_skin_performance_wheel_dance_charge = maxf(0.0, _skin_performance_wheel_dance_charge - SKIN_PERFORMANCE_WHEEL_DECAY_PER_SECOND * delta)
	_skin_performance_wheel_victory_charge = maxf(0.0, _skin_performance_wheel_victory_charge - SKIN_PERFORMANCE_WHEEL_DECAY_PER_SECOND * delta)
	_refresh_skin_performance_wheel_bar_visuals()
	if _skin_performance_wheel_dance_charge <= 0.0 and _skin_performance_wheel_victory_charge <= 0.0:
		_reset_skin_performance_wheel_bar()


func _ensure_skin_performance_wheel_bar() -> void:
	if _skin_performance_wheel_bar_root and is_instance_valid(_skin_performance_wheel_bar_root):
		return
	var root := Node3D.new()
	root.name = "SkinPerformanceWheelBar"
	root.position = Vector3(0.86, 1.48, 0.0)
	add_child(root)
	_skin_performance_wheel_bar_root = root
	root.add_child(_make_skin_performance_wheel_bar_piece("DanceBarBack", Color(0.03, 0.04, 0.06, 0.58), Vector3(0.0, 0.24, 0.0), Vector3(0.12, 0.42, 0.022)))
	root.add_child(_make_skin_performance_wheel_bar_piece("VictoryBarBack", Color(0.03, 0.04, 0.06, 0.58), Vector3(0.0, -0.24, 0.0), Vector3(0.12, 0.42, 0.022)))
	root.add_child(_make_skin_performance_wheel_bar_piece("WheelBarSplit", Color(1.0, 1.0, 1.0, 0.42), Vector3.ZERO, Vector3(0.16, 0.025, 0.03)))
	_skin_performance_wheel_dance_fill = _make_skin_performance_wheel_bar_piece("DanceBarFill", Color(0.18, 0.78, 1.0, 0.92), Vector3(0.0, 0.05, 0.018), Vector3(0.075, SKIN_PERFORMANCE_WHEEL_BAR_SEGMENT_HEIGHT, 0.028))
	_skin_performance_wheel_victory_fill = _make_skin_performance_wheel_bar_piece("VictoryBarFill", Color(1.0, 0.42, 0.88, 0.92), Vector3(0.0, -0.05, 0.018), Vector3(0.075, SKIN_PERFORMANCE_WHEEL_BAR_SEGMENT_HEIGHT, 0.028))
	root.add_child(_skin_performance_wheel_dance_fill)
	root.add_child(_skin_performance_wheel_victory_fill)
	_refresh_skin_performance_wheel_bar_visuals()
	_face_skin_performance_wheel_bar_to_camera()


func _make_skin_performance_wheel_bar_piece(node_name: String, color: Color, local_position: Vector3, size: Vector3) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.name = node_name
	piece.position = local_position
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := BoxMesh.new()
	mesh.size = size
	piece.mesh = mesh
	mesh.material = _make_skin_performance_wheel_bar_material(color)
	return piece


func _make_skin_performance_wheel_bar_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.disable_fog = true
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.35
	return material


func _refresh_skin_performance_wheel_bar_visuals() -> void:
	var dance_amount := clampf(_skin_performance_wheel_dance_charge, 0.0, 1.0)
	var victory_amount := clampf(_skin_performance_wheel_victory_charge, 0.0, 1.0)
	var half_height := SKIN_PERFORMANCE_WHEEL_BAR_SEGMENT_HEIGHT * 0.5
	if _skin_performance_wheel_dance_fill and is_instance_valid(_skin_performance_wheel_dance_fill):
		_skin_performance_wheel_dance_fill.visible = dance_amount > 0.01
		_skin_performance_wheel_dance_fill.scale = Vector3(1.0, maxf(dance_amount, 0.01), 1.0)
		_skin_performance_wheel_dance_fill.position.y = 0.24 - half_height + half_height * dance_amount
	if _skin_performance_wheel_victory_fill and is_instance_valid(_skin_performance_wheel_victory_fill):
		_skin_performance_wheel_victory_fill.visible = victory_amount > 0.01
		_skin_performance_wheel_victory_fill.scale = Vector3(1.0, maxf(victory_amount, 0.01), 1.0)
		_skin_performance_wheel_victory_fill.position.y = -0.24 + half_height - half_height * victory_amount


func _face_skin_performance_wheel_bar_to_camera() -> void:
	if not _skin_performance_wheel_bar_root or not is_instance_valid(_skin_performance_wheel_bar_root):
		return
	var camera := get_viewport().get_camera_3d()
	if camera:
		_skin_performance_wheel_bar_root.global_basis = camera.global_basis


func _reset_skin_performance_wheel_bar() -> void:
	_skin_performance_wheel_dance_charge = 0.0
	_skin_performance_wheel_victory_charge = 0.0
	_skin_performance_wheel_bar_idle_remaining = 0.0
	_skin_performance_wheel_dance_fill = null
	_skin_performance_wheel_victory_fill = null
	if _skin_performance_wheel_bar_root and is_instance_valid(_skin_performance_wheel_bar_root):
		_skin_performance_wheel_bar_root.queue_free()
	_skin_performance_wheel_bar_root = null


func _connect_active_skin_animation_signals() -> void:
	if not _active_skin_node or not is_instance_valid(_active_skin_node):
		return
	if not _active_skin_node.has_signal("action_finished"):
		return
	var callback := Callable(self, "_on_active_skin_action_finished")
	if not _active_skin_node.is_connected("action_finished", callback):
		_active_skin_node.connect("action_finished", callback)


func _play_skin_reaction(action: String) -> void:
	if _is_prop_disguised:
		return
	_play_skin_action(action)


func _should_hold_party_monster_trip_action(action: String) -> bool:
	# While the knockdown lock is active, suppress locomotion/air actions so the trip pose holds
	# (on peers too). The lock itself marks the knockdown — no per-model gate needed now that
	# every character uses the party_monster skin.
	if not _party_monster_trip_action_locked:
		return false
	# "trip" is held too: the knockdown clip is issued exactly once (the trip RPC calls the skin
	# directly), so any per-frame re-issue from the synced visual state must be swallowed — otherwise
	# the skin restarts/alternates trip_01<->trip_02 from frame 0 every frame, which on peers reads
	# as the downed player standing upright and jittering instead of holding the lying pose.
	return action == "idle" or action == "move" or action == "walk" or action == "run" or action == "jump" or action == "fall" or action == "land" or action == "trip"


func _play_skin_action(action: String) -> void:
	if not _active_skin_node or not is_instance_valid(_active_skin_node):
		return

	var normalized := action.strip_edges().to_lower()
	# A non-locomotion action interrupts locomotion, so clear the locomotion guard key — the
	# next run/walk/move must re-issue to the skin instead of being skipped as "unchanged".
	if normalized != "run" and normalized != "walk" and normalized != "move":
		_remote_locomotion_action_key = ""
	if _should_hold_party_monster_trip_action(normalized):
		return
	if _skin_performance_camera_active and not SKIN_PERFORMANCE_ACTIONS.has(normalized) and normalized != "idle":
		_restore_skin_performance_camera_now()
	var did_play := false
	match normalized:
		"move":
			if _active_skin_node.has_method("set_walk_run_blending"):
				_active_skin_node.call("set_walk_run_blending", 1.0 if _input_action_held("shift") else 0.25)
			if _active_skin_node.has_method("move"):
				_active_skin_node.call("move")
				did_play = true
			elif _active_skin_node.has_method("run"):
				_active_skin_node.call("run")
				did_play = true
		"jump":
			if _active_skin_node.has_method("jump"):
				_active_skin_node.call("jump")
				did_play = true
		"fall":
			if _active_skin_node.has_method("fall"):
				_active_skin_node.call("fall")
				did_play = true
		_:
			if _active_skin_node.has_method(normalized):
				_active_skin_node.call(normalized)
				did_play = true
			elif _active_skin_node.has_method("play_action"):
				did_play = bool(_active_skin_node.call("play_action", normalized))

	if not did_play and _active_skin_node.has_method("idle"):
		_active_skin_node.call("idle")
	if did_play and SKIN_PERFORMANCE_ACTIONS.has(normalized):
		_begin_skin_performance_camera(normalized)


func _get_skin_performance_front_camera_yaw() -> float:
	var visual_yaw := 0.0
	if _body and is_instance_valid(_body):
		visual_yaw = _body.rotation.y
	elif _active_skin_node and is_instance_valid(_active_skin_node):
		visual_yaw = _active_skin_node.rotation.y
	return wrapf(visual_yaw + SKIN_PERFORMANCE_CAMERA_FRONT_YAW_OFFSET, -PI, PI)


func _get_skin_performance_camera() -> Camera3D:
	if _spring_arm_offset and is_instance_valid(_spring_arm_offset):
		return _spring_arm_offset.get_node_or_null("SpringArm3D/Camera3D") as Camera3D
	return get_node_or_null("SpringArmOffset/SpringArm3D/Camera3D") as Camera3D


func _begin_skin_performance_camera(action: String) -> void:
	if not _should_render_local_feedback():
		_reset_skin_performance_wheel_bar()
		_stop_skin_performance_music()
		return
	if not _spring_arm_offset:
		return
	if not _spring_arm_offset.has_method("capture_camera_rig_state") or not _spring_arm_offset.has_method("set_camera_rig_pose"):
		return
	var performance_camera := _get_skin_performance_camera()
	_skin_performance_camera_token += 1
	_reset_skin_performance_wheel_bar()
	_skin_performance_camera_action = action
	if not _skin_performance_camera_active:
		_skin_performance_camera_state = _spring_arm_offset.call("capture_camera_rig_state") as Dictionary
		_skin_performance_previous_current_camera = get_viewport().get_camera_3d()
	_skin_performance_camera_active = true
	if _spring_arm_offset.has_method("set_camera_input_locked"):
		_spring_arm_offset.call("set_camera_input_locked", true)
	var performance_yaw := _get_skin_performance_front_camera_yaw()
	_spring_arm_offset.call("set_camera_rig_pose", performance_yaw, SKIN_PERFORMANCE_CAMERA_PITCH, SKIN_PERFORMANCE_CAMERA_SPRING_LENGTH, SKIN_PERFORMANCE_CAMERA_FOV, true)
	if performance_camera and is_instance_valid(performance_camera):
		performance_camera.current = true
	_start_skin_performance_effects()
	_play_skin_performance_music()
	var animation_length := _get_active_skin_current_animation_length()
	var fallback_delay := maxf(animation_length, 1.0) + SKIN_PERFORMANCE_CAMERA_RETURN_DELAY
	_restore_skin_performance_camera_after_delay(_skin_performance_camera_token, fallback_delay)


func _get_active_skin_current_animation_length() -> float:
	if _active_skin_node and is_instance_valid(_active_skin_node) and _active_skin_node.has_method("get_current_animation_length"):
		return float(_active_skin_node.call("get_current_animation_length"))
	return 0.0


func _on_active_skin_action_finished(action_name: String, _clip_name: String) -> void:
	if action_name == "trip":
		# The trip clip played out but the knockdown HOLDS: stay locked and start awaiting the
		# stand-up (owner presses jump; peers wait for the broadcast stand_up event). Never
		# auto-recover here, or the player would pop upright the instant the clip ends.
		if _party_monster_trip_action_locked:
			_stand_up_system.begin()
	if not _skin_performance_camera_active:
		return
	if action_name != _skin_performance_camera_action:
		return
	_restore_skin_performance_camera_after_delay(_skin_performance_camera_token, SKIN_PERFORMANCE_CAMERA_RETURN_DELAY)


func _restore_skin_performance_camera_now() -> void:
	if not _skin_performance_camera_active:
		_clear_skin_performance_effects()
		_skin_performance_previous_current_camera = null
		return
	_skin_performance_camera_token += 1
	_clear_skin_performance_effects()
	if _spring_arm_offset and _spring_arm_offset.has_method("apply_camera_rig_state"):
		_spring_arm_offset.call("apply_camera_rig_state", _skin_performance_camera_state, true)
		if _spring_arm_offset.has_method("set_camera_input_locked"):
			_spring_arm_offset.call("set_camera_input_locked", false)
	_restore_skin_performance_view_camera()
	_skin_performance_camera_state = {}
	_skin_performance_camera_action = ""
	_skin_performance_camera_active = false


func _restore_skin_performance_camera_after_delay(token: int, delay: float) -> void:
	await get_tree().create_timer(maxf(delay, 0.0)).timeout
	if token != _skin_performance_camera_token or not _skin_performance_camera_active:
		return
	if _spring_arm_offset and _spring_arm_offset.has_method("apply_camera_rig_state"):
		_spring_arm_offset.call("apply_camera_rig_state", _skin_performance_camera_state, false)
		if _spring_arm_offset.has_method("set_camera_input_locked"):
			_spring_arm_offset.call("set_camera_input_locked", false)
	_restore_skin_performance_view_camera()
	_skin_performance_camera_state = {}
	_skin_performance_camera_action = ""
	_skin_performance_camera_active = false
	_clear_skin_performance_effects()


func _restore_skin_performance_view_camera() -> void:
	var performance_camera := _get_skin_performance_camera()
	var current_camera := get_viewport().get_camera_3d()
	if performance_camera and is_instance_valid(performance_camera) and current_camera == performance_camera:
		if _skin_performance_previous_current_camera and is_instance_valid(_skin_performance_previous_current_camera) and _skin_performance_previous_current_camera != performance_camera:
			_skin_performance_previous_current_camera.current = true
		elif not _is_local_authority():
			performance_camera.current = false
	_skin_performance_previous_current_camera = null


func _start_skin_performance_effects() -> void:
	_clear_skin_performance_effects()
	var root := Node3D.new()
	root.name = "SkinPerformanceEffects"
	root.position = Vector3(0.0, 2.2, 0.0)
	add_child(root)
	_skin_performance_effect_root = root

	var tween := create_tween()
	tween.set_parallel(true)
	_skin_performance_effect_tween = tween

	for i in range(SKIN_PERFORMANCE_CONFETTI_COUNT):
		var paper := MeshInstance3D.new()
		paper.name = "Confetti%02d" % i
		paper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mesh := BoxMesh.new()
		mesh.size = Vector3(randf_range(0.035, 0.06), randf_range(0.006, 0.012), randf_range(0.075, 0.13))
		paper.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = SKIN_PERFORMANCE_CONFETTI_COLORS[i % SKIN_PERFORMANCE_CONFETTI_COLORS.size()]
		material.emission_enabled = true
		material.emission = material.albedo_color
		material.emission_energy_multiplier = 0.65
		material.disable_receive_shadows = true
		mesh.material = material
		paper.position = Vector3(randf_range(-0.38, 0.38), randf_range(0.02, 0.48), randf_range(-0.38, 0.38))
		paper.rotation_degrees = Vector3(randf_range(0.0, 180.0), randf_range(0.0, 180.0), randf_range(0.0, 180.0))
		root.add_child(paper)
		var duration := randf_range(1.0, 1.65)
		var target_position := paper.position + Vector3(randf_range(-0.92, 0.92), randf_range(-1.05, -0.46), randf_range(-0.92, 0.92))
		tween.tween_property(paper, "position", target_position, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(paper, "rotation_degrees", paper.rotation_degrees + Vector3(randf_range(260.0, 720.0), randf_range(260.0, 720.0), randf_range(260.0, 720.0)), duration)
		tween.tween_property(paper, "scale", Vector3.ONE * 0.18, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	for i in range(SKIN_PERFORMANCE_DISCO_LIGHT_COUNT):
		var angle := TAU * float(i) / float(SKIN_PERFORMANCE_DISCO_LIGHT_COUNT)
		var color: Color = SKIN_PERFORMANCE_CONFETTI_COLORS[(i + 1) % SKIN_PERFORMANCE_CONFETTI_COLORS.size()]
		var light := OmniLight3D.new()
		light.name = "DiscoLight%02d" % i
		light.light_color = color
		light.light_energy = SKIN_PERFORMANCE_DISCO_LIGHT_ENERGY
		light.light_specular = 0.9
		light.omni_range = SKIN_PERFORMANCE_DISCO_LIGHT_RANGE
		light.omni_attenuation = 0.35
		light.shadow_enabled = false
		light.position = Vector3(cos(angle) * 1.35, -0.95 + float(i % 2) * 0.28, sin(angle) * 1.35)
		root.add_child(light)

		var marker := MeshInstance3D.new()
		marker.name = "DiscoLightMarker%02d" % i
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var marker_mesh := SphereMesh.new()
		marker_mesh.radius = 0.055
		marker_mesh.height = 0.11
		marker.mesh = marker_mesh
		var marker_material := StandardMaterial3D.new()
		marker_material.albedo_color = color
		marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		marker_material.emission_enabled = true
		marker_material.emission = color
		marker_material.emission_energy_multiplier = 2.2
		marker_material.disable_receive_shadows = true
		marker.mesh.material = marker_material
		marker.position = light.position
		root.add_child(marker)

		tween.tween_property(light, "light_energy", SKIN_PERFORMANCE_DISCO_LIGHT_ENERGY * 1.18, 0.42).set_delay(float(i) * 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(marker, "scale", Vector3.ONE * 1.22, 0.42).set_delay(float(i) * 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(light, "light_energy", SKIN_PERFORMANCE_DISCO_LIGHT_ENERGY, 0.42).set_delay(0.46 + float(i) * 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(marker, "scale", Vector3.ONE, 0.42).set_delay(0.46 + float(i) * 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _clear_skin_performance_effects() -> void:
	_stop_skin_performance_music()
	if _skin_performance_effect_tween and _skin_performance_effect_tween.is_valid():
		_skin_performance_effect_tween.kill()
	_skin_performance_effect_tween = null
	if _skin_performance_effect_root and is_instance_valid(_skin_performance_effect_root):
		_skin_performance_effect_root.queue_free()
	_skin_performance_effect_root = null


func get_network_visual_state() -> Dictionary:
	var action: String = _current_network_visual_action()
	_update_network_visual_action_export(action)
	var move_intent: Vector3 = _current_network_visual_move_intent()
	return {
		"action": action,
		"action_seq": _network_visual_action_sequence,
		"action_tick": _network_visual_action_tick,
		"yaw": _current_network_visual_yaw(),
		"grounded": is_on_floor(),
		"move_speed": Vector2(velocity.x, velocity.z).length(),
		"move_x": move_intent.x,
		"move_z": move_intent.z,
		"sprinting": _input_action_held("shift"),
	}


func _update_network_visual_action_export(action: String) -> void:
	var normalized: String = _normalize_network_visual_action(action)
	if normalized.is_empty():
		normalized = "idle"
	if normalized == _network_visual_export_action:
		return
	_network_visual_export_action = normalized
	_network_visual_action_sequence = _next_network_visual_action_sequence(_network_visual_action_sequence)
	_network_visual_action_tick = get_network_input_tick()
	# Mirror important transitions onto the reliable action bus so a dropped/throttled visual
	# state packet can never make peers miss a fall / land / dizzy / trip / getup.
	if _is_local_authority() and NETWORK_VISUAL_RELIABLE_ACTIONS.has(normalized):
		publish_network_action("visual_action", {"action": normalized, "seq": _network_visual_action_sequence})


func _next_network_visual_action_sequence(current_sequence: int) -> int:
	var next_sequence: int = current_sequence + 1
	return 1 if next_sequence >= 0x7fffffff else next_sequence


func apply_network_visual_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	if _is_local_authority():
		return
	var action: String = _normalize_network_visual_action(str(state.get("action", "")))
	if action.is_empty():
		action = "idle"
	var previous_action: String = _network_visual_action
	var incoming_sequence: int = max(0, int(state.get("action_seq", _network_visual_action_sequence)))
	if not state.has("action_seq") and action != previous_action:
		incoming_sequence = _next_network_visual_action_sequence(_network_visual_action_sequence)
	_network_visual_action = action
	_network_visual_action_sequence = incoming_sequence
	_network_visual_action_tick = max(0, int(state.get("action_tick", _network_visual_action_tick)))
	if action != previous_action:
		_network_visual_applied_action_sequence = -1
	_network_visual_yaw = _network_visual_finite_float(state.get("yaw", _network_visual_yaw), _network_visual_yaw)
	_network_visual_yaw = wrapf(_network_visual_yaw, -PI, PI)
	_network_visual_grounded = bool(state.get("grounded", _network_visual_grounded))
	_network_visual_move_speed = clampf(_network_visual_finite_float(state.get("move_speed", 0.0), 0.0), 0.0, RUN_SPEED * 2.0)
	_network_visual_move_intent = Vector3(
		_network_visual_finite_float(state.get("move_x", 0.0), 0.0),
		0.0,
		_network_visual_finite_float(state.get("move_z", 0.0), 0.0)
	)
	if _network_visual_move_intent.length_squared() > 1.0:
		_network_visual_move_intent = _network_visual_move_intent.normalized()
	_network_visual_sprinting = bool(state.get("sprinting", _network_visual_sprinting))
	_network_visual_state_msec = Time.get_ticks_msec()


func _current_network_visual_move_intent() -> Vector3:
	var input_direction: Vector2 = _movement_input_vector() if _is_local_authority() else Vector2.ZERO
	if input_direction.length_squared() > TURN_INPUT_DEADZONE * TURN_INPUT_DEADZONE:
		var camera_basis: Basis = _spring_arm_offset.global_transform.basis if _spring_arm_offset else global_transform.basis
		var camera_forward: Vector3 = -camera_basis.z
		camera_forward.y = 0.0
		camera_forward = camera_forward.normalized()
		var camera_right: Vector3 = camera_basis.x
		camera_right.y = 0.0
		camera_right = camera_right.normalized()
		var direction: Vector3 = camera_right * input_direction.x + camera_forward * -input_direction.y
		if direction.length_squared() > 1.0:
			direction = direction.normalized()
		return direction
	var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	if horizontal_velocity.length_squared() > REMOTE_MOVE_SPEED_THRESHOLD * REMOTE_MOVE_SPEED_THRESHOLD:
		return horizontal_velocity.normalized()
	return Vector3.ZERO


func _current_network_visual_action() -> String:
	if _is_dead:
		return "die"
	if _party_monster_trip_action_locked:
		return "trip"
	var locomotion_action: String = _derive_network_locomotion_action()
	if _active_skin_node and is_instance_valid(_active_skin_node) and _active_skin_node.has_method("get_current_animation_action"):
		var skin_action: String = _normalize_network_visual_action(str(_active_skin_node.call("get_current_animation_action")))
		if not skin_action.is_empty():
			# Export the long-idle "dizzy" pose even though it reads as a locomotion action,
			# otherwise peers only ever see plain idle.
			if NETWORK_VISUAL_IDLE_VARIANT_ACTIONS.has(skin_action):
				return skin_action
			if not NETWORK_VISUAL_LOCOMOTION_ACTIONS.has(skin_action):
				return skin_action
	return locomotion_action


func _derive_network_locomotion_action() -> String:
	if not is_on_floor():
		return "fall" if velocity.y < 0.0 else "jump"
	var move_intent: Vector3 = _current_network_visual_move_intent()
	if move_intent.length_squared() > TURN_INPUT_DEADZONE * TURN_INPUT_DEADZONE:
		return "run" if _input_action_held("shift") else "move"
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	if horizontal_speed >= REMOTE_RUN_SPEED_THRESHOLD:
		return "run"
	if horizontal_speed > REMOTE_MOVE_SPEED_THRESHOLD:
		return "move"
	return "idle"


func _current_network_visual_yaw() -> float:
	if _body and is_instance_valid(_body):
		return wrapf(_body.rotation.y, -PI, PI)
	if _active_skin_node and is_instance_valid(_active_skin_node):
		return wrapf(_active_skin_node.rotation.y, -PI, PI)
	return wrapf(rotation.y, -PI, PI)


func _normalize_network_visual_action(action: String) -> String:
	var normalized: String = action.strip_edges().to_lower().replace("-", "_").replace(" ", "_")
	if normalized.length() > NETWORK_VISUAL_ACTION_MAX_LENGTH:
		normalized = normalized.substr(0, NETWORK_VISUAL_ACTION_MAX_LENGTH)
	return normalized


func _network_visual_finite_float(value: Variant, fallback: float = 0.0) -> float:
	var value_type: int = typeof(value)
	if value_type != TYPE_FLOAT and value_type != TYPE_INT:
		return fallback
	var result: float = float(value)
	return result if is_finite(result) else fallback


func _has_fresh_network_visual_state() -> bool:
	if _network_visual_state_msec <= 0:
		return false
	return Time.get_ticks_msec() - _network_visual_state_msec <= NETWORK_VISUAL_STATE_MAX_AGE_MSEC


func _apply_synced_network_visual_state(delta: float) -> bool:
	if not _has_fresh_network_visual_state():
		return false
	_apply_network_visual_yaw(_network_visual_yaw, delta)
	_play_synced_network_visual_action(_network_visual_action)
	return true


func _apply_network_visual_yaw(target_yaw: float, delta: float) -> void:
	var visual_root: Node3D = null
	if _body and is_instance_valid(_body):
		visual_root = _body
	elif _active_skin_node and is_instance_valid(_active_skin_node):
		visual_root = _active_skin_node
	if visual_root == null:
		return
	var clean_yaw: float = wrapf(target_yaw, -PI, PI)
	if delta <= 0.0:
		visual_root.rotation.y = clean_yaw
		return
	var blend: float = clampf(1.0 - exp(-NETWORK_VISUAL_YAW_LERP_SPEED * delta), 0.0, 1.0)
	visual_root.rotation.y = lerp_angle(visual_root.rotation.y, clean_yaw, blend)


func _play_synced_network_visual_action(action: String) -> void:
	var normalized: String = _normalize_network_visual_action(action)
	if normalized.is_empty():
		normalized = "idle"
	var sequence_pending: bool = _network_visual_action_sequence != _network_visual_applied_action_sequence
	if _should_force_network_visual_locomotion_recovery(normalized, sequence_pending):
		if _force_network_visual_locomotion_recovery(normalized):
			_network_visual_applied_action_sequence = _network_visual_action_sequence
			return
	if normalized == "run":
		_play_remote_skin_locomotion("run", REMOTE_RUN_BLEND)
		_network_visual_applied_action_sequence = _network_visual_action_sequence
		return
	if normalized == "walk":
		_play_remote_skin_locomotion("walk", REMOTE_WALK_BLEND)
		_network_visual_applied_action_sequence = _network_visual_action_sequence
		return
	if normalized == "move":
		if _network_visual_sprinting or _network_visual_move_speed >= REMOTE_RUN_SPEED_THRESHOLD:
			_play_remote_skin_locomotion("run", REMOTE_RUN_BLEND)
		else:
			_play_remote_skin_locomotion("move", REMOTE_WALK_BLEND)
		_network_visual_applied_action_sequence = _network_visual_action_sequence
		return
	_play_skin_action(normalized)
	_network_visual_applied_action_sequence = _network_visual_action_sequence


func _network_visual_directional_locomotion_action(base_action: String) -> String:
	var normalized: String = _normalize_network_visual_action(base_action)
	if normalized == "move":
		normalized = "run" if _network_visual_sprinting or _network_visual_move_speed >= REMOTE_RUN_SPEED_THRESHOLD else "walk"
	if normalized != "run" and normalized != "walk":
		return normalized
	if not CharacterSkinCatalog.is_party_monster(character_model_id):
		return normalized
	if not _active_skin_node or not is_instance_valid(_active_skin_node):
		return normalized
	if _network_visual_move_intent.length_squared() <= TURN_INPUT_DEADZONE * TURN_INPUT_DEADZONE:
		return normalized
	var intent: Vector3 = _network_visual_move_intent.normalized()
	var yaw: float = wrapf(_network_visual_yaw, -PI, PI)
	var facing_forward := Vector3(-sin(yaw), 0.0, -cos(yaw)).normalized()
	var facing_right := Vector3(cos(yaw), 0.0, -sin(yaw)).normalized()
	var forward_amount: float = intent.dot(facing_forward)
	var side_amount: float = intent.dot(facing_right)
	var suffix := "forward"
	if absf(side_amount) > maxf(absf(forward_amount) * 0.85, 0.35):
		suffix = "right" if side_amount > 0.0 else "left"
	elif forward_amount < -0.35:
		suffix = "backward"
	var candidate: String = normalized + "_" + suffix
	if _active_skin_node.has_method("has_action") and bool(_active_skin_node.call("has_action", candidate)):
		return candidate
	return normalized


func _should_force_network_visual_locomotion_recovery(action: String, sequence_pending: bool) -> bool:
	if _is_dead:
		return false
	if not NETWORK_VISUAL_RECOVERY_ACTIONS.has(action):
		return false
	if _party_monster_trip_action_locked:
		# Hold the knockdown on peers: only the explicit stand_up event recovers it. A stray
		# locomotion visual-state sample must NOT pop the downed body back upright early.
		return false
	var current_action: String = _active_network_skin_action()
	if not NETWORK_VISUAL_INTERRUPTABLE_ACTIONS.has(current_action):
		return false
	if sequence_pending:
		return true
	return current_action != action


func _active_network_skin_action() -> String:
	if not _active_skin_node or not is_instance_valid(_active_skin_node):
		return ""
	if _active_skin_node.has_method("get_current_animation_action"):
		return _normalize_network_visual_action(str(_active_skin_node.call("get_current_animation_action")))
	return ""


func _force_network_visual_locomotion_recovery(action: String) -> bool:
	if not _active_skin_node or not is_instance_valid(_active_skin_node):
		return false
	if _party_monster_trip_action_locked:
		_finish_party_monster_trip_lock()
	if _skin_performance_camera_active and not SKIN_PERFORMANCE_ACTIONS.has(action):
		_restore_skin_performance_camera_now()
	var target_action: String = action
	if action == "move":
		target_action = "run" if _network_visual_sprinting or _network_visual_move_speed >= REMOTE_RUN_SPEED_THRESHOLD else "walk"
	if _active_skin_node.has_method("set_walk_run_blending"):
		var blend: float = REMOTE_RUN_BLEND if target_action == "run" else REMOTE_WALK_BLEND
		_active_skin_node.call("set_walk_run_blending", blend)
	target_action = _network_visual_directional_locomotion_action(target_action)
	if CharacterSkinCatalog.is_party_monster(character_model_id) and _active_skin_node.has_method("play_action"):
		return bool(_active_skin_node.call("play_action", target_action))
	if target_action == "run" and _active_skin_node.has_method("run"):
		_active_skin_node.call("run")
		return true
	if target_action == "walk" and _active_skin_node.has_method("walk"):
		_active_skin_node.call("walk")
		return true
	if target_action == "move" and _active_skin_node.has_method("move"):
		_active_skin_node.call("move")
		return true
	if target_action == "idle" and _active_skin_node.has_method("idle"):
		_active_skin_node.call("idle")
		return true
	if _active_skin_node.has_method("play_action"):
		return bool(_active_skin_node.call("play_action", target_action))
	return false


func _resolve_netfox_transform_sync() -> NetfoxPlayerTransformSync:
	if _netfox_transform_sync and is_instance_valid(_netfox_transform_sync):
		return _netfox_transform_sync
	_netfox_transform_sync = get_node_or_null("NetfoxTransformSync") as NetfoxPlayerTransformSync
	return _netfox_transform_sync


func _remote_motion_velocity_sample(delta: float) -> Dictionary:
	var transform_sync := _resolve_netfox_transform_sync()
	if transform_sync and transform_sync.has_method("has_fresh_remote_visual_sample"):
		var is_fresh := bool(transform_sync.call("has_fresh_remote_visual_sample", REMOTE_VISUAL_SAMPLE_MAX_AGE_MSEC))
		if is_fresh and transform_sync.has_method("get_remote_visual_velocity"):
			var velocity_value: Variant = transform_sync.call("get_remote_visual_velocity", REMOTE_VISUAL_SAMPLE_MAX_AGE_MSEC)
			var network_velocity := Vector3.ZERO
			if velocity_value is Vector3:
				network_velocity = velocity_value
			var position_value: Variant = global_position
			if transform_sync.has_method("get_remote_visual_position"):
				position_value = transform_sync.call("get_remote_visual_position", REMOTE_VISUAL_SAMPLE_MAX_AGE_MSEC)
			_remote_visual_position = global_position
			if position_value is Vector3:
				_remote_visual_position = position_value
			return {
				"ready": true,
				"velocity": network_velocity,
				"source": "netfox",
			}

	var sample: Dictionary = _remote_motion_sampler.sample(global_position, delta, _remote_visual_move_hold)
	if bool(sample.get("ready", false)):
		_remote_visual_position = sample.get("position", global_position)
	return sample


func _play_remote_skin_locomotion(action: String, blend: float) -> void:
	if not _active_skin_node or not is_instance_valid(_active_skin_node):
		return
	var normalized := action.strip_edges().to_lower()
	if _should_hold_party_monster_trip_action(normalized):
		return
	if _skin_performance_camera_active and not SKIN_PERFORMANCE_ACTIONS.has(normalized) and normalized != "idle":
		_restore_skin_performance_camera_now()
	if _active_skin_node.has_method("set_walk_run_blending"):
		_active_skin_node.call("set_walk_run_blending", blend)
	var directional_action: String = _network_visual_directional_locomotion_action(normalized)
	# Only (re)issue the skin locomotion when it actually changes. Re-issuing every frame makes
	# the skin re-roll a different run/walk clip variant and restart it, so peers see the legs
	# and arms rapidly cycle. The walk/run blend above still updates every frame.
	if directional_action == _remote_locomotion_action_key:
		return
	_remote_locomotion_action_key = directional_action
	if directional_action != normalized and _active_skin_node.has_method("play_action") and bool(_active_skin_node.call("play_action", directional_action)):
		return
	if normalized == "run" and _active_skin_node.has_method("run"):
		_active_skin_node.call("run")
		return
	if normalized == "walk" and _active_skin_node.has_method("walk"):
		_active_skin_node.call("walk")
		return
	if _active_skin_node.has_method("move"):
		_active_skin_node.call("move")
		return
	if _active_skin_node.has_method("play_action") and bool(_active_skin_node.call("play_action", normalized)):
		return
	if _active_skin_node.has_method("idle"):
		_active_skin_node.call("idle")


func _animate_remote_skin_from_network_motion(delta: float) -> void:
	if not _active_skin_node or not is_instance_valid(_active_skin_node):
		return
	if delta <= 0.0:
		return
	if _skin_performance_camera_active:
		return
	if not _remote_visual_position_initialized:
		_remote_visual_position = global_position
		_remote_visual_position_initialized = true
		_remote_motion_sampler.reset(global_position, true)
		_play_skin_action("idle")
		return
	if _apply_synced_network_visual_state(delta):
		return

	var sample: Dictionary = _remote_motion_velocity_sample(delta)
	if not bool(sample.get("ready", false)):
		return
	# Low-pass the noisy per-sample network velocity so the action thresholds below
	# (jump / fall / run / walk / idle) stop flickering, which reads as choppy animation.
	var raw_visual_velocity: Vector3 = sample.get("velocity", Vector3.ZERO)
	var velocity_smooth_rate: float = RemoteVisualPolicy.velocity_smooth_rate(
		NetworkTime.remote_rtt, NetworkTimeSynchronizer.rtt_jitter)
	_remote_visual_velocity_smoothed = _remote_visual_velocity_smoothed.lerp(raw_visual_velocity, clampf(delta * velocity_smooth_rate, 0.0, 1.0))
	var visual_velocity: Vector3 = _remote_visual_velocity_smoothed
	var horizontal_velocity := Vector3(visual_velocity.x, 0.0, visual_velocity.z)
	var horizontal_speed := horizontal_velocity.length()
	if visual_velocity.y > REMOTE_VERTICAL_ACTION_SPEED:
		_play_skin_action("jump")
	elif visual_velocity.y < -REMOTE_VERTICAL_ACTION_SPEED:
		_play_skin_action("fall")
	elif horizontal_speed > REMOTE_MOVE_SPEED_THRESHOLD:
		_remote_visual_move_hold = RemoteVisualPolicy.move_hold_sec(
			NetworkTime.remote_rtt, NetworkTimeSynchronizer.rtt_jitter)
		_current_speed = horizontal_speed
		_apply_body_rotation(horizontal_velocity)
		if horizontal_speed >= REMOTE_RUN_SPEED_THRESHOLD:
			_play_remote_skin_locomotion("run", REMOTE_RUN_BLEND)
		else:
			_play_remote_skin_locomotion("move", REMOTE_WALK_BLEND)
	elif _remote_visual_move_hold > 0.0:
		_remote_visual_move_hold = maxf(0.0, _remote_visual_move_hold - delta)
		_play_remote_skin_locomotion("move", REMOTE_WALK_BLEND)
	else:
		_current_speed = 0.0
		_play_skin_action("idle")


func set_mesh_texture(mesh_instance: MeshInstance3D, texture: Texture2D) -> void:
	if mesh_instance:
		var material := _ensure_unique_standard_material(mesh_instance, 0)
		material.albedo_texture = texture
		material.albedo_color = Color.WHITE

# Inventory Network Functions - Server authoritative, client-specific
@rpc("any_peer", "call_local", "reliable")
func request_inventory_sync():
	if _should_log_runtime_debug():
		print("Debug: request_inventory_sync called on player ", name, " (authority: ", get_multiplayer_authority(), ") by client ", multiplayer.get_remote_sender_id())

	if not _is_runtime_multiplayer_server():
		return

	var requesting_client = multiplayer.get_remote_sender_id()
	if requesting_client != get_multiplayer_authority():
		push_warning("Client " + str(requesting_client) + " tried to request inventory for player " + str(get_multiplayer_authority()))
		return

	if player_inventory:
		sync_inventory_to_owner.rpc_id(requesting_client, player_inventory.to_dict())

@rpc("any_peer", "call_local", "reliable")
func sync_inventory_to_owner(inventory_data: Dictionary):
	var sender_id: int = multiplayer.get_remote_sender_id() if _has_runtime_multiplayer_peer() else 1
	if _should_log_runtime_debug():
		print("Debug: sync_inventory_to_owner called on player ", name, " (authority: ", get_multiplayer_authority(), ") - local peer id: ", _local_peer_id(), " from: ", sender_id)

	if sender_id != 1:
		return

	if not _is_local_authority():
		return

	if not player_inventory:
		player_inventory = PlayerInventory.new()
	player_inventory.from_dict(inventory_data)

	var level_scene = get_tree().get_current_scene()
	if level_scene:
		if _is_local_authority() or get_multiplayer_authority() == _local_peer_id():
			if _should_log_runtime_debug():
				print("Debug: This is the local player, updating UI")
			if level_scene.has_method("update_local_inventory_display"):
				level_scene.update_local_inventory_display()
			if level_scene.has_node("InventoryUI"):
				var inventory_ui = level_scene.get_node("InventoryUI")
				if inventory_ui.visible and inventory_ui.has_method("refresh_display"):
					if _should_log_runtime_debug():
						print("Debug: Calling refresh_display directly on InventoryUI")
					inventory_ui.refresh_display()
		else:
			if _should_log_runtime_debug():
				print("Debug: Not the local player, skipping UI update")

@rpc("any_peer", "call_local", "reliable")
func request_move_item(from_slot: int, to_slot: int, quantity: int = -1):
	if _should_log_runtime_debug():
		print("Debug: request_move_item called - from:", from_slot, " to:", to_slot, " on player ", name, " (authority: ", get_multiplayer_authority(), ") by client ", multiplayer.get_remote_sender_id())

	if not _is_runtime_multiplayer_server():
		return

	var requesting_client = multiplayer.get_remote_sender_id()
	if requesting_client != get_multiplayer_authority():
		push_warning("Client " + str(requesting_client) + " tried to modify inventory for player " + str(get_multiplayer_authority()))
		return

	if not player_inventory:
		return

	if from_slot < 0 or from_slot >= PlayerInventory.INVENTORY_SIZE or to_slot < 0 or to_slot >= PlayerInventory.INVENTORY_SIZE:
		push_warning("Invalid slot indices: from=" + str(from_slot) + " to=" + str(to_slot))
		return

	var success = false
	if quantity == -1:
		success = player_inventory.move_item(from_slot, to_slot)
		if not success:
			success = player_inventory.swap_items(from_slot, to_slot)
			if _should_log_runtime_debug():
				print("Debug: Swapped items between slots ", from_slot, " and ", to_slot)
		elif _should_log_runtime_debug():
			print("Debug: Moved item from slot ", from_slot, " to ", to_slot)
	else:
		success = player_inventory.move_item(from_slot, to_slot, quantity)
		if _should_log_runtime_debug():
			print("Debug: Moved ", quantity, " items from slot ", from_slot, " to ", to_slot)

	if success:
		if _should_log_runtime_debug():
			print("Debug: Move successful, syncing inventory to owner ", get_multiplayer_authority())
		var owner_id = get_multiplayer_authority()
		if owner_id != 1:
			sync_inventory_to_owner.rpc_id(owner_id, player_inventory.to_dict())
		else:
			var level_scene = get_tree().get_current_scene()
			if level_scene and level_scene.has_method("update_local_inventory_display"):
				level_scene.update_local_inventory_display()
	elif _should_log_runtime_debug():
		print("Debug: Move/swap failed")

@rpc("any_peer", "call_local", "reliable")
func request_add_item(item_id: String, quantity: int = 1):
	if _should_log_runtime_debug():
		print("Debug: request_add_item called on player ", name, " (authority: ", get_multiplayer_authority(), ") by client ", multiplayer.get_remote_sender_id())

	if not _is_runtime_multiplayer_server():
		return

	var requesting_client = multiplayer.get_remote_sender_id()
	if requesting_client != get_multiplayer_authority() and requesting_client != 1:
		push_warning("Client " + str(requesting_client) + " tried to add items to player " + str(get_multiplayer_authority()))
		return

	if not player_inventory:
		return

	if quantity <= 0:
		push_warning("Invalid quantity: " + str(quantity))
		return

	var item = ItemDatabase.get_item(item_id)
	if not item:
		push_warning("Item not found: " + item_id)
		return

	var remaining = player_inventory.add_item(item, quantity)
	var added = quantity - remaining
	if _should_log_runtime_debug():
		print("Debug: Added ", added, " ", item_id, " to inventory (", remaining, " remaining)")

	if added > 0:
		var owner_id = get_multiplayer_authority()
		if _should_log_runtime_debug():
			print("Debug: Syncing inventory to owner ", owner_id)
		if owner_id != 1:
			sync_inventory_to_owner.rpc_id(owner_id, player_inventory.to_dict())
		else:
			var level_scene = get_tree().get_current_scene()
			if level_scene and level_scene.has_method("update_local_inventory_display"):
				level_scene.update_local_inventory_display()

@rpc("any_peer", "call_local", "reliable")
func request_remove_item(item_id: String, quantity: int = 1):
	if _should_log_runtime_debug():
		print("Debug: request_remove_item called on player ", name, " (authority: ", get_multiplayer_authority(), ") by client ", multiplayer.get_remote_sender_id())

	if not _is_runtime_multiplayer_server():
		return

	var requesting_client = multiplayer.get_remote_sender_id()
	if requesting_client != get_multiplayer_authority():
		push_warning("Client " + str(requesting_client) + " tried to remove items from player " + str(get_multiplayer_authority()))
		return

	if not player_inventory:
		return

	if quantity <= 0:
		push_warning("Invalid quantity: " + str(quantity))
		return

	var removed = player_inventory.remove_item(item_id, quantity)

	if removed > 0:
		var owner_id = get_multiplayer_authority()
		if owner_id != 1:
			sync_inventory_to_owner.rpc_id(owner_id, player_inventory.to_dict())

func get_inventory() -> PlayerInventory:
	return player_inventory

func get_health() -> float:
	return health


func get_max_health() -> float:
	return max_health


# Display name shown on the overhead Label3D; used by the bottom-left health HUD.
func get_display_name() -> String:
	if nickname and is_instance_valid(nickname) and not nickname.text.is_empty():
		return nickname.text
	return str(name)


# =============================================================================
# Screen-space overhead nameplate (WorldNameplateHUD) hooks
# =============================================================================
var _screen_nameplate_active := false


# Toggle whether the world Label3D name is suppressed in favour of the 2D HUD.
func set_screen_nameplate_active(active: bool) -> void:
	if _screen_nameplate_active == active:
		return
	_screen_nameplate_active = active
	_refresh_nickname_visibility()


# World-space anchor the 2D nameplate projects from (sits above the head).
func get_overhead_anchor_position() -> Vector3:
	if nickname and is_instance_valid(nickname):
		return nickname.global_position
	return global_position + Vector3(0.0, 2.4, 0.0)


# Reuse the existing team / stalker-stealth / bounty visibility rules so the 2D
# nameplate hides exactly what the world Label3D used to.
func nameplate_should_show_for_local_viewer() -> bool:
	return _should_show_nickname_for_local_viewer()


# Same side as the local viewer? Hunters team vs props (Chameleon + Stalker).
func is_ally_of_local_viewer() -> bool:
	var viewer_role := _get_local_viewer_role()
	var viewer_hunter := viewer_role == Network.Role.HUNTER
	var self_hunter := role == Network.Role.HUNTER
	var viewer_prop := viewer_role == Network.Role.CHAMELEON or viewer_role == Network.Role.STALKER
	var self_prop := role == Network.Role.CHAMELEON or role == Network.Role.STALKER
	return (viewer_hunter and self_hunter) or (viewer_prop and self_prop)


# Server-only: tell the attacker's client to briefly reveal this victim's HP bar
# (enemy bars are normally hidden). Skips self-damage and non-peer sources.
func _server_report_damage_to_attacker(attacker_id: int) -> void:
	if attacker_id <= 1:
		return
	if attacker_id == int(str(name)):
		return
	_reveal_damaged_enemy_bar.rpc_id(attacker_id, int(str(name)), health, max_health)


@rpc("any_peer", "reliable")
func _reveal_damaged_enemy_bar(victim_peer: int, victim_health: float, victim_max: float) -> void:
	# Only trust the server; this is a UI-only hint on the attacker's client.
	if multiplayer.get_remote_sender_id() != 1:
		return
	var ratio := victim_health / maxf(victim_max, 1.0)
	get_tree().call_group("world_nameplate_hud", "register_enemy_reveal", victim_peer, ratio)


# =============================================================================
# Debug console hooks (DebugConsole). Gated to debug builds so exported release
# clients can't be poked by these RPCs.
# =============================================================================
func debug_tools_enabled() -> bool:
	return OS.is_debug_build()


# Set health to a fraction (0..1) of max — used by heal / sethp / kill. Routed
# to the authoritative server like real damage so the HUD path stays identical.
@rpc("any_peer", "call_local", "reliable")
func debug_set_health_fraction(fraction: float) -> void:
	# Apply only on the authoritative side (the server, or an offline session
	# where there is no peer). Intentionally NOT gated to debug builds so it also
	# works against a release dedicated server while testing — the DebugConsole
	# is the access gate.
	if multiplayer.has_multiplayer_peer() and not _is_runtime_multiplayer_server():
		return
	var target := clampf(fraction, 0.0, 1.0) * max_health
	if target <= 0.0:
		_is_dead = false
		take_damage(max_health + 1.0, 0)
		return
	if _is_dead:
		apply_network_alive_state(true)
	health = target
	if multiplayer.has_multiplayer_peer():
		_sync_health.rpc(health)
	else:
		health_changed.emit(health)


# Toggle the bounty marker across all peers so the nameplate bounty icon can be
# verified without the full bounty minigame.
@rpc("any_peer", "call_local", "reliable")
func debug_set_bounty(marked: bool) -> void:
	set_party_monster_bounty_marked(marked)


# Role drives the hitpoint pool: Hunter is tankier than the props it chases.
func _max_health_for_role() -> float:
	match role:
		Network.Role.HUNTER:
			return HUNTER_MAX_HEALTH
		Network.Role.CHAMELEON, Network.Role.STALKER:
			return PROP_MAX_HEALTH
		_:
			return DEFAULT_MAX_HEALTH


# Recompute max_health after a role assignment. The authoritative server refills
# to the new max (role is assigned at match start / draft) and broadcasts it;
# remote peers only adopt the new ceiling and wait for the server's _sync_health.
func _apply_role_max_health() -> void:
	# Role is (re)assigned at match start — reset the per-match performance budget.
	_skin_performance_use_count = 0
	var previous_max := max_health
	max_health = _max_health_for_role()
	if max_health == previous_max:
		max_health_changed.emit(max_health)
		return
	if _is_runtime_multiplayer_server():
		health = max_health
		_sync_health.rpc(health)
	elif health <= 0.0 or health > max_health or is_equal_approx(health, previous_max):
		# Keep the local HUD coherent until the server's authoritative value lands.
		health = max_health
		health_changed.emit(health)
	max_health_changed.emit(max_health)


func is_dead() -> bool:
	return _is_dead

func _add_starting_items():
	if not player_inventory:
		return

	var sword = ItemDatabase.get_item("iron_sword")
	var potion = ItemDatabase.get_item("health_potion")

	if sword:
		player_inventory.add_item(sword, 1)
	if potion:
		player_inventory.add_item(potion, 3)


# =============================================================================
# 鎴樻枟绯荤粺(琚?WeaponSystem 璋冪敤)
# =============================================================================

# 鏈嶅姟鍣ㄤ晶:鐜╁鍙楀埌浼ゅ
@rpc("any_peer", "call_local", "reliable")
func take_damage(amount: float, attacker_id: int, is_headshot: bool = false):
	if not _is_runtime_multiplayer_server():
		return
	if _is_dead or health <= 0.0:
		return
	if _card_damage_immunity_remaining > 0.0 or _card_hunter_skill_immunity_remaining > 0.0:
		_card_feedback_to_owner("IMMUNE", Color(0.62, 1.0, 0.74, 1.0), 0.65)
		return

	var player_id := int(name)
	var projected_health := health - amount
	if _is_prop_role() and projected_health <= 5.0 and Network.server_try_consume_reactive_card(player_id, "prop_emergency_conceal"):
		health = maxf(health, max_health * CARD_RESCUE_HEALTH_RATIO)
		_sync_health.rpc(health)
		return

	if _should_log_runtime_debug():
		print("[Combat] Player ", name, " took ", amount, "% damage from ",
			attacker_id, " (headshot=", is_headshot, ")")

	health = max(0.0, health - amount)
	_server_report_damage_to_attacker(attacker_id)

	if health <= 0.0:
		_server_die(attacker_id)
	else:
		_play_skin_reaction("get_hit")
		_sync_health.rpc(health)


func _server_die(killer_id: int) -> void:
	if not _is_runtime_multiplayer_server():
		return
	if _is_dead:
		return
	if _is_prop_role() and Network.server_try_consume_reactive_card(int(name), "prop_revival"):
		if _should_log_runtime_debug():
			print("[Combat] Player ", name, " consumed Revival Card after lethal hit by ", killer_id)
		_is_dead = true
		health = 0.0
		_sync_health.rpc(health)
		_broadcast_death.rpc(killer_id)
		if Network.players.has(int(name)):
			Network.server_set_player_alive(int(name), false)
		_server_revive_from_card_after_delay()
		return
	if _should_log_runtime_debug():
		print("[Combat] Player ", name, " killed by ", killer_id)

	_is_dead = true
	health = 0.0
	_sync_health.rpc(health)
	_broadcast_death.rpc(killer_id)
	if Network.players.has(int(name)):
		Network.server_set_player_alive(int(name), false)


func _server_revive_from_card_after_delay() -> void:
	await get_tree().create_timer(5.0).timeout
	if not is_instance_valid(self):
		return
	_is_dead = false
	_death_effect_played = false
	_prop_death_visual_hidden = false
	_clear_death_dissolve_visual()
	_exit_dead_free_spectator()
	health = max_health * CARD_RESCUE_HEALTH_RATIO
	set_global_position_immediate(_card_find_respawn_outside_hunter_view())
	velocity = Vector3.ZERO
	_set_character_visual_visible(true)
	clear_prop_disguise()
	_sync_health.rpc(health)
	if Network.players.has(int(name)):
		Network.server_set_player_alive(int(name), true)
	_card_feedback_to_owner("REVIVED", Color(0.62, 1.0, 0.74, 1.0), 1.0)


func _card_find_respawn_outside_hunter_view() -> Vector3:
	for attempt in range(12):
		var angle := randf() * TAU
		var distance := randf_range(28.0, 48.0)
		var candidate := _card_grounded_position(Vector3(cos(angle) * distance, 0.0, sin(angle) * distance))
		var too_close := false
		for node in get_tree().get_nodes_in_group("players"):
			if not node is Character:
				continue
			var hunter := node as Character
			if hunter.is_hunter() and hunter.global_position.distance_to(candidate) < 18.0:
				too_close = true
				break
		if not too_close:
			return candidate
	return _card_grounded_position(global_position + Vector3(randf_range(-24.0, 24.0), 0.0, randf_range(-24.0, 24.0)))


@rpc("any_peer", "call_local", "reliable")
func _broadcast_death(killer_id: int):
	if not _is_authoritative_state_rpc_sender():
		return
	if _death_effect_played:
		return
	_death_effect_played = true
	_is_dead = true
	health = 0.0
	if _should_log_runtime_debug():
		print("[Combat] ", name, " was killed by ", killer_id)
	_finish_party_monster_trip_lock()
	_play_skin_reaction("die")
	_begin_dead_observer_state()
	var death_position := global_position
	if _is_prop_role():
		_spawn_prop_death_smoke(_get_prop_death_effect_position())
		_spawn_prop_tombstone(death_position)
		_play_prop_death_vanish()
	else:
		_play_character_death_vanish()
	# TODO: 瑙﹀彂姝讳骸 UI


@rpc("any_peer", "call_local", "reliable")
func _sync_health(new_health: float):
	if not _is_authoritative_state_rpc_sender():
		return
	if _is_dead and new_health > 0.0 and not _is_network_marked_alive():
		health = 0.0
		health_changed.emit(health)
		return
	var previous_health := health
	health = new_health
	if health > 0.0 and previous_health > health:
		_play_skin_reaction("get_hit")
	if health <= 0.0:
		_is_dead = true
		_begin_dead_observer_state()
	if health > 0.0 and _prop_death_visual_hidden:
		_prop_death_visual_hidden = false
		_set_character_visual_visible(true)
	health_changed.emit(health)


func _is_authoritative_state_rpc_sender() -> bool:
	var sender_id := multiplayer.get_remote_sender_id()
	return sender_id == 0 or sender_id == 1


func _is_network_marked_alive() -> bool:
	var player_id := int(name)
	if Network.players.has(player_id):
		return bool(Network.players[player_id].get("alive", true))
	return true


func _is_prop_role() -> bool:
	return role == Network.Role.CHAMELEON or role == Network.Role.STALKER


func apply_network_alive_state(alive: bool) -> void:
	if alive:
		_is_dead = false
		_death_effect_played = false
		_prop_death_visual_hidden = false
		_clear_death_dissolve_visual()
		_exit_dead_free_spectator()
		if health <= 0.0:
			health = max_health
			health_changed.emit(health)
		if not _is_prop_disguised:
			_set_character_visual_visible(true)
		return
	_is_dead = true
	health = 0.0
	health_changed.emit(health)
	_begin_dead_observer_state()
	if not _prop_death_visual_hidden:
		if _is_prop_role():
			_play_prop_death_vanish()
		else:
			_play_character_death_vanish()


func _begin_dead_observer_state() -> void:
	_set_dead_collision_enabled(false)
	_hide_dead_tool_visuals()
	velocity = Vector3.ZERO
	_current_speed = 0.0
	if _is_local_authority():
		_ensure_dead_free_spectator()


func _play_character_death_vanish() -> void:
	_clear_hunter_prop_sense_feedback()
	_clear_party_monster_bounty_visuals()
	_spawn_death_dissolve_visual()
	_set_character_visual_visible(false)
	_prop_death_visual_hidden = true
	_set_dead_collision_enabled(false)


func _play_prop_death_vanish() -> void:
	_clear_hunter_prop_sense_feedback()
	_clear_party_monster_bounty_visuals()
	if _prop_disguise_tween and _prop_disguise_tween.is_valid():
		_prop_disguise_tween.kill()
	_spawn_death_dissolve_visual()
	_clear_prop_disguise_node()
	_set_character_visual_visible(false)
	_prop_death_visual_hidden = true
	_is_prop_disguised = false
	_current_disguise_name = ""
	_prop_disguise_is_q_scene_replica = false
	_prop_disguise_base_position = Vector3.ZERO
	_prop_disguise_height_offset = 0.0
	_restore_default_collision_shape()
	_set_dead_collision_enabled(false)


func _clear_dead_prop_disguise_after_vanish() -> void:
	_play_prop_death_vanish()


func _spawn_death_dissolve_visual() -> void:
	var source: Node3D = _get_death_dissolve_source()
	if source == null:
		return
	_clear_death_dissolve_visual()
	var parent: Node = get_tree().get_current_scene() if get_tree() else null
	if parent == null:
		parent = get_parent()
	if parent == null:
		return
	var clone := source.duplicate(Node.DUPLICATE_USE_INSTANTIATION) as Node3D
	if clone == null:
		return
	clone.name = "DeathDissolveVisual"
	clone.top_level = true
	parent.add_child(clone)
	clone.global_transform = source.global_transform
	_set_dissolve_visual_runtime_disabled(clone)
	_set_dissolve_visual_visible(clone)
	_apply_death_dissolve_visual_render_policy(clone)
	_disable_prop_collisions(clone)
	var dissolve_material: ShaderMaterial = _make_death_dissolve_material()
	var mesh_count: int = _apply_death_dissolve_material(clone, dissolve_material)
	if mesh_count <= 0:
		clone.queue_free()
		return
	_death_dissolve_root = clone
	_death_dissolve_material = dissolve_material
	_death_dissolve_tween = create_tween()
	_death_dissolve_tween.tween_method(_set_death_dissolve_threshold, 0.0, 1.0, DEATH_DISSOLVE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_death_dissolve_tween.tween_callback(_finish_death_dissolve_visual)


func _get_death_dissolve_source() -> Node3D:
	if _is_prop_disguised and _prop_disguise_node and is_instance_valid(_prop_disguise_node):
		return _prop_disguise_node
	if _active_skin_node and is_instance_valid(_active_skin_node):
		return _active_skin_node
	if _robot_visual_root and is_instance_valid(_robot_visual_root):
		return _robot_visual_root
	if _body and is_instance_valid(_body):
		return _body
	return null


func _make_death_dissolve_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.resource_local_to_scene = true
	material.shader = DEATH_DISSOLVE_SHADER
	material.set_shader_parameter("t", 0.0)
	material.set_shader_parameter("albedo_and_emissive_color", Color(1.0, 1.0, 1.0, 1.0))
	material.set_shader_parameter("edge_color", Color(0.62, 1.0, 0.25, 1.0))
	material.set_shader_parameter("noise_scale", DEATH_DISSOLVE_NOISE_SCALE)
	material.set_shader_parameter("edge_width", DEATH_DISSOLVE_EDGE_WIDTH)
	var noise := NoiseTexture2D.new()
	noise.width = 256
	noise.height = 256
	noise.seamless = true
	var fast_noise := FastNoiseLite.new()
	fast_noise.seed = int(Time.get_ticks_usec() % 2147483647)
	fast_noise.frequency = 0.038
	fast_noise.fractal_octaves = 4
	noise.noise = fast_noise
	material.set_shader_parameter("noise_tex", noise)
	return material


func _apply_death_dissolve_material(root: Node3D, material: ShaderMaterial) -> int:
	var meshes: Array[MeshInstance3D] = []
	_find_prop_disguise_mesh_instances(root, meshes)
	for mesh_instance in meshes:
		if not mesh_instance or not is_instance_valid(mesh_instance):
			continue
		mesh_instance.material_override = material
		mesh_instance.visible = true
		_apply_death_dissolve_geometry_policy(mesh_instance)
	return meshes.size()


func _set_dissolve_visual_runtime_disabled(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	node.set_process_input(false)
	node.set_process_unhandled_input(false)
	if node is AnimationPlayer:
		(node as AnimationPlayer).active = false
	elif node is AudioStreamPlayer3D:
		(node as AudioStreamPlayer3D).stop()
	elif node is AudioStreamPlayer2D:
		(node as AudioStreamPlayer2D).stop()
	elif node is AudioStreamPlayer:
		(node as AudioStreamPlayer).stop()
	for child in node.get_children():
		_set_dissolve_visual_runtime_disabled(child)


func _set_dissolve_visual_visible(node: Node) -> void:
	if node is Node3D:
		(node as Node3D).visible = true
	for child in node.get_children():
		_set_dissolve_visual_visible(child)


func _apply_death_dissolve_visual_render_policy(node: Node) -> void:
	if node is GeometryInstance3D:
		_apply_death_dissolve_geometry_policy(node as GeometryInstance3D)
	for child in node.get_children():
		_apply_death_dissolve_visual_render_policy(child)


func _apply_death_dissolve_geometry_policy(instance: GeometryInstance3D) -> void:
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	instance.visibility_range_end = DEATH_DISSOLVE_VISUAL_CULL_RANGE
	instance.visibility_range_end_margin = DEATH_DISSOLVE_VISUAL_CULL_MARGIN
	instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	if instance.lod_bias > RemoteVisualPolicy.DEFAULT_REMOTE_LOD_BIAS:
		instance.lod_bias = RemoteVisualPolicy.DEFAULT_REMOTE_LOD_BIAS


func _set_death_dissolve_threshold(value: float) -> void:
	if _death_dissolve_material and is_instance_valid(_death_dissolve_material):
		_death_dissolve_material.set_shader_parameter("t", value)


func _finish_death_dissolve_visual() -> void:
	if _death_dissolve_root and is_instance_valid(_death_dissolve_root):
		_death_dissolve_root.queue_free()
	_death_dissolve_root = null
	_death_dissolve_tween = null
	_death_dissolve_material = null


func _clear_death_dissolve_visual() -> void:
	if _death_dissolve_tween and _death_dissolve_tween.is_valid():
		_death_dissolve_tween.kill()
	_death_dissolve_tween = null
	if _death_dissolve_root and is_instance_valid(_death_dissolve_root):
		_death_dissolve_root.queue_free()
	_death_dissolve_root = null
	_death_dissolve_material = null


func _get_prop_death_effect_position() -> Vector3:
	if _is_prop_disguised and _prop_disguise_node and is_instance_valid(_prop_disguise_node):
		var bounds := _calculate_node_bounds(_prop_disguise_node)
		if bounds.size != Vector3.ZERO:
			return _prop_disguise_node.global_transform * (bounds.position + bounds.size * 0.5)
	var meshes := _get_stalker_visual_meshes()
	if not meshes.is_empty():
		var bounds := _calculate_meshes_world_bounds(meshes)
		if bounds.size != Vector3.ZERO:
			return bounds.position + bounds.size * 0.5
	return global_position + Vector3.UP * 0.85


func _calculate_meshes_world_bounds(meshes: Array[MeshInstance3D]) -> AABB:
	var has_bounds := false
	var bounds := AABB()
	for mesh_instance in meshes:
		if not mesh_instance or not is_instance_valid(mesh_instance) or not mesh_instance.mesh:
			continue
		var world_bounds := _transform_aabb(mesh_instance.global_transform, mesh_instance.get_aabb())
		if not has_bounds:
			bounds = world_bounds
			has_bounds = true
		else:
			bounds = bounds.merge(world_bounds)
	return bounds if has_bounds else AABB()


func _spawn_prop_death_smoke(position: Vector3) -> void:
	var scene_root := get_tree().get_current_scene() if get_tree() else null
	if not scene_root:
		scene_root = self
	var root := Node3D.new()
	root.name = "PropDeathSmokeRise"
	root.top_level = true
	scene_root.add_child(root)
	root.global_position = position
	var base_material := StandardMaterial3D.new()
	base_material.resource_local_to_scene = true
	base_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	base_material.albedo_color = Color(0.78, 0.80, 0.82, 0.48)
	base_material.emission_enabled = true
	base_material.emission = Color(0.42, 0.48, 0.54, 1.0)
	base_material.emission_energy_multiplier = 0.18
	for i in range(18):
		var puff := MeshInstance3D.new()
		puff.name = "PropDeathSmokePuff"
		var mesh := SphereMesh.new()
		mesh.radius = randf_range(0.055, 0.13)
		mesh.height = mesh.radius * 2.0
		puff.mesh = mesh
		var material := base_material.duplicate() as StandardMaterial3D
		material.albedo_color.a = randf_range(0.32, 0.56)
		puff.material_override = material
		root.add_child(puff)
		var angle := randf() * TAU
		var start_radius := randf_range(0.05, 0.34)
		var start_height := randf_range(-0.36, 0.24)
		puff.position = Vector3(cos(angle) * start_radius, start_height, sin(angle) * start_radius)
		puff.scale = Vector3.ONE * randf_range(0.45, 0.85)
		var drift_angle := angle + randf_range(-0.55, 0.55)
		var drift_radius := randf_range(0.36, 0.92)
		var rise := randf_range(0.82, 1.82)
		var target := Vector3(cos(drift_angle) * drift_radius, start_height + rise, sin(drift_angle) * drift_radius)
		var tween := puff.create_tween()
		tween.parallel().tween_property(puff, "position", target, randf_range(0.82, 1.18)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(puff, "scale", Vector3.ONE * randf_range(1.6, 2.8), randf_range(0.82, 1.18)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(material, "albedo_color:a", 0.0, randf_range(0.72, 1.08)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	var cleanup := root.create_tween()
	cleanup.tween_interval(1.35)
	cleanup.tween_callback(root.queue_free)


func _spawn_prop_tombstone(death_position: Vector3) -> void:
	var scene_root := get_tree().get_current_scene() if get_tree() else null
	if not scene_root:
		scene_root = self
	var tombstone := _instantiate_prop_tombstone()
	tombstone.name = "PropDeathTombstone"
	tombstone.top_level = true
	scene_root.add_child(tombstone)
	_fit_node_to_height(tombstone, PROP_TOMBSTONE_TARGET_HEIGHT)
	var final_position := _resolve_tombstone_ground_position(death_position)
	var apex_position := final_position + Vector3.UP * 0.78
	tombstone.set_meta("death_rpc_synced", true)
	tombstone.set_meta("starts_underground", true)
	tombstone.set_meta("apex_offset", apex_position.y - final_position.y)
	tombstone.global_position = final_position + Vector3.DOWN * 1.35
	var final_scale := tombstone.scale
	tombstone.scale = Vector3(final_scale.x * 0.58, final_scale.y * 0.12, final_scale.z * 0.58)
	var tween := tombstone.create_tween()
	tween.tween_property(tombstone, "global_position", apex_position, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(tombstone, "scale", Vector3(final_scale.x * 0.82, final_scale.y * 1.22, final_scale.z * 0.82), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(tombstone, "scale", Vector3(final_scale.x * 1.10, final_scale.y * 0.82, final_scale.z * 1.10), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(tombstone, "global_position", final_position, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(tombstone, "scale", Vector3(final_scale.x * 1.20, final_scale.y * 0.72, final_scale.z * 1.20), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): _spawn_tombstone_landing_dust(scene_root, final_position))
	tween.tween_property(tombstone, "scale", Vector3(final_scale.x * 0.94, final_scale.y * 1.08, final_scale.z * 0.94), 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(tombstone, "scale", final_scale, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _instantiate_prop_tombstone() -> Node3D:
	var packed := load(PROP_TOMBSTONE_SCENE_PATH)
	var tombstone: Node3D = null
	if packed is PackedScene:
		tombstone = (packed as PackedScene).instantiate() as Node3D
	if not tombstone:
		tombstone = _build_fallback_tombstone()
	return tombstone


func _build_fallback_tombstone() -> Node3D:
	var root := Node3D.new()
	var material := StandardMaterial3D.new()
	material.resource_local_to_scene = true
	material.albedo_color = Color(0.34, 0.36, 0.39, 1.0)
	material.roughness = 0.86
	var stone := MeshInstance3D.new()
	stone.name = "FallbackTombstoneStone"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.72, 1.02, 0.18)
	stone.mesh = mesh
	stone.position.y = 0.51
	stone.material_override = material
	root.add_child(stone)
	var cap := MeshInstance3D.new()
	cap.name = "FallbackTombstoneCap"
	var cap_mesh := SphereMesh.new()
	cap_mesh.radius = 0.36
	cap_mesh.height = 0.36
	cap.mesh = cap_mesh
	cap.position.y = 1.02
	cap.scale = Vector3(1.0, 0.5, 0.25)
	cap.material_override = material
	root.add_child(cap)
	return root


func _resolve_tombstone_ground_position(death_position: Vector3) -> Vector3:
	if not is_inside_tree() or not get_world_3d():
		return death_position
	var query := PhysicsRayQueryParameters3D.create(death_position + Vector3.UP * 2.0, death_position + Vector3.DOWN * 5.0, WORLD_COLLISION_MASK)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return death_position
	return hit.get("position", death_position)


func _fit_node_to_height(node: Node3D, target_height: float) -> void:
	var bounds := _calculate_node_bounds(node)
	if bounds.size.y <= 0.001:
		node.scale = Vector3.ONE * 0.35
		return
	var scale_factor := target_height / bounds.size.y
	node.scale *= scale_factor
	bounds = _calculate_node_bounds(node)
	if bounds.size != Vector3.ZERO:
		node.position.y -= bounds.position.y


func _calculate_node_bounds(node: Node3D) -> AABB:
	var meshes: Array[MeshInstance3D] = []
	_find_prop_disguise_mesh_instances(node, meshes)
	var has_bounds := false
	var bounds := AABB()
	for mesh_instance in meshes:
		if not mesh_instance.mesh:
			continue
		var local_bounds := _transform_aabb(node.global_transform.affine_inverse() * mesh_instance.global_transform, mesh_instance.get_aabb())
		if not has_bounds:
			bounds = local_bounds
			has_bounds = true
		else:
			bounds = bounds.merge(local_bounds)
	return bounds if has_bounds else AABB()


func _spawn_tombstone_landing_dust(parent: Node, position: Vector3) -> void:
	var root := Node3D.new()
	root.name = "PropTombstoneLandingDust"
	root.top_level = true
	parent.add_child(root)
	root.global_position = position
	var dust_material := StandardMaterial3D.new()
	dust_material.resource_local_to_scene = true
	dust_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_material.albedo_color = Color(0.50, 0.43, 0.35, 0.42)
	for i in range(10):
		var mote := MeshInstance3D.new()
		mote.name = "PropTombstoneDustMote"
		var mesh := SphereMesh.new()
		mesh.radius = randf_range(0.035, 0.075)
		mesh.height = mesh.radius * 2.0
		mote.mesh = mesh
		mote.material_override = dust_material
		root.add_child(mote)
		var angle := randf() * TAU
		var drift := Vector3(cos(angle), randf_range(0.18, 0.42), sin(angle)) * randf_range(0.18, 0.46)
		var tween := mote.create_tween()
		tween.parallel().tween_property(mote, "position", drift, 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(mote, "scale", Vector3.ONE * 0.15, 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var cleanup := root.create_tween()
	cleanup.tween_interval(0.85)
	cleanup.tween_callback(root.queue_free)


# 鏈嶅姟鍣ㄤ晶:澶撮儴鍒ゅ畾(绠€鍖?鐢ㄧ鎾炰綅缃?vs 澶撮儴楂樺害)
func is_head_shot() -> bool:
	# 绠€鍖?浠讳綍鍑讳腑澶撮儴楂樺害鐨勫皠绾胯涓虹垎澶?
	# 鐪熷疄瀹炵幇:raycast 鍛戒腑鐐?y 鍧愭爣 vs 瑙掕壊澶撮儴 y 鍧愭爣
	return false  # TODO: 瀹炵幇绮剧‘鐖嗗ご鍒ゅ畾
