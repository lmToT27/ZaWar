extends Node3D

const FLOOR_HALF_SIZE: float = 14.0
const FLOOR_TOP_Y: float = 0.5

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D

func _ready() -> void:
	var nav_mesh := NavigationMesh.new()
	nav_mesh.set_vertices(PackedVector3Array([
		Vector3(-FLOOR_HALF_SIZE, FLOOR_TOP_Y, -FLOOR_HALF_SIZE),
		Vector3(-FLOOR_HALF_SIZE, FLOOR_TOP_Y, FLOOR_HALF_SIZE),
		Vector3(FLOOR_HALF_SIZE, FLOOR_TOP_Y, FLOOR_HALF_SIZE),
		Vector3(FLOOR_HALF_SIZE, FLOOR_TOP_Y, -FLOOR_HALF_SIZE),
	]))
	nav_mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	nav_region.navigation_mesh = nav_mesh
