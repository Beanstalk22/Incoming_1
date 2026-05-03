extends Control
# game_settings menu.gd

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
	
