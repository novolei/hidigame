class_name VegetationBakeData
extends Resource

const BAKE_VERSION: int = 1

@export var bake_version: int = BAKE_VERSION
@export var map_id: String = ""
@export var tier_name: String = ""
@export var profile_id: String = ""
@export var generation_seed: int = 0
@export var source_asset_root: String = ""
@export var total_instance_count: int = 0
@export var grass_instance_count: int = 0
@export var flower_instance_count: int = 0
@export var tree_instance_count: int = 0
@export var grass_chunk_size: float = 16.0
@export var flower_chunk_size: float = 16.0
@export var grass_chunks: Array[Dictionary] = []
@export var flower_chunks: Array[Dictionary] = []
@export var tree_placements: Array[Dictionary] = []


func can_use_for(requested_profile_id: String) -> bool:
	return bake_version == BAKE_VERSION and profile_id == requested_profile_id
