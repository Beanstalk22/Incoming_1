# level_bar.gd
extends ProgressBar

func _ready() -> void:
	# 1. Connect ang signal para sa mga susunod na XP updates
	LevelManager.xp_changed.connect(_on_xp_changed)
	
	# 2. I-set agad ang value at max_value pagka-load ng bagong scene
	# Gagamitin natin yung function mong get_required_xp()
	max_value = LevelManager.get_required_xp(LevelManager.current_level)
	value = LevelManager.current_xp

func _on_xp_changed(current_xp: int, required_xp: int) -> void:
	max_value = required_xp
	value = current_xp
