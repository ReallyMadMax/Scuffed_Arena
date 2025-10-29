extends Control

@onready var IpAddress = $VBoxContainer/HBoxContainer/IpAddress
@onready var ExtIpAddress = $VBoxContainer/ExtIpAddress
@onready var StartGame = $VBoxContainer/StartGame
@onready var HostGame = $VBoxContainer/HBoxContainer/HostGame

func _ready() -> void:
	Server.player_joined.connect(_on_players_updated)
	Server.player_left.connect(_on_players_updated)
	IpAddress.text = IP.get_local_addresses()[1]
	ExtIpAddress.text = Server.ext_ip

func _on_host_game_button_down() -> void:
	host_game(IpAddress.text)

func host_game(ip:String) -> void:
	# Auto-start C# signaling server
	print("[HostMenu] Starting signaling server...")
	var server_started = await Server.start_signaling_server()

	if not server_started:
		print("[HostMenu] ERROR: Failed to start signaling server!")
		print("[HostMenu] Make sure .NET SDK is installed and SignalingServer project exists")
		return

	# Use localhost if not specified otherwise
	if ip.is_empty() or ip == "127.0.0.1" or ip.begins_with("192.168"):
		ip = "ws://localhost"
		print("[HostMenu] Using local signaling server: " + ip)

	# Start the legacy GDScript server (for backwards compatibility)
	Server.start_server()

	# Connect to signaling server
	Client.connectToServer(ip, 6000)
	while(!Client.create_lobby()):
		await get_tree().create_timer(1.0).timeout
	StartGame.disabled = false
	StartGame.grab_focus()

func _on_start_game_button_down() -> void:
	Client.start_game.rpc()
	queue_free()

func _on_players_updated():
	$VBoxContainer2/PlayerCount.text = "Players Connected: " + str(Server.users.size()) + "/8"
	if Server.lobby:
		$VBoxContainer2/LobbyCount.text = "Players in Lobby: " + str(Server.lobby.Players.size()) + "/8"

func _on_ip_address_text_changed(new_text: String) -> void:
	HostGame.disabled = new_text.is_empty()
