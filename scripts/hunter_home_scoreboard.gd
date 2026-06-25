extends Node3D

const TICKER_MESSAGES: Array[String] = [
	"HUNTER HOME LIVE  |  猎人之家现场  |  READY ROOM OPEN",
	"COUNTDOWN SYNCED  |  TEAM SPAWNS LOCKED  |  FIND THE BEST ROUTE",
	"NO OVERLAP SPAWNS  |  KEEP MOVING  |  PREPARE THE HUNT",
]

@export var scroll_speed: float = 18.0

var _elapsed: float = 0.0
var _message_index: int = 0
var _ticker_labels: Array[Label3D] = []
var _status_labels: Array[Label3D] = []


func _ready() -> void:
	_collect_labels(self)
	_update_scoreboard_text()


func _process(delta: float) -> void:
	_elapsed += delta * scroll_speed
	if _elapsed >= 96.0:
		_elapsed = 0.0
		_message_index = (_message_index + 1) % TICKER_MESSAGES.size()
	_update_scoreboard_text()


func _collect_labels(node: Node) -> void:
	for child in node.get_children():
		if child is Label3D:
			var label := child as Label3D
			var label_name := String(label.name)
			if label_name.begins_with("TickerText"):
				_ticker_labels.append(label)
			elif label_name.begins_with("StatusText"):
				_status_labels.append(label)
		_collect_labels(child)


func _update_scoreboard_text() -> void:
	var base_message := TICKER_MESSAGES[_message_index]
	var padded := "        " + base_message + "        "
	var start := int(_elapsed) % padded.length()
	var wrapped := padded.substr(start) + padded.substr(0, start)
	var visible_text := wrapped.substr(0, min(64, wrapped.length()))
	for label in _ticker_labels:
		if label and is_instance_valid(label):
			label.text = visible_text
	for label in _status_labels:
		if label and is_instance_valid(label):
			label.text = "HUNTERS  READY   00 : 03   PROPS  HIDING"
