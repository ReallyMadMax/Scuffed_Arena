extends Control


func _on_host_game_button_down() -> void:
	var scene = load("res://scenes/gui/menus/host_menu.tscn").instantiate()
	get_tree().root.add_child(scene)
	queue_free()


func _on_join_game_button_down() -> void:
	var scene = load("res://scenes/gui/menus/connect_menu.tscn").instantiate()
	get_tree().root.add_child(scene)
	queue_free()


func _on_testing_mode_pressed() -> void:
	var id = 0
	var player_name = "test"
	GameManager.Players[id] = {
		"id": id,
		"name": player_name
	};
	Client.start_game()
