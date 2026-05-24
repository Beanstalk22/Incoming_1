extends Resource
class_name PlayerData
# I-save ito bilang "player_data.gd" sa iyong res:// folder

# --- Profile ---
@export var player_name: String = "PLayer"
@export var level: int = 1
@export var current_xp: int = 0

# --- Statistics ---
@export var longest_wave: int = 0
@export var total_takedowns: int = 0
@export var total_repairs: int = 0

# --- Account Connection (Template) ---
@export var is_account_connected: bool = false
@export var account_id: String = ""
@export var account_email: String = ""
@export var account_username: String = ""

# --- Audio & Settings (mula sa lumang setup) ---
@export var master_volume: float = 1.0
@export var music_volume: float = 0.7
@export var sfx_volume: float = 0.8
@export var mouse_sensitivity: float = 0.002
@export var zoom_sensitivity: float = 0.001
