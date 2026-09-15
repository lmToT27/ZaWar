extends Node3D

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 6.0
@export var base_max_enemies: int = 4
@export var spawn_radius: float = 12.0
@export var min_distance_from_player: float = 6.0
@export var spawn_y: float = 0.5

@onready var spawn_timer: Timer = $SpawnTimer

var player: Player

func _ready() -> void:
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)

func _on_spawn_timer_timeout() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return

	var target_max := maxi(base_max_enemies - GameManager.pacifist_streak, 0)
	if get_tree().get_nodes_in_group("enemy").size() >= target_max:
		return

	var spawn_pos: Variant = _find_spawn_position()
	if spawn_pos == null:
		return

	var enemy := enemy_scene.instantiate()
	get_parent().add_child(enemy)
	enemy.global_position = spawn_pos

func _find_spawn_position() -> Variant:
	var forward := -player.global_transform.basis.z
	for _attempt in range(8):
		var angle := randf() * TAU
		var dist := randf_range(min_distance_from_player, spawn_radius)
		var pos := player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * dist
		pos.y = spawn_y
		var to_pos := (pos - player.global_position).normalized()
		if forward.dot(to_pos) < 0.3:
			# clamp to the actual walkable navmesh so a spawn point can never
			# land outside the level bounds (near/inside a wall) regardless
			# of where the player is standing.
			return NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, pos)
	return null
