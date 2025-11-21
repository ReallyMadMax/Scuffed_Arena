@abstract
class_name Upgrade
extends Resource

@export var name: String
@export_multiline var description: String
@export var icon: Texture2D

func apply(_player: Player) -> void:
	pass

func remove(_player: Player) -> void:
	pass

func on_damage_taken(_player: Player, _damage: float) -> void:
	pass

func on_damage_dealt(_player: Player, _damage: float) -> void:
	pass

func on_kill(_player: Player, _enemy: Player) -> void:
	pass

func on_hit(_player: Player, _enemy: Player) -> void:
	pass

# add more conditions as needed
