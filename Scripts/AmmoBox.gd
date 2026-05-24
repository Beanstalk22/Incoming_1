extends RigidBody3D


@export var item_icon: Texture2D = preload("res://icon.svg")
@export var item_name: String = "ammo box" 

func interact(player: CharacterBody3D):
	# Check if inventory has space instead of just checking held_object
	if player.inventory.size() < player.max_slots:
		player.collect_item(self)
