extends RigidBody3D

@export var forward_speed := 40.0
@export var fall_accel := 5.0
@export var roll_speed := 2.5   # radians/sec
@export var crash_lifetime: float = 3.0
var crash_timer: float = 0.0
var crashed := true
func _ready():
	# Start with forward momentum
	linear_velocity = transform.basis.x * forward_speed

	# Start rolling around forward axis
	angular_velocity = transform.basis.x * roll_speed

func _physics_process(delta):
	# Gravity-like fall (Y axis only)
	linear_velocity.y -= fall_accel * delta
	if crashed:
		crash_timer += delta
		if crash_timer >= crash_lifetime:
			queue_free()
