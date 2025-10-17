extends Control

func _on_join_lobby_button_down() -> void:
	Client.join_lobby($LobbyID.text)

func _on_start_client_button_down() -> void:
	Client.connectToServer($IpAddress.text, 6000)
