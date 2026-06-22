# Third-Party Assets

## GDQuest 3D Characters

- Source: https://github.com/gdquest-demos/godot-4-3D-Characters
- Copyright: GDQuest
- Code license: MIT
- Art assets license: CC-BY-NC-SA 4.0
- Imported folders: `addons/gdquest_gdbot`, `addons/gdquest_sophia`, `addons/gdquest_gobot`, `addons/gdquest_round_bat`, `addons/gdquest_bee_bot`, `addons/gdquest_beetle_bot`, `addons/gdquest_models_shared`

The character models and textures are non-commercial assets. They are suitable for prototype/testing use in this project, but should be replaced or separately licensed before any commercial Steam release.

## GDQuest 3D Character Controller Tutorial

- Source path: `H:\Godot source\godot-4-3d-character-controller-tutorial-1.0.0`
- Imported map resources: `level`
- Imported player audio: `assets/audio/player/robot_jump.wav`, `assets/audio/player/robot_land.wav`, `assets/audio/player/robot_step_01.wav` through `robot_step_05.wav`
- License status: no license file was found in the local source package during import.

These assets are currently integrated for prototype/testing use. Confirm the original package license or replace the assets before commercial Steam release.

## Local Unity Asset Migration

- Source paths:
  - `C:\Users\aresr\My project (2)\Assets\Synty`
  - `C:\Users\aresr\Tanks Complete Project`
  - `C:\Users\aresr\My project (2)\Assets\Low Poly Weapons VOL.1`
- Imported project folder: `assets/unity_migrated`
- Runtime catalog integration: selected GLB conversions are referenced by `scripts/unity_asset_catalog.gd`, `scripts/tank_demo_map.gd`, and the hunter weapon scene.
- Conversion tool used locally: Godot FBX2glTF `v0.13.1`

The migration keeps reusable source assets such as FBX models, image textures, fonts, and audio. A source-reference copy of the Tank Complete `Tutorial_Demo` Unity scenes/prefabs is kept under `assets/unity_migrated/tanks_complete/Tutorial_Demo`, but runtime gameplay uses Godot `.glb`, `.tres`, and `.tscn` resources instead of Unity-only files. These local assets should be treated as prototype/testing assets until the original Unity package licenses are confirmed for redistribution and commercial Steam release.
