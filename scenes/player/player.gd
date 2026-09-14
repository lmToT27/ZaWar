class_name Player
extends CharacterBody3D

enum PlayerState { IDLE, COMBAT, SHEATHE }

const GRAVITY: float = 9.8

@export var move_speed: float = 5.0
@export var jump_velocity: float = 3.8
@export var fall_gravity_multiplier: float = 1.6
@export var landing_recovery_time: float = 0.3
@export var landing_recovery_speed_mult: float = 0.4
@export var mouse_sensitivity: float = 0.003
@export var max_health: float = 100.0
@export var max_stamina: float = 100.0
@export var base_stamina_cost: float = 10.0
@export var base_attack_damage: float = 25.0
@export var regen_delay: float = 2.0
@export var health_regen_rate: float = 10.0
@export var stamina_regen_rate: float = 15.0
@export var sheathe_delay: float = 1.5

@onready var head: Node3D = $Head
@onready var melee_hitbox: Area3D = $Head/Camera3D/MeleeHitbox
@onready var regen_delay_timer: Timer = $RegenDelayTimer

var health: float
var stamina: float
var state: PlayerState = PlayerState.IDLE

var _camera_pitch: float = 0.0
var _sheathe_elapsed: float = 0.0
var _air_time: float = 0.0
var _was_on_floor: bool = true
var _landing_recovery_timer: float = 0.0

func _ready() -> void:
	add_to_group("player")
	health = max_health
	stamina = max_stamina
	regen_delay_timer.wait_time = regen_delay
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_camera_pitch = clampf(_camera_pitch - event.relative.y * mouse_sensitivity, -1.4, 1.4)
		head.rotation.x = _camera_pitch
	elif event.is_action_pressed("attack") and state != PlayerState.SHEATHE:
		state = PlayerState.COMBAT
		_attack()
	elif event.is_action_pressed("sheathe") and state == PlayerState.COMBAT:
		_sheathe_elapsed = 0.0
		state = PlayerState.SHEATHE

func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_handle_state(delta)
	_handle_regen(delta)
	move_and_slide()
	_handle_landing(delta)

func _handle_movement(delta: float) -> void:
	if not is_on_floor():
		var gravity_scale := fall_gravity_multiplier if velocity.y < 0.0 else 1.0
		velocity.y -= GRAVITY * gravity_scale * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	var speed := move_speed
	if _landing_recovery_timer > 0.0:
		speed *= landing_recovery_speed_mult

	var input_dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)
	var move_dir := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	velocity.x = move_dir.x * speed
	velocity.z = move_dir.z * speed

func _handle_landing(delta: float) -> void:
	var grounded := is_on_floor()
	if grounded:
		if not _was_on_floor and _air_time >= 0.25:
			_landing_recovery_timer = landing_recovery_time
		_air_time = 0.0
	else:
		_air_time += delta
	_was_on_floor = grounded
	_landing_recovery_timer = maxf(_landing_recovery_timer - delta, 0.0)

func _handle_state(delta: float) -> void:
	match state:
		PlayerState.COMBAT:
			if not Input.is_action_pressed("attack"):
				_sheathe_elapsed = 0.0
				state = PlayerState.SHEATHE
		PlayerState.SHEATHE:
			_sheathe_elapsed += delta
			if _sheathe_elapsed >= sheathe_delay:
				state = PlayerState.IDLE
		PlayerState.IDLE:
			pass

func _attack() -> void:
	var cost: float = GameManager.get_stamina_cost(base_stamina_cost)
	if stamina < cost:
		return
	stamina -= cost
	regen_delay_timer.start()
	for body in melee_hitbox.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(base_attack_damage)

func _handle_regen(delta: float) -> void:
	if regen_delay_timer.is_stopped():
		health = minf(health + health_regen_rate * delta, max_health)
		stamina = minf(stamina + stamina_regen_rate * delta, max_stamina)

func take_damage(amount: float) -> void:
	health = maxf(health - amount, 0.0)
	regen_delay_timer.start()
