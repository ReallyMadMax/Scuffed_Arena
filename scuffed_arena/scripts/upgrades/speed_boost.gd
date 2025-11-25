extends Upgrade
class_name SpeedBoostUpgrade

@export var quantity:float

func apply(_player: Player) -> void:
	_player.speed *= quantity

func remove(_player: Player) -> void:
	_player.speed /= quantity
