extends Node3D

@export var hit_particle_scene: PackedScene = preload("res://explode_hit.tscn")
@export var speed: float = 60.0
@export var damage: int = 25
@export var max_lifetime: float = 7.0

var timer: float = 0.0

func _ready() -> void:
	# Detach from parent immediately so it doesn't follow the plane's turns after firing
	set_as_top_level(true)
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
	
	var result = space_state.intersect_ray(query)

	if result:
		_on_impact(result.collider, result.position)
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
	var current := collider
	while current:
		if current.has_method("take_damage"):
			current.take_damage(damage)
			break
		current = current.get_parent()

	if hit_particle_scene:
		var particles = hit_particle_scene.instantiate()
		get_tree().current_scene.add_child(particles)
		particles.global_position = hit_pos
		
		if particles is GPUParticles3D or particles is CPUParticles3D:
			particles.emitting = true

	queue_free()
	
	
