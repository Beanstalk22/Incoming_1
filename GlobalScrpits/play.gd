extends Control
# game_settings menu.gd

@onready var option_button: OptionButton = $MarginContainer/BoxContainer/VBoxContainer/Difficulty/OptionButton

#@onready var ff_toggle = $FriendlyFireCheckBox
#@onready var ai_slider = $AICountSlider

# 1. You need to define this variable at the top!
var selected_map = null

# This is your resource variable
var map_to_load: CustomMapData = null

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://menu.tscn")

func _on_start_pressed() -> void:
	#GameManager.friendly_fire = ff_toggle.button_pressed
	#GameManager.ai_count = ai_slider.value

	get_tree().change_scene_to_file("res://game.tscn")
	


func _on_friendly_fire_toggled(_toggled_on: bool) -> void:
	pass # Replace with function body.


func _on_spin_box_changed() -> void: #function for how many ai friendlies
	pass # Replace with function body.
