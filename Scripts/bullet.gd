extends Node3D

@export var hit_particle_scene: PackedScene = preload("res://explode_hit.tscn")
@export var speed: float = 110.0
@export var damage: int = 25
@export var max_lifetime: float = 5.0

var timer: float = 0.0

# I-cache natin ang mga ito sa taas para hindi tayo gumagawa ng bagong object kada frame
var query: PhysicsRayQueryParameters3D
var space_state: PhysicsDirectSpaceState3D

func _ready() -> void:
	# KEY OPTIMIZATION: Gumagawa tayo ng query object ISANG BESES lang.
	query = PhysicsRayQueryParameters3D.new()
	query.exclude = [self] 
	query.collide_with_areas = true
	query.collide_with_bodies = true
	# TIP: I-set ang collision_mask para kalaban lang ang idedetect ng raycast!
	# query.collision_mask = 2 # (Kung layer 2 ang mga eroplano)

func _physics_process(delta: float) -> void:
	var forward_dir = -global_transform.basis.z
	var distance = speed * delta
	var from = global_position
	var to = from + forward_dir * distance

	if not space_state:
		space_state = get_world_3d().direct_space_state
	
	# Ina-update lang natin ang from/to ng existing query.
	query.from = from
	query.to = to
	
	var _result = space_state.intersect_ray(query)
	
	if _result:
		_on_impact(_result.collider, _result.position)
	else:
		global_position = to

	timer += delta
	if timer >= max_lifetime:
		queue_free() # Babala: Para sa 1000 bullets/sec, kailangan itong palitan ng Object Pooling.

# ------------------------------
# Impact function
# ------------------------------
func _on_impact(collider: Node, hit_pos: Vector3) -> void:
	# KEY OPTIMIZATION: Pinasimple ang parent crawling.
	# Ang pag-loop pababa o pataas sa tree habang may tama ay mabigat sa CPU.
	if collider.has_method("take_damage"):
		collider.take_damage(damage)
	elif collider.owner and collider.owner.has_method("take_damage"):
		collider.owner.take_damage(damage)

	if hit_particle_scene:
		var particles = hit_particle_scene.instantiate()
		get_tree().current_scene.add_child(particles)
		particles.global_position = hit_pos
		if particles is GPUParticles3D or particles is CPUParticles3D:
			particles.emitting = true

	queue_free()
