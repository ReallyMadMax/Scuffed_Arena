extends Control

@onready var IpAddress = $VBoxContainer/HBoxContainer/IpAddress
@onready var LobbyId = $VBoxContainer/LobbyId

func _ready() -> void:
	Server.lobby_created.connect(_on_lobby_created)

func _on_host_game_button_down() -> void:
	Server.start_server()
	Client.connectToServer(IpAddress.text, 6000)
	while(!Client.join_lobby("")):
		await get_tree().create_timer(1.0).timeout

func _on_start_game_button_down() -> void:
	Client.start_game.rpc()

func _on_lobby_created(lobbyId:String):
	LobbyId.text = lobbyId
