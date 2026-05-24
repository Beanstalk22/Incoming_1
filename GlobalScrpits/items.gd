extends GridContainer

@export var editor: MapEditor 

# Define colors for a "Tactical" UI look
const COLOR_NORMAL = Color("3d4043")
const COLOR_HOVER = Color("949aa1ff")
const COLOR_PRESSED = Color("1a1c1e")

func _ready() -> void:
	# Centering the GridContainer itself within its parent
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Adjust spacing between buttons
	add_theme_constant_override("h_separation", 5)
	add_theme_constant_override("v_separation", 10)
	
	await get_tree().process_frame
	render_buttons()

func render_buttons():
	for child in get_children():
		child.queue_free()
	
	var all_item_ids = ItemRegistry.get_all_ids()
	
	for id in all_item_ids:
		var btn = Button.new()
		
		# 1. Text Styling
		btn.text = id.replace("_", " ").capitalize()
		btn.custom_minimum_size = Vector2(140, 45) # Slightly larger for better tap/click targets
		
		# 2. Applying Stylish Appearance
		_apply_button_style(btn)
		
		# 3. Alignment & Expansion
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		if editor:
			btn.pressed.connect(editor.select_item_for_placement.bind(id))
		
		add_child(btn)

func _apply_button_style(btn: Button):
	# Create a flat look with rounded corners
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = COLOR_NORMAL
	style_normal.set_corner_radius_all(4) # Rounded corners
	style_normal.set_border_width_all(1)
	style_normal.border_color = Color("6b6f74") # Subtle border
	
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = COLOR_HOVER
	
	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = COLOR_PRESSED
	
	# Apply styles to the button's theme overrides
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new()) # Hide the focus ring
	
	# Font styling
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", Color.WHITE)
