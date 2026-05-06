extends Node3D
class_name MapEditor

# --- ENUMS & EXPORTS ---
enum EditorMode { PLACE, SELECT }

@export var placement_mask: int = 1 # Layer for terrain
@export var item_mask: int = 2      # Layer for placed items (ensure your items use this layer!)

# --- ONREADY VARIABLES ---
@onready var world_env: WorldEnvironment = $Environment/WorldEnvironment
@onready var sun: DirectionalLight3D = $Environment/DirectionalLight3D
@onready var camera: Camera3D = $Camera3D
@onready var error_dialog: AcceptDialog = $ErrorDialog

# --- STATE VARIABLES ---
var map_data: CustomMapData = CustomMapData.new()
var current_mode: EditorMode = EditorMode.PLACE
var undo_redo := UndoRedo.new()
var path: String = "res://Maps/"

# --- PLACEMENT & SELECTION VARIABLES ---
var current_item_id: String = ""
var ghost_node: Node3D = null
var selected_node: Node3D = null
var selected_data: PlaceableItemData = null
var selection_material: StandardMaterial3D = null
var items_container: Node3D

var is_dragging: bool = false
var drag_start_position: Vector3 = Vector3.ZERO

# --- UI & DIALOG VARIABLES ---
var exit_dialog: ConfirmationDialog
var name_map_dialog: ConfirmationDialog
var map_name_input: LineEdit
var is_waiting_to_exit: bool = false

# ==========================================
# BUILT-IN FUNCTIONS
# ==========================================

func _init() -> void:
	# Create a glowing, semi-transparent blue material for selection
	selection_material = StandardMaterial3D.new()
	selection_material.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	selection_material.albedo_color = Color(0, 0.5, 1.0, 0.4) # Semi-transparent Blue
	selection_material.emission_enabled = true
	selection_material.emission = Color(0, 0.5, 1.0)
	selection_material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED # Makes it "glow"

func _ready() -> void:
	items_container = Node3D.new()
	items_container.name = "Items"
	add_child(items_container)
	
	# Default to placement mode
	select_item_for_placement("ammo_box")

	# Setup Exit Confirmation Dialog
	exit_dialog = ConfirmationDialog.new()
	exit_dialog.title = "Confirm Exit"
	exit_dialog.dialog_text = "Are you sure you want to exit?"
	exit_dialog.ok_button_text = "Save and Close"
	exit_dialog.cancel_button_text = "Cancel"
	exit_dialog.add_button("Close Without Saving", true, "close_no_save")
	add_child(exit_dialog)
	
	exit_dialog.confirmed.connect(_on_exit_dialog_save_and_close)
	exit_dialog.custom_action.connect(_on_exit_dialog_custom_action)
	
	# Setup Custom "Name Your Map" Dialog
	name_map_dialog = ConfirmationDialog.new()
	name_map_dialog.title = "Name Your Map"
	name_map_dialog.ok_button_text = "Save"
	
	var vbox = VBoxContainer.new()
	map_name_input = LineEdit.new()
	map_name_input.placeholder_text = "Enter map name here..."
	map_name_input.custom_minimum_size = Vector2(250, 0)
	vbox.add_child(map_name_input)
	name_map_dialog.add_child(vbox)
	add_child(name_map_dialog)
	
	name_map_dialog.confirmed.connect(_on_name_map_confirmed)
	name_map_dialog.canceled.connect(func(): is_waiting_to_exit = false)

	if MapFiles.current_map_path != "res://Maps/" and FileAccess.file_exists(MapFiles.current_map_path):
		load_map(MapFiles.current_map_path)
	else:
		map_data = CustomMapData.new()

func _physics_process(_delta: float) -> void:
	var space_state = get_world_3d().direct_space_state
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * 2000.0

	# PLACEMENT LOGIC
	if current_mode == EditorMode.PLACE and is_instance_valid(ghost_node):
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end, placement_mask)
		var hit = space_state.intersect_ray(query)
		
		if hit:
			ghost_node.global_position = hit.position
			ghost_node.visible = true
		else:
			ghost_node.visible = false

	# DRAGGING LOGIC
	elif current_mode == EditorMode.SELECT and is_dragging and is_instance_valid(selected_node):
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end, placement_mask)
		var hit = space_state.intersect_ray(query)
		
		if hit:
			selected_node.global_position = hit.position

func _unhandled_input(event: InputEvent) -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				if current_mode == EditorMode.PLACE:
					if is_instance_valid(ghost_node) and ghost_node.visible:
						confirm_placement()
			
				elif current_mode == EditorMode.SELECT:
					_perform_selection_raycast()
					if selected_node:
						is_dragging = true
						drag_start_position = selected_node.global_position
						_set_collision_disabled_recursive(selected_node, true)
			else:
				if current_mode == EditorMode.SELECT and is_dragging:
					is_dragging = false
					
					if is_instance_valid(selected_node):
						_set_collision_disabled_recursive(selected_node, false)
						if selected_node.global_position != drag_start_position:
							_commit_item_move()

		elif event.button_index == MOUSE_BUTTON_RIGHT and current_mode == EditorMode.SELECT and event.is_pressed():
			pass # Reserved for future delete/context menu

		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.is_pressed():
			_rotate_target(deg_to_rad(15))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.is_pressed():
			_rotate_target(deg_to_rad(-15))
				
	if event is InputEventKey and event.is_pressed():
		if event.keycode == KEY_DELETE:
			delete_selected_item()
		if event.keycode == KEY_S:
			enter_select_mode()
		if event.keycode == KEY_Z and event.ctrl_pressed:
			_on_undo_pressed()
		if event.keycode == KEY_Y and event.ctrl_pressed:
			_on_redo_pressed()

# ==========================================
# EDITOR LOGIC
# ==========================================

func select_item_for_placement(item_id: String) -> void:
	current_mode = EditorMode.PLACE
	current_item_id = item_id
	deselect_item()
	
	if is_instance_valid(ghost_node):
		ghost_node.queue_free()
		
	var scene = ItemRegistry.get_packed_scene(item_id)
	if scene:
		ghost_node = scene.instantiate()
		add_child(ghost_node)
		_disable_collisions_recursive(ghost_node)

func enter_select_mode() -> void:
	current_mode = EditorMode.SELECT
	current_item_id = ""
	if is_instance_valid(ghost_node):
		ghost_node.visible = false

func deselect_item() -> void:
	if is_instance_valid(selected_node):
		_set_item_highlight(selected_node, false)
	
	selected_node = null
	selected_data = null

func _perform_selection_raycast() -> void:
	var space_state = get_world_3d().direct_space_state
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * 2000.0
	
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end, item_mask)
	var hit = space_state.intersect_ray(query)
	
	if hit:
		var actual_item = _find_root_item_node(hit.collider)
		if actual_item and actual_item.has_meta("map_data_ref"):
			deselect_item()
			selected_node = actual_item
			selected_data = actual_item.get_meta("map_data_ref")
			_set_item_highlight(selected_node, true)
			print("Selected: ", selected_data.item_id)
	else:
		deselect_item()

func _find_root_item_node(node: Node) -> Node3D:
	while node != null and node != items_container:
		if node.has_meta("map_data_ref"):
			return node
		node = node.get_parent()
	return null

func _rotate_target(amount: float) -> void:
	if current_mode == EditorMode.PLACE and ghost_node:
		ghost_node.rotate_y(amount)
	elif current_mode == EditorMode.SELECT and selected_node:
		var old_rot = selected_node.rotation
		var new_rot = old_rot + Vector3(0, amount, 0)
		
		undo_redo.create_action("Rotate Item")
		undo_redo.add_do_method(_set_item_rotation.bind(selected_node, selected_data, new_rot))
		undo_redo.add_undo_method(_set_item_rotation.bind(selected_node, selected_data, old_rot))
		undo_redo.commit_action()

func _set_item_rotation(node: Node3D, data: PlaceableItemData, rot: Vector3) -> void:
	if is_instance_valid(node):
		node.rotation = rot
	if data:
		data.rotation = rot

func delete_selected_item() -> void:
	if selected_node and selected_data:
		undo_redo.create_action("Delete Item")
		undo_redo.add_do_method(_remove_item_from_map.bind(selected_data))
		undo_redo.add_undo_method(_add_item_to_map.bind(selected_data))
		undo_redo.commit_action()
		deselect_item()

func confirm_placement() -> void:
	var new_item_data = PlaceableItemData.new()
	new_item_data.item_id = current_item_id
	new_item_data.position = ghost_node.global_position
	new_item_data.rotation = ghost_node.rotation
	
	undo_redo.create_action("Place Item")
	undo_redo.add_do_method(_add_item_to_map.bind(new_item_data))
	undo_redo.add_undo_method(_remove_item_from_map.bind(new_item_data))
	undo_redo.commit_action()

func _spawn_actual_scene(data: PlaceableItemData) -> void:
	var scene = ItemRegistry.get_packed_scene(data.item_id)
	if scene:
		var instance = scene.instantiate()
		items_container.add_child(instance)
		instance.global_position = data.position
		instance.rotation = data.rotation
		instance.set_meta("map_data_ref", data)
		
		if data.item_id == "player_spawn":
			if instance.has_method("set_physics_process"):
				instance.set_physics_process(false)
			_disable_collisions_recursive(instance)

func _add_item_to_map(data: PlaceableItemData) -> void:
	if not map_data.placed_items.has(data):
		map_data.placed_items.append(data)
	_spawn_actual_scene(data)

func _remove_item_from_map(data: PlaceableItemData) -> void:
	map_data.placed_items.erase(data)
	for child in items_container.get_children():
		if child.has_meta("map_data_ref") and child.get_meta("map_data_ref") == data:
			child.queue_free()
			break

func _commit_item_move() -> void:
	var new_pos = selected_node.global_position
	
	undo_redo.create_action("Move Item")
	undo_redo.add_do_method(_set_item_position.bind(selected_node, selected_data, new_pos))
	undo_redo.add_undo_method(_set_item_position.bind(selected_node, selected_data, drag_start_position))
	undo_redo.commit_action()

func _set_item_position(node: Node3D, data: PlaceableItemData, pos: Vector3) -> void:
	if is_instance_valid(node):
		node.global_position = pos
	if data:
		data.position = pos
	if is_instance_valid(ghost_node):
		_disable_collisions_recursive(ghost_node)

func _set_collision_disabled_recursive(node: Node, is_disabled: bool) -> void:
	if node is CollisionShape3D or node is CollisionPolygon3D:
		node.disabled = is_disabled
	for child in node.get_children():
		_set_collision_disabled_recursive(child, is_disabled)

func _disable_collisions_recursive(node: Node) -> void:
	_set_collision_disabled_recursive(node, true)

func _set_item_highlight(node: Node3D, enabled: bool) -> void:
	if not is_instance_valid(node):
		return
	
	var meshes = node.find_children("*", "MeshInstance3D", true)
	for mesh in meshes:
		if mesh is MeshInstance3D:
			if enabled:
				mesh.material_override = selection_material
			else:
				mesh.material_override = null

# ==========================================
# FILE SYSTEM & SAVING
# ==========================================

func has_spawn_point() -> bool:
	for item in map_data.placed_items:
		if item.item_id == "player_spawn":
			return true
	return false

func save_map(file_path: String) -> void:
	map_data.sun_rotation = sun.rotation
	map_data.sun_color = sun.light_color
	map_data.sun_energy = sun.light_energy
	
	var env = world_env.environment
	map_data.fog_enabled = env.volumetric_fog_enabled
	map_data.fog_color = env.volumetric_fog_albedo
	map_data.fog_density = env.volumetric_fog_density
	
	var directory = file_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(directory):
		DirAccess.make_dir_recursive_absolute(directory)
		
	var err = ResourceSaver.save(map_data, file_path)
	
	if err == OK:
		print("Map successfully saved to: ", file_path)
		if is_waiting_to_exit:
			_perform_exit()
	else:
		push_error("Failed to save map! Error code: ", err)
		is_waiting_to_exit = false

func load_map(file_path: String) -> void:
	if ResourceLoader.exists(file_path):
		var loaded_data = ResourceLoader.load(file_path) as CustomMapData
		if loaded_data:
			map_data = loaded_data
			
			for child in items_container.get_children():
				child.queue_free()
				
			for item_data in map_data.placed_items:
				_spawn_actual_scene(item_data)
				
			print("Map successfully loaded from: ", file_path)
	else:
		print("No save file found at: ", file_path)

func create_world_folder(new_world_name: String) -> void:
	var base_path = "res://Maps/"
	var new_world_path = base_path.path_join(new_world_name)
	
	if not DirAccess.dir_exists_absolute(new_world_path):
		DirAccess.make_dir_recursive_absolute(new_world_path)
		
		# FIX: We use the actual variable 'new_world_name' here so the JSON matches the folder
		var file = FileAccess.open(new_world_path.path_join("map_data.json"), FileAccess.WRITE)
		var json_data = {
			"name": new_world_name,
			"created": "2026"
		}
		file.store_string(JSON.stringify(json_data))
		file.close()
		
		print("World folder created at: ", new_world_path)

func get_unique_map_name(base_name: String) -> String:
	var final_name = base_name
	var count = 1
	
	while DirAccess.dir_exists_absolute("res://Maps/".path_join(final_name)):
		final_name = base_name + " (" + str(count) + ")"
		count += 1
		
	return final_name
	
func is_map_name_taken(new_name: String) -> bool:
	var check_path = "res://Maps".path_join(new_name)
	return DirAccess.dir_exists_absolute(check_path)

func refresh_map_list(list_node: ItemList) -> void:
	list_node.clear()
	var dir = DirAccess.open(path)
	
	if dir:
		dir.list_dir_begin()
		var folder_name = dir.get_next()
		
		while folder_name != "":
			if dir.current_is_dir() and not folder_name.begins_with("."):
				list_node.add_item(folder_name)
			folder_name = dir.get_next()
		dir.list_dir_end()
	else:
		print("An error occurred when trying to access the path.")

func _perform_exit() -> void:
	get_tree().change_scene_to_file("res://select_map.tscn")

# ==========================================
# SIGNAL HANDLERS & UI CALLBACKS
# ==========================================

func _on_mode_pressed() -> void:
	enter_select_mode()

func _on_delete_pressed() -> void:
	delete_selected_item()

func _on_undo_pressed() -> void:
	if undo_redo.has_undo():
		undo_redo.undo()
		print("Undone last action: ", undo_redo.get_current_action_name())

func _on_redo_pressed() -> void:
	if undo_redo.has_redo():
		undo_redo.redo()
		print("Redone action: ", undo_redo.get_current_action_name())

func _on_save_pressed() -> void:
	if not has_spawn_point():
		push_error("Map Validation Failed: A player spawn point is required!")
		return
		
	map_name_input.text = ""
	name_map_dialog.popup_centered()

func _on_name_map_confirmed() -> void:
	var user_input = map_name_input.text.strip_edges()
	
	if user_input == "":
		push_error("Map name cannot be empty!")
		is_waiting_to_exit = false
		return
		
	var world_name = get_unique_map_name(user_input)
	
	# --- ADD THIS LINE HERE ---
	# This sets the internal property that your Select Map scene is looking for!
	map_data.map_name = world_name
	# --------------------------

	create_world_folder(world_name)
	
	var final_data_path = "res://Maps/".path_join(world_name).path_join("map_data.tres")
	MapFiles.current_map_path = final_data_path
	save_map(final_data_path)

func _on_create_button_pressed(user_input: String) -> void:
	if is_map_name_taken(user_input):
		push_error("Map already exists! Choose a different name.")
	else:
		create_world_folder(user_input)

func _on_exit_pressed() -> void:
	exit_dialog.popup_centered()

func _on_exit_dialog_save_and_close() -> void:
	is_waiting_to_exit = true
	_on_save_pressed()

func _on_exit_dialog_custom_action(action: StringName) -> void:
	if action == "close_no_save":
		_perform_exit()
