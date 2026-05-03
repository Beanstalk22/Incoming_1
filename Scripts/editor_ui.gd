extends CanvasLayer

# Removed class_name EditorUI to avoid "hides a global script class" errors 
# if another script in the project already uses this name.

signal spawn_model_requested(packed_scene: PackedScene)

@onready var grid_container: GridContainer = $MarginContainer/ModelSelectorPanel/ScrollContainer/GridContainer
@onready var name_label: Label = $MarginContainer/InfoPanel/VBoxContainer/NameLabel
@onready var position_label: Label = $MarginContainer/InfoPanel/VBoxContainer/PositionLabel
@onready var rotation_label: Label = $MarginContainer/InfoPanel/VBoxContainer/RotationLabel
@onready var title_label: Label = $MarginContainer/InfoPanel/VBoxContainer/TitleLabel

# Mock database of models. In a real project, these would be pre-loaded paths.
@export var available_models: Array[PackedScene] = [preload("res://ammo_box.tscn")] 

func _ready() -> void:
	_populate_model_selector()

func _populate_model_selector() -> void:
	# Clear existing
	for child in grid_container.get_children():
		child.queue_free()
		
	# Check if models are assigned in the inspector
	if available_models.is_empty():
		for i in range(6):
			var btn = Button.new()
			btn.text = "Empty Slot %d" % i
			btn.custom_minimum_size = Vector2(80, 80)
			btn.disabled = true
			grid_container.add_child(btn)
	else:
		for model in available_models:
			if model:
				var btn = Button.new()
				btn.text = model.resource_path.get_file().get_basename()
				btn.custom_minimum_size = Vector2(80, 80)
				btn.pressed.connect(func(): spawn_model_requested.emit(model))
				grid_container.add_child(btn)

func update_info_panel(selected_objects: Array[Node3D], current_mode: int, snapping: bool) -> void:
	# Map the enum integers to human-readable strings
	var mode_names = ["None", "Translate (G)", "Rotate (R)", "Scale (S)"]
	var mode_str = mode_names[current_mode] if current_mode < mode_names.size() else "Unknown"
	
	title_label.text = "Mode: %s | Snap (X): %s" % [mode_str, "ON" if snapping else "OFF"]
	
	if selected_objects.is_empty():
		name_label.text = "Name: Nothing Selected"
		position_label.text = "Position: ---"
		rotation_label.text = "Rotation: ---"
	elif selected_objects.size() == 1:
		var obj = selected_objects[0]
		if is_instance_valid(obj):
			name_label.text = "Name: " + obj.name
			
			var pos = obj.global_position
			position_label.text = "Position: (%.2f, %.2f, %.2f)" % [pos.x, pos.y, pos.z]
			
			var rot = obj.global_rotation_degrees
			rotation_label.text = "Rotation: (%.2f, %.2f, %.2f)" % [rot.x, rot.y, rot.z]
	else:
		name_label.text = "Name: %d Objects Selected" % selected_objects.size()
		position_label.text = "Position: [Multiple]"
		rotation_label.text = "Rotation: [Multiple]"
