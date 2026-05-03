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
	
	# If players create these maps, 'user://' is better because 'res://' is read-only in exported games.
	# For now, we will stick to your res:// path.
	var path = "res://Maps/new_map/"
	var dir = DirAccess.open(path)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			# Look for .tres instead of .tscn because CustomMapData is a Resource
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				
				# Load the resource file into memory
				var full_path = path + file_name
				var map_resource = ResourceLoader.load(full_path) as CustomMapData
				
				# If it successfully loaded as CustomMapData, add it to our list
				if map_resource:
					loaded_maps.append(map_resource)
					
					# Use the exported map_name string you defined in custom_map_data.gd
					map_list.add_item(map_resource.map_name)
					
			file_name = dir.get_next()
	else:
		print("Could not open the Maps directory.")

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
		# Optional: Actually delete the file from the hard drive
		# var file_to_delete = "res://Maps/" + ... 
		# DirAccess.remove_absolute(file_to_delete)
		
		map_list.remove_item(selected_map_index)
		loaded_maps.remove_at(selected_map_index) # Remove from our data array too!
		
		selected_map_index = -1
		play.disabled = true
		edit.disabled = true
		delete.disabled = true

func _on_create_pressed() -> void:
	get_tree().change_scene_to_file("res://map_editor.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://menu.tscn")

func _on_load_pressed() -> void:
	# Later: Pass loaded_maps[selected_map_index] to the map_editor.tscn
	pass
