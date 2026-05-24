extends Control


@onready var crew_panel: PanelContainer = $Arsenal/Control/crew_panel
@onready var weapon_panel: PanelContainer = $Arsenal/Control/weapon_panel
@onready var armor_panel: PanelContainer = $Arsenal/Control/armor_panel
@onready var cosmetics: PanelContainer = $Arsenal/Control/cosmetics
@onready var vehicles: PanelContainer = $Arsenal/Control/vehicles

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://m_menu.tscn")
	 # Replace with function body.
