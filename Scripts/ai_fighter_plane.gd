extends Area3D

@export_group("Visuals")
@export var plane_type_name: String = "Spotter"
@export var score_value: int = 5
@export var min_credit_value: int = 5
@export var max_credit_value: int = 9

@export_group("Combat")
@export var max_health: float = 100.0
@export var smoke_threshold: float = 25.0

@export_group("Weapons")
@export var spread_deg: float = 3.0
@export var fire_rate: float = 2.0
@export var bullet_scene: PackedScene = preload("res://enemy_bullet.tscn")

@export_group("Speeds")
@export var cruise_speed: float = 12.0
@export var dive_speed: float = 9.0
@export var rotation_speed: float = 1.0

@export_group("Flight Dynamics")
@export var wobble_amplitude: Vector2 = Vector2(15.0, 5.0)
@export var wobble_speed: Vector2 = Vector2(1.5, 2.0)

@export_group("Crashing Settings")
@export var crash_spin_speed: float = 1.5
@export var crash_duration: float = 10.0

@export_group("Flight Distances")
@export var spawn_distance: float = 200.0
@export var dive_trigger_distance: float = 100.0
@export var spawn_height: float = 60.0
@export var pull_up_height: float = 10.0
@export var turnaround_distance: float = 150.0

enum State { CRUISE, DIVING, PULLING_UP, FLY_AWAY, CRASHING }

var current_state: State = State.CRUISE
var health: float
var is_dead: bool = false
var fire_timer: float = 1.0
var current_muzzle_index: int = 0
var has_hit_ground: bool = false
var is_wave_managed: bool = false

var flight_time: float = 0.0
var phase_offset: float = 0.0

@onready var dive_trigger_sq: float = dive_trigger_distance * dive_trigger_distance
@onready var muzzles: Array[Node3D] = [$Muzzle, $Muzzle2]
@onready var enemy_muzzle_spark: GPUParticles3D = $Muzzle/enemy_muzzle_spark
@onready var enemy_muzzle_spark2: GPUParticles3D = $Muzzle2/enemy_muzzle_spark
@onready var explosion_scene: GPUParticles3D = $crash_explode
@onready var smoke_particles: GPUParticles3D = $SmokeParticles
@onready var plane_mesh =  $Nieuport11_scout_plane

# Crash physics cache
var crash_initialized : bool = false
var crash_torque : Vector3 = Vector3.ZERO
var crash_gravity : float
var crash_drag : float
var crash_current_speed: float = 0.0

signal plane_destroyed(plane_node)

func _ready() -> void:
	_init_plane()

func _process(delta: float) -> void:
	var active_player = GameManager.player
	if not active_player: return
	
	var my_pos = global_position
	var player_pos = active_player.global_position
	var my_forward = -global_transform.basis.z
	var dist_to_player_sq = my_pos.distance_squared_to(player_pos)

	if has_hit_ground: return

	flight_time += delta
	var dist_to_player = sqrt(dist_to_player_sq)
	var wobble = _get_wobble_offset(dist_to_player)

	match current_state:
		State.CRUISE:
			if dist_to_player_sq <= dive_trigger_sq:
				current_state = State.DIVING
			_maintain_level_flight(delta, my_pos, player_pos, wobble)
			global_position += my_forward * cruise_speed * delta

		State.DIVING:
			_smooth_look_at(player_pos + wobble, rotation_speed * delta, my_pos)
			_handle_firing(delta, my_forward, player_pos, my_pos)
			if my_pos.y <= player_pos.y + pull_up_height:
				current_state = State.PULLING_UP
			global_position += my_forward * dive_speed * delta

		State.PULLING_UP:
			var exit_point = my_pos + my_forward * 20.0
			exit_point.y = max(my_pos.y, player_pos.y + pull_up_height)
			_smooth_look_at(exit_point + wobble, rotation_speed * delta, my_pos)
			if abs(global_transform.basis.z.y) < 0.1:
				current_state = State.FLY_AWAY
			global_position += my_forward * dive_speed * delta

		State.FLY_AWAY:
			var climb_target = my_pos + (my_forward * 50)
			climb_target.y = player_pos.y + spawn_height
			_smooth_look_at(climb_target + wobble, rotation_speed * delta, my_pos)
			
			# Turn around ONLY when altitude is reached AND distance is met
			var turnaround_sq = turnaround_distance * turnaround_distance
			if my_pos.y >= (player_pos.y + spawn_height) - 2.0 and dist_to_player_sq > turnaround_sq:
				current_state = State.CRUISE
				
			global_position += my_forward * cruise_speed * delta

		State.CRASHING:
			if not crash_initialized: _init_crash()
			crash_current_speed = lerp(crash_current_speed, 0.0, delta * crash_drag)
			var movement_velocity = (my_forward * crash_current_speed) + (Vector3.DOWN * crash_gravity)
			global_position += movement_velocity * delta
			rotate_object_local(Vector3.RIGHT, crash_torque.x * delta)
			rotate_object_local(Vector3.UP, crash_torque.y * delta)
			rotate_object_local(Vector3.FORWARD, crash_torque.z * delta)
			if movement_velocity.length_squared() > 1.0:
				_smooth_look_at(my_pos + movement_velocity, delta * 2.5, my_pos)

func _get_wobble_offset(dist_to_player: float) -> Vector3:
	var distance_factor = clamp(dist_to_player / dive_trigger_distance, 0.15, 1.0)
	var wobble_x = sin(flight_time * wobble_speed.x + phase_offset) * wobble_amplitude.x * distance_factor
	var wobble_y = cos(flight_time * wobble_speed.y + phase_offset) * wobble_amplitude.y * distance_factor
	var right_vec = global_transform.basis.x
	var up_vec = global_transform.basis.y
	return (right_vec * wobble_x) + (up_vec * wobble_y)

func _init_plane() -> void:
	health = max_health
	current_state = State.CRUISE
	phase_offset = randf_range(0.0, TAU)
	
	var p_node = GameManager.player
	var p_pos = p_node.global_position if p_node else Vector3.ZERO
	$audio/engine.play(3)
	
	var angle = randf_range(0, TAU)
	var pos = p_pos + Vector3(cos(angle), 0, sin(angle)) * spawn_distance
	global_position = Vector3(pos.x, p_pos.y + spawn_height, pos.z)
	look_at(p_pos + Vector3.UP * spawn_height, Vector3.UP)

func _init_crash() -> void:
	var crash_types = ["NOSE_DIVE", "STALL", "AGGRESSIVE_TUMBLE"]
	match crash_types.pick_random():
		"AGGRESSIVE_TUMBLE":
			crash_torque = Vector3(10, 9, 8); crash_gravity = 15.0; crash_drag = 5.0
		"NOSE_DIVE":
			crash_torque = Vector3(-1.5, 0, 0); crash_gravity = 9.0; crash_drag = 3.8
		"STALL":
			crash_torque = Vector3(0, 1, 0); crash_gravity = 5.0; crash_drag = 15.0
	crash_current_speed = cruise_speed
	crash_initialized = true

func take_damage(amount: float) -> void:
	if is_dead: return
	health -= amount
	if health <= smoke_threshold: smoke_particles.emitting = true
	if health <= 0: _start_crash()

func _start_crash() -> void:
	var random_reward: int = randi_range(min_credit_value, min_credit_value)
	if is_dead: return
	
	is_dead = true
	current_state = State.CRASHING
	if GameManager.has_method("add_points"):
		GameManager.add_points(score_value)
	if CurrencyManager.has_method("add_currency"):
		CurrencyManager.add_currency("credit", random_reward)
	
	plane_destroyed.emit(self)

func _on_body_entered(_body: Node3D) -> void:
	if current_state != State.CRASHING or has_hit_ground: return
	has_hit_ground = true
	explosion_scene.restart()
	
	var lingering_smoke = $black_smoke.duplicate()
	get_parent().add_child(lingering_smoke)
	lingering_smoke.global_position = global_position
	lingering_smoke.emitting = true
	
	get_tree().create_timer(40.0).timeout.connect(lingering_smoke.queue_free)
	get_tree().create_timer(2.0).timeout.connect(queue_free) # Permanently delete instead of pooling

func _handle_firing(delta: float, my_forward: Vector3, player_pos: Vector3, my_pos: Vector3) -> void:
	fire_timer -= delta
	if fire_timer <= 0:
		var to_player = (player_pos - my_pos).normalized()
		if my_forward.dot(to_player) > 0.8:
			_fire_projectile()
			fire_timer = fire_rate

func _maintain_level_flight(delta: float, my_pos: Vector3, player_pos: Vector3, wobble: Vector3) -> void:
	var level_target = player_pos
	level_target.y = player_pos.y + spawn_height
	# Spreads out their turning arcs dynamically
	level_target.x += sin(flight_time) * 30.0
	level_target.z += cos(flight_time) * 30.0
	
	_smooth_look_at(level_target + wobble, rotation_speed * delta, my_pos)

func _smooth_look_at(target: Vector3, weight: float, current_pos: Vector3) -> void:
	if current_pos.distance_squared_to(target) < 0.1: return
	var direction = (target - current_pos).normalized()
	var up_ref = Vector3.UP if abs(direction.y) < 0.99 else Vector3.FORWARD
	var look_trans = global_transform.looking_at(target, up_ref)
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
	if b.has_method("set_direction"): b.set_direction(-b.global_transform.basis.z)
	current_muzzle_index = (current_muzzle_index + 1) % muzzles.size()
