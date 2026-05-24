# placeable_item_data.gd
extends Resource
class_name PlaceableItemData

@export var item_id: String = "ammo_box" # e.g., "flak_88", "searchlight", "sandbag_wall"
@export var position: Vector3
@export var rotation: Vector3
