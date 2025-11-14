extends Control

@onready var StartGame = $VBoxContainer/StartGame
@onready var HostGame = $VBoxContainer/HostGame
@onready var LobbyID = $VBoxContainer/LobbyID

func _ready():
	Client.player_connected.connect(_on_player_joined)
	Client.lobby_joined.connect(_on_lobby_created)

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

func _on_lobby_created(id:String):
	LobbyID.text = id

func _on_player_joined(_id:int):
	$VBoxContainer2/PlayerCount.text = "Player count " + str(GameManager.Players.size()) + "/8"
