extends Node

class_name EditorManager

enum EditMode { NONE, TRANSLATE, ROTATE, SCALE }

@export var camera: Camera3D
@export var world_objects_container: Node3D
@export var editor_ui: CanvasLayer
@export var editables_layer_mask: int = 2 # Layer 2

var selected_objects: Array[Node3D] = []
var highlight_material: StandardMaterial3D

var current_mode: EditMode = EditMode.NONE
var snapping_enabled: bool = false
var snap_step_translate: float = 1.0
var snap_step_rotate: float = deg_to_rad(15.0)

# Manipulation State
var _manipulation_active: bool = false
var _manipulation_start_pos: Vector2
var _initial_transforms: Dictionary = {}

func _ready() -> void:
	# Create the visual highlight material
	highlight_material = StandardMaterial3D.new()
	highlight_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	highlight_material.albedo_color = Color(1.0, 0.64, 0.0, 0.5) # Orange-ish highlight
	highlight_material.grow = true
	highlight_material.grow_amount = 0.05
	
	if editor_ui:
		editor_ui.spawn_model_requested.connect(_on_spawn_model_requested)

func _process(_delta: float) -> void:
	if editor_ui:
		editor_ui.update_info_panel(selected_objects, current_mode, snapping_enabled)

func _unhandled_input(event: InputEvent) -> void:
	# Snapping Toggle
	if event is InputEventKey and event.pressed and event.keycode == KEY_X:
		snapping_enabled = !snapping_enabled
	
	# Modes (G, R, S)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_G:
			_set_mode(EditMode.TRANSLATE)
		elif event.keycode == KEY_R:
			_set_mode(EditMode.ROTATE)
		elif event.keycode == KEY_S:
			_set_mode(EditMode.SCALE)
		elif event.keycode == KEY_ESCAPE:
			_set_mode(EditMode.NONE)
			
		# Duplication Ctrl+D
		if event.keycode == KEY_D and Input.is_key_pressed(KEY_CTRL):
			duplicate_selection()

	# Selection Logic
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			if current_mode != EditMode.NONE and selected_objects.size() > 0:
				# Start manipulation
				_manipulation_active = true
				_manipulation_start_pos = event.position
				_store_initial_transforms()
			else:
				# Raycast for selection
				_perform_raycast_selection(event.position, Input.is_key_pressed(KEY_SHIFT))
		else:
			# End manipulation
			_manipulation_active = false

	# Active Manipulation Logic
	if event is InputEventMouseMotion and _manipulation_active:
		_apply_manipulation(event.position)

func _set_mode(mode: EditMode) -> void:
	current_mode = mode
	_manipulation_active = false # Reset dragging when mode changes

func _perform_raycast_selection(screen_pos: Vector2, is_multi_select: bool) -> void:
	if not camera: return
	
	var space_state = camera.get_world_3d().direct_space_state
	var origin = camera.project_ray_origin(screen_pos)
	var end = origin + camera.project_ray_normal(screen_pos) * 1000.0
	
	var query = PhysicsRayQueryParameters3D.create(origin, end, editables_layer_mask)
	var result = space_state.intersect_ray(query)
	
	if result:
		var hit_obj = result.collider
		if is_multi_select:
			if selected_objects.has(hit_obj):
				_deselect_object(hit_obj)
			else:
				_select_object(hit_obj, true)
		else:
			clear_selection()
			_select_object(hit_obj, false)
	else:
		if not is_multi_select:
			clear_selection()

func _select_object(obj: Node3D, append: bool) -> void:
	if not append:
		clear_selection()
	if not selected_objects.has(obj):
		selected_objects.append(obj)
		_apply_highlight(obj, true)

func _deselect_object(obj: Node3D) -> void:
	if selected_objects.has(obj):
		selected_objects.erase(obj)
		_apply_highlight(obj, false)

func clear_selection() -> void:
	for obj in selected_objects:
		_apply_highlight(obj, false)
	selected_objects.clear()

func _apply_highlight(obj: Node3D, enable: bool) -> void:
	# Recursively find meshes to apply/remove the material overlay
	var meshes = _get_all_meshes(obj)
	for mesh_instance in meshes:
		if enable:
			mesh_instance.material_overlay = highlight_material
		else:
			mesh_instance.material_overlay = null

func _get_all_meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_get_all_meshes(child))
	return result

func duplicate_selection() -> void:
	var new_selection: Array[Node3D] = []
	for obj in selected_objects:
		var duplicate = obj.duplicate()
		world_objects_container.add_child(duplicate)
		duplicate.global_transform = obj.global_transform
		new_selection.append(duplicate)
		_apply_highlight(obj, false) # Deselect original
		
	selected_objects = new_selection
	for obj in selected_objects:
		_apply_highlight(obj, true)
	_set_mode(EditMode.TRANSLATE) # Auto switch to move duplicated objects

func _store_initial_transforms() -> void:
	_initial_transforms.clear()
	for obj in selected_objects:
		if is_instance_valid(obj):
			_initial_transforms[obj] = obj.global_transform

func _apply_manipulation(current_mouse_pos: Vector2) -> void:
	if selected_objects.is_empty(): return
	
	var mouse_delta = current_mouse_pos - _manipulation_start_pos
	var cam_right = camera.global_transform.basis.x
	var cam_up = camera.global_transform.basis.y
	
	for obj in selected_objects:
		if not is_instance_valid(obj) or not _initial_transforms.has(obj): continue
		
		var initial_tr = _initial_transforms[obj]
		
		match current_mode:
			EditMode.TRANSLATE:
				# Translate parallel to camera viewing plane
				var move_vector = (cam_right * mouse_delta.x - cam_up * mouse_delta.y) * 0.02
				var new_pos = initial_tr.origin + move_vector
				if snapping_enabled:
					new_pos = new_pos.snapped(Vector3(snap_step_translate, snap_step_translate, snap_step_translate))
				obj.global_position = new_pos
				
			EditMode.ROTATE:
				# Rotate around Y axis based on X mouse movement
				var rot_amount = mouse_delta.x * 0.01
				if snapping_enabled:
					rot_amount = snappedf(rot_amount, snap_step_rotate)
				obj.global_rotation.y = initial_tr.basis.get_euler().y - rot_amount
				
			EditMode.SCALE:
				# Uniform scale based on Y mouse movement (up to scale up)
				var scale_factor = 1.0 - (mouse_delta.y * 0.01)
				scale_factor = max(0.1, scale_factor) # Prevent negative/zero scale
				if snapping_enabled:
					scale_factor = snappedf(scale_factor, 0.5)
				obj.scale = initial_tr.basis.get_scale() * scale_factor

func _on_spawn_model_requested(packed_scene: PackedScene) -> void:
	if not packed_scene or not world_objects_container or not camera: return
	
	var instance = packed_scene.instantiate() as Node3D
	world_objects_container.add_child(instance)
	
	# Place in front of camera
	var spawn_pos = camera.global_position - camera.global_transform.basis.z * 5.0
	if snapping_enabled:
		spawn_pos = spawn_pos.snapped(Vector3(snap_step_translate, snap_step_translate, snap_step_translate))
	instance.global_position = spawn_pos
	
	clear_selection()
	_select_object(instance, false)
