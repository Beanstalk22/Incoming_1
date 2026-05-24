extends Control

@onready var name_label: Label = %NameLabel
@onready var level_label: Label = %LevelLabel

# ... existing code ...
@onready var profile: Panel = $ProfileLayer/Control/profile
@onready var statistics: Panel = $ProfileLayer/Control/statistics
@onready var accounts: Panel = $ProfileLayer/Control/accounts

func _ready() -> void:
	_hide_all_panels()
	profile.visible = true # Default na bukas
	_load_profile_data()

func _hide_all_panels() -> void:
	profile.visible = false
	statistics.visible = false
	accounts.visible = false

func _load_profile_data() -> void:
	var data = GameManager.player_profile
	if not data: return
	
	# PAALALA: Gumawa ng mga Label nodes sa loob ng iyong Panels na may ganitong mga pangalan:
	
	# Profile UI
	if profile.has_node("VBoxContainer/NameLabel"): profile.get_node("VBoxContainer/NameLabel").text = "Name: " + data.player_name
	if profile.has_node("$LevelLabel"): profile.get_node("$LevelLabel").text = "Level: " + str(data.level)
	
	# Statistics UI
	if statistics.has_node("VBoxContainer/WaveLabel"): statistics.get_node("VBoxContainer/WaveLabel").text = "Longest Wave Suvived: " + str(data.longest_wave)
	if statistics.has_node("VBoxContainer/TakeDowns"): statistics.get_node("VBoxContainer/TakeDowns").text = "Total Takedowns: " + str(data.total_takedowns)
	if statistics.has_node("VBoxContainer/Repairs"): statistics.get_node("VBoxContainer/Repairs").text = "Total Repairs: " + str(data.total_repairs)
	
	# Account UI (Template)
	if accounts.has_node("VBoxContainer/StatusLabel"): 
		var status = "Connected (" + data.account_username + ")" if data.is_account_connected else "Hindi Konektado"
		accounts.get_node("VBoxContainer/StatusLabel").text = "Status: " + status

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://m_menu.tscn")

func _on_profile_pressed() -> void:
	_hide_all_panels()
	profile.visible = true
	_load_profile_data()

func _on_statistic_pressed() -> void:
	_hide_all_panels()
	statistics.visible = true
	_load_profile_data()

func _on_account_pressed() -> void:
	_hide_all_panels()
	accounts.visible = true
	_load_profile_data()
