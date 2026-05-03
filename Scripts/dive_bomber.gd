extends Area3D
@export var drop_altitude: float = 50.0 # Adjust this to change drop height
@export var bomb_scene: PackedScene = preload("res://bomb.tscn")
@onready var enemy_muzzle_spark: GPUParticles3D = $Muzzle/enemy_muzzle_spark
@onready var enemy_muzzle_spark2: GPUParticles3D = $Muzzle2/enemy_muzzle_spark
var has_dropped_bomb: bool = false

# Add these to your existing @export_group section
@export_group("Visuals")
@export var plane_type_name: String = "Dive Bomber"
@export var score_value: int = 15

@export_group("Combat")
@export var max_health: float = 100.0
@export var smoke_threshold: float = 25.0 # Starts smoking at this HP
@onready var explosion_scene: GPUParticles3D = $crash_explode
@export var respawn_delay: float = 5.0

@export_group("Weapons")
@export var spread_deg: float = 2.0
@export var fire_rate: float = 0.9

@export var bullet_scene: PackedScene = preload("res://enemy_bullet.tscn")

@export_group("Speeds")
@export var cruise_speed: float = 12.0
@export var dive_speed: float = 5.0
@export var rotation_speed: float = 6.0

@export_group("Crashing Settings")
@export var crash_speed: float = 0.0
@export var crash_spin_speed: float = 1.5
@export var crash_duration: float = 10.0 # Time spent falling before exploding
@onready var smoke_particles: GPUParticles3D = $SmokeParticles

@export_group("Flight Distances")
@export var spawn_distance: float = 200.0
@export var dive_trigger_distance: float = 100.0
@export var despawn_distance: float = 250.0
@export var spawn_height: float = 90.0
@export var pull_up_height: float = 10.0

enum State { CRUISE, DIVING, PULLING_UP, FLY_AWAY, CRASHING }

var current_state: State = State.CRUISE
var player: Node3D
var health: float
var is_dead: bool = false
var fire_timer: float = 1.0
var current_muzzle_index: int = 0

# FIXED: Strictly typed array for Godot 4
@onready var muzzles: Array[Node3D] = [$Muzzle, $Muzzle2]

func _ready() -> void:
	health = max_health
	player = get_tree().get_first_node_in_group("player")
	
	if player:
		_setup_spawn()
	else:
		queue_free()


var crash_initialized : bool = false
var crash_torque : Vector3 = Vector3.ZERO  # The "flavor" of the spin
var crash_gravity : float             # How heavy the plane feels
var crash_drag : float                # How fast forward speed bleeds out

func _process(delta: float) -> void:
	if not player: return
	
	if is_dead and current_state != State.CRASHING: return

	var dist_to_player = global_position.distance_to(player.global_position)
	
	# We remove this from the top so the crashing state can manage its own speed properly
	var current_speed = cruise_speed

	match current_state:
		State.CRUISE:
			current_speed = cruise_speed
			if dist_to_player <= dive_trigger_distance:
				current_state = State.DIVING
			_maintain_level_flight(delta)
			# Apply normal flight movement
			global_position += -global_transform.basis.z * current_speed * delta
		State.DIVING:
	# 1. Accelerate during the dive (Gravity assist!)
			current_speed = lerp(current_speed, dive_speed, delta * 2.0)
	# 2. Look aggressively at the player
			_smooth_look_at(player.global_position, rotation_speed * delta)
	# 3. Sound/Visual FX: If you have a siren, start it here!
	
	# 4. Fire guns while diving
			_handle_firing(delta)
	# 5. Check for pull-up
			if global_position.y <= player.global_position.y + pull_up_height:
				current_state = State.PULLING_UP
		# Add a "Whoosh" or G-force effect here
			if global_position.y <= player.global_position.y + drop_altitude and not has_dropped_bomb:
					_release_bomb()
					has_dropped_bomb = true # Create this variable at the top
		
			global_position += -global_transform.basis.z * current_speed * delta
			
			
		State.PULLING_UP:
			current_speed = dive_speed
			var exit_point = global_position + (-global_transform.basis.z * 20)
			exit_point.y = max(global_position.y + 9, player.global_position.y + pull_up_height)
			_smooth_look_at(exit_point, rotation_speed * 3.5 * delta)
			if abs(global_transform.basis.z.y) < 0.1:
				current_state = State.FLY_AWAY
			# Apply normal flight movement
			global_position += -global_transform.basis.z * current_speed * delta
			
			
		State.CRASHING:
			# 1. INITIALIZE THE "DESTINY"
			if not crash_initialized:
				var crash_types = ["NOSE_DIVE", "STALL", "STABLE_GLIDE", "DEAD_PILOT", "AGGRESSIVE_TUMBLE"]
				var picked_type = crash_types.pick_random()
		
				match picked_type:
					"DEAD_PILOT":
						crash_torque = Vector3(10, 10, 0)
						crash_gravity = 9.0
						crash_drag = 4.5
					"AGGRESSIVE_TUMBLE":
						crash_torque = Vector3(10, 9, 8)
						crash_gravity = 14.0
						crash_drag = 5.0
					"NOSE_DIVE":
						crash_torque = Vector3(randf_range(-4, -2), 0, 1)
						crash_gravity = 3.0
						crash_drag = 3.8
					"STALL":
						crash_torque = Vector3(-1.0, randf_range(-1, 0), 0)
						crash_gravity = 5.0
						crash_drag = 15
					"STABLE_GLIDE":
						crash_torque = Vector3(-1, 0, 0)
						crash_gravity = 4.5
						crash_drag = 10

				crash_initialized = true

			# 2. CALCULATE INERTIA & GRAVITY
			# Bleed off forward speed
			current_speed = lerp(current_speed, 0.0, delta * crash_drag)
	
			# FIX: Use Vector3.DOWN for world gravity, not local basis.y
			var forward_vec = -global_transform.basis.z * current_speed
			var down_vec = Vector3.DOWN * crash_gravity
			var movement_velocity = (forward_vec + down_vec)
	
			# This is the ONLY movement applied during crashing
			global_position += movement_velocity * delta

			# 3. APPLY ROTATIONAL SPIN (Torque)
			rotate_object_local(Vector3.RIGHT, crash_torque.x * delta)
			rotate_object_local(Vector3.UP, crash_torque.y * delta)
			rotate_object_local(Vector3.FORWARD, crash_torque.z * delta)

			# 4. PHYSICS-BASED LOOK-AT
			if movement_velocity.length() > 1.0:
				var target_look = global_position + movement_velocity
				_smooth_look_at(target_look, delta * 2.5)
			
		State.FLY_AWAY:
			current_speed = cruise_speed
			var climb_target = global_position + (-global_transform.basis.z * 50)
			climb_target.y = player.global_position.y + spawn_height
			
			_smooth_look_at(climb_target, rotation_speed * delta)
			
			if global_position.y >= (player.global_position.y + spawn_height) - 2.0:
				current_state = State.CRUISE
				
			# Apply normal flight movement
			global_position += -global_transform.basis.z * current_speed * delta

	# Respawn if out of range
	if dist_to_player > despawn_distance and current_state != State.CRASHING:
		_respawn()
func take_damage(amount: float) -> void:
	if is_dead: return
	health -= amount
	
	if health <= smoke_threshold and health > 0:
		$SmokeParticles.emitting = true
	if health <= 0:
		_start_crash()
		
func _handle_firing(delta: float) -> void:
	fire_timer -= delta
	if fire_timer <= 0:
		var forward = -global_transform.basis.z
		var to_player = (player.global_position - global_position).normalized()
		if forward.dot(to_player) > 0.8:
			_fire_projectile()
			fire_timer = fire_rate
			
func _respawn() -> void:
	current_state = State.CRUISE
	_setup_spawn()

func _maintain_level_flight(delta: float) -> void:
	var level_target = global_position + (-global_transform.basis.z * 40)
	level_target.y = player.global_position.y + spawn_height
	_smooth_look_at(level_target, rotation_speed * delta)

func _smooth_look_at(target: Vector3, weight: float) -> void:
	if global_position.is_equal_approx(target):
		return
		
	var direction = (target - global_position).normalized()
	var up_reference = Vector3.UP
	
	if abs(direction.dot(Vector3.UP)) > 0.999:
		up_reference = Vector3.FORWARD
		
	var look_trans = global_transform.looking_at(target, up_reference)
	global_transform = global_transform.interpolate_with(look_trans, weight)

func _fire_projectile() -> void:
	var muzzle = muzzles[current_muzzle_index]
	var b = bullet_scene.instantiate()
	get_tree().root.add_child(b)
	b.global_transform = muzzle.global_transform
	enemy_muzzle_spark.restart()
	enemy_muzzle_spark2.restart()
	
	var s = deg_to_rad(spread_deg)
	b.rotate_object_local(Vector3.UP, randf_range(-s, s))
	b.rotate_object_local(Vector3.RIGHT, randf_range(-s, s))
	
	if b.has_method("set_direction"):
		b.set_direction(-b.global_transform.basis.z)
		
	current_muzzle_index = (current_muzzle_index + 1) % muzzles.size()
	
func _start_crash() -> void:
	if is_dead: return
	is_dead = true
	current_state = State.CRASHING
	$SmokeParticles.emitting = true
	# FIXED: True disables the collision shape.
	$CollisionShape3D.set_deferred("disabled", false)
	GameManager.add_points(10)
	#await get_tree().create_timer(crash_duration).timeout

	if current_state == State.CRASHING:
		_initial_mid_air_explosion()
var has_hit_ground: bool = false

func _on_body_entered(_body: Node3D) -> void:
	if current_state != State.CRASHING or has_hit_ground:
		return
		
	has_hit_ground = true
	$SmokeParticles.emitting = false
	set_process(false)
	
	$crash_explode.emitting = true
	
	# --- THE FIX: Create detached smoke that stays behind ---
	# 1. Clone the black smoke node
	var lingering_smoke = $black_smoke.duplicate()
	
	# 2. Add it to the main world (so it is no longer attached to the plane)
	get_parent().add_child(lingering_smoke)
	
	# 3. Put it exactly where the plane crashed
	lingering_smoke.global_position = global_position
	lingering_smoke.emitting = true
	
	# 4. Tell this specific smoke clone to delete itself in 20 seconds
	get_tree().create_timer(80.0).timeout.connect(lingering_smoke.queue_free)
	# --------------------------------------------------------
	
	# Wait for the wreckage to burn seconds before respawning the plane
	await get_tree().create_timer(score_value).timeout

	if current_state == State.CRASHING:
		_final_impact_and_respawn()
		
func _setup_spawn() -> void:
	
	$black_smoke.emitting = false
	var angle = randf_range(0, TAU)
	var pos = player.global_position + Vector3(cos(angle), 0, sin(angle)) * spawn_distance
	global_position = Vector3(pos.x, player.global_position.y + spawn_height, pos.z)
	
	# FIXED: Safely look at the target without causing gimbal lock crashes
	var target_pos = player.global_position + Vector3.UP * spawn_height
	if not global_position.is_equal_approx(target_pos):
		look_at(target_pos, Vector3.UP)

func _initial_mid_air_explosion() -> void:
	# Ensure it only happens if we are still in the crashing state
	if current_state != State.CRASHING: return
	$SmokeParticles.emitting = true
	
func _final_impact_and_respawn() -> void:
	hide()
	set_process(false)
	set_deferred("monitoring", false)
	await get_tree().create_timer(respawn_delay).timeout
	_reset_for_respawn()
	
		
func _reset_for_respawn() -> void:
	health = max_health
	is_dead = false
	has_hit_ground = false # FIXED: Reset our ground flag
	current_state = State.CRUISE
	show()
	set_process(true)
	set_deferred("monitoring", true)
	
	# FIXED: Re-enable collisions upon respawn
	$CollisionShape3D.set_deferred("disabled", false)
	
	_setup_spawn()
func _release_bomb():
	var b = bomb_scene.instantiate()
	get_tree().root.add_child(b)
	
	# Calculate the plane's current forward velocity to pass to the bomb
	var forward_velocity = -global_transform.basis.z * cruise_speed
	
	# Spawn it slightly below the plane
	var spawn_pos = global_transform
	spawn_pos.origin -= global_transform.basis.y * 2.0 
	
	b.start_drop(spawn_pos, forward_velocity)
