class_name PlayerMatchStats
extends RefCounted
# =============================================================================
# PlayerMatchStats — pure per-player scoreboard record for one match.
#
# Columns mirror the scoreboard UI:
#   E = kills, A = assists, D = deaths, R = revives, plus the COMBAT / SUPPORT /
#   OBJECTIVE point buckets. Kept as a plain data object (RefCounted) so it carries
#   no scene/network concerns — the server-side MatchScoreTracker owns instances and
#   the HUD consumes packed rows.
# =============================================================================

var kills: int = 0       # E
var assists: int = 0     # A
var deaths: int = 0      # D
var revives: int = 0     # R
var combat: int = 0      # COMBAT points (enemy damage + kill bonuses)
var support: int = 0     # SUPPORT points (assists, support actions)
var objective: int = 0   # OBJECTIVE points (bounties, pickups, capture)


# Compact wire/HUD row: [peer_id, E, A, D, R, COMBAT, SUPPORT, OBJECTIVE].
func to_row(peer_id: int) -> Array:
	return [peer_id, kills, assists, deaths, revives, combat, support, objective]


# Indices into a to_row() array, so producers and consumers agree on the layout.
enum Row { PEER, KILLS, ASSISTS, DEATHS, REVIVES, COMBAT, SUPPORT, OBJECTIVE }
