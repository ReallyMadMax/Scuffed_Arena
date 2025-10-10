extends Node

@export var PlayerScene : PackedScene

func _ready():
	for i in GameManager.Players:
		var currentPlayer = PlayerScene.instantiate()
		currentPlayer.name = str(GameManager.Players[i].id)
		add_child(currentPlayer)
		var spawn = get_tree().get_nodes_in_group("PlayerSpawnPoint").get(0)
		currentPlayer.global_position = spawn.global_position
