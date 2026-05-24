extends CanvasLayer

var stats: Dictionary = {}
var label: Label

func _ready() -> void:
	layer = 100 # Ensures it renders over all other UI
	
	label = Label.new()
	label.position = Vector2(10, 10)
	
	# Optional: Make text readable against the sky/environment
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	
	add_child(label)

# Call this from anywhere to update or add a new debug line
func update_prop(title: String, value: Variant) -> void:
	stats[title] = value
	_refresh_text()

# Only rebuilds the string when a value actually changes
func _refresh_text() -> void:
	var new_text = ""
	for key in stats:
		new_text += str(key) + ": " + str(stats[key]) + "\n"
	label.text = new_text
