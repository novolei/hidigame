# Polygon Apocalypse Migration Manifest

Generated from the Unity asset pack under:

- `H:/3D Resource/effect/Party Monster Rumble PBR v1.0/New Unity Project/Assets/PolygonApocalypse`

Godot runtime entrypoints:

- `res://scripts/polygon_apocalypse_map.gd`
- `res://scenes/level/maps/polygon_apocalypse_bunker.tscn`
- `res://scenes/level/maps/polygon_apocalypse_building_interior_dressing.tscn`
- `res://scenes/level/maps/polygon_apocalypse_city_standard.tscn`
- `res://scenes/level/maps/polygon_apocalypse_city_urp.tscn`

Layouts:

- `layouts/building_interior_dressing.json`: 1452 mesh objects, 3 lights
- `layouts/bunker.json`: 266 mesh objects, 26 lights
- `layouts/city_standard.json`: 7883 mesh objects, 2 lights
- `layouts/city_urp.json`: 7882 mesh objects, 1 lights

Referenced source FBX models: 942

Unity `.unity`, `.prefab`, and `.mat` files are not loaded directly by Godot. The layout JSON stores resolved mesh/material GUID references and the Godot map script rebuilds a static scene at runtime.
