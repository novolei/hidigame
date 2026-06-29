extends Control
class_name HexBadge

## Flat-top hexagon badge (Fall-Guys "Show Summary" style). Draws an optional outer
## glow rim, a filled hex, and an outline. An icon TextureRect / glyph is parented on
## top by the caller.

var fill_color := Color(0.96, 0.62, 0.18, 1.0)
var border_color := Color(1.0, 1.0, 1.0, 0.9)
var border_width := 3.0
var glow_color := Color(0.0, 0.0, 0.0, 0.0)


func configure(new_fill: Color, new_border: Color, new_border_width: float, new_glow: Color = Color(0.0, 0.0, 0.0, 0.0)) -> void:
	fill_color = new_fill
	border_color = new_border
	border_width = new_border_width
	glow_color = new_glow
	queue_redraw()


func _hex_points(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(6):
		var angle := deg_to_rad(60.0 * float(i))
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x * 0.5, size.y / sqrt(3.0)) - border_width
	if radius <= 1.0:
		return
	# Two faint, progressively larger hexes read as a soft outer halo.
	if glow_color.a > 0.001:
		draw_colored_polygon(_hex_points(center, radius * 1.28), Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * 0.4))
		draw_colored_polygon(_hex_points(center, radius * 1.14), Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * 0.7))
	var points := _hex_points(center, radius)
	draw_colored_polygon(points, fill_color)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, border_color, border_width, true)
