extends StaticBody3D

# Attach this to your Ship node or Water node
@export var water_material: ShaderMaterial
@export var ship_node: Node3D

func _process(_delta: float) -> void:
	if water_material and ship_node:
		# Pass the ship's current global position into the shader
		water_material.set_shader_parameter("ship_world_pos", ship_node.global_position)
