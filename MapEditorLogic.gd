extends Node3D
class_name MapEditor

enum EditorMode { PLACE, SELECT }

var selection_material: StandardMaterial3D = null
# --- NEW DRAGGING VARIABLES ---
var is_dragging: bool = false
var drag_start_position: Vector3 = Vector3.ZERO

@onready var camera: Camera3D = $Camera3D
@export var placement_mask: int = 1 # Layer for terrain
@export var item_mask: int = 2      # Layer for placed items (ensure your items use this layer!)

var map_data: CustomMapData = CustomMapData.new()
var current_mode: EditorMode = EditorMode.PLACE
var current_item_id: String = ""
var ghost_node: Node3D = null
var undo_redo := UndoRedo.new()

# Selection variables
var selected_node: Node3D = null
var selected_data: PlaceableItemData = null

var items_container: Node3D

func _ready():
	items_container = Node3D.new()
	items_container.name = "Items"
	add_child(items_container)
	
	# Default to placement mode
	select_item_for_placement("ammo_box")

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
		_set_item_highlight(selected_node, false) # TURN HIGHLIGHT OFF
	
	selected_node = null
	selected_data = null

func _physics_process(_delta: float) -> void:
	var space_state = get_world_3d().direct_space_state
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * 2000.0

	# --- PLACEMENT LOGIC ---
	if current_mode == EditorMode.PLACE and is_instance_valid(ghost_node):
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end, placement_mask)
		var hit = space_state.intersect_ray(query)
		
		if hit:
			ghost_node.global_position = hit.position
			ghost_node.visible = true
		else:
			ghost_node.visible = false

	# --- NEW DRAGGING LOGIC ---
	elif current_mode == EditorMode.SELECT and is_dragging and is_instance_valid(selected_node):
		# Raycast against the terrain/placement_mask so it slides along the ground
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end, placement_mask)
		var hit = space_state.intersect_ray(query)
		
		if hit:
			selected_node.global_position = hit.position

func _unhandled_input(event: InputEvent) -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		return
		
	if event is InputEventMouseButton:
		# LEFT CLICK (Press and Release)
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				if current_mode == EditorMode.PLACE:
					if is_instance_valid(ghost_node) and ghost_node.visible:
						confirm_placement()
			
				elif current_mode == EditorMode.SELECT:
					_perform_selection_raycast()
					# If we successfully clicked an item, start dragging it
					if selected_node:
						is_dragging = true
						drag_start_position = selected_node.global_position
						# TURN OFF collision so the raycast passes through to the floor!
						_set_collision_disabled_recursive(selected_node, true)
			else:
				# Mouse button RELEASED
				if current_mode == EditorMode.SELECT and is_dragging:
					is_dragging = false
					
					if is_instance_valid(selected_node):
						# TURN ON collision again now that we dropped it
						_set_collision_disabled_recursive(selected_node, false)
						
						# Only save to Undo/Redo if we actually moved it
						if selected_node.global_position != drag_start_position:
							_commit_item_move()

		# DELETE ITEM (Optional Right Click)
		elif event.button_index == MOUSE_BUTTON_RIGHT and current_mode == EditorMode.SELECT and event.is_pressed():
			pass

		# ROTATION (Works for both ghost and selected item)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.is_pressed():
			_rotate_target(deg_to_rad(15))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.is_pressed():
			_rotate_target(deg_to_rad(-15))
				
	if event is InputEventKey and event.is_pressed():
		# Hotkeys
		if event.keycode == KEY_DELETE:
			delete_selected_item()
		if event.keycode == KEY_S: # Press S to enter Select Mode
			enter_select_mode()
		
		# Undo/Redo/Save
		if event.keycode == KEY_Z and event.ctrl_pressed:
			_on_undo_pressed()
		if event.keycode == KEY_Y and event.ctrl_pressed:
			_on_redo_pressed()

func _perform_selection_raycast():
	var space_state = get_world_3d().direct_space_state
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * 2000.0
	
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end, item_mask)
	var hit = space_state.intersect_ray(query)
	
	if hit:
		var actual_item = _find_root_item_node(hit.collider)
		if actual_item and actual_item.has_meta("map_data_ref"):
			deselect_item() # Clean up old selection
			
			selected_node = actual_item
			selected_data = actual_item.get_meta("map_data_ref")
			
			# TURN HIGHLIGHT ON
			_set_item_highlight(selected_node, true)
			print("Selected: ", selected_data.item_id)
	else:
		deselect_item()

# Helper to find the parent node that contains the metadata
func _find_root_item_node(node: Node) -> Node3D:
	while node != null and node != items_container:
		if node.has_meta("map_data_ref"):
			return node
		node = node.get_parent()
	return null

func _rotate_target(amount: float):
	if current_mode == EditorMode.PLACE and ghost_node:
		ghost_node.rotate_y(amount)
	elif current_mode == EditorMode.SELECT and selected_node:
		# Rotating an existing item via UndoRedo
		var old_rot = selected_node.rotation
		var new_rot = old_rot + Vector3(0, amount, 0)
		
		undo_redo.create_action("Rotate Item")
		undo_redo.add_do_method(_set_item_rotation.bind(selected_node, selected_data, new_rot))
		undo_redo.add_undo_method(_set_item_rotation.bind(selected_node, selected_data, old_rot))
		undo_redo.commit_action()

func _set_item_rotation(node: Node3D, data: PlaceableItemData, rot: Vector3):
	if is_instance_valid(node):
		node.rotation = rot
	data.rotation = rot # Keep resource in sync

func delete_selected_item():
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
		
		# --- FIX: Disable physics if it's the player spawn ---
		if data.item_id == "player_spawn":
			if instance.has_method("set_physics_process"):
				instance.set_physics_process(false) # Stops gravity
			_disable_collisions_recursive(instance) # Stops it from falling through floor

func _add_item_to_map(data: PlaceableItemData):
	if not map_data.placed_items.has(data):
		map_data.placed_items.append(data)
	_spawn_actual_scene(data)

func _remove_item_from_map(data: PlaceableItemData):
	map_data.placed_items.erase(data)
	for child in items_container.get_children():
		if child.has_meta("map_data_ref") and child.get_meta("map_data_ref") == data:
			child.queue_free()
			break

# --- UI Button Hooks ---

func _on_mode_pressed():
	enter_select_mode()

func _on_delete_pressed():
	delete_selected_item()

# ... (Keep your existing Save/Load/Undo/Redo functions) ...

func _disable_collisions_recursive(node: Node) -> void:
	if node is CollisionShape3D or node is CollisionPolygon3D:
		node.disabled = true
	for child in node.get_children():
		_disable_collisions_recursive(child)
		
		
# ... (Keep your variables and _ready function as they are) ...

func _on_undo_pressed() -> void:
	if undo_redo.has_undo():
		undo_redo.undo()
		print("Undone last action: ", undo_redo.get_current_action_name())

func _on_redo_pressed() -> void:
	if undo_redo.has_redo():
		undo_redo.redo()
		print("Redone action: ", undo_redo.get_current_action_name())

func _on_save_pressed() -> void:
	save_dialog.current_file = "new_map.tres"
	if not has_spawn_point():
		push_error("Map Validation Failed: A player spawn point is required!")
		return # Stops the function, preventing the save dialog from opening
	save_dialog.popup_centered()
	
@onready var error_dialog: AcceptDialog = $ErrorDialog
@onready var save_dialog: FileDialog = $FileDialog

# Connect the "file_selected" signal from the FileDialog to this:
	# Now it uses the path YOU picked in the window

func save_map(file_path: String) -> void:
	# 1. Ensure the directory exists so Godot doesn't crash
	var directory = file_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(directory):
		DirAccess.make_dir_recursive_absolute(directory)
		
	# 2. Use ResourceSaver to turn your 'map_data' object into a file
	var err = ResourceSaver.save(map_data, file_path)
	
	if err == OK:
		print("Map successfully saved to: ", file_path)
	else:
		push_error("Failed to save map! Error code: ", err)
		
		
func load_map(file_path: String) -> void:
	if ResourceLoader.exists(file_path):
		var loaded_data = ResourceLoader.load(file_path) as CustomMapData
		if loaded_data:
			map_data = loaded_data
			
			# Clear current visual items so we don't double up
			for child in items_container.get_children():
				child.queue_free()
				
			# Spawn the items from the file
			for item_data in map_data.placed_items:
				_spawn_actual_scene(item_data)
				
			print("Map successfully loaded from: ", file_path)
	else:
		print("No save file found at: ", file_path)
		
		
# --- NEW MOVEMENT HELPERS ---
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
		data.position = pos # Keep resource in sync
	_disable_collisions_recursive(ghost_node)
		
func _set_collision_disabled_recursive(node: Node, is_disabled: bool) -> void:
	if node is CollisionShape3D or node is CollisionPolygon3D:
		node.disabled = is_disabled
	for child in node.get_children():
		_set_collision_disabled_recursive(child, is_disabled)
		
		
func _set_item_highlight(node: Node3D, enabled: bool) -> void:
	if not is_instance_valid(node):
		return
	
	# Find every mesh inside the item (even in sub-folders)
	var meshes = node.find_children("*", "MeshInstance3D", true)
	
	for mesh in meshes:
		if mesh is MeshInstance3D:
			if enabled:
				# Apply our blue glow over the original material
				mesh.material_override = selection_material
			else:
				# Remove the override to show original materials again
				mesh.material_override = null

func _init():
	# Create a glowing, semi-transparent blue material for selection
	selection_material = StandardMaterial3D.new()
	selection_material.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	selection_material.albedo_color = Color(0, 0.5, 1.0, 0.4) # Semi-transparent Blue
	selection_material.emission_enabled = true
	selection_material.emission = Color(0, 0.5, 1.0)
	selection_material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED # Makes it "glow"
func has_spawn_point() -> bool:
	for item in map_data.placed_items:
		# Replace "player_spawn" with the exact ID you use for the spawn point in your ItemRegistry
		if item.item_id == "player_spawn":
			return true
	return false

var path = "res://Maps/"

func _on_file_dialog_file_selected(file_path: String) -> void:
	# 1. Get the name the user typed (e.g., "EpicLevel")
	var world_name = file_path.get_file().get_basename()
	
	# 2. Create the folder first (Minecraft style)
	create_world_folder(world_name)
	
	# 3. Save the actual map data INSIDE that new folder
	# Path: user://Maps/EpicLevel/map_data.tres
	var final_data_path = "res://Maps/".path_join(world_name).path_join("map_data.tres")
	save_map(final_data_path)

	
# Put this in your Map Editor script (where the user types a world name)
func create_world_folder(new_world_name: String):
	var base_path = "res://Maps/"
	var new_world_path = base_path.path_join(new_world_name)
	
	# Create the specific folder for THIS world
	if not DirAccess.dir_exists_absolute(new_world_path):
		DirAccess.make_dir_recursive_absolute(new_world_path)
		
		# Now save a small 'info' file inside so the game knows this folder is a map
		var file = FileAccess.open(new_world_path.path_join("map_data.json"), FileAccess.WRITE)
		file.store_string('{"name": "' + new_world_name + '", "created": "2026"}')
		file.close()
		
		print("World folder created at: ", new_world_path)
