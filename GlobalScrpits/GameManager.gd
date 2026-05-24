# GameManager.gd
extends Node

# --- IN-GAME VARIABLES ---
var player: CharacterBody3D = null 
var current_custom_map = null 
var total_score: int = 0
signal score_changed(new_score)

# --- APP/PROFILE VARIABLES ---
const SAVE_PATH = "res://player_profile.tres" 
var player_profile: Resource = null 

signal data_loaded


func _ready() -> void:
	load_player_profile()

# ==========================================
# APP & PROFILE LOGIC
# ==========================================



func load_player_profile() -> void:
	if ResourceLoader.exists(SAVE_PATH):
		var loaded_res = ResourceLoader.load(SAVE_PATH)
		if "player_name" in loaded_res:
			player_profile = loaded_res
			print("[LOGBOOK] Loaded existing service record for: ", player_profile.player_name)
		else:
			printerr("[LOGBOOK] File at save path is not a valid PlayerData resource! Resetting.")
			_create_default_profile()
	else:
		_create_default_profile()
	
	apply_audio_settings()
	data_loaded.emit()

func _create_default_profile() -> void:
	if ClassDB.class_exists("PlayerData"):
		player_profile = ClassDB.instantiate("PlayerData")
	else:
		player_profile = load("res://player_data.gd").new()
		
	if "player_name" in player_profile and player_profile.player_name.is_empty():
		player_profile.player_name = "Player"
	
	if "master_volume" in player_profile: player_profile.master_volume = 1
	if "music_volume" in player_profile: player_profile.music_volume = 0.7
	if "sfx_volume" in player_profile: player_profile.sfx_volume = 0.8
	if "mouse_sensitivity" in player_profile: player_profile.mouse_sensitivity = 0.002
	if "zoom_sensitivity" in player_profile: player_profile.zoom_sensitivity = 0.001
	
	save_player_profile()
	print("[LOGBOOK] Opened new wartime player logbook.")

func save_player_profile() -> void:
	if player_profile:
		var err = ResourceSaver.save(player_profile, SAVE_PATH)
		if err != OK:
			printerr("[LOGBOOK] Failed to save profile! Error code: ", err)

# ==========================================
# SETTINGS APPLICATION LOGIC
# ==========================================

func apply_audio_settings() -> void:
	if not player_profile: return
	
	var music_val = player_profile.get("music_volume") if "music_volume" in player_profile else 0.7
	var sfx_val = player_profile.get("sfx_volume") if "sfx_volume" in player_profile else 0.8
	var master_val = player_profile.get("master_volume") if "master_volume" in player_profile else 1.0
	
	var music_bus = AudioServer.get_bus_index("Music")
	if music_bus != -1:
		AudioServer.set_bus_volume_db(music_bus, linear_to_db(music_val))
		
	var sfx_bus = AudioServer.get_bus_index("SFX")
	if sfx_bus != -1:
		AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(sfx_val))
		
		
	var master = AudioServer.get_bus_index("Master")
	if master != -1:
		AudioServer.set_bus_volume_db(master, linear_to_db(master_val))
	

func apply_control_settings() -> void:
	if not player or not player_profile: return
	
	var sens = player_profile.get("mouse_sensitivity") if "mouse_sensitivity" in player_profile else 0.002
	var zoom = player_profile.get("zoom_sensitivity") if "zoom_sensitivity" in player_profile else 0.001
	
	if "mouse_sensitivity" in player: player.mouse_sensitivity = sens
	if "zoom_sensitivity" in player: player.zoom_sensitivity = zoom
		
	print("[CONTROLS] Handwheel sensitivity calibrated to: ", sens, " | Zoom Gear: ", zoom)

# ==========================================
# IN-GAME LOGIC
# ==========================================

func add_points(amount: int):
	total_score += amount
	score_changed.emit(total_score)

func start_game(map_data): 
	if map_data == null:
		print("[ERROR] No map dispatch found!")
		return

	var player_scene = preload("res://player.tscn")
	var spawn_pos = Vector3.ZERO
	
	for item in map_data.placed_items:
		if item.item_id == "player_spawn":
			spawn_pos = item.position
			break
			
	var player_instance = player_scene.instantiate()
	
	var current_scene = get_tree().current_scene
	if current_scene:
		current_scene.add_child(player_instance)
	else:
		printerr("[ERROR] No current scene found to spawn player into.")
		return
	
	self.player = player_instance 
	player_instance.global_position = spawn_pos
	
	apply_control_settings()
	

# --- STATISTICS TRACKERS ---
func add_takedown() -> void:
	if player_profile:
		player_profile.total_takedowns += 1
		save_player_profile()

func add_repair() -> void:
	if player_profile:
		player_profile.total_repairs += 1
		save_player_profile()

func update_longest_wave(wave: int) -> void:
	if player_profile and wave > player_profile.longest_wave:
		player_profile.longest_wave = wave
		save_player_profile()
