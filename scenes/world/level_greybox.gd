extends Node3D

const FLOOR_HALF_SIZE: float = 14.0
const FLOOR_TOP_Y: float = 0.5
# Hand-declared navmesh has no agent-radius erosion like a real bake would -
# shrink it well inside the floor so agents never path close enough to the
# walls for their own collision radius to clip into one.
const WALL_SAFETY_MARGIN: float = 1.5
const NAV_HALF_SIZE: float = FLOOR_HALF_SIZE - WALL_SAFETY_MARGIN

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D

func _ready() -> void:
	var nav_mesh := NavigationMesh.new()
	nav_mesh.set_vertices(PackedVector3Array([
		Vector3(-NAV_HALF_SIZE, FLOOR_TOP_Y, -NAV_HALF_SIZE),
		Vector3(-NAV_HALF_SIZE, FLOOR_TOP_Y, NAV_HALF_SIZE),
		Vector3(NAV_HALF_SIZE, FLOOR_TOP_Y, NAV_HALF_SIZE),
		Vector3(NAV_HALF_SIZE, FLOOR_TOP_Y, -NAV_HALF_SIZE),
	]))
	nav_mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	nav_region.navigation_mesh = nav_mesh
