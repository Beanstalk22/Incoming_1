extends CharacterBody3D

@export_category("Movement")
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var jump_velocity: float = 4.5

@export_category("Camera")
@export var mouse_sensitivity: float = 0.002

@export_category("Head Bobbing")
@export var bob_frequency: float = 2.0
@export var bob_amplitude: float = 0.08

# Cache for performance
var t_bob: float = 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var held_object: Node3D = null

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/camera
@onready var interact_ray: RayCast3D = $CameraPivot/camera/InteractRay
@onready var hold_pos: Marker3D = $CameraPivot/camera/HoldPos

func _ready() -> void:
	GameManager.player = self
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Atom optimization: Direct rotation is lighter than complex transform manipulation
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		camera_pivot.rotation.x = clampf(camera_pivot.rotation.x, -1.55, 1.55) # Approx 89 degrees in rads

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED)
			
	if event.is_action_pressed("interact") and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if held_object:
			drop_object()
		elif interact_ray.is_colliding():
			var target = interact_ray.get_collider()
			if target.has_method("interact"):
				target.interact(self)

func _physics_process(delta: float) -> void:
	var on_floor = is_on_floor()
	
	if not on_floor:
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("ui_accept"):
		velocity.y = jump_velocity

	# Movement logic
	var current_speed := sprint_speed if Input.is_action_pressed("shft_left") else walk_speed
	var input_dir := Input.get_vector("A", "D", "W", "S")
	
	# Optimization: Use global_transform.basis directly to avoid creating extra vectors
	var direction := (global_transform.basis.z * input_dir.y + global_transform.basis.x * input_dir.x).normalized()

	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()
	
	# --- OPTIMIZED Head Bobbing ---
	# Only calculate trig if moving and on floor to save CPU cycles
	if on_floor and input_dir != Vector2.ZERO:
		t_bob += delta * velocity.length()
		var bob_offset = Vector3.ZERO
		bob_offset.y = sin(t_bob * bob_frequency) * bob_amplitude
		bob_offset.x = cos(t_bob * (bob_frequency * 0.5)) * bob_amplitude
		camera.transform.origin = bob_offset
	else:
		if t_bob != 0.0:
			t_bob = move_toward(t_bob, 0.0, delta * walk_speed)
			camera.transform.origin = camera.transform.origin.lerp(Vector3.ZERO, delta * 10.0)

	# --- OPTIMIZED Hold Logic ---
	if held_object:
		# interpolate_with is heavy. Use lerp for position and direct basis for rotation.
		var target_trans = hold_pos.global_transform
		held_object.global_position = held_object.global_position.lerp(target_trans.origin, delta * 20.0)
		held_object.global_basis = target_trans.basis

func pick_up(object: Node3D):
	held_object = object
	if held_object is RigidBody3D:
		held_object.freeze = true
		held_object.add_collision_exception_with(self)

func drop_object():
	if held_object:
		if held_object is RigidBody3D:
			held_object.freeze = false
			held_object.remove_collision_exception_with(self)
		held_object = null

func equip_weapon(weapon_name: String):
	# No change needed here as it is not called per-frame
	print("Weapon equipped: ", weapon_name)

func _on_ai_plane_body_entered(_body: Node3D) -> void:
	pass
	
func _exit_tree():
	# If the player is destroyed or the level restarts, clear the variable
	# so enemies don't try to chase a deleted node.
	if GameManager.player == self:
		GameManager.player = null
