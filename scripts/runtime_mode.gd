class_name RuntimeMode
extends RefCounted


static func is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


static func has_multiplayer_peer(multiplayer_api: MultiplayerAPI) -> bool:
	return multiplayer_api != null and multiplayer_api.multiplayer_peer != null


static func is_multiplayer_server(multiplayer_api: MultiplayerAPI) -> bool:
	return has_multiplayer_peer(multiplayer_api) and multiplayer_api.is_server()


static func is_dedicated_public_server(multiplayer_api: MultiplayerAPI, lobby_config: Dictionary) -> bool:
	return is_headless() and is_multiplayer_server(multiplayer_api) and bool(lobby_config.get("public_server", false))
