extends Control


@onready var profile: Button = $M_menu/profile_container/HBoxContainer/VBoxContainer/Profile
@onready var progress_bar: ProgressBar = $M_menu/profile_container/HBoxContainer/VBoxContainer/ProgressBar

@onready var credit: Button = $M_menu/Top_panel/HBoxContainer/Credit 
@onready var gold: Button = $M_menu/Top_panel/HBoxContainer/Gold 

func _ready() -> void:
	# Secure safely connected currency listener boundaries
	if CurrencyManager.has_signal("currency_changed"):
		CurrencyManager.currency_changed.connect(_on_currency_changed)
		
	_on_currency_changed("credit", CurrencyManager.get_balance("credit")) 
	_on_currency_changed("gold", CurrencyManager.get_balance("gold")) 

# Navigation Methods
func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://settings_from_main_menu.tscn") 

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://select_map.tscn") 

func _on_profile_pressed() -> void:
	get_tree().change_scene_to_file("res://ProfileLayer.tscn") 

func _on_arsenal_pressed() -> void:
	get_tree().change_scene_to_file("res://arsenal.tscn") 
	
# Consolidated conditional formatting patterns 
func _on_currency_changed(type: String, new_amount: int) -> void:
	match type:
		"credit":
			if is_instance_valid(credit):
				credit.text = "Credit: %d" % new_amount 
		"gold":
			if is_instance_valid(gold):
				gold.text = "Gold: %d" % new_amount
func _update_profile_ui() -> void:
	var data = GameManager.player_profile
	if data:
		# Ipakita ang Pangalan at Level sa iisang button
		profile.text = data.player_name + " (Lv. " + str(data.level) + ")"
		
		# I-setup ang XP bar (Halimbawa: 100 XP per level)
		progress_bar.max_value = 100
		progress_bar.value = data.current_xp
