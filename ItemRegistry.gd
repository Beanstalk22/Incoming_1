extends Node

# The central dictionary mapping IDs to file paths.
# This prevents map files from breaking if you move scenes in the res:// folder.
var _registry: Dictionary = {
	"Lewis_Gun": "res://gun.tscn",
	"ammo_box": "res://ammo_box.tscn",
	"speed_boat": "res://speed_boat.tscn",
	"player_spawn": "res://player_spawn.tscn"
}

# Helper method to get the path safely
func get_scene_path(item_id: String) -> String:
	if _registry.has(item_id):
		return _registry[item_id]
	else:
		push_error("ItemRegistry: No path found for item_id -> " + item_id)
		return ""

# Helper to instantly grab a PackedScene (useful for spawning)
func get_packed_scene(item_id: String) -> PackedScene:
	var path = get_scene_path(item_id)
	if path != "":
		return load(path) as PackedScene
	return null
	
func get_all_ids() -> Array:
	return _registry.keys()
