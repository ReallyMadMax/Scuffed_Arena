extends Control

@onready var IpAddress = $VBoxContainer/HBoxContainer/IpAddress
@onready var StartGame = $VBoxContainer/StartGame
@onready var HostGame = $VBoxContainer/HBoxContainer/HostGame

func _ready() -> void:
	Server.player_joined.connect(_on_players_updated)
	Server.player_left.connect(_on_players_updated)
	IpAddress.text = IP.get_local_addresses()[1]

func _on_host_game_button_down() -> void:
	host_game(IpAddress.text)

func host_game(ip:String) -> void:
	Server.start_server()
	Client.connectToServer(ip, 6000)
	while(!Client.create_lobby()):
		await get_tree().create_timer(1.0).timeout
	StartGame.disabled = false
	StartGame.grab_focus()

func _on_start_game_button_down() -> void:
	Client.start_game.rpc()

func _on_players_updated():
	$VBoxContainer2/PlayerCount.text = "Players Connected: " + str(Server.users.size()) + "/8"
	if Server.lobby:
		$VBoxContainer2/LobbyCount.text = "Players in Lobby: " + str(Server.lobby.Players.size()) + "/8"

func _on_ip_address_text_changed(new_text: String) -> void:
	HostGame.disabled = new_text.is_empty()
