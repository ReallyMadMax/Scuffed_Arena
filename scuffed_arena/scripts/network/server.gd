# SignalingServer.gd
extends Node

signal lobby_created(lobby_id: String)
signal player_joined
signal player_left

enum Message {
	ID,
	JOIN,
	USER_CONNECTED,
	USER_DISCONNECTED,
	CREATE_LOBBY,
	JOIN_LOBBY,
	HOLE_PUNCH_INFO,
	READY_TO_CONNECT,
	CANDIDATE,
	OFFER,
	ANSWER,
	CHECK_IN
}

# Separate ports for WebSocket signaling and game traffic
var websocket_port = 6000  # For signaling only
var game_port_range_start = 7000  # For actual game connections

var peer = WebSocketMultiplayerPeer.new()
var users = {}
var lobbies = {}  # Multiple lobbies support
var chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMMNOPQRSTUVWXYZ1234567890"
var ext_ip

func _ready():
	peer.peer_connected.connect(peer_connected)
	peer.peer_disconnected.connect(peer_disconnected)
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_http_request_completed)
	http.request("https://ipv4.icanhazip.com")

func _on_http_request_completed(_result:int, response_code:int, _headers:PackedStringArray, body:PackedByteArray) -> void:
	if response_code == 200:
		ext_ip = body.get_string_from_utf8().strip_edges()
	else:
		print("Failed to get external IP, response code: ", response_code)

func _process(_delta):
	peer.poll()
	if peer.get_available_packet_count() > 0:
		var packet = peer.get_packet()
		if packet != null:
			var data_string = packet.get_string_from_utf8()
			var data = JSON.parse_string(data_string)
			handle_message(data)

func handle_message(data):
	var msg_type = int(data.message) if typeof(data.message) == TYPE_FLOAT else data.message
	match msg_type:
		Message.CREATE_LOBBY:
			create_lobby(data)
		Message.JOIN_LOBBY:
			join_lobby(data)
		Message.HOLE_PUNCH_INFO:
			relay_punch_info(data)
		Message.READY_TO_CONNECT:
			notify_ready_to_connect(data)
		Message.OFFER, Message.ANSWER, Message.CANDIDATE:
			relay_rtc_message(data)

func peer_connected(id: int):
	print("Peer connected: ", id)
	users[id] = {
		"id": id,
		"lobby_id": null,
		"game_port": 0,
		"ext_ip": "",
	}
	
	var welcome = {
		"message": Message.ID,
		"your_id": id
	}
	send_to_player(id, welcome)
	player_joined.emit()

func peer_disconnected(id: int):
	print("Peer disconnected: ", id)
	
	# Remove from lobby if in one
	if users.has(id) and users[id].lobby_id:
		var lobby_id = users[id].lobby_id
		if lobbies.has(lobby_id):
			lobbies[lobby_id].players.erase(id)
			
			# Notify other players
			for player_id in lobbies[lobby_id].players:
				var disconnect_msg = {
					"message": Message.USER_DISCONNECTED,
					"player_id": id
				}
				send_to_player(player_id, disconnect_msg)
			
			# Delete empty lobbies
			if lobbies[lobby_id].players.is_empty():
				lobbies.erase(lobby_id)
	
	users.erase(id)
	player_left.emit()

func create_lobby(data):
	var lobby_id = generate_lobby_code()
	var creator_id = int(data.user_id)
	
	# Assign a game port for this player
	var game_port = game_port_range_start + lobbies.size()
	
	lobbies[lobby_id] = {
		"host_id": creator_id,
		"players": {
			creator_id: {
				"name": data.get("name", "Player"),
				"ext_ip": data.get("ext_ip", ""),
				"game_port": game_port,
				"ready": false
			}
		}
	}
	
	users[creator_id].lobby_id = lobby_id
	users[creator_id].game_port = game_port
	
	var response = {
		"message": Message.CREATE_LOBBY,
		"lobby_id": lobby_id,
		"your_game_port": game_port,
		"is_host": true
	}
	send_to_player(creator_id, response)
	lobby_created.emit(lobby_id)
	print("Lobby created: ", lobby_id)

func join_lobby(data):
	var lobby_id = data.lobby_id
	var joiner_id = data.user_id
	
	if not lobbies.has(lobby_id):
		var error = {
			"message": Message.JOIN_LOBBY,
			"error": "Lobby not found"
		}
		send_to_player(joiner_id, error)
		return
	
	# Assign game port
	var game_port = game_port_range_start + lobbies.size() + lobbies[lobby_id].players.size()
	
	lobbies[lobby_id].players[joiner_id] = {
		"name": data.get("name", "Player"),
		"ext_ip": data.get("ext_ip", ""),
		"game_port": game_port,
		"ready": false
	}
	
	users[joiner_id].lobby_id = lobby_id
	users[joiner_id].game_port = game_port
	
	# Send lobby info to joiner
	var lobby_info = {
		"message": Message.JOIN_LOBBY,
		"lobby_id": lobby_id,
		"your_game_port": game_port,
		"is_host": false,
		"host_id": lobbies[lobby_id].host_id,
		"players": lobbies[lobby_id].players
	}
	send_to_player(joiner_id, lobby_info)
	
	# Notify all existing players about new player
	for player_id in lobbies[lobby_id].players:
		if player_id != joiner_id:
			var join_notification = {
				"message": Message.USER_CONNECTED,
				"player_id": joiner_id,
				"player_info": lobbies[lobby_id].players[joiner_id]
			}
			send_to_player(player_id, join_notification)
	
	print("Player ", joiner_id, " joined lobby ", lobby_id)

func relay_punch_info(data):
	# Client has punched their hole, relay info to other players
	var sender_id = int(data.user_id)
	var lobby_id = users[sender_id].lobby_id
	
	if not lobbies.has(lobby_id):
		return
	
	# Update player's punch info
	lobbies[lobby_id].players[sender_id].ext_ip = data.ext_ip
	lobbies[lobby_id].players[sender_id].game_port = data.game_port
	
	# Relay to all other players in lobby
	for player_id in lobbies[lobby_id].players:
		if player_id != sender_id:
			var punch_info = {
				"message": Message.HOLE_PUNCH_INFO,
				"from_player": sender_id,
				"ext_ip": data.ext_ip,
				"game_port": data.game_port
			}
			send_to_player(player_id, punch_info)

func notify_ready_to_connect(data):
	var sender_id = int(data.user_id)
	var lobby_id = users[sender_id].lobby_id
	
	if not lobbies.has(lobby_id):
		return
	
	lobbies[lobby_id].players[sender_id].ready = true
	
	# Check if all players are ready
	var all_ready = true
	for player_id in lobbies[lobby_id].players:
		if not lobbies[lobby_id].players[player_id].ready:
			all_ready = false
			break
	
	if all_ready:
		# Tell everyone to start connecting
		for player_id in lobbies[lobby_id].players:
			var start_msg = {
				"message": Message.READY_TO_CONNECT,
				"all_players": lobbies[lobby_id].players
			}
			send_to_player(player_id, start_msg)

func relay_rtc_message(data):
	# For WebRTC fallback (if hole punching fails)
	if data.has("target_peer"):
		send_to_player(data.target_peer, data)

func send_to_player(user_id: int, data):
	# Check if user exists in our users dictionary
	if users.has(user_id):
		# Try to get the peer and send packet
		var peer_instance = peer.get_peer(user_id)
		if peer_instance != null:
			peer_instance.put_packet(JSON.stringify(data).to_utf8_buffer())
		else:
			print("Warning: Peer ", user_id, " not found in WebSocket")
	else:
		print("Warning: User ", user_id, " not found in users dictionary")

func generate_lobby_code() -> String:
	var code = ""
	for i in range(6):
		code += chars[randi() % chars.length()]
	return code.to_upper()

func start_server():
	var err = peer.create_server(websocket_port)
	if err != OK:
		print("Failed to start server: ", err)
		return
	print("Signaling server started on port ", websocket_port)

func _on_start_server_button_down():
	start_server()
