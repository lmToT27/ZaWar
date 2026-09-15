extends Node3D

@export var max_pacifist_streak_for_lerp: int = 10
@export var critical_ratio: float = 0.2

const FOG_COLOR_ACTIVE: Color = Color(0.6, 0.1, 0.1)
const FOG_COLOR_CALM: Color = Color(0.4, 0.5, 0.55)
const FOG_DENSITY_ACTIVE: float = 0.03
const FOG_DENSITY_CALM: float = 0.005
const LIGHT_ENERGY_DAY: float = 1.0
const LIGHT_ENERGY_NIGHT: float = 0.25

@onready var player: Player = $Player
@onready var health_bar: ProgressBar = $UI/HealthBar
@onready var stamina_bar: ProgressBar = $UI/StaminaBar
@onready var status_label: Label = $UI/StatusLabel
@onready var fade_overlay: ColorRect = $UI/FadeOverlay
@onready var day_night_timer: Timer = $DayNightTimer
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var directional_light: DirectionalLight3D = $LevelGreybox/DirectionalLight3D

var _health_pulsing: bool = false
var _stamina_pulsing: bool = false

func _ready() -> void:
	day_night_timer.one_shot = true
	day_night_timer.timeout.connect(_on_day_night_timeout)
	day_night_timer.start(GameManager.day_duration_sec)

	GameManager.environment_changed.connect(_on_environment_changed)
	GameManager.day_night_changed.connect(_on_day_night_changed)
	player.true_ending_triggered.connect(_on_true_ending_triggered)

func _process(_delta: float) -> void:
	var health_ratio := player.health / player.max_health
	var stamina_ratio := player.stamina / player.max_stamina
	health_bar.value = health_ratio * 100.0
	stamina_bar.value = stamina_ratio * 100.0
	status_label.text = "Streak: %d  Guilt: %.1f  %s" % [
		GameManager.pacifist_streak,
		GameManager.guilt_score,
		"NIGHT" if GameManager.is_night else "DAY",
	]

	_update_critical_pulse(health_bar, health_ratio < critical_ratio, _health_pulsing)
	_health_pulsing = health_ratio < critical_ratio
	_update_critical_pulse(stamina_bar, stamina_ratio < critical_ratio, _stamina_pulsing)
	_stamina_pulsing = stamina_ratio < critical_ratio

func _update_critical_pulse(bar: ProgressBar, is_critical: bool, was_pulsing: bool) -> void:
	if is_critical and not was_pulsing:
		var tween := create_tween().set_loops()
		tween.tween_property(bar, "modulate", Color(1, 0.3, 0.3), 0.3)
		tween.tween_property(bar, "modulate", Color(1, 1, 1), 0.3)
		bar.set_meta("pulse_tween", tween)
	elif not is_critical and was_pulsing:
		var tween: Tween = bar.get_meta("pulse_tween", null)
		if tween:
			tween.kill()
		bar.modulate = Color(1, 1, 1)

func _on_day_night_timeout() -> void:
	if GameManager.is_night:
		GameManager.complete_cycle()
		GameManager.set_night(false)
		day_night_timer.start(GameManager.day_duration_sec)
	else:
		GameManager.set_night(true)
		day_night_timer.start(GameManager.night_duration_sec)

func _on_day_night_changed(is_night: bool) -> void:
	var target_energy := LIGHT_ENERGY_NIGHT if is_night else LIGHT_ENERGY_DAY
	create_tween().tween_property(directional_light, "light_energy", target_energy, 3.0)

func _on_environment_changed(streak: int) -> void:
	var t := clampf(float(streak) / float(max_pacifist_streak_for_lerp), 0.0, 1.0)
	var env := world_environment.environment
	var tween := create_tween()
	tween.tween_property(env, "fog_light_color", FOG_COLOR_ACTIVE.lerp(FOG_COLOR_CALM, t), 2.0)
	tween.parallel().tween_property(env, "fog_density", lerpf(FOG_DENSITY_ACTIVE, FOG_DENSITY_CALM, t), 2.0)

func _on_true_ending_triggered() -> void:
	var tween := create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 1.0, 2.0)
	await tween.finished
	status_label.text = "TRUE ENDING"
	print("TRUE ENDING TRIGGERED")
	get_tree().paused = true
