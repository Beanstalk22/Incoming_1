extends Control

# ==========================================
# 1. VARIABLES
# ==========================================
@onready var map_list: ItemList = $MarginContainer/Panel/MapList
@onready var play: Button = $MarginContainer/BoxContainer/HBoxContainer/play
@onready var edit: Button = $MarginContainer/BoxContainer/HBoxContainer/load
@onready var delete: Button = $MarginContainer/BoxContainer/HBoxContainer/delete

# We'll use this to remember which map the user clicked
var selected_map_index = -1

# NEW: Array to hold the actual map data so we can pass it to the game
var loaded_maps: Array[CustomMapData] = []

# ==========================================
# 2. BUILT-IN FUNCTIONS
# ==========================================
func _ready():
	play.disabled = true
	edit.disabled = true
	delete.disabled = true
	
	# Call the load function when the menu opens
	load_maps_from_folder()

# ==========================================
# 3. CORE LOGIC
# ==========================================
func load_maps_from_folder():
	map_list.clear()
	loaded_maps.clear()
	
	var base_path = "res://Maps/"
	
	# 1. Get a list of all folder names inside res://Maps/
	if not DirAccess.dir_exists_absolute(base_path):
		DirAccess.make_dir_recursive_absolute(base_path)
		return

	var folders = DirAccess.get_directories_at(base_path)
	
	for folder_name in folders:
		
		var map_file_path = base_path.path_join(folder_name).path_join("map_data.tres")
		
		if FileAccess.file_exists(map_file_path):
			var map_resource = ResourceLoader.load(map_file_path) as CustomMapData
			
			if map_resource:
				loaded_maps.append(map_resource)
				
				# Use the map_name from the resource. 
				# If map_name is empty, fallback to the folder name.
				var display_name = map_resource.map_name
				if display_name == "":
					display_name = folder_name
				
				# Add to ItemList and store the path in metadata for easy retrieval
				var idx = map_list.add_item(display_name)
				map_list.set_item_metadata(idx, map_file_path)

	if loaded_maps.is_empty():
		print("No maps found in ", base_path)
# ==========================================
# 4. SIGNAL FUNCTIONS
# ==========================================
func _on_map_list_item_selected(index):
	selected_map_index = index
	play.disabled = false
	edit.disabled = false
	delete.disabled = false


func _on_play_pressed() -> void:
	# 1. ALWAYS check if something is selected first
	if selected_map_index != -1:
		GameManager.current_custom_map = loaded_maps[selected_map_index]
		# 3. NOW change the scene
		get_tree().change_scene_to_file("res://play.tscn")
	else:
		print("No map selected!")


func _on_delete_pressed():
	if selected_map_index != -1:
		# Get the path we stored in metadata
		var map_file_path = map_list.get_item_metadata(selected_map_index)
		var folder_to_delete = map_file_path.get_base_dir() # Gets the folder path
		
		# Remove the folder and its contents
		# Note: DirAccess.remove_absolute only works on empty folders.
		# You might need a helper function to clear the folder first.
		OS.move_to_trash(ProjectSettings.globalize_path(folder_to_delete))
		
		map_list.remove_item(selected_map_index)
		loaded_maps.remove_at(selected_map_index)
		
		selected_map_index = -1
		play.disabled = true
		edit.disabled = true
		delete.disabled = true

func _on_create_pressed() -> void:
	get_tree().change_scene_to_file("res://map_editor.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://m_menu.tscn")

func _on_load_pressed() -> void:
	if selected_map_index != -1:
		# Get the path from metadata
		var map_path = map_list.get_item_metadata(selected_map_index)
		
		# Tell the global script which map we are working on
		MapFiles.current_map_path = map_path
		
		# Go to the editor
		get_tree().change_scene_to_file("res://map_editor.tscn")
