class_name MatchScoreTracker
extends Node
# =============================================================================
# MatchScoreTracker — server-authoritative match scoring.
#
# Lives only on the server (added under the level). Gameplay code forwards raw
# events here via the "match_score_tracker" group (record_damage / record_kill /
# record_revive / record_objective_*). The tracker turns them into the per-player
# PlayerMatchStats rows that the level broadcasts to clients for the Tab scoreboard.
#
# Teams: Hunters vs Props (Chameleon + Stalker). Only cross-team combat scores.
# =============================================================================

const PlayerMatchStatsScript := preload("res://scripts/scoring/player_match_stats.gd")

# Tunable scoring weights.
const ASSIST_WINDOW_MSEC := 8000        # recent damage that still counts as an assist on a kill
const KILL_COMBAT_BONUS := 150          # COMBAT awarded per kill (on top of damage)
const ASSIST_SUPPORT_BONUS := 75        # SUPPORT awarded per assist
const SUPPORT_ACTION_BONUS := 50        # SUPPORT for a generic support action (heal/buff/utility)
const OBJECTIVE_PICKUP := 200           # OBJECTIVE for grabbing a scene accessory
const OBJECTIVE_BOUNTY_KILL := 500      # OBJECTIVE for a hunter clearing a bountied prop

var _stats: Dictionary = {}             # peer_id -> PlayerMatchStats
var _recent_damage: Dictionary = {}     # victim_id -> { attacker_id: last_hit_msec }


func _ready() -> void:
	add_to_group("match_score_tracker")


func reset() -> void:
	_stats.clear()
	_recent_damage.clear()


# --- event intake (server) -------------------------------------------------

func record_damage(attacker_id: int, victim_id: int, amount: float) -> void:
	if attacker_id <= 0 or attacker_id == victim_id or amount <= 0.0:
		return
	if not _are_enemies(attacker_id, victim_id):
		return
	_stat(attacker_id).combat += int(round(amount))
	var recent: Dictionary = _recent_damage.get(victim_id, {})
	recent[attacker_id] = Time.get_ticks_msec()
	_recent_damage[victim_id] = recent


func record_kill(killer_id: int, victim_id: int) -> void:
	_stat(victim_id).deaths += 1
	if killer_id > 0 and killer_id != victim_id and _are_enemies(killer_id, victim_id):
		var killer_stats = _stat(killer_id)
		killer_stats.kills += 1
		killer_stats.combat += KILL_COMBAT_BONUS
	_award_assists(killer_id, victim_id)
	_recent_damage.erase(victim_id)


func record_revive(peer_id: int) -> void:
	if peer_id <= 0:
		return
	_stat(peer_id).revives += 1


func record_support(peer_id: int, amount: int = SUPPORT_ACTION_BONUS) -> void:
	if peer_id <= 0:
		return
	_stat(peer_id).support += amount


func record_objective_pickup(peer_id: int) -> void:
	if peer_id <= 0:
		return
	_stat(peer_id).objective += OBJECTIVE_PICKUP


func record_bounty_kill(killer_id: int) -> void:
	if killer_id <= 0:
		return
	_stat(killer_id).objective += OBJECTIVE_BOUNTY_KILL


# Packed rows for the network/HUD: Array of [peer_id, E, A, D, R, COMBAT, SUPPORT, OBJECTIVE].
func snapshot_rows() -> Array:
	var rows: Array = []
	for peer_id in _stats.keys():
		rows.append(_stats[peer_id].to_row(int(peer_id)))
	return rows


# --- internals -------------------------------------------------------------

func _stat(peer_id: int):
	if not _stats.has(peer_id):
		_stats[peer_id] = PlayerMatchStatsScript.new()
	return _stats[peer_id]


func _award_assists(killer_id: int, victim_id: int) -> void:
	var recent: Dictionary = _recent_damage.get(victim_id, {})
	var now := Time.get_ticks_msec()
	for raw_attacker in recent.keys():
		var attacker_id := int(raw_attacker)
		if attacker_id == killer_id or attacker_id == victim_id:
			continue
		if now - int(recent[raw_attacker]) > ASSIST_WINDOW_MSEC:
			continue
		var assist_stats = _stat(attacker_id)
		assist_stats.assists += 1
		assist_stats.support += ASSIST_SUPPORT_BONUS


func _are_enemies(a: int, b: int) -> bool:
	var role_a := _role_of(a)
	var role_b := _role_of(b)
	if role_a == Network.Role.NONE or role_b == Network.Role.NONE:
		return false
	return _is_hunter(role_a) != _is_hunter(role_b)


func _is_hunter(role: int) -> bool:
	return role == Network.Role.HUNTER


func _role_of(peer_id: int) -> int:
	var info: Dictionary = Network.players.get(peer_id, {}) as Dictionary
	return int(info.get("role", Network.Role.NONE))
