extends Node3D
class_name MapEditor

# --- ENUMS & EXPORTS ---
enum EditorMode { PLACE, SELECT, TERRAIN }
enum SculptMode { ADD, SUBTRACT, SMOOTH }

@export var placement_mask: int = 1 
@export var item_mask: int = 2      

# --- ONREADY VARIABLES ---
@onready var world_env: WorldEnvironment = $Environment/WorldEnvironment
@onready var sun: DirectionalLight3D = $Environment/DirectionalLight3D
@onready var camera: Camera3D = $Camera3D
@onready var error_dialog: AcceptDialog = $ErrorDialog
@onready var terrain_settings: HBoxContainer = $CanvasLayer/Control/Control/Terrain_settings
@onready var terrain_mesh_node: MeshInstance3D = $"Terrain/StaticBody3D/1"
@onready var mode_button: Button = $CanvasLayer/Control/modes

# --- STATE VARIABLES ---
var map_data: CustomMapData = CustomMapData.new()
var current_mode: EditorMode = EditorMode.PLACE
var undo_redo := UndoRedo.new()
var path: String = "res://Maps/"

# Terrain Variables
var current_sculpt_mode: SculptMode = SculptMode.ADD
var brush_radius: float = 20.0
var sculpt_strength: float = 4.0
var is_sculpting := false
var active_terrain_vertices: PackedVector3Array
var pre_stroke_vertices: PackedVector3Array # For Undo/Redo

# --- PLACEMENT & SELECTION VARIABLES ---
var current_item_id: String = ""
var ghost_node: Node3D = null
var selected_node: Node3D = null
var selected_data: PlaceableItemData = null
var selection_material: StandardMaterial3D = null
var items_container: Node3D

var is_dragging: bool = false
var drag_start_position: Vector3 = Vector3.ZERO
var latest_terrain_hit: Dictionary = {}

# --- UI & DIALOG VARIABLES ---
var exit_dialog: ConfirmationDialog
var name_map_dialog: ConfirmationDialog
var map_name_input: LineEdit
var is_waiting_to_exit: bool = false

# ==========================================
# BUILT-IN FUNCTIONS
# ==========================================

func _init() -> void:
	selection_material = StandardMaterial3D.new()
	selection_material.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	selection_material.albedo_color = Color(0, 0.5, 1.0, 0.4)
	selection_material.emission_enabled = true
	selection_material.emission = Color(0, 0.5, 1.0)
	selection_material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED

func _ready() -> void:
	terrain_settings.visible = false
	items_container = Node3D.new()
	items_container.name = "Items"
	add_child(items_container)
	
	setup_terrain()
	select_item_for_placement("")
	_setup_dialogs()

	if MapFiles.current_map_path != "res://Maps/" and FileAccess.file_exists(MapFiles.current_map_path):
		load_map(MapFiles.current_map_path)
	else:
		map_data = CustomMapData.new()

func _physics_process(_delta: float) -> void:
	_update_raycast_hit()

	match current_mode:
		EditorMode.PLACE:
			if is_instance_valid(ghost_node):
				if latest_terrain_hit:
					ghost_node.global_position = latest_terrain_hit.position
					ghost_node.visible = true
				else:
					ghost_node.visible = false
					
		EditorMode.SELECT:
			if is_dragging and is_instance_valid(selected_node) and latest_terrain_hit:
				selected_node.global_position = latest_terrain_hit.position
				
		EditorMode.TERRAIN:
			if is_sculpting and latest_terrain_hit:
				_apply_sculpt_stroke(latest_terrain_hit.position)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed():
		_handle_shortcuts(event)
		return

	if event is InputEventMouseButton:
		_handle_camera_wheel(event)
		
		match current_mode:
			EditorMode.PLACE: _handle_place_input(event)
			EditorMode.SELECT: _handle_select_input(event)
			EditorMode.TERRAIN: _handle_terrain_input(event)

# ==========================================
# INPUT DELEGATION
# ==========================================

func _handle_shortcuts(event: InputEventKey) -> void:
	if event.keycode == KEY_DELETE: delete_selected_item()
	if event.keycode == KEY_S: set_editor_mode(EditorMode.SELECT)
	if event.keycode == KEY_Z and event.ctrl_pressed: _on_undo_pressed()
	if event.keycode == KEY_Y and event.ctrl_pressed: _on_redo_pressed()

func _handle_camera_wheel(event: InputEventMouseButton) -> void:
	if not event.is_pressed(): return
	if event.button_index == MOUSE_BUTTON_WHEEL_UP: _rotate_target(deg_to_rad(15))
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: _rotate_target(deg_to_rad(-15))

func _handle_place_input(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		if is_instance_valid(ghost_node) and ghost_node.visible:
			confirm_placement()

func _handle_select_input(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			_perform_selection_raycast()
			if selected_node:
				is_dragging = true
				drag_start_position = selected_node.global_position
				_set_collision_disabled_recursive(selected_node, true)
		else:
			if is_dragging:
				is_dragging = false
				if is_instance_valid(selected_node):
					_set_collision_disabled_recursive(selected_node, false)
					if selected_node.global_position != drag_start_position:
						_commit_item_move()

func _handle_terrain_input(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			_begin_sculpting()
		else:
			_end_sculpting()

# ==========================================
# MODE MANAGEMENT & CLEANUP
# ==========================================

func set_editor_mode(new_mode: EditorMode) -> void:
	_cleanup_current_mode()
	current_mode = new_mode

	match current_mode:
		EditorMode.PLACE:
			mode_button.text = "PLACE MODE"
			_update_ui_layout(false)
			if is_instance_valid(ghost_node): ghost_node.visible = true

		EditorMode.SELECT:
			mode_button.text = "SELECT MODE"
			_update_ui_layout(false)

		EditorMode.TERRAIN:
			mode_button.text = "SCULPT MODE"
			_update_ui_layout(true)

func _cleanup_current_mode() -> void:
	is_dragging = false
	is_sculpting = false
	
	if current_mode == EditorMode.PLACE and is_instance_valid(ghost_node):
		ghost_node.visible = false
		
	if current_mode == EditorMode.SELECT:
		if is_instance_valid(selected_node):
			_set_collision_disabled_recursive(selected_node, false)
		deselect_item()

# ==========================================
# TERRAIN & SCULPTING LOGIC
# ==========================================

func setup_terrain():
	if terrain_mesh_node.mesh is PlaneMesh:
		var array_mesh = ArrayMesh.new()
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, terrain_mesh_node.mesh.get_mesh_arrays())
		terrain_mesh_node.mesh = array_mesh
	
	# Extract base data for internal manipulation
	var arrays = terrain_mesh_node.mesh.surface_get_arrays(0)
	active_terrain_vertices = arrays[Mesh.ARRAY_VERTEX]

func _begin_sculpting() -> void:
	is_sculpting = true
	pre_stroke_vertices = active_terrain_vertices.duplicate()

func _end_sculpting() -> void:
	if not is_sculpting: return
	is_sculpting = false
	
	# Only push to undo/redo if modified
	if active_terrain_vertices != pre_stroke_vertices:
		var post_stroke_vertices = active_terrain_vertices.duplicate()
		undo_redo.create_action("Sculpt Terrain")
		undo_redo.add_do_method(_apply_terrain_data.bind(post_stroke_vertices))
		undo_redo.add_undo_method(_apply_terrain_data.bind(pre_stroke_vertices))
		undo_redo.commit_action()
		
	_update_terrain_collision()

func _apply_sculpt_stroke(hit_point: Vector3):
	var transformed_hit = terrain_mesh_node.to_local(hit_point)
	var modified = false

	for i in range(active_terrain_vertices.size()):
		var vtx = active_terrain_vertices[i]
		var dist = Vector2(vtx.x, vtx.z).distance_to(Vector2(transformed_hit.x, transformed_hit.z))

		if dist < brush_radius:
			var falloff = 1.0 - (dist / brush_radius)
			modified = true

			match current_sculpt_mode:
				SculptMode.ADD: vtx.y += sculpt_strength * falloff
				SculptMode.SUBTRACT: vtx.y -= sculpt_strength * falloff
				SculptMode.SMOOTH: vtx.y = lerp(vtx.y, 0.0, falloff * 0.05)
				
			active_terrain_vertices[i] = vtx

	if modified:
		_rebuild_terrain_mesh()

func _apply_terrain_data(vertices: PackedVector3Array) -> void:
	active_terrain_vertices = vertices.duplicate()
	_rebuild_terrain_mesh()
	_update_terrain_collision()

func _rebuild_terrain_mesh() -> void:
	var arrays = terrain_mesh_node.mesh.surface_get_arrays(0)
	arrays[Mesh.ARRAY_VERTEX] = active_terrain_vertices
	
	var temp_mesh = ArrayMesh.new()
	temp_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	var st = SurfaceTool.new()
	st.create_from(temp_mesh, 0)
	st.generate_normals()
	terrain_mesh_node.mesh = st.commit()

func _update_terrain_collision() -> void:
	var static_body = terrain_mesh_node.get_parent()
	if static_body is StaticBody3D:
		var col_shape = static_body.get_node_or_null("CollisionShape3D")
		if col_shape and terrain_mesh_node.mesh is ArrayMesh:
			col_shape.shape = terrain_mesh_node.mesh.create_trimesh_shape()

# ==========================================
# RAYCASTING & HELPERS
# ==========================================

func _update_raycast_hit() -> void:
	var space_state = get_world_3d().direct_space_state
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * 2000.0

	var terrain_query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	terrain_query.collision_mask = placement_mask
	latest_terrain_hit = space_state.intersect_ray(terrain_query)

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
	else:
		deselect_item()

func _find_root_item_node(node: Node) -> Node3D:
	while node != null and node != items_container:
		if node.has_meta("map_data_ref"): return node
		node = node.get_parent()
	return null

# ==========================================
# EDITOR LOGIC (Items)
# ==========================================

func select_item_for_placement(item_id: String) -> void:
	set_editor_mode(EditorMode.PLACE)
	current_item_id = item_id
	
	if is_instance_valid(ghost_node):
		ghost_node.queue_free()
		
	if item_id == "": return
		
	var scene = ItemRegistry.get_packed_scene(item_id)
	if scene:
		ghost_node = scene.instantiate()
		add_child(ghost_node)
		_disable_collisions_recursive(ghost_node)

func deselect_item() -> void:
	if is_instance_valid(selected_node):
		_set_item_highlight(selected_node, false)
	selected_node = null
	selected_data = null

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
	if is_instance_valid(node): node.rotation = rot
	if data: data.rotation = rot

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
	if is_instance_valid(node): node.global_position = pos
	if data: data.position = pos
	if is_instance_valid(ghost_node): _disable_collisions_recursive(ghost_node)

func _set_collision_disabled_recursive(node: Node, is_disabled: bool) -> void:
	if node is CollisionShape3D or node is CollisionPolygon3D:
		node.disabled = is_disabled
	for child in node.get_children():
		_set_collision_disabled_recursive(child, is_disabled)

func _disable_collisions_recursive(node: Node) -> void:
	_set_collision_disabled_recursive(node, true)

func _set_item_highlight(node: Node3D, enabled: bool) -> void:
	if not is_instance_valid(node): return
	var meshes = node.find_children("*", "MeshInstance3D", true)
	for mesh in meshes:
		if mesh is MeshInstance3D:
			mesh.material_override = selection_material if enabled else null

# ==========================================
# FILE SYSTEM & SAVING
# ==========================================

func _setup_dialogs() -> void:
	exit_dialog = ConfirmationDialog.new()
	exit_dialog.title = "Confirm Exit"
	exit_dialog.dialog_text = "Are you sure you want to exit?"
	exit_dialog.ok_button_text = "Save and Close"
	exit_dialog.cancel_button_text = "Cancel"
	exit_dialog.add_button("Close Without Saving", true, "close_no_save")
	add_child(exit_dialog)
	
	exit_dialog.confirmed.connect(_on_exit_dialog_save_and_close)
	exit_dialog.custom_action.connect(_on_exit_dialog_custom_action)
	
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

func has_spawn_point() -> bool:
	for item in map_data.placed_items:
		if item.item_id == "player_spawn": return true
	return false

func save_map(file_path: String) -> void:
	map_data.sun_rotation = sun.rotation
	map_data.sun_color = sun.light_color
	map_data.sun_energy = sun.light_energy
	
	var env = world_env.environment
	map_data.fog_enabled = env.volumetric_fog_enabled
	map_data.fog_color = env.volumetric_fog_albedo
	map_data.fog_density = env.volumetric_fog_density
	
	# Also save terrain data to map resource if CustomMapData supports it
	if "terrain_vertices" in map_data:
		map_data.terrain_vertices = active_terrain_vertices.duplicate()
	
	var directory = file_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(directory):
		DirAccess.make_dir_recursive_absolute(directory)
		
	var err = ResourceSaver.save(map_data, file_path)
	if err == OK:
		if is_waiting_to_exit: _perform_exit()
	else:
		push_error("Failed to save map! Error code: ", err)
		is_waiting_to_exit = false

func load_map(file_path: String) -> void:
	if ResourceLoader.exists(file_path):
		var loaded_data = ResourceLoader.load(file_path) as CustomMapData
		if loaded_data:
			map_data = loaded_data
			
			var env = world_env.environment
			env.fog_enabled = map_data.fog_enabled
			env.fog_mode = map_data.fog_mode
			env.fog_albedo = map_data.fog_color
			env.fog_density = map_data.fog_density
			
			sun.rotation = map_data.sun_rotation
			sun.light_color = map_data.sun_color
			sun.light_energy = map_data.sun_energy
			env.adjustment_enabled = true
			env.adjustment_saturation = map_data.saturation
			
			if "terrain_vertices" in map_data and map_data.terrain_vertices.size() > 0:
				_apply_terrain_data(map_data.terrain_vertices)
			
			for child in items_container.get_children():
				child.queue_free()
				
			for item_data in map_data.placed_items:
				_spawn_actual_scene(item_data)

func create_world_folder(new_world_name: String) -> void:
	var new_world_path = "res://Maps/".path_join(new_world_name)
	if not DirAccess.dir_exists_absolute(new_world_path):
		DirAccess.make_dir_recursive_absolute(new_world_path)
		var file = FileAccess.open(new_world_path.path_join("map_data.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"name": new_world_name, "created": "2026"}))
		file.close()

func get_unique_map_name(base_name: String) -> String:
	var final_name = base_name
	var count = 1
	while DirAccess.dir_exists_absolute("res://Maps/".path_join(final_name)):
		final_name = base_name + " (" + str(count) + ")"
		count += 1
	return final_name
	
func is_map_name_taken(new_name: String) -> bool:
	return DirAccess.dir_exists_absolute("res://Maps".path_join(new_name))

func _perform_exit() -> void:
	get_tree().change_scene_to_file("res://select_map.tscn")
	
func _update_ui_layout(show_terrain_ui: bool):
	terrain_settings.visible = show_terrain_ui

# ==========================================
# SIGNAL HANDLERS
# ==========================================

func _on_undo_pressed() -> void:
	if undo_redo.has_undo(): undo_redo.undo()

func _on_redo_pressed() -> void:
	if undo_redo.has_redo(): undo_redo.redo()

func _on_save_pressed() -> void:
	if not has_spawn_point():
		push_error("A player spawn point is required!")
		return
	map_name_input.text = ""
	name_map_dialog.popup_centered()

func _on_name_map_confirmed() -> void:
	var user_input = map_name_input.text.strip_edges()
	if user_input == "":
		is_waiting_to_exit = false
		return
		
	var world_name = get_unique_map_name(user_input)
	map_data.map_name = world_name
	create_world_folder(world_name)
	
	var final_data_path = "res://Maps/".path_join(world_name).path_join("map_data.tres")
	MapFiles.current_map_path = final_data_path
	save_map(final_data_path)

func _on_exit_dialog_save_and_close() -> void:
	is_waiting_to_exit = true
	_on_save_pressed()

func _on_exit_dialog_custom_action(action: StringName) -> void:
	if action == "close_no_save": _perform_exit()

func _on_add_toggled(_toggled_on: bool) -> void: current_sculpt_mode = SculptMode.ADD
func _on_subtract_toggled(_toggled_on: bool) -> void: current_sculpt_mode = SculptMode.SUBTRACT
func _on_smooth_toggled(_toggled_on: bool) -> void: current_sculpt_mode = SculptMode.SMOOTH

func _on_modes_pressed() -> void:
	match current_mode:
		EditorMode.PLACE: set_editor_mode(EditorMode.SELECT)
		EditorMode.SELECT: set_editor_mode(EditorMode.TERRAIN)
		EditorMode.TERRAIN: set_editor_mode(EditorMode.PLACE)


func _on_delete_pressed() -> void:
	delete_selected_item()

func _on_exit_pressed() -> void:
	if is_instance_valid(exit_dialog):
		exit_dialog.popup_centered()
	
