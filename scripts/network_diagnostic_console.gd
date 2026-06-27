extends RefCounted
class_name NetworkDiagnosticConsole

const COMMANDS: PackedStringArray = [
	"net.mode",
	"net.peers",
	"net.rtt",
	"net.noray",
	"net.room",
	"net.sync_budget",
	"net.simulator",
]


static func execute(command_line: String) -> String:
	var trimmed: String = command_line.strip_edges()
	if trimmed.is_empty():
		return ""
	var parts: PackedStringArray = trimmed.split(" ", false)
	var command: String = parts[0].to_lower()
	var args: PackedStringArray = PackedStringArray()
	for index: int in range(1, parts.size()):
		args.append(parts[index])
	match command:
		"help", "?":
			return "commands: " + ", ".join(COMMANDS)
		"net.mode":
			return _format_mode(Network.get_diagnostic_snapshot())
		"net.peers":
			return _format_peers(Network.get_diagnostic_snapshot())
		"net.rtt":
			return _format_rtt(Network.get_diagnostic_snapshot())
		"net.noray":
			return _format_noray(Network.get_diagnostic_snapshot())
		"net.room":
			return _format_room(Network.get_diagnostic_snapshot())
		"net.sync_budget":
			return _format_sync_budget(Network.get_diagnostic_snapshot())
		"net.simulator":
			return _handle_simulator(args)
		_:
			return "unknown command: %s" % command


static func _format_mode(snapshot: Dictionary) -> String:
	var netfox: Dictionary = snapshot.get("netfox", {})
	return "mode=%s role=%s local=%s server=%s peer=%s tick=%s tickrate=%s" % [
		str(snapshot.get("mode", "offline")),
		str(snapshot.get("role", "client")),
		str(snapshot.get("local_peer_id", 1)),
		str(snapshot.get("is_server", false)),
		str(snapshot.get("peer_assigned", false)),
		str(netfox.get("tick", 0)),
		str(netfox.get("tickrate_setting", 0)),
	]


static func _format_peers(snapshot: Dictionary) -> String:
	var peers: Array = snapshot.get("peers", [])
	return "peers=%d players=%d ids=%s" % [
		int(snapshot.get("peer_count", peers.size())),
		int(snapshot.get("players", 0)),
		str(peers),
	]


static func _format_rtt(snapshot: Dictionary) -> String:
	var stats: Dictionary = snapshot.get("rtt", {})
	if stats.is_empty():
		return "rtt=no-enet-peer-stats"
	var lines: Array[String] = []
	for peer_key: Variant in stats.keys():
		var peer_stats: Dictionary = stats.get(peer_key, {})
		lines.append("%s rtt=%.1fms last=%.1fms loss=%.3f throttle=%.2f remote=%s" % [
			str(peer_key),
			float(peer_stats.get("rtt_ms", 0.0)),
			float(peer_stats.get("last_rtt_ms", 0.0)),
			float(peer_stats.get("packet_loss", 0.0)),
			float(peer_stats.get("throttle", 0.0)),
			str(peer_stats.get("remote", "")),
		])
	return " | ".join(lines)


static func _format_noray(snapshot: Dictionary) -> String:
	var noray: Dictionary = snapshot.get("noray", {})
	return "noray mode=%s host=%s:%d local_port=%d connected=%s attempt=%s done=%s error=%d share=%s" % [
		str(noray.get("active_mode", "")),
		str(noray.get("noray_host", "")),
		int(noray.get("noray_port", 0)),
		int(noray.get("local_port", -1)),
		str(noray.get("connected_to_host", false)),
		str(noray.get("client_attempt_mode", "")),
		str(noray.get("client_attempt_done", false)),
		int(noray.get("client_attempt_error", 0)),
		str(noray.get("share_code", "")),
	]


static func _format_room(snapshot: Dictionary) -> String:
	var room: Dictionary = snapshot.get("room", {})
	return "room=%s public=%s lobby=%s id=%s server=%s address=%s private=%s code=%s" % [
		str(room.get("name", "")),
		str(room.get("public_server", false)),
		str(room.get("public_lobby", false)),
		str(room.get("public_room_id", "")),
		str(room.get("public_server_code", "")),
		str(room.get("public_address", "")),
		str(room.get("private_connection_mode", "")),
		str(room.get("private_connection_code", "")),
	]


static func _format_sync_budget(snapshot: Dictionary) -> String:
	var budget: Dictionary = snapshot.get("sync_budget", {})
	var netfox: Dictionary = snapshot.get("netfox", {})
	return "perf=%s events=%s event_kb=%.1f frames=%d slow=%d avg=%.2fms worst=%.2fms netfox_loop=%.2fms rollback=%.2fms props=%s/%s ratio=%.3f" % [
		str(budget.get("perf_enabled", false)),
		str(budget.get("event_summary", "-")),
		float(budget.get("event_kb", 0.0)),
		int(budget.get("frames", 0)),
		int(budget.get("slow_frames", 0)),
		float(budget.get("avg_ms", 0.0)),
		float(budget.get("worst_ms", 0.0)),
		float(netfox.get("network_loop_ms", 0.0)),
		float(netfox.get("rollback_loop_ms", 0.0)),
		str(netfox.get("sent_state_props", 0)),
		str(netfox.get("full_state_props", 0)),
		float(netfox.get("sent_state_ratio", 0.0)),
	]


static func _handle_simulator(args: PackedStringArray) -> String:
	if args.is_empty():
		var snapshot: Dictionary = Network.get_diagnostic_snapshot()
		var simulator: Dictionary = snapshot.get("simulator", {})
		return "simulator enabled=%s host=%s port=%d latency=%dms loss=%.2f%% compression=%s" % [
			str(simulator.get("enabled", false)),
			str(simulator.get("host", "")),
			int(simulator.get("port", 0)),
			int(simulator.get("latency_ms", 0)),
			float(simulator.get("packet_loss_percent", 0.0)),
			str(simulator.get("compression", false)),
		]
	var action: String = args[0].to_lower()
	if action != "on" and action != "off":
		return "usage: net.simulator [on|off] [latency_ms] [packet_loss_percent]"
	var latency_ms: int = int(args[1]) if args.size() >= 2 and args[1].is_valid_int() else -1
	var packet_loss_percent: float = float(args[2]) if args.size() >= 3 and args[2].is_valid_float() else -1.0
	return Network.set_network_simulator_diagnostics_enabled(action == "on", latency_ms, packet_loss_percent)
