# custom_map_data.gd
extends Resource
class_name CustomMapData

@export var map_name: String = "New Map"
@export var environment_settings: Dictionary # Time of day, weather
@export var placed_items: Array[PlaceableItemData] = []

func _load_map_on_menu():
	#idk wwhat to do here
	pass
