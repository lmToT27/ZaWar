class_name Enemy
extends CharacterBody3D

enum EnemyState { CHASE, ATTACK, STUNNED, OBSERVE }

const OBSERVE_STREAK_THRESHOLD: int = 3

@export var move_speed: float = 3.0
@export var speed_variance: float = 0.15
@export var attack_range: float = 1.5
@export var attack_damage_day: float = 10.0
@export var attack_damage_night: float = 18.0
@export var attack_cooldown: float = 1.2
@export var stun_duration: float = 0.8
@export var max_health: float = 60.0
@export var target_update_interval: float = 0.2
@export var approach_offset_radius: float = 1.5
@export var acceleration: float = 15.0
@export var attack_exit_range_mult: float = 1.3
@export var attack_lunge_distance: float = 0.15
@export var attack_lunge_duration: float = 0.15

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var growl_player: AudioStreamPlayer3D = $GrowlPlayer3D
@onready var mesh: MeshInstance3D = $MeshInstance3D

var health: float
var state: EnemyState = EnemyState.CHASE
var player: Player

var _attack_cooldown_timer: float = 0.0
var _stun_timer: float = 0.0
var _target_update_timer: float = 0.0
var _approach_offset: Vector3 = Vector3.ZERO
var _mesh_base_position: Vector3
var _lunge_timer: float = 0.0
var _lunge_direction: Vector3 = Vector3.ZERO

func _ready() -> void:
	add_to_group("enemy")
	health = max_health
	move_speed *= randf_range(1.0 - speed_variance, 1.0 + speed_variance)
	_target_update_timer = randf_range(0.0, target_update_interval)
	var angle := randf() * TAU
	_approach_offset = Vector3(cos(angle), 0.0, sin(angle)) * randf_range(0.0, approach_offset_radius)
	_mesh_base_position = mesh.position

func _physics_process(delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return

	var desired_velocity := Vector3.ZERO
	match state:
		EnemyState.CHASE:
			desired_velocity = _process_chase(delta)
		EnemyState.ATTACK:
			_process_attack(delta)
		EnemyState.STUNNED:
			_process_stunned(delta)
		EnemyState.OBSERVE:
			_process_observe()

	velocity = velocity.move_toward(desired_velocity, acceleration * delta)
	move_and_slide()
	_update_lunge_offset(delta)

func _horizontal_distance_to_player() -> float:
	var diff := player.global_position - global_position
	diff.y = 0.0
	return diff.length()

func _update_lunge_offset(delta: float) -> void:
	_lunge_timer = maxf(_lunge_timer - delta, 0.0)
	if _lunge_timer <= 0.0:
		mesh.position = _mesh_base_position
		return
	var t := 1.0 - _lunge_timer / attack_lunge_duration
	mesh.position = _mesh_base_position + _lunge_direction * sin(t * PI) * attack_lunge_distance

func _trigger_attack_lunge() -> void:
	_lunge_timer = attack_lunge_duration
	var dir := player.global_position - global_position
	dir.y = 0.0
	_lunge_direction = dir.normalized() if dir.length() > 0.01 else Vector3.ZERO

func _process_chase(delta: float) -> Vector3:
	_target_update_timer -= delta
	if _target_update_timer <= 0.0:
		_target_update_timer = target_update_interval
		var desired_target := player.global_position + _approach_offset
		var map := nav_agent.get_navigation_map()
		if NavigationServer3D.map_get_iteration_id(map) > 0:
			desired_target = NavigationServer3D.map_get_closest_point(map, desired_target)
		nav_agent.target_position = desired_target

	if _horizontal_distance_to_player() <= attack_range:
		_attack_cooldown_timer = 0.0
		_set_state(_next_attack_state())
		return Vector3.ZERO

	var next_pos := nav_agent.get_next_path_position()
	var dir := next_pos - global_position
	dir.y = 0.0
	return dir.normalized() * move_speed if dir.length() > 0.01 else Vector3.ZERO

func _process_attack(delta: float) -> void:
	if _horizontal_distance_to_player() > attack_range * attack_exit_range_mult:
		_set_state(EnemyState.CHASE)
		return

	_attack_cooldown_timer -= delta
	if _attack_cooldown_timer <= 0.0:
		_attack_cooldown_timer = attack_cooldown
		var damage := attack_damage_night if GameManager.is_night else attack_damage_day
		player.take_damage(damage)
		_trigger_attack_lunge()

func _process_stunned(delta: float) -> void:
	_stun_timer -= delta
	if _stun_timer <= 0.0:
		_set_state(EnemyState.CHASE)

func _process_observe() -> void:
	if not _is_redemption_active():
		_set_state(EnemyState.CHASE)

func _next_attack_state() -> EnemyState:
	return EnemyState.OBSERVE if _is_redemption_active() else EnemyState.ATTACK

func _is_redemption_active() -> bool:
	return GameManager.is_night and GameManager.pacifist_streak >= OBSERVE_STREAK_THRESHOLD

func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0.0:
		GameManager.register_kill()
		queue_free()
		return
	if not GameManager.is_night:
		_set_state(EnemyState.STUNNED)
		_stun_timer = stun_duration

func _set_state(new_state: EnemyState) -> void:
	if new_state == state:
		return
	state = new_state
	if new_state == EnemyState.CHASE or new_state == EnemyState.ATTACK:
		if growl_player.stream:
			growl_player.pitch_scale = randf_range(0.9, 1.1)
			growl_player.play()
