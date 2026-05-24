extends Node

signal settings_updated

const SAVE_PATH = "res://settings.json"

# Your project's new default settings baseline
var config : Dictionary = {
	"graphics": {
		"render_scale": 1.0,
		"vsync": true
	},
	"audio": {
		"master_volume": 1.0,
		"music_volume": 1.,
		"sfx_volume": 1.0
	},
	"controls": {
		"mouse_sensitivity": 0.005,
		"zoom_sens": 0.002
	},
	"profile": {
		"player_name": "Player"
	}
}

func _ready():
	load_settings()
	apply_settings()

func save_settings():
	var json_string = JSON.stringify(config, "\t") 
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()

func load_settings():
	if not FileAccess.file_exists(SAVE_PATH):
		save_settings() 
		return
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var parsed_data = JSON.parse_string(json_string)
		if typeof(parsed_data) == TYPE_DICTIONARY:
			config = parsed_data

func apply_settings():
	# --- GRAPHICS ---
	var gfx = config["graphics"]
	var vsync_mode = DisplayServer.VSYNC_ENABLED if gfx["vsync"] else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vsync_mode)
	get_viewport().scaling_3d_scale = gfx["render_scale"]
	
	# --- AUDIO ---
	var audio = config["audio"]
	set_bus_volume("Master", audio["master_volume"])
	set_bus_volume("BGM", audio["music_volume"])
	set_bus_volume("SFX", audio["sfx_volume"])
	
	settings_updated.emit()

# Clean helper function to change audio bus levels safely
func set_bus_volume(bus_name: String, linear_value: float):
	var bus_index = AudioServer.get_bus_index(bus_name)
	if bus_index != -1: # Checks if the bus actually exists in your Audio panel
		var volume_db = linear_to_db(linear_value)
		AudioServer.set_bus_volume_db(bus_index, volume_db)
