extends Node2D

@export var item: InvItem
var player = null
var Player_parent = null
var player_in_area = false


func _on_area_2d_body_entered(body):
	if body is player_class:
		print("sword 2")
		player_in_area = true
		player = body
		player.shoot_cooldown -= 0.09
		if player.shoot_cooldown <= 0:
			player.shoot_cooldown = 0.005
		print(player.shoot_cooldown)
		player.collect(item)
		self.queue_free()
