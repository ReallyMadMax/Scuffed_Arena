extends Node2D

@export var item: InvItem
var player = null
var player_in_area = false

func _on_area_2d_body_entered(body):

	if body is player_class:
		print("sword 1")
		player_in_area = true
		player = body
		player.collect(item)
		self.queue_free()
