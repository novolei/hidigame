extends RefCounted

## Manual recovery from a knockdown (the party_monster trip). After the trip animation the
## player stays down until they press the stand-up key, which stands them up instead of jumping;
## movement stays locked until then. Owner-driven with a safety timeout so nobody is stuck down.
##
## Pure recovery-state policy — the player facade owns the lock, animation and networking and
## just drives this. A dedicated system instead of growing player.gd (CODE_ORGANIZATION_STANDARDS).

const MAX_DOWN_SECONDS := 8.0

var _awaiting := false
var _down_seconds := 0.0


func is_awaiting() -> bool:
	return _awaiting


# Enter "waiting for the player to get up" (called once the trip animation has played out).
func begin() -> void:
	if _awaiting:
		return
	_awaiting = true
	_down_seconds = 0.0


func cancel() -> void:
	_awaiting = false
	_down_seconds = 0.0


# Advance the safety timer; returns true once the OWNER has been down too long (force a recover
# so a dropped stand-up input can never strand a player). Peers wait for the owner's event.
func tick(delta: float, is_owner: bool) -> bool:
	if not _awaiting:
		return false
	_down_seconds += maxf(delta, 0.0)
	return is_owner and _down_seconds >= MAX_DOWN_SECONDS


# Consume a stand-up request; returns true if we were awaiting (so the caller performs the
# stand-up and the input is NOT also treated as a jump).
func consume() -> bool:
	if not _awaiting:
		return false
	_awaiting = false
	_down_seconds = 0.0
	return true
