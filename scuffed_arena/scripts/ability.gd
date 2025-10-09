extends Resource
class_name Ability

@export var id: String = ""
@export var display_name: String = "New Ability"
@export var description: String = ""
@export var icon: Texture2D
@export var cooldown: float = 1.0
@export var ability_range: float = 0.0
@export var damage: float = 0.0

# runtime state
var _last_used_time: float = -INF

func _init():
	_last_used_time = -INF

func can_use() -> bool:
	# check if the ability can be used (off cooldown)
	return remaining_cooldown() <= 0.0

func use() -> bool:
	# mark the ability as used; returns true if use succeeded
	if not can_use():
		return false
	_last_used_time = Time.get_unix_time_from_system() / 1000.0
	return true

func remaining_cooldown() -> float:
	if _last_used_time == -INF:
		return 0.0
	var elapsed: float = Time.get_unix_time_from_system() - _last_used_time
	return max(0.0, cooldown - elapsed)

func reset_cooldown() -> void:
	_last_used_time = -INF

func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": display_name,
		"description": description,
		"cooldown": cooldown,
		"range": range,
		"damage": damage
	}
