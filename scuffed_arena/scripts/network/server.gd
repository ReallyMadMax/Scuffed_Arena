extends Node

signal lobby_created(lobbyID:String)
signal player_joined
signal player_left

enum Message {
	ID,
	JOIN,
	USER_CONNECTED,
	USER_DISCONNECTED,
	CREATE_LOBBY,
	JOIN_LOBBY,
	CANDIDATE,
	OFFER,
	ANSWER,
	CHECK_IN
}

var peer = WebSocketMultiplayerPeer.new()
var port = 6000
var users = {}
var lobby:Lobby
var LOBBY_ID:String = "BAHAHAHAHA"
var chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMMNOPQRSTUVWXYZ1234567890"


func _ready():
	peer.connect("peer_connected", peer_connected)
	peer.connect("peer_disconnected", peer_disconnected)

func _process(_delta):
	peer.poll()
	if peer.get_available_packet_count() > 0:
		var packet = peer.get_packet()
		if packet != null:
			var dataString = packet.get_string_from_utf8()
			var data = JSON.parse_string(dataString)
			print(data)
			if data.message == Message.CREATE_LOBBY:
				create_lobby(data)
			if data.message == Message.JOIN_LOBBY:
				join_lobby(data)
			
			if data.message == Message.OFFER || data.message == Message.ANSWER || data.message == Message.CANDIDATE:
				print("source id is " + str(data.org_peer) + "data is ")
				send_to_player(data.peer, data)
	

func peer_connected(id:int):
	print("peer connected : " + str(id))
	users[id] = {
		"id": id,
		"message" : Message.ID
	}
	send_to_player(id, users[id])
	player_joined.emit()

func peer_disconnected(id:int):
	lobby.remove_player(id)
	users.erase(id)
	player_left.emit()

func create_lobby(user):
	user.lobby_id = LOBBY_ID
	lobby_created.emit(user.lobby_id)
	
	lobby = Lobby.new(user.id)
	
	join_lobby(user)

func join_lobby(user):
	lobby.add_player(user.id, user.name)
	
	for p in lobby.Players:
		send_connection_packet(user.id, p, null)
		send_connection_packet(p, user.id, null)
		
		var lobby_info = {
			"message" : Message.JOIN_LOBBY,
			"players" : lobby.Players,
			"lobby_id" : user.lobby_id
		}
		send_to_player(p, lobby_info)
	
	send_connection_packet(user.id, user.id, lobby)
	player_joined.emit()

func send_connection_packet(sender_id:int, receiver_id:int, new_lobby:Lobby):
	var data = {
		"message" : Message.USER_CONNECTED,
		"sender_id" : sender_id,
	}
	if new_lobby:
		data["host"] = new_lobby.HostId
		data["player"] = new_lobby.Players[sender_id]
	
	send_to_player(receiver_id, data)

func send_to_player(user_id:int, data):
	peer.get_peer(user_id).put_packet(JSON.stringify(data).to_utf8_buffer())

func generate_random_string():
	var result = ""
	for i in range(32):
		var random_idx = randi() % chars.length()
		result += chars[random_idx]
	return result

func start_server():
	peer.create_server(port)
	print("started server")

func _on_start_server_button_down():
	start_server()
