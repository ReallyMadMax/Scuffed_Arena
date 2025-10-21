extends Node2D

@export var item: InvItem
var player = null

func _on_area_2d_body_entered(body):
	if body is player_class:
		player = body
		player.collect(item)
		self.queue_free()
