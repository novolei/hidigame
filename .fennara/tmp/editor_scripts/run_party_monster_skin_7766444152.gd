@tool
extends RefCounted

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		var new_root: Node3D = Node3D.new()
		new_root.name = "PartyMonsterSkin"
		ctx.set_scene_root(new_root)
		root = new_root
		ctx.log("created_root=PartyMonsterSkin")
	root.name = "PartyMonsterSkin"
	var script: Script = load("res://assets/characters/party_monster/party_monster_skin.gd") as Script
	if script == null:
		ctx.error("Party Monster skin script missing")
		return
	root.set_script(script)
	root.set("character_model_id", "party_monster_c01")
	ctx.log("attached_script=res://assets/characters/party_monster/party_monster_skin.gd")
	ctx.mark_modified()
