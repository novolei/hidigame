extends Control
class_name CountdownRing

## Custom-drawn countdown ring. Replaces TextureProgressBar to avoid the radial
## seam/notch artifact at the fill boundary: a full track arc is always drawn,
## with the remaining-time arc painted clockwise from the top over it.

var progress := 1.0                              # 0..1 remaining fraction
var track_color := Color(1.0, 1.0, 1.0, 0.16)
var fill_color := Color(1.0, 1.0, 1.0, 0.92)
var thickness := 7.0


func configure(new_progress: float, new_fill: Color, new_track: Color, new_thickness: float) -> void:
	progress = clampf(new_progress, 0.0, 1.0)
	fill_color = new_fill
	track_color = new_track
	thickness = new_thickness
	queue_redraw()


func set_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - thickness * 0.5 - 2.0
	if radius <= 1.0:
		return
	draw_arc(center, radius, 0.0, TAU, 96, track_color, thickness, true)
	if progress > 0.001:
		var start := -PI * 0.5                    # 12 o'clock
		var end := start + progress * TAU         # clockwise, depletes toward the top
		draw_arc(center, radius, start, end, 96, fill_color, thickness, true)
