extends Node3D
@onready var whizz: AudioStreamPlayer = $Node3D/Whizz
@onready var arrow_whizz: AudioStreamPlayer = $Node3D/ArrowWhizz



@export var hit_particle_scene: PackedScene = preload("res://explode_hit.tscn")
@export var speed: float = 110.0
@export var damage: int = 25
@export var max_lifetime: float = 5.0

var timer: float = 0.0

func _ready() -> void:
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	
	
	# KEY CHANGE: Godot's forward is -Z (Negative Z). 
	# This grabs the direction the bullet is currently facing.
	var forward_dir = -global_transform.basis.z
	
	var distance = speed * delta
	var from = global_position
	var to = from + forward_dir * distance

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self] # Don't hit yourself
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	var _result = space_state.intersect_ray(query)
	
	if _result:
		_on_impact(_result.collider, _result.position)
	else:
		# Move the bullet to the new position
		global_position = to

	timer += delta
	if timer >= max_lifetime:
		queue_free()

# ------------------------------
# Impact function
# ------------------------------
func _on_impact(collider: Node, hit_pos: Vector3) -> void:
	$Node3D/Whizz.play(.05)
	
	
	# Damage
	var current := collider
	while current:
		if current.has_method("take_damage"):
			current.take_damage(damage)
			break
		current = current.get_parent()

	# Spawn hit particles
	if hit_particle_scene:
		var particles = hit_particle_scene.instantiate()
		get_tree().current_scene.add_child(particles)
		particles.global_position = hit_pos
		if particles is GPUParticles3D or particles is CPUParticles3D:
			particles.emitting = true

	# Remove bullet
	queue_free()

# ------------------------------
# Optional explosion function
# ------------------------------
func _explode(pos: Vector3) -> void:
	if hit_particle_scene:
		var explosion = hit_particle_scene.instantiate()
		get_tree().current_scene.add_child(explosion)
		explosion.global_position = pos
		if explosion is GPUParticles3D or explosion is CPUParticles3D:
			explosion.emitting = true
