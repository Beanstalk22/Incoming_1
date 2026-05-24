# level_manager.gd
extends Node

signal xp_changed(current_xp: int, required_xp: int)
signal leveled_up(new_level: int)

var current_level: int = 1
var current_xp: int = 0

@export var base_xp: int = 100
@export var xp_exponent: float = 1.5

func _ready() -> void:
	# I-load ang saved data mula sa GameManager bago mag-emit
	if GameManager.player_profile:
		current_level = GameManager.player_profile.level
		current_xp = GameManager.player_profile.current_xp
		
	await get_tree().process_frame
	xp_changed.emit(current_xp, get_required_xp(current_level))

func get_required_xp(level: int) -> int:
	return int(base_xp * pow(level, xp_exponent))

func add_xp(amount: int) -> void:
	current_xp += amount

	while current_xp >= get_required_xp(current_level):
		current_xp -= get_required_xp(current_level) 
		current_level += 1
		leveled_up.emit(current_level)
		print("Level Up! You are now Level: ", current_level)

	xp_changed.emit(current_xp, get_required_xp(current_level))
	
	# I-SAVE ANG BAGONG XP AT LEVEL SA PLAYER PROFILE
	if GameManager.player_profile:
		GameManager.player_profile.current_xp = current_xp
		GameManager.player_profile.level = current_level
		GameManager.save_player_profile()
