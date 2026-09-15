class_name Player
extends CharacterBody3D

signal true_ending_triggered

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
@export var true_ending_hold_time: float = 3.0
@export var observer_check_radius: float = 6.0
@export var observer_required_count: int = 2
@export var shake_decay_speed: float = 0.12
@export var shake_on_hit_strength: float = 0.09
@export var shake_on_damage_strength: float = 0.03
@export var shake_guilt_weight: float = 0.01
@export var jump_kick_amplitude: float = 0.05
@export var landing_kick_amplitude: float = 0.08
@export var vertical_kick_duration: float = 0.3
@export var run_sway_amplitude: float = 0.15
@export var bob_frequency: float = 8.0
@export var bob_amplitude: float = 0.04
@export var bob_side_amplitude: float = 0.02
@export var locomotion_fade_speed: float = 6.0
@export var low_resource_ratio: float = 0.25

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var melee_hitbox: Area3D = $Head/MeleeHitbox
@onready var regen_delay_timer: Timer = $RegenDelayTimer
@onready var heartbeat_player: AudioStreamPlayer = $HeartbeatPlayer
@onready var footstep_player: AudioStreamPlayer3D = $FootstepPlayer3D

var health: float
var stamina: float
var state: PlayerState = PlayerState.IDLE

var _camera_pitch: float = 0.0
var _sheathe_elapsed: float = 0.0
var _air_time: float = 0.0
var _was_on_floor: bool = true
var _landing_recovery_timer: float = 0.0
var _drop_weapon_hold: float = 0.0
var _true_ending_fired: bool = false
var _camera_base_position: Vector3
var _bob_phase: float = 0.0
var _last_footstep_step: int = 0
var _shake_strength: float = 0.0
var _vertical_kick_timer: float = 0.0
var _vertical_kick_amplitude: float = 0.0
var _locomotion_intensity: float = 0.0

func _ready() -> void:
	add_to_group("player")
	health = max_health
	stamina = max_stamina
	regen_delay_timer.wait_time = regen_delay
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_camera_base_position = camera.position

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
	_handle_true_ending(delta)
	_handle_camera_effects(delta)
	_handle_heartbeat()
	move_and_slide()
	_handle_landing(delta)
	_shake_strength = maxf(_shake_strength - shake_decay_speed * delta, 0.0)
	_vertical_kick_timer = maxf(_vertical_kick_timer - delta, 0.0)

func _handle_movement(delta: float) -> void:
	if not is_on_floor():
		var gravity_scale := fall_gravity_multiplier if velocity.y < 0.0 else 1.0
		velocity.y -= GRAVITY * gravity_scale * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
		_trigger_vertical_kick(jump_kick_amplitude)

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
			_trigger_vertical_kick(-landing_kick_amplitude)
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
	var hit_something := false
	for body in melee_hitbox.get_overlapping_bodies():
		if body == self:
			continue
		if body.has_method("take_damage"):
			body.take_damage(base_attack_damage)
			hit_something = true
	if hit_something:
		_trigger_shake(shake_on_hit_strength + GameManager.guilt_score * shake_guilt_weight)

func _handle_regen(delta: float) -> void:
	if regen_delay_timer.is_stopped():
		health = minf(health + health_regen_rate * delta, max_health)
		stamina = minf(stamina + stamina_regen_rate * delta, max_stamina)

func take_damage(amount: float) -> void:
	health = maxf(health - amount, 0.0)
	regen_delay_timer.start()
	_trigger_shake(shake_on_damage_strength + GameManager.guilt_score * shake_guilt_weight)

func _handle_true_ending(delta: float) -> void:
	if _true_ending_fired:
		return
	if not Input.is_action_pressed("drop_weapon"):
		_drop_weapon_hold = 0.0
		return
	_drop_weapon_hold += delta
	if _drop_weapon_hold < true_ending_hold_time:
		return
	if GameManager.pacifist_streak < Enemy.OBSERVE_STREAK_THRESHOLD:
		return
	if not _is_surrounded_by_observers():
		return
	_true_ending_fired = true
	true_ending_triggered.emit()

func _handle_camera_effects(delta: float) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var is_running := is_on_floor() and horizontal_speed > 0.1
	_update_bob_phase(delta, is_running, horizontal_speed)
	_update_locomotion_intensity(delta, is_running, horizontal_speed)

	var offset := Vector3.ZERO
	offset += _compute_bob_offset() * _locomotion_intensity
	offset += _compute_run_sway_offset() * _locomotion_intensity
	offset += _compute_vertical_kick_offset()
	offset += _compute_impact_offset()
	camera.position = _camera_base_position + offset

	_update_footstep_audio()

func _update_bob_phase(delta: float, is_running: bool, horizontal_speed: float) -> void:
	if is_running:
		_bob_phase += delta * bob_frequency * (horizontal_speed / move_speed)
	# Phase is NOT reset to 0 when stopping - it just stops advancing, so
	# _locomotion_intensity (below) fades the amplitude out smoothly from
	# whatever point in the cycle it was at, instead of snapping position
	# to a different phase value in the same frame the player stops.

func _update_locomotion_intensity(delta: float, is_running: bool, horizontal_speed: float) -> void:
	var target := clampf(horizontal_speed / move_speed, 0.0, 1.0) if is_running else 0.0
	_locomotion_intensity = move_toward(_locomotion_intensity, target, locomotion_fade_speed * delta)

func _compute_bob_offset() -> Vector3:
	return Vector3(
		sin(_bob_phase * 0.5) * bob_side_amplitude,
		absf(sin(_bob_phase)) * bob_amplitude,
		0.0
	)

func _compute_run_sway_offset() -> Vector3:
	return Vector3(sin(_bob_phase) * run_sway_amplitude, 0.0, 0.0)

func _compute_vertical_kick_offset() -> Vector3:
	if _vertical_kick_timer <= 0.0:
		return Vector3.ZERO
	var t := 1.0 - _vertical_kick_timer / vertical_kick_duration
	# Ease-in-ease-out bump: velocity is exactly 0 at t=0 and t=1, unlike
	# sin(t*PI) whose slope is nonzero at both ends - that discontinuity in
	# velocity is what read as an abrupt "jerk" rather than a smooth dip.
	var eased := (1.0 - cos(t * TAU)) * 0.5
	return Vector3(0.0, _vertical_kick_amplitude * eased, 0.0)

func _compute_impact_offset() -> Vector3:
	if _shake_strength <= 0.0:
		return Vector3.ZERO
	return Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * _shake_strength

func _update_footstep_audio() -> void:
	if not is_on_floor():
		return
	var step_index := int(_bob_phase / PI)
	if step_index == _last_footstep_step:
		return
	_last_footstep_step = step_index
	if footstep_player.stream:
		footstep_player.pitch_scale = randf_range(0.9, 1.1)
		footstep_player.play()

func _trigger_shake(strength: float) -> void:
	_shake_strength = maxf(_shake_strength, strength)

func _trigger_vertical_kick(amplitude: float) -> void:
	_vertical_kick_amplitude = amplitude
	_vertical_kick_timer = vertical_kick_duration

func _handle_heartbeat() -> void:
	var stamina_ratio := stamina / max_stamina
	if stamina_ratio < low_resource_ratio:
		var intensity := 1.0 - stamina_ratio / low_resource_ratio
		if heartbeat_player.stream and not heartbeat_player.playing:
			heartbeat_player.play()
		heartbeat_player.volume_db = lerpf(-6.0, 0.0, intensity)
		heartbeat_player.pitch_scale = lerpf(1.0, 1.4, intensity)
	elif heartbeat_player.playing:
		heartbeat_player.stop()

func _is_surrounded_by_observers() -> bool:
	var count := 0
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Enemy
		if enemy == null:
			continue
		if enemy.state != Enemy.EnemyState.OBSERVE:
			continue
		if global_position.distance_to(enemy.global_position) > observer_check_radius:
			continue
		count += 1
		if count >= observer_required_count:
			return true
	return false
