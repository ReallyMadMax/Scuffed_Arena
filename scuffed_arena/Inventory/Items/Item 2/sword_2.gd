extends Node2D

@export var item: InvItem
var player = null
var Player_parent = null
var player_in_area = false


func _on_area_2d_body_entered(body):
	print(1)

	if body.has_method("player"):
		print(1)
		player_in_area = true
		player = body
		player.collect(item)
		self.queue_free()
