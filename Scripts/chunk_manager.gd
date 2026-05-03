extends Node3D

# 1. Settings
var chunk_scene = preload("res://chunk_manager.tscn") # Load our tile
var chunk_size = 256        # Must match the PlaneMesh size
var view_distance = 2       # How many chunks to show around player (2 = 5x5 grid)
var active_chunks = {}      # A dictionary to remember which chunks exist

# LOD Settings: Ring Distance -> Resolution
var lod_resolutions = {
	0: 256, # Center (Player's chunk)
	1: 128,  # Mid ring (1 chunk away)
	2: 64   # Outer ring (2 chunks away)
}

@onready var player = get_viewport().get_camera_3d() # Follow the camera

func _process(_delta):
	update_chunks()

func update_chunks():
	# 2. Find where the player is in "Grid Coordinates"
	var p_x = int(floor(player.global_position.x / chunk_size))
	var p_z = int(floor(player.global_position.z / chunk_size))

	# 3. Check the area around the player
	for x in range(p_x - view_distance, p_x + view_distance + 1):
		for z in range(p_z - view_distance, p_z + view_distance + 1):
			var chunk_coord = Vector2(x, z)
			
			# Calculate how many "rings" away this chunk is from the player
			var dist_x = abs(x - p_x)
			var dist_z = abs(z - p_z)
			var ring_distance = max(dist_x, dist_z) # Will be 0, 1, or 2
			
			# Get the target resolution for this ring (fallback to 16 if outside defined rings)
			var target_res = lod_resolutions.get(ring_distance, 16)
			
			# If we haven't built a chunk here yet, build it!
			if not active_chunks.has(chunk_coord):
				create_chunk(chunk_coord, target_res)
			else:
				# If it exists, update its resolution (player might have moved closer/further)
				update_chunk_lod(active_chunks[chunk_coord], target_res)

	# 4. Cleanup: Remove chunks that are too far away
	for coord in active_chunks.keys():
		if abs(coord.x - p_x) > view_distance or abs(coord.y - p_z) > view_distance:
			active_chunks[coord].queue_free() # Delete from game
			active_chunks.erase(coord)        # Forget it from memory

func create_chunk(coord, resolution):
	var new_chunk = chunk_scene.instantiate()
	
	# Position the chunk. Grid coordinate * size = World position
	new_chunk.position = Vector3(coord.x * chunk_size, 0, coord.y * chunk_size)
	
	add_child(new_chunk)
	active_chunks[coord] = new_chunk # Save it to our list
	
	# Apply the initial LOD resolution
	update_chunk_lod(new_chunk, resolution)

func update_chunk_lod(chunk, resolution):
	# OPTION A: If you created a custom script on your chunk_scene with this function:
	if chunk.has_method("set_resolution"):
		chunk.set_resolution(resolution)
		
	# OPTION B: Fallback - Auto-find the MeshInstance3D and update it directly
	else:
		# Find the MeshInstance (whether it is the root node or named "MeshInstance3D")
		var mesh_instance = chunk if chunk is MeshInstance3D else chunk.get_node_or_null("MeshInstance3D")
		
		if mesh_instance and mesh_instance.mesh is PlaneMesh:
			# Critical: Make sure the mesh is unique so we don't accidentally change ALL chunks at once
			if not mesh_instance.mesh.resource_local_to_scene:
				mesh_instance.mesh = mesh_instance.mesh.duplicate()
				mesh_instance.mesh.resource_local_to_scene = true
				
			# Update subdivisions if they don't match our target LOD
			if mesh_instance.mesh.subdivide_width != resolution:
				mesh_instance.mesh.subdivide_width = resolution
				mesh_instance.mesh.subdivide_depth = resolution
