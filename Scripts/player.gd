extends CharacterBody3D
#player.gd
@onready var health_bar: ProgressBar = $control/VBoxContainer/VBoxContainer/CharacterHealth

@export_category("Health")
@export var max_health: float = 100.0
var current_health: float = 100.0

@export_category("Repair System")
@export var repair_time: float = 5.0
var current_repair_time: float = 0.0
@onready var repair_ui: ProgressBar = %RepairUI

@export_category("Progression")
@export var crew_stats: CrewStats

@onready var binocularing: Control = $binocularing

@export_category("Mount State")
var is_mounted: bool = false

@onready var wrench: Node3D = $Wrench 
@onready var binocular: Node3D = $Binocular

@onready var hotbar_ui: Control = $Hotbar

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/camera
@onready var interact_ray: RayCast3D = $CameraPivot/camera/InteractRay
@onready var hold_pos: Marker3D = $CameraPivot/camera/HoldPos

@export_category("UI")
@onready var interact_label: Label = %interact_label

@export_category("Inventory")
var inventory: Array = []# Stores item nodes or data
var current_index: int = -1
var max_slots: int = 5

@onready var default_fov: float = camera.fov
var is_zooming: bool = false

@export_category("Movement")
@export var base_walk_speed: float = 5.0
@export var base_sprint_speed: float = 8.0
@export var jump_velocity: float = 4.5

# Variables are exposed so GameManager can safely inject custom values from the player_profile.tres
@export_category("Camera Settings")
var mouse_sensitivity: float = 0.002
var zoom_sensitivity: float = 0.001

@export_category("Head Bobbing")
@export var bob_frequency: float = 2.0
@export var bob_amplitude: float = 0.08

# Cache for performance
var t_bob: float = 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var held_object: Node3D = null

func _ready() -> void:
	current_health = max_health
	update_health_ui()
	
	process_mode = Node.PROCESS_MODE_ALWAYS
	if get_tree().paused or is_mounted:
		return
	binocularing.visible = false
	GameManager.player = self
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Fallback if no stats resource is attached
	if not crew_stats:
		crew_stats = CrewStats.new()
	
	# Awtomatikong itago sa 'undroppable' group para hindi ma-drop
	if wrench:
		wrench.add_to_group("undroppable")
		collect_item(wrench) 
	if binocular:
		binocular.add_to_group("undroppable")
		collect_item(binocular)
		
func _input(event: InputEvent) -> void:
	if get_tree().paused:
		return

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if not is_mounted:
			var actual_sens = zoom_sensitivity if is_zooming else mouse_sensitivity
			rotate_y(-event.relative.x * actual_sens)
			camera_pivot.rotate_x(-event.relative.y * actual_sens)
			camera_pivot.rotation.x = clampf(camera_pivot.rotation.x, -1.55, 1.55)

	if event.is_action_pressed("interact"):
		if interact_ray.is_colliding():
			var target = interact_ray.get_collider()
			
			if target.has_method("reload") and "current_ammo" in target and target.current_ammo < target.max_ammo:
				if held_object and held_object.get("item_name") == "ammo box":
					target.reload()
					consume_held_item()
					return 
					
			if target.is_in_group("pickups") and inventory.size() < max_slots and not is_mounted:
				collect_item(target)
			elif target.has_method("interact"):
				target.interact(self)

	if not is_mounted:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				scroll_inventory(-1)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				scroll_inventory(1)
				
		if event is InputEventKey and event.pressed:
			if event.keycode >= KEY_1 and event.keycode <= KEY_5:
				switch_item(event.keycode - KEY_1)
				
		if event is InputEventMouseButton and held_object:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if "Binocular" in held_object.name:
					toggle_binoculars(event.pressed) 

	#		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
	#			if held_object.name == "Wrench":
	#				use_wrench()

		if event.is_action_pressed("Drop") and current_index != -1:
			var current_item = inventory[current_index]
			if current_item.name != "Wrench" and not "Binocular" in current_item.name:
				drop_from_inventory(current_index)

func _physics_process(delta: float) -> void:
	
	if current_health == 0:
		die()
	handle_repair(delta)
	if is_mounted:
		return
		
	var on_floor = is_on_floor()
	if not on_floor:
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("ui_accept"):
		velocity.y = jump_velocity

	# Apply dynamic speed based on CrewStats
	var speed_modifier = crew_stats.get_speed_bonus()
	var current_walk_speed = base_walk_speed + speed_modifier
	var current_sprint_speed = base_sprint_speed + speed_modifier
	
	var current_speed: float = current_sprint_speed if Input.is_action_pressed("shft_left") else current_walk_speed
	
	var input_dir := Input.get_vector("A", "D", "W", "S")
	
	var direction := (global_transform.basis.z * input_dir.y + global_transform.basis.x * input_dir.x).normalized()

	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()
	
	if interact_label:
		interact_label.visible = false
		if not is_mounted and interact_ray.is_colliding():
			var target = interact_ray.get_collider()
			if target.has_method("reload") and "current_ammo" in target and target.current_ammo < target.max_ammo:
				if held_object and held_object.get("item_name") == "ammo box":
					interact_label.text = "[E] Reload"
					interact_label.visible = true
	
	if on_floor and input_dir != Vector2.ZERO:
		t_bob += delta * velocity.length()
		var bob_offset = Vector3.ZERO
		bob_offset.y = sin(t_bob * bob_frequency) * bob_amplitude
		bob_offset.x = cos(t_bob * (bob_frequency * 0.5)) * bob_amplitude
		camera.transform.origin = bob_offset
	else:
		if t_bob != 0.0:
			t_bob = move_toward(t_bob, 0.0, delta * current_walk_speed)
			camera.transform.origin = camera.transform.origin.lerp(Vector3.ZERO, delta * 10.0)

	if held_object:
		var target_trans = hold_pos.global_transform
		held_object.global_position = held_object.global_position.lerp(target_trans.origin, delta * 20.0)
		held_object.global_basis = target_trans.basis
		
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and held_object.has_method("fire"):
			held_object.fire()
			
	var target_fov = 10.0 if is_zooming else default_fov
	camera.fov = lerp(camera.fov, target_fov, delta * 10.0)

func collect_item(item: Node3D):
	if item.get_parent():
		item.get_parent().remove_child(item)
	hold_pos.add_child(item)
	
	if item is RigidBody3D:
		item.freeze = true
		item.add_collision_exception_with(self)
		
	item.position = Vector3.ZERO
	item.rotation = Vector3.ZERO
	item.visible = false 
	inventory.append(item)
	if inventory.size() == 1:
		switch_item(0)

	if hotbar_ui:
		hotbar_ui.refresh_icons(inventory)
		hotbar_ui.update_selection(current_index)

func switch_item(index: int):
	if index < 0 or index >= inventory.size() or index == current_index:
		return
		
	if held_object:
		held_object.visible = false
		
	current_index = index
	held_object = inventory[current_index]
	held_object.visible = true
	
	if is_zooming:
		toggle_binoculars(false)
	if hotbar_ui:
		hotbar_ui.update_selection(index)
		
func drop_from_inventory(index: int):
	var item_to_drop = inventory[index]
	inventory.remove_at(index)
	
	hold_pos.remove_child(item_to_drop)
	get_tree().current_scene.add_child(item_to_drop)
	item_to_drop.global_position = hold_pos.global_position
	
	if item_to_drop is RigidBody3D:
		item_to_drop.freeze = false
		item_to_drop.remove_collision_exception_with(self)
	
	held_object = null
	current_index = -1
	
	if inventory.size() > 0:
		switch_item(0)
		
	if hotbar_ui:
		hotbar_ui.refresh_icons(inventory)
		hotbar_ui.update_selection(current_index)



func toggle_binoculars(active: bool):
	is_zooming = active
	if binocularing:
		binocularing.visible = active 

func consume_held_item():
	if current_index != -1:
		var item = inventory[current_index]
		inventory.remove_at(current_index)
		item.queue_free() 
		held_object = null
		current_index = -1
		
		if inventory.size() > 0:
			switch_item(0)
			
		if hotbar_ui:
			hotbar_ui.refresh_icons(inventory)
			hotbar_ui.update_selection(current_index)

func _exit_tree():
	if GameManager.player == self:
		GameManager.player = null
		
func scroll_inventory(direction: int) -> void:
	if inventory.size() <= 1:
		return
		
	var new_index = current_index + direction
	
	if new_index >= inventory.size():
		new_index = 0
	elif new_index < 0:
		new_index = inventory.size() - 1
		
	switch_item(new_index)
	
func set_mounted(mounted: bool) -> void:
	is_mounted = mounted
	
	if is_mounted:
		if held_object:
			held_object.visible = false
		if hotbar_ui:
			hotbar_ui.visible = false
			
		if is_zooming:
			toggle_binoculars(false)
	else:
		if held_object:
			held_object.visible = true
		if hotbar_ui:
			hotbar_ui.visible = true
func handle_repair(delta: float) -> void:
	# Check if holding wrench and holding right click
	if held_object and held_object.name == "Wrench" and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		if interact_ray.is_colliding():
			var target = interact_ray.get_collider()
			
			# Check if target is a gun and is damaged
			if target.has_method("repair") and target.has_method("needs_repair") and target.needs_repair():
				current_repair_time += delta
				
				# Update UI
				if repair_ui:
					repair_ui.visible = true
					repair_ui.value = (current_repair_time / repair_time) * 100.0
				
				# Apply repair when timer completes
				if current_repair_time >= repair_time:
					var base_repair = 15
					var bonus = crew_stats.get_repair_bonus()
					target.repair(base_repair + bonus)
					current_repair_time = 0.0 # Reset to loop the repair if held
				return

	# Reset timer and hide UI if conditions fail (stopped holding click, max health reached, looked away)
	current_repair_time = 0.0
	if repair_ui:
		repair_ui.visible = false
		
func update_health_ui() -> void:
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

func die() -> void:
	print("Player died")
	queue_free()
	
func take_damage(amount: float) -> void:
	current_health -= amount
	update_health_ui()
