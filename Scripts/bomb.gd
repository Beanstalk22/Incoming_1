extends Area3D

@export var initial_speed: float = 1.0
@export var bomb_gravity: float = 2.0
@export var air_drag: float = 2.5 # NEW: Slows down forward movement for a realistic arc
@export var damage_radius: float = 10.0
@export var damage_amount: float = 50.0

var velocity: Vector3 = Vector3.ZERO

func _ready():
	# Connect the hit signal
	body_entered.connect(_on_impact)
	
func start_drop(spawn_transform: Transform3D, plane_velocity: Vector3):
	global_transform = spawn_transform
	# Inherit the plane's current speed
	velocity = plane_velocity

func _physics_process(delta):
	# 1. Apply Gravity (Fixed: Using your custom bomb_gravity)
	velocity.y -= bomb_gravity * delta
	
	# NEW: Apply air drag to horizontal movement (X and Z axis)
	# This bleeds off the plane's forward speed, causing the bomb to arc downward steeply!
	velocity.x = move_toward(velocity.x, 0, air_drag * delta)
	velocity.z = move_toward(velocity.z, 0, air_drag * delta)
	
	# 2. Move the bomb
	global_position += velocity * delta
	
	# 3. Make the bomb point in the direction it's falling
	if velocity.length() > 0.1:
		# Added a safety check: if falling perfectly straight down, look_at gets confused by Vector3.UP
		# If it's not falling perfectly down, point the nose forward and keep the top facing UP
		if abs(velocity.normalized().y) < 0.99:
			look_at(global_position + velocity, Vector3.UP)

func _on_impact(_body):
	# Stop moving and hide the bomb mesh
	set_physics_process(false)
	$MeshInstance3D.hide()
	
	# Trigger Visuals & Sound
	# Fixed typo: changed $expode to $explode (assuming it was a typo in your scene tree!)
	if has_node("explode"):
		$explode.emitting = true
	#$AudioStreamPlayer3D.play()
	
	# Damage everything in the blast radius
	_explode_aoe()
	
	# Delete after the explosion finishes
	await get_tree().create_timer(2.0).timeout
	queue_free()

func _explode_aoe():
	var targets = get_tree().get_nodes_in_group("player")
	for target in targets:
		var dist = global_position.distance_to(target.global_position)
		if dist <= damage_radius:
			if target.has_method("take_damage"):
				target.take_damage(damage_amount)
