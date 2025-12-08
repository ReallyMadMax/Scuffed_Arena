extends Control


func _on_host_game_button_down() -> void:
	HUD.show_menu(HUD.menu.HOST_MENU)


func _on_join_game_button_down() -> void:
	HUD.show_menu(HUD.menu.CONNECT_MENU)


func _on_testing_mode_pressed() -> void:
	var id = 0
	var player_name = "test"

	GameManager.add_player(id, player_name, "poop")
	GameManager.client_id = id
	GameManager.game_mode = load("res://resources/game_modes/timed_deathmatch.tres")
	GameManager.start_game()
