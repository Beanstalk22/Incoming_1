# custom_map_data.gd
extends Resource
class_name CustomMapData

@export var map_name: String = "New Map"
@export var environment_settings: Dictionary # Time of day, weather
@export var placed_items: Array[PlaceableItemData] = []
@export var terrain_vertices: PackedVector3Array = [] 



# --- NEW ENVIRONMENT VARIABLES ---
@export var sun_rotation: Vector3
@export var sun_color: Color = Color.WHITE
@export var sun_energy: float = 1.0

@export var fog_enabled: bool = true
@export var fog_color: Color = Color.WHITE
@export var fog_density: float = 0.01
