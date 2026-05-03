extends GridContainer

# 1. This allows you to drag the MapEditor node into this slot in the Inspector
@export var editor: MapEditor 

func _ready() -> void:
	# We wait a tiny bit to make sure the ItemRegistry is ready
	await get_tree().process_frame
	render_buttons()

func render_buttons():
	# Clear any old buttons (useful if you call this multiple times)
	for child in get_children():
		child.queue_free()
	
	# 2. Loop through every ID in your Autoloaded ItemRegistry
	var all_item_ids = ItemRegistry.get_all_ids()
	
	for id in all_item_ids:
		var btn = Button.new()
		
		# Format the ID (e.g., "flak_88" becomes "Flak 88")
		btn.text = id.replace("_", " ").capitalize()
		
		# 3. CRITICAL: Buttons created in code often have 0 size. We must set this.
		btn.custom_minimum_size = Vector2(120, 40)
		
		# 4. Connect the button to the editor's placement function
		if editor:
			btn.pressed.connect(editor.select_item_for_placement.bind(id))
		else:
			push_warning("UI Error: MapEditor node not assigned in the Inspector!")
		
		# Add it to the GridContainer
		add_child(btn)
