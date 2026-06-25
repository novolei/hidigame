# Hovl Projectile Effects

This directory contains a Godot-native visual recreation layer for the Unity
package at `H:\3D Resource\effect\New Unity Project\Assets\Hovl Studio`.

Imported source resources:

- `textures/`: copied from `HSFiles/Textures`
- `models/`: copied from `HSFiles/Models`

Runtime entry point:

- `res://scripts/hovl_projectile_effect.gd`

The script exposes 25 projectile presets matching the Unity `AAA Projectiles
Vol 2/Prefabs/Projectile *.prefab` files. Unity particle systems, custom Hovl
shaders, and Shader Graph behavior cannot be imported directly into Godot, so
the recreation keeps the source prefab names, Hit/Flash pair names, material
reference summaries, main textures, colors, speed hints, and motif-specific
Godot meshes/lights/tweens.

Typical use:

```gdscript
var effect := HovlProjectileEffect.new()
add_child(effect)
effect.configure("projectile_04_fire")
effect.launch(start_position, hit_position)
```
