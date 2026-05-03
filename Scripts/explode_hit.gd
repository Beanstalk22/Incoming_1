extends GPUParticles3D
@onready var impact: AudioStreamPlayer = $Node3D/Impact

func _ready() -> void:
	
	$Node3D/Whizz.play(.1)
	$Node3D/ArrowWhizz.play(.01)
	
	emitting = true
	
	await finished
	# Wait for the particles to finish their cycle
	
	# Delete the node to free up RAM
	queue_free()
