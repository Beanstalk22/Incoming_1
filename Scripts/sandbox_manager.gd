extends Node3D
class_name SandboxManager

@export var camera: Camera3D
@export var placeable_models: Array[PackedScene ] = [preload("res://ammo_box.tscn"), preload("res://gun.tscn")]
@export var placement_container: Node3D # An empty Node3D to hold all spawned objects

var current_model_index: int = 0
var selected_object: Node3D = null

const SAVE_FILE_PATH = "res://Map/sandbox_save.json"

func _unhandled_input(event: InputEvent) -> void:
	# 1. Model Selection (Numbers 1-9 to select models)
	if event is InputEventKey and event.is_pressed():
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var index = event.keycode - KEY_1
			if index < placeable_models.size():
				current_model_index = index
				print("Selected model: ", current_model_index)
				
		# Quick Save/Load binds
		if event.keycode == KEY_F5:
			save_sandbox()
		elif event.keycode == KEY_F6:
			load_sandbox()

	# 2. Placement & Selection (Left Click)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# Don't place/select if we are currently flying around (Right click held)
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			return
			
		perform_raycast()

func perform_raycast():
	var space_state = get_world_3d().direct_space_state
	var mouse_pos = get_viewport().get_mouse_position()
	
	var origin = camera.project_ray_origin(mouse_pos)
	var end = origin + camera.project_ray_normal(mouse_pos) * 1000.0
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var hit_collider = result.collider
		
		# Check if we clicked an existing placed object (assuming they are in a "spawned" group)
		if hit_collider.is_in_group("spawned_objects"):
			select_object(hit_collider)
		else:
			# We clicked the ground/environment, place a new object
			place_object(result.position)

# --- SYSTEM: PLACEMENT & SELECTION ---

func place_object(pos: Vector3):
	if placeable_models.is_empty(): return
	
	var new_object = placeable_models[current_model_index].instantiate()
	placement_container.add_child(new_object)
	new_object.global_position = pos
	
	# Add to a group so we can easily identify them for saving and selection later
	new_object.add_to_group("spawned_objects")
	
	# Store the scene file path inside the object so we know what to spawn when loading
	new_object.set_meta("scene_path", placeable_models[current_model_index].resource_path)

func select_object(obj: Node3D):
	# Deselect previous
	if selected_object:
		# Revert highlight logic here (e.g., standard material)
		pass 
		
	selected_object = obj
	print("Selected: ", obj.name)
	# Apply highlight logic here (e.g., outline shader or emission material)

# --- SYSTEM: SAVE & LOAD ---

func save_sandbox():
	var saved_data = []
	
	for obj in get_tree().get_nodes_in_group("spawned_objects"):
		var obj_data = {
			"scene_path": obj.get_meta("scene_path"),
			"pos_x": obj.global_position.x,
			"pos_y": obj.global_position.y,
			"pos_z": obj.global_position.z,
			"rot_y": obj.rotation.y
		}
		saved_data.append(obj_data)
		
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(saved_data))
	print("Sandbox Saved!")

func load_sandbox():
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		print("No save file found.")
		return
		
	# Clear existing objects first
	for obj in get_tree().get_nodes_in_group("spawned_objects"):
		obj.queue_free()
		
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	var json_string = file.get_as_text()
	var saved_data = JSON.parse_string(json_string)
	
	if typeof(saved_data) == TYPE_ARRAY:
		for item in saved_data:
			var loaded_scene = load(item["scene_path"]) as PackedScene
			if loaded_scene:
				var new_object = loaded_scene.instantiate()
				placement_container.add_child(new_object)
				new_object.global_position = Vector3(item["pos_x"], item["pos_y"], item["pos_z"])
				new_object.rotation.y = item["rot_y"]
				new_object.add_to_group("spawned_objects")
				new_object.set_meta("scene_path", item["scene_path"])
				
	print("Sandbox Loaded!")

# --- SYSTEM: SCENE LOADER ---

func load_base_scene(scene_path: String):
	# This replaces the current base scene
	get_tree().change_scene_to_file(scene_path)
