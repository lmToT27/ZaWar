extends StaticBody3D

@export var max_health: float = 60.0

var health: float

func _ready() -> void:
	health = max_health

func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0.0:
		GameManager.register_kill()
		queue_free()
