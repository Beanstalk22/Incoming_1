extends Control
func _ready() -> void:
	setup_game_folders()
	
func setup_game_folders():
	var maps_path = "user://Maps/"
	
	# Check if the folder exists
	if not DirAccess.dir_exists_absolute(maps_path):
		# If it doesn't exist, create it!
		var error = DirAccess.make_dir_recursive_absolute(maps_path)
		
		if error == OK:
			print("Successfully created the Maps folder!")
		else:
			print("Something went wrong creating the folder. Error code: ", error)
# --- SCENE PATHS ---
# Edit these strings to match the actual location of your .tscn files
const PLAY = "res://select_map.tscn"
const SETTINGS = "res://scenes/settings_menu.tscn"
const CUSTOM_PATH = "res://scenes/customization_menu.tscn"

# --- BUTTON SIGNALS ---
# To make these work, go to the "Node" tab next to the Inspector 
# and connect the "pressed()" signal of each button to these functions.

func _on_play_pressed() -> void:
	# This skips the setup and jumps straight into the action
	get_tree().change_scene_to_file(PLAY)


func _on_settings_pressed() -> void:
	# Opens your audio, graphics, and keybinding options
	get_tree().change_scene_to_file(SETTINGS)


func _on_customized_pressed() -> void:
	# Goes to the menu where you select AI numbers and Difficulty
	get_tree().change_scene_to_file(CUSTOM_PATH)


func _on_quit_pressed() -> void:
	# Closes the application completely
	get_tree().quit()

# --- OPTIONAL: EXTRA POLISH ---
