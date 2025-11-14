extends Node2D
class_name Sword1

@export var item: InvItem
var player = null
var player_in_area = false

func _on_area_2d_body_entered(body):
	if body is player_class:
		# Only process pickup for the local player
		if str(body.name).to_int() != multiplayer.get_unique_id():
			return

		print("sword 1")
		player_in_area = true
		player = body
		player.speed += 100
		print(player.speed)
		player.collect.rpc(item.resource_path)
		despawn_item.rpc()

@rpc("any_peer", "call_local")
func despawn_item():
	queue_free()
