extends StaticBody3D

@onready var pivot: Node3D = $gun/base/turret/cam_pivot

# --- Control Variables ---
var is_controlled: bool = false
var player_ref: CharacterBody3D = null

@onready var mount_pos: Marker3D = $gun/base/turret/MountPos
# ------------------------------

# Fixed paths to include "$gun/" prefix
@onready var audio_stream_player_3d: AudioStreamPlayer3D = $gun/base/turret/pivot/barrel/Muzzle/sfx/AudioStreamPlayer3D
@onready var audio_stream_player_3d_2: AudioStreamPlayer3D = $gun/base/turret/pivot/barrel/Muzzle/sfx/AudioStreamPlayer3D2
@onready var audio_stream_player_3d_3: AudioStreamPlayer3D = $gun/base/turret/pivot/barrel/Muzzle/sfx/AudioStreamPlayer3D3

@export var max_health := 100000.0 # Toned this down slightly for readability
var current_health := 100000.0

@export_group("Settings")
@export var mouse_sensitivity := 0.002
@export var turret_speed := 3.0
@export var barrel_speed := 4.0
@export var barrel_max_pitch := 90.0
@export var barrel_min_pitch := -20.0

@export_group("Combat")
@export var projectile_scene: PackedScene = preload("res://bullet.tscn")
@export var fire_rate := 0.1

@onready var turret: MeshInstance3D = $gun/base/turret
@onready var barrel: MeshInstance3D = $gun/base/turret/pivot/barrel

@onready var camera_node: Camera3D = $gun/Camera3D

@onready var fpv_marker: Camera3D = $gun/base/turret/pivot/barrel/fps
@onready var tpv_marker: Camera3D = $gun/base/turret/cam_pivot/SpringArm3D/tps
@onready var muzzle = $gun/base/turret/pivot/barrel/Muzzle
@onready var muzzle_spark: GPUParticles3D = $gun/base/turret/pivot/barrel/Muzzle/muzzle_spark

var target_yaw := 0.0
var target_pitch := 0.0
var is_third_person : = true
var time_since_last_shot := 0.0
var pitch_min := 0.0
var pitch_max := 0.0

func _ready() -> void:
	current_health = max_health
	target_yaw = turret.rotation.y
	target_pitch = barrel.rotation.x
	pitch_min = deg_to_rad(barrel_min_pitch)
	pitch_max = deg_to_rad(barrel_max_pitch)
	
	# Keep it off until a player hops in
	set_process(false)
	set_process_input(false)

func interact(player: CharacterBody3D) -> void:
	if not is_controlled:
		enter_gun(player)
	else:
		exit_gun()

func enter_gun(player: CharacterBody3D) -> void:
	is_controlled = true
	player_ref = player
	
	# Snap player body to the gun's mount position
	player_ref.global_transform.origin = mount_pos.global_transform.origin
	
	# COMPLETELY disable the player so they cannot rotate, shoot, or process input
	player_ref.process_mode = Node.PROCESS_MODE_DISABLED
	
	# Take over camera control
	camera_node.make_current()
	
	set_process(true)
	set_process_input(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print("MG Manning Started")

func exit_gun() -> void:
	if player_ref:
		is_controlled = false
		
		# Pop player out behind the turret
		var exit_offset = -turret.global_transform.basis.z * 1.5
		player_ref.global_transform.origin += exit_offset
		
		# Re-enable the player
		player_ref.process_mode = Node.PROCESS_MODE_INHERIT
		
		# Return camera control to the player safely
		if "camera" in player_ref and player_ref.camera:
			player_ref.camera.make_current()
		
		set_process(false)
		set_process_input(false)
		player_ref = null
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		

func _input(event: InputEvent) -> void:
	# Ensure we only process input if the gun is active and mouse is captured
	if not is_controlled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return

	if event.is_action_pressed("ui_select"): # Space to exit
		exit_gun()
		return

	# Unified Mouse Motion logic - calculates target only, _process handles the smoothing
	if event is InputEventMouseMotion:
		target_yaw -= event.relative.x * mouse_sensitivity
		target_pitch = clamp(target_pitch + event.relative.y * mouse_sensitivity, pitch_min, pitch_max)

	# Toggle FPV/TPV
	elif event.is_action_pressed("ui_down"):
		is_third_person = !is_third_person
		


func _process(delta: float) -> void:
	if not is_controlled: return

	# 1. Smooth Rotation (Fixed the negative sign bug that was causing violent stutters)
	turret.rotation.y = lerp_angle(turret.rotation.y, target_yaw, delta * turret_speed)
	barrel.rotation.x = lerp_angle(barrel.rotation.x, target_pitch, delta * barrel_speed)
	
	# Optional: Keep player visually locked to mount pos if the turret base itself moves
	if player_ref:
		player_ref.global_transform.origin = mount_pos.global_transform.origin

	# 2. Dynamic Camera Positioning (FPV/TPV)
	var _target_transform = tpv_marker.global_transform if is_third_person else fpv_marker.global_transform
	camera_node.global_transform = camera_node.global_transform.interpolate_with(_target_transform, delta * 10.0)
	# 3. Zoom Logic (Right Click) - applied to the active camera_node
	var zoom_target := 15.0 if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) else 75.0
	camera_node.fov = lerp(camera_node.fov, zoom_target, delta * 10.0)

	# 4. Shooting Logic
	time_since_last_shot += delta
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and time_since_last_shot >= fire_rate:
		fire_weapon()

func fire_weapon() -> void:
	if projectile_scene == null: return
	
	muzzle_spark.restart()
	time_since_last_shot = 0.0
	
	var bullet = projectile_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_transform = muzzle.global_transform
	
	audio_stream_player_3d.play()
	audio_stream_player_3d_2.play()
	audio_stream_player_3d_3.play(.5)

func take_damage(amount: int) -> void:
	current_health -= amount
	if current_health <= 0:
		if is_controlled: exit_gun()
		queue_free()


func _on_ai_plane_body_entered(_body: Node3D) -> void:
	pass # Replace with function body.
