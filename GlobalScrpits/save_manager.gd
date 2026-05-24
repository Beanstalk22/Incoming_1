# save_manager.gd
extends Node

const SAVE_FILE_PATH = "res://savegame.dat"

func _ready() -> void:
	# 1. ALWAYS load the game first.
	load_game()
	
	# 2. Connect to the signals ONLY AFTER loading is complete.
	# This prevents the game from accidentally saving over itself while booting up.
	CurrencyManager.currency_changed.connect(_on_currency_changed)
	LevelManager.xp_changed.connect(_on_xp_changed)

func save_game() -> void:
	var save_data: Dictionary = {
		"currency_balances": CurrencyManager.balances,
		"player_level": LevelManager.current_level,
		"player_xp": LevelManager.current_xp
	}
	
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()
		print(" [Auto-Save] Progress written to disk successfully.")
	else:
		push_error("Failed to auto-save: ", FileAccess.get_open_error())

# Called automatically whenever any currency is added or spent
func _on_currency_changed(_type: String, _current_balance: int, amount_changed: int = 0) -> void:
	# Small safety check: We only save if an actual transaction occurred.
	# (This ignores initial UI refreshes where amount_changed is 0)
	if amount_changed != 0:
		save_game()

# Called automatically whenever the player earns XP
func _on_xp_changed(_current_xp: int, _required_xp: int) -> void:
	save_game()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		print("No save file found. Starting fresh profile.")
		return
		
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file:
		var save_data = file.get_var()
		file.close()
		
		# Inject data into Currency Manager
		if save_data.has("currency_balances"):
			CurrencyManager.balances = save_data["currency_balances"]
			# Update UI without triggering a save loop (amount_changed is 0)
			for type in CurrencyManager.balances:
				CurrencyManager.currency_changed.emit(type, CurrencyManager.balances[type], 0)
				
		# Inject data into Level Manager
		if save_data.has("player_level"):
			LevelManager.current_level = save_data["player_level"]
		if save_data.has("player_xp"):
			LevelManager.current_xp = save_data["player_xp"]
			var required_xp = LevelManager.get_required_xp(LevelManager.current_level)
			LevelManager.xp_changed.emit(LevelManager.current_xp, required_xp)
			
		print("Game successfully loaded!")
