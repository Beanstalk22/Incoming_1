extends Control

@export var item_name: String = "Item"
@onready var container = $control/HBoxContainer
var slots: Array = []

func _ready():
	slots = container.get_children()
	update_selection(-1) # Start with nothing selected

# Highlights the active slot's border and dims others
func update_selection(current_index: int):
	for i in range(slots.size()):
		var slot = slots[i]
		var border = slot.get_node_or_null("Border") # Safely look for a dedicated border node
		
		if i == current_index:
			slot.modulate = Color(1.0, 1.0, 1.0, 1.0) # Full brightness
			if border:
				border.visible = true
				border.modulate = Color(1.0, 0.8, 0.0, 1.0) # Gold Highlight
		else:
			slot.modulate = Color(0.6, 0.6, 0.6, 0.8) # Dimmed unselected slot
			if border:
				border.visible = false # Hide border when not selected

# Updates the icons based on the player's inventory
func refresh_icons(inventory: Array):
	for i in range(slots.size()):
		var icon_rect = slots[i].get_node("TextureRect")
		if i < inventory.size():
			icon_rect.texture = inventory[i].item_icon
		else:
			icon_rect.texture = null
