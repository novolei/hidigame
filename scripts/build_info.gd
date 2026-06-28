extends RefCounted
class_name BuildInfo

# Single source of truth for this build's network-compatibility identity.
#
# protocol_version is a CODE constant: it is compiled into the build, so it can
# never drift from the code that actually defines the networked contracts. It is
# the authoritative gate for whether a client and a server may play together.
#
# build_id / content_version are descriptive metadata, optionally stamped into
# res://build_info.json by the release tooling (Pillar C). They are used for
# diagnostics and soft warnings, never for hard gating.
#
# BUMP NETWORK_PROTOCOL_VERSION whenever a networked contract changes in a way
# that makes mismatched client/server builds incompatible, e.g.:
#   - an @rpc method signature or payload shape changes,
#   - the lobby/full-sync/room schema changes,
#   - the rollback / movement / action-bus contract changes.
# The decoration-batch RPC payload change that crashed mismatched clients is
# exactly the kind of change that must bump this number.

const NETWORK_PROTOCOL_VERSION: int = 1

const _BUILD_INFO_PATH: String = "res://build_info.json"

static var _cache: Dictionary = {}
static var _loaded: bool = false


static func protocol_version() -> int:
	return NETWORK_PROTOCOL_VERSION


# True only when a remote peer's advertised protocol matches this build. A remote
# that predates the handshake advertises no protocol; callers pass -1, which is
# correctly treated as incompatible.
static func is_compatible(remote_protocol: int) -> bool:
	return remote_protocol == NETWORK_PROTOCOL_VERSION


static func build_id() -> String:
	_ensure_loaded()
	return str(_cache.get("build_id", "dev-unstamped"))


static func content_version() -> String:
	_ensure_loaded()
	var fallback := str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	return str(_cache.get("content_version", fallback))


# Compact payload exchanged during the multiplayer join handshake.
static func handshake_payload() -> Dictionary:
	return {
		"protocol_version": NETWORK_PROTOCOL_VERSION,
		"build_id": build_id(),
		"content_version": content_version(),
	}


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(_BUILD_INFO_PATH):
		return
	var text: String = FileAccess.get_file_as_string(_BUILD_INFO_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		_cache = parsed
