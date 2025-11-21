extends Upgrade
class_name KillStreakUpgrade

@export var speed_increase:float
@export var duration:float

func on_kill(_player: Player, _enemy: Player) -> void:
	# increase the speed for a short duration then remove the increase
	_player.speed += speed_increase
	_player.get_tree().create_timer(duration).timeout.connect(func():
		_player.speed -= speed_increase
	)
