extends MeshInstance3D

func _process(_delta):
	var cam = get_viewport().get_camera_3d()
	if cam:
		# Snap the mesh to the camera's X and Z, but keep Y at 0 (sea level)
		global_position = Vector3(cam.global_position.x, 0, cam.global_position.z)
