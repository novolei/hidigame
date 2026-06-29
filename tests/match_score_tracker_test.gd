extends SceneTree
# Headless test for the scoring subsystem (scripts/scoring/*).
# Run: godot --headless tests/match_score_tracker_test.gd

const MatchScoreTrackerScript := preload("res://scripts/scoring/match_score_tracker.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# Roster: two hunters (1, 4) vs one prop chameleon (2), plus prop stalker (3).
	Network.players = {
		1: {"role": Network.Role.HUNTER, "nick": "H1"},
		4: {"role": Network.Role.HUNTER, "nick": "H2"},
		2: {"role": Network.Role.CHAMELEON, "nick": "P1"},
		3: {"role": Network.Role.STALKER, "nick": "P2"},
	}

	var tracker = MatchScoreTrackerScript.new()
	root.add_child(tracker)

	# Cross-team damage scores COMBAT; same-team damage does not.
	tracker.record_damage(1, 2, 50.0)   # hunter -> prop
	tracker.record_damage(4, 2, 30.0)   # hunter -> prop (assist setup)
	tracker.record_damage(3, 2, 99.0)   # prop -> prop: ignored (same team)

	# Hunter 1 kills prop 2; hunter 4 should get the assist.
	tracker.record_kill(1, 2)
	tracker.record_revive(2)
	tracker.record_objective_pickup(2)
	tracker.record_bounty_kill(1)

	var rows := {}
	for row in tracker.snapshot_rows():
		rows[int(row[0])] = row

	# Row layout: [pid, E, A, D, R, COMBAT, SUPPORT, OBJECTIVE]
	_expect(rows.has(1) and rows.has(2) and rows.has(4), "tracked all involved peers")
	_expect(int(rows[1][1]) == 1, "hunter 1 has 1 kill (E)")
	_expect(int(rows[2][3]) == 1, "prop 2 has 1 death (D)")
	_expect(int(rows[4][2]) == 1, "hunter 4 has 1 assist (A)")
	_expect(int(rows[2][4]) == 1, "prop 2 has 1 revive (R)")
	# combat = 50 + KILL_COMBAT_BONUS(150) = 200 for hunter 1
	_expect(int(rows[1][5]) == 200, "hunter 1 combat = damage + kill bonus, got %d" % int(rows[1][5]))
	# hunter 4 combat = 30 (damage only), support = ASSIST_SUPPORT_BONUS(75)
	_expect(int(rows[4][5]) == 30, "hunter 4 combat = 30, got %d" % int(rows[4][5]))
	_expect(int(rows[4][6]) == 75, "hunter 4 support = assist bonus, got %d" % int(rows[4][6]))
	# prop 2 objective = pickup(200) ; bounty kill objective(500) credited to killer 1
	_expect(int(rows[2][7]) == 200, "prop 2 objective = pickup, got %d" % int(rows[2][7]))
	_expect(int(rows[1][7]) == 500, "hunter 1 objective = bounty kill, got %d" % int(rows[1][7]))
	# same-team damage was ignored: prop 3 has no combat row or zero combat
	_expect(not rows.has(3) or int(rows[3][5]) == 0, "same-team damage ignored")

	# reset() clears everything.
	tracker.reset()
	_expect(tracker.snapshot_rows().is_empty(), "reset clears all stats")

	if failures.is_empty():
		print("[MatchScoreTrackerTest] PASS")
		quit(0)
	else:
		for failure in failures:
			push_error("[MatchScoreTrackerTest] " + failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
