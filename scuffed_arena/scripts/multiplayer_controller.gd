extends Control

@export var Address = "127.0.0.1"
@export var port = 6000
var peer

func _ready():
	multiplayer.peer_connected.connect(player_connected)
	multiplayer.peer_disconnected.connect(player_disconnected)
	multiplayer.connected_to_server.connect(connected_to_server)
	multiplayer.connection_failed.connect(connection_failed)

# this gets called on the server and the clients
func player_connected(id):
	print("Player Connected " + str(id))
	

# this gets called on the server and the clients
func player_disconnected(id):
	print("Player Disonnected " + str(id))

# only on clients
func connected_to_server():
	send_player_info.rpc_id(1, $LineEdit.text, multiplayer.get_unique_id())
	print("Connected to server")

# only on clients
func connection_failed():
	print("Could not connect")

@rpc("any_peer")
func send_player_info(player_name, id):
	if !GameManager.Players.has(id):
		GameManager.Players[id] = {
			"name":player_name,
			"id":id,
			"score":0
		}
	
	if multiplayer.is_server():
		for i in GameManager.Players:
			send_player_info.rpc(GameManager.Players[i].name, i)

@rpc("any_peer", "call_local")
func start_game():
	var scene = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(scene)
	self.hide()

func _on_host_button_down() -> void:
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, 8)
	if error != OK:
		print("cannot host: " + error)
		return
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	
	multiplayer.set_multiplayer_peer(peer)
	print("Waiting for players")
	send_player_info($LineEdit.text, multiplayer.get_unique_id())

func _on_join_button_down() -> void:
	peer = ENetMultiplayerPeer.new()
	peer.create_client(Address, port)
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.set_multiplayer_peer(peer)


func _on_start_game_button_down() -> void:
	start_game.rpc()
