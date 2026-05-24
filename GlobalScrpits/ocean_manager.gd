extends Node3D


# Called when the node enters the scene tree for the first time.
# Get the player's current grid position
var player_chunk_x = floor(player.global_position.x / CHUNK_SIZE)
var player_chunk_z = floor(player.global_position.z / CHUNK_SIZE)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
