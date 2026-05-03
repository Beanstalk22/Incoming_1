extends RigidBody3D

func interact(player: CharacterBody3D):
	# If the player isn't already carrying something
	if player.held_object == null:
		player.pick_up(self)
