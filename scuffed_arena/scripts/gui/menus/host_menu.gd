extends Control

@onready var StartGame = $VBoxContainer/StartGame
@onready var HostGame = $VBoxContainer/HostGame
@onready var LobbyID = $VBoxContainer/LobbyID

func host_game() -> void:
	# Auto-start C# signaling server
	Client.connectToServer()
	while(!Client.create_lobby()):
		await get_tree().create_timer(1.0).timeout
	StartGame.disabled = false
	HostGame.disabled = true
	StartGame.grab_focus()

func _on_host_game_button_down() -> void:
	host_game()

func _on_start_game_button_down() -> void:
	Client.start_game.rpc()
	queue_free()

func _on_ip_address_text_changed(new_text: String) -> void:
	HostGame.disabled = new_text.is_empty()
