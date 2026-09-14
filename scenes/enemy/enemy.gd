class_name Enemy
extends CharacterBody3D

enum EnemyState { CHASE, ATTACK, STUNNED, OBSERVE }

const OBSERVE_STREAK_THRESHOLD: int = 3

@export var move_speed: float = 3.0
@export var attack_range: float = 1.5
@export var attack_damage_day: float = 10.0
@export var attack_damage_night: float = 18.0
@export var attack_cooldown: float = 1.2
@export var stun_duration: float = 0.8
@export var max_health: float = 60.0
@export var target_update_interval: float = 0.2

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var health: float
var state: EnemyState = EnemyState.CHASE
var player: Player

var _attack_cooldown_timer: float = 0.0
var _stun_timer: float = 0.0
var _target_update_timer: float = 0.0

func _ready() -> void:
	add_to_group("enemy")
	health = max_health

func _physics_process(delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return

	match state:
		EnemyState.CHASE:
			_process_chase(delta)
		EnemyState.ATTACK:
			_process_attack(delta)
		EnemyState.STUNNED:
			_process_stunned(delta)
		EnemyState.OBSERVE:
			_process_observe()

	move_and_slide()

func _process_chase(delta: float) -> void:
	_target_update_timer -= delta
	if _target_update_timer <= 0.0:
		_target_update_timer = target_update_interval
		nav_agent.target_position = player.global_position

	if global_position.distance_to(player.global_position) <= attack_range:
		velocity = Vector3.ZERO
		_attack_cooldown_timer = 0.0
		state = _next_attack_state()
		return

	var next_pos := nav_agent.get_next_path_position()
	var dir := next_pos - global_position
	dir.y = 0.0
	velocity = dir.normalized() * move_speed if dir.length() > 0.01 else Vector3.ZERO

func _process_attack(delta: float) -> void:
	velocity = Vector3.ZERO
	if global_position.distance_to(player.global_position) > attack_range:
		state = EnemyState.CHASE
		return

	_attack_cooldown_timer -= delta
	if _attack_cooldown_timer <= 0.0:
		_attack_cooldown_timer = attack_cooldown
		var damage := attack_damage_night if GameManager.is_night else attack_damage_day
		player.take_damage(damage)

func _process_stunned(delta: float) -> void:
	velocity = Vector3.ZERO
	_stun_timer -= delta
	if _stun_timer <= 0.0:
		state = EnemyState.CHASE

func _process_observe() -> void:
	velocity = Vector3.ZERO
	if not _is_redemption_active():
		state = EnemyState.CHASE

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
		state = EnemyState.STUNNED
		_stun_timer = stun_duration
