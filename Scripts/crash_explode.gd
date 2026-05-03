extends GPUParticles3D

func _body(_on_body_entered: Node3D):
	
	emitting = true
	
	await finished
	# Wait for the particles to finish their cycle
	
	# Delete the node to free up RAM
	queue_free()
