extends Camera3D
class_name FlyCamera

@export var base_move_speed: float = 10.0
@export var look_sensitivity: float = 0.003
@export var min_speed: float = 1.0
@export var max_speed: float = 100.0
@export var speed_step: float = 2.0

var _current_move_speed: float
var _is_mouse_captured: bool = false
var _camera_rotation: Vector2 = Vector2.ZERO

func _ready() -> void:
	_current_move_speed = base_move_speed
	_camera_rotation = Vector2(rotation.y, rotation.x)

func _unhandled_input(event: InputEvent) -> void:
	# Handle Mouse Capture for Panning
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.is_pressed():
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				_is_mouse_captured = true
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				_is_mouse_captured = false
				
	# Handle Mouse Look & Speed adjustments (Only when captured)
	if _is_mouse_captured:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.is_pressed():
				_current_move_speed = clamp(_current_move_speed + speed_step, min_speed, max_speed)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.is_pressed():
				_current_move_speed = clamp(_current_move_speed - speed_step, min_speed, max_speed)
				
		if event is InputEventMouseMotion:
			_camera_rotation.x -= event.relative.x * look_sensitivity
			_camera_rotation.y -= event.relative.y * look_sensitivity
			_camera_rotation.y = clamp(_camera_rotation.y, -PI/2.1, PI/2.1) # Prevent flipping
			
			rotation.y = _camera_rotation.x
			rotation.x = _camera_rotation.y

func _process(delta: float) -> void:
	# WASD and Q/E Movement
	var direction: Vector3 = Vector3.ZERO
	
	if Input.is_physical_key_pressed(KEY_W):
		direction -= transform.basis.z
	if Input.is_physical_key_pressed(KEY_S):
		direction += transform.basis.z
	if Input.is_physical_key_pressed(KEY_A):
		direction -= transform.basis.x
	if Input.is_physical_key_pressed(KEY_D):
		direction += transform.basis.x
	if Input.is_physical_key_pressed(KEY_Q): # Down
		direction -= transform.basis.y
	if Input.is_physical_key_pressed(KEY_E): # Up
		direction += transform.basis.y

	if direction != Vector3.ZERO:
		direction = direction.normalized()
		position += direction * _current_move_speed * delta
