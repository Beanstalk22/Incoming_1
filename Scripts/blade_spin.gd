extends Node3D

@onready var animation_player: AnimationPlayer = $AnimationPlayer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$AnimationPlayer.play("1")
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
