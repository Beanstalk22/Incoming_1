# game.gd main game
extends Node3D

@onready var terrain_mesh_node: MeshInstance3D = %terrainmesh
@onready var world_env: WorldEnvironment = $Environment/WorldEnvironment
@onready var sun: DirectionalLight3D = $Environment/DirectionalLight3D

# The central dictionary mapping IDs to file paths.
var _registry: Dictionary = {
	"Lewis_Gun": "res://gun.tscn",
	"ammo_box": "res://ammo_box.tscn",
	"speed_boat": "res://speed_boat.tscn",
	"player_spawn": "res://player_spawn.tscn",
	"tent": "res://camp_tent.tscn"
}

func _ready():
	# As soon as the game scene starts, it looks in the locker
	if GameManager.current_custom_map:
		_build_map(GameManager.current_custom_map)
	else:
		print("No map data found in GameManager!")

func spawn_player(spawn_position: Vector3):
	var player_scene = load("res://player.tscn")
	if player_scene:
		var player_instance = player_scene.instantiate()
		add_child(player_instance)
		player_instance.global_position = spawn_position
	else:
		print("Error: Player scene not found at res://player.tscn")

# --- Registry Helpers ---

func get_scene_path(item_id: String) -> String:
	return _registry.get(item_id, "")

func get_packed_scene(item_id: String) -> PackedScene:
	var path = get_scene_path(item_id)
	if path != "":
		return load(path) as PackedScene
	return null

func _build_map(data: CustomMapData):
# 1. LOAD THE TERRAIN
	if data.terrain_vertices.size() > 0 and is_instance_valid(terrain_mesh_node):

		# Convert primitive mesh into editable ArrayMesh if needed
		if not terrain_mesh_node.mesh is ArrayMesh:
			var array_mesh := ArrayMesh.new()
			array_mesh.add_surface_from_arrays(
				Mesh.PRIMITIVE_TRIANGLES,
				terrain_mesh_node.mesh.get_mesh_arrays()
			)
			# Inherit the material from the primitive mesh
			array_mesh.surface_set_material(0, terrain_mesh_node.mesh.surface_get_material(0))
			terrain_mesh_node.mesh = array_mesh

		var mesh := terrain_mesh_node.mesh as ArrayMesh
		var arrays = mesh.surface_get_arrays(0)
		
		# SAFETY CHECK: Ensure the saved vertex count matches the current mesh's vertex count
		if arrays[Mesh.ARRAY_VERTEX].size() != data.terrain_vertices.size():
			push_error("Map Data vertex count does not match the base terrain mesh! Cannot load terrain.")
		else:
			# Cache the material before clearing surfaces
			var terrain_material = mesh.surface_get_material(0)

			# Replace vertices with saved sculpted terrain
			arrays[Mesh.ARRAY_VERTEX] = data.terrain_vertices

			# Rebuild mesh properly using a temporary ArrayMesh
			var temp_mesh := ArrayMesh.new()
			temp_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

			var st := SurfaceTool.new()
			st.create_from(temp_mesh, 0)
			st.generate_normals()

			mesh.clear_surfaces()
			st.commit(mesh)
			
			# Re-apply the cached material
			if terrain_material:
				mesh.surface_set_material(0, terrain_material)

			# Rebuild collision
			var static_body := terrain_mesh_node.get_parent() as StaticBody3D
			if static_body:
				var col_shape := static_body.get_node_or_null("CollisionShape3D") as CollisionShape3D
				if col_shape:
					# Clear old shape before assigning the new one to prevent memory leaks
					col_shape.shape = null
					col_shape.shape = mesh.create_trimesh_shape()
	# 2. LOAD THE ENVIRONMENT
	if is_instance_valid(world_env) and is_instance_valid(sun):
		var env = world_env.environment
		env.volumetric_fog_enabled = data.fog_enabled
		env.volumetric_fog_albedo = data.fog_color
		env.volumetric_fog_density = data.fog_density
			
		sun.rotation = data.sun_rotation
		sun.light_color = data.sun_color
		sun.light_energy = data.sun_energy

	# 3. LOAD THE ITEMS
	for item in data.placed_items:
		var scene = get_packed_scene(item.item_id)
		if scene:
			var instance = scene.instantiate()
			add_child(instance)
			
			instance.global_position = item.position
			# Ensure we use global_rotation (radians) which is how it's saved in the editor
			instance.global_rotation = item.rotation 
			
			# Specific item logic
			if item.item_id == "player_spawn":
				spawn_player(item.position)
			elif item.item_id == "Lewis_Gun" and instance.has_method("set_friendly_fire"):
				instance.set_friendly_fire(GameManager.friendly_fire)
