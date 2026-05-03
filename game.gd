# game.gd main game
extends Node3D

# The central dictionary mapping IDs to file paths.
var _registry: Dictionary = {
	"Lewis_Gun": "res://gun.tscn",
	"ammo_box": "res://ammo_box.tscn",
	"speed_boat": "res://speed_boat.tscn",
	"player_spawn": "res://player_spawn.tscn"
	
}

func _ready():
	# As soon as the game scene starts, it looks in the locker
	if GameManager.current_custom_map:
		_build_map(GameManager.current_custom_map)
	else:
		print("No map data found in GameManager!")

func _build_map(data: CustomMapData):
	for item in data.placed_items:
		var scene = get_packed_scene(item.item_id)
		
		if scene:
			var instance = scene.instantiate()
			
			# 1. Add to the tree FIRST so global_position exists
			add_child(instance)
			
			# 2. NOW set the position and rotation
			instance.global_position = item.position
			instance.global_rotation_degrees = item.rotation
			
			# 3. Specific item logic
			if item.item_id == "player_spawn":
				spawn_player(item.position)
			elif item.item_id == "Lewis_Gun" and instance.has_method("set_friendly_fire"):
				instance.set_friendly_fire(GameManager.friendly_fire)


func spawn_player(spawn_position: Vector3):
	var player_scene = load("res://player.tscn")
	var player_instance = player_scene.instantiate()
	
	# Add child first to avoid the "!is_inside_tree()" error
	add_child(player_instance)
	player_instance.global_position = spawn_position

# --- Registry Helpers ---

func get_scene_path(item_id: String) -> String:
	return _registry.get(item_id, "")

func get_packed_scene(item_id: String) -> PackedScene:
	var path = get_scene_path(item_id)
	if path != "":
		return load(path) as PackedScene
	return null
