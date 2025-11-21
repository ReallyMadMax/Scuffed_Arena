class_name SpeedBoost
extends Upgrade

@export var quantity:float

func apply(_player: Player) -> void:
	_player.speed *= quantity

func remove(_player: Player) -> void:
	_player.speed /= quantity
