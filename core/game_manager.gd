extends Node

signal day_night_changed(is_night: bool)
signal environment_changed(pacifist_streak: int)
signal kill_registered

@export var base_stamina_cost: float = 10.0
@export var guilt_weight: float = 0.5
@export var day_duration_sec: float = 180.0
@export var night_duration_sec: float = 120.0

var is_night: bool = false
var guilt_score: float = 0.0
var pacifist_streak: int = 0
var total_kills: int = 0

var _killed_this_cycle: bool = false

func register_kill() -> void:
	total_kills += 1
	guilt_score += 1.0
	pacifist_streak = 0
	_killed_this_cycle = true
	kill_registered.emit()

func get_stamina_cost(base: float) -> float:
	if is_night:
		return base + guilt_score * guilt_weight
	return base

func set_night(night: bool) -> void:
	is_night = night
	day_night_changed.emit(is_night)

func complete_cycle() -> void:
	if not _killed_this_cycle:
		pacifist_streak += 1
		environment_changed.emit(pacifist_streak)
	_killed_this_cycle = false
