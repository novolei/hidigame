@tool
extends RefCounted

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		var control_root: Control = Control.new()
		control_root.name = "PartyMonsterHuntHUDVisualTest"
		control_root.anchor_right = 1.0
		control_root.anchor_bottom = 1.0
		control_root.offset_right = 1280.0
		control_root.offset_bottom = 720.0
		ctx.set_scene_root(control_root)
		root = control_root
	else:
		ctx.clear_children(root)

	var root_control: Control = root as Control
	if root_control == null:
		ctx.error("Root is not a Control")
		return

	var background: ColorRect = ColorRect.new()
	background.name = "Backdrop"
	background.color = Color(0.025, 0.035, 0.05, 1.0)
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	root_control.add_child(background)
	ctx.own(background)

	var hud_script: Script = load("res://scripts/party_monster_hunt_hud.gd") as Script
	if hud_script == null:
		ctx.error("PartyMonsterHuntHUD script failed to load")
		return
	var hunt_hud: Control = hud_script.new() as Control
	if hunt_hud == null:
		ctx.error("PartyMonsterHuntHUD instance failed to create")
		return
	hunt_hud.name = "MarkedHuntHUD"
	root_control.add_child(hunt_hud)
	hunt_hud.call("set_hunt_state", true, true, "Eyes 02 or Mouth 05", 31.0, 78.0, 0.0, 2, "Eyes 02 / Mouth 05 / Headpiece 16", "Eyes or Mouth")
	_own_raw_subtree(ctx, hunt_hud)
	ctx.log("Saved marked Party Monster hunt HUD visual fixture")
	ctx.mark_modified()


func _own_raw_subtree(ctx, node: Node) -> void:
	ctx.own(node)
	for child: Node in node.get_children():
		_own_raw_subtree(ctx, child)
