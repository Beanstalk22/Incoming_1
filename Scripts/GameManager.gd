# GameManager.gd
extends Node

var player: Node3D = null
var current_custom_map: CustomMapData = null
# GameManager.gd (Make sure this is in Project Settings > Autoloads)

signal score_changed(new_score)

var total_score: int = 0

func add_points(amount: int):
	total_score += amount
	score_changed.emit(total_score) # Tell the UI to update
	print("Score: ", total_score)

func start_game(map_data: CustomMapData):
	
	if current_custom_map == null:
		print("No map data found!")
		return

	var player_scene = preload("res://player.tscn")
	# ... (rest of your spawning logic from before)
	
	var spawn_pos = Vector3.ZERO
	
	# 1. Find the spawn coordinates in the saved data
	for item in map_data.placed_items:
		if item.item_id == "player_spawn":
			spawn_pos = item.position
			break
			
	# 2. Spawn the real player at that location
	var player_instance = player_scene.instantiate()
	get_parent().add_child(player_instance) # Add to the world, not the editor
	player_instance.global_position = spawn_pos
	
# Game Rules Storage
#var difficulty: int = 1         # 0 = Easy, 1 = Normal, 2 = Hard
#var friendly_fire: bool = false
#var ai_count: int = 10
