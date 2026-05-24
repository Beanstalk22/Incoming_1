extends Node

signal enemies_left_changed(count) # ADD THIS SIGNAL
signal wave_started(num, count)
signal wave_cleared(num)

@export_group("Prefabs")
@export var spotter_scene: PackedScene = preload("res://ai_spotter_plane.tscn")
@export var fighter_scene: PackedScene = preload("res://ai_fighter_plane.tscn")
@export var bomber_fighter_scene: PackedScene = preload("res://light_plane.tscn")
@export var bomber_scene: PackedScene

@export_group("Wave Scaling")
@export var base_enemy_count: int = 1
@export var linear_growth: int = 2 

var current_wave: int = 0
var active_enemies: int = 0
var spawn_queue: Array[String] = []

func _ready() -> void:
	# Small delay before first wave
	await get_tree().create_timer(3.0).timeout
	start_next_wave()

func start_next_wave():
	current_wave += 1
	
	# SCALING LOGIC: 
	# Using a custom sequence that feels like Fibonacci early 
	# but stays manageable: Count = Base + (Wave * Growth)
	var total_to_spawn = base_enemy_count + (current_wave * linear_growth)
	
	_prepare_queue(total_to_spawn)
	active_enemies = total_to_spawn
	
	wave_started.emit(current_wave, total_to_spawn)
	enemies_left_changed.emit(active_enemies) #
	_process_spawn_queue()

func _prepare_queue(total: int):
	spawn_queue.clear()
	var remaining = total
	
	# Rule 1: Max 3 Spotters
	var spotters = clampi(remaining, 0, 3)
	remaining -= spotters
	
	# Rule 2: Max 20 Fighters
	var fighters = clampi(remaining, 0, 20)
	remaining -= fighters

	
	# Rule 3: Max 20 Fighter-Bombers
	var f_bombers = clampi(remaining, 0, 20)
	remaining -= f_bombers
	
	# Rule 4: Everything else is a heavy Bomber
	var bombers = max(0, remaining)
	
	for i in spotters: spawn_queue.append("spotter")
	for i in fighters: spawn_queue.append("fighter")
	for i in f_bombers: spawn_queue.append("fighter_bomber")
	for i in bombers: spawn_queue.append("bomber")
	
	# Randomize spawn order so types are mixed
	spawn_queue.shuffle()

func _process_spawn_queue():
	while spawn_queue.size() > 0:
		var type = spawn_queue.pop_front()
		_spawn_enemy(type)
		# Staggered spawning so they don't pop in all at once
		await get_tree().create_timer(1.5).timeout

func _spawn_enemy(type: String):
	var scene: PackedScene
	match type:
		"spotter": scene = spotter_scene
		"fighter": scene = fighter_scene
		"fighter_bomber": scene = bomber_fighter_scene
		"bomber": scene = bomber_scene
	
	if scene:
		var enemy = scene.instantiate()
		get_parent().add_child(enemy)
		
		# UPDATE THIS CHECK: Safely look for the destroyed signal instead of pooling
		if enemy.has_signal("plane_destroyed"):
			enemy.is_wave_managed = true
			enemy.plane_destroyed.connect(_on_plane_down)

func _on_plane_down(_plane_node):
	active_enemies -= 1 # Reduce the count when a plane is destroyed
	enemies_left_changed.emit(active_enemies) # EMIT THE NEW COUNT
	
	if active_enemies <= 0:
		wave_cleared.emit(current_wave)
		print("Wave ", current_wave, " Cleared!")
		await get_tree().create_timer(5.0).timeout 
		start_next_wave()
