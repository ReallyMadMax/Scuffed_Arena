extends Node

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

var peer: WebSocketMultiplayerPeer = WebSocketMultiplayerPeer.new()
var client_id: int = 0
var rtc_peer: WebRTCMultiplayerPeer = WebRTCMultiplayerPeer.new()
var lobby_id = ""
var my_game_port: int = 0
var is_host: bool = false

# UDP socket for hole punching
var udp_socket: PacketPeerUDP = PacketPeerUDP.new()

var is_websocket_connected = false

func _ready() -> void:
	multiplayer.connected_to_server.connect(RTCServerConnected)
	multiplayer.peer_connected.connect(RTCPeerConnected)
	multiplayer.peer_disconnected.connect(RTCPeerDisconnected)

func RTCServerConnected(_id):
	print("Server connected")
	pass

func RTCPeerConnected(id):
	print("Peer connected " + str(id))
	pass

func RTCPeerDisconnected(id):
	print("Peer disconnected " + str(id))
	pass

func _process(_delta):
	peer.poll()
	
	# Check WebSocket connection status
	var status = peer.get_connection_status()
	if status == MultiplayerPeer.CONNECTION_CONNECTED and not is_websocket_connected:
		is_websocket_connected = true
		print("WebSocket connected to signaling server!")
	elif status == MultiplayerPeer.CONNECTION_DISCONNECTED and is_websocket_connected:
		is_websocket_connected = false
		print("WebSocket disconnected from signaling server!")
	
	if peer.get_available_packet_count() > 0:
		var packet = peer.get_packet()
		if packet == null:
			return
		
		var dataString = packet.get_string_from_utf8()
		var data = JSON.parse_string(dataString)
		print(data)
		
		# Convert message to int if it's a float
		var msg_type = int(data.message)
		print("Message type: ", msg_type)
		
		match msg_type:
			Message.ID:
				client_id = int(data.your_id)
				print("Client id: " + str(client_id))
				connected(client_id)
			
			Message.CREATE_LOBBY:
				handle_lobby_created(data)
			
			Message.JOIN_LOBBY:
				handle_lobby_joined(data)
			
			Message.USER_CONNECTED:
				handle_user_connected(data)
			
			Message.USER_DISCONNECTED:
				handle_user_disconnected(data)
			
			Message.HOLE_PUNCH_INFO:
				handle_punch_info(data)
			
			Message.READY_TO_CONNECT:
				handle_ready_to_connect(data)
			
			Message.CANDIDATE:
				if rtc_peer.has_peer(data.org_peer):
					print("Got candidate " + str(data.org_peer) + ", my id is " + str(client_id))
					rtc_peer.get_peer(data.org_peer).connection.add_ice_candidate(data.mid, data.index, data.sdp)
			
			Message.OFFER:
				if rtc_peer.has_peer(data.org_peer):
					print("Got Offer " + str(data.org_peer) + ", my id is " + str(client_id))
					rtc_peer.get_peer(data.org_peer).connection.set_remote_description("offer", data.data)
			
			Message.ANSWER:
				if rtc_peer.has_peer(data.org_peer):
					print("Got Answer " + str(data.org_peer) + ", my id is " + str(client_id))
					rtc_peer.get_peer(data.org_peer).connection.set_remote_description("answer", data.data)

func handle_lobby_created(data):
	lobby_id = data.lobby_id
	my_game_port = data.your_game_port
	is_host = data.is_host
	print("Lobby created: ", lobby_id, " on game port: ", my_game_port)
	
	# Start hole punching process
	start_hole_punching()

func handle_lobby_joined(data):
	if data.has("error"):
		print("Error joining lobby: ", data.error)
		return
	
	lobby_id = data.lobby_id
	my_game_port = data.your_game_port
	is_host = data.is_host
	GameManager.Players = data.players
	print("Joined lobby: ", lobby_id, " on game port: ", my_game_port)
	
	# Start hole punching process
	start_hole_punching()

func handle_user_connected(data):
	var player_id = data.player_id
	var player_info = data.player_info
	print("New player joined: ", player_id, " - ", player_info.name)
	
	# Update players list
	if GameManager.Players.has(lobby_id):
		GameManager.Players[lobby_id].players[player_id] = player_info
	
	# Create WebRTC peer for the new player
	createPeer(player_id)

func handle_user_disconnected(data):
	var player_id = data.player_id
	print("Player disconnected: ", player_id)
	
	if rtc_peer.has_peer(player_id):
		rtc_peer.remove_peer(player_id)

func handle_punch_info(data):
	var from_player = data.from_player
	var ext_ip = data.ext_ip
	var game_port = data.game_port
	print("Received punch info from ", from_player, ": ", ext_ip, ":", game_port)
	
	# Attempt to connect via UDP hole punching
	punch_to_peer(ext_ip, game_port)

func handle_ready_to_connect(data):
	var all_players = data.all_players
	print("All players ready! Starting connections...")
	print("Players: ", all_players)
	
	# Create WebRTC peers for all players
	for player_id in all_players:
		if int(player_id) != client_id:
			createPeer(player_id)

func start_hole_punching():
	# Bind to the assigned game port
	var err = udp_socket.bind(my_game_port)
	if err != OK:
		print("Failed to bind UDP socket on port ", my_game_port, ": ", err)
		return
	
	print("UDP socket bound to port ", my_game_port)
	
	# Get external IP (you may need to implement this via a STUN server or API)
	var ext_ip = get_external_ip()
	
	# Send hole punch info to server
	var punch_info = {
		"message": Message.HOLE_PUNCH_INFO,
		"user_id": client_id,
		"ext_ip": ext_ip,
		"game_port": my_game_port
	}
	peer.put_packet(JSON.stringify(punch_info).to_utf8_buffer())
	
	# Notify ready to connect
	var ready_msg = {
		"message": Message.READY_TO_CONNECT,
		"user_id": client_id
	}
	peer.put_packet(JSON.stringify(ready_msg).to_utf8_buffer())

func get_external_ip() -> String:
	# Placeholder - you'll need to implement this
	# Options:
	# 1. Use a STUN server
	# 2. Query an IP API service
	# 3. Have the server tell you your IP when you connect
	
	# For now, return empty string
	# The server should ideally detect the client's IP from the WebSocket connection
	return ""

func punch_to_peer(target_ip: String, target_port: int):
	# Send UDP packets to target to open NAT hole
	print("Punching hole to ", target_ip, ":", target_port)
	
	for i in range(5):  # Send multiple packets
		var packet = "PUNCH".to_utf8_buffer()
		udp_socket.set_dest_address(target_ip, target_port)
		udp_socket.put_packet(packet)
		await get_tree().create_timer(0.1).timeout

func connected(id: int):
	rtc_peer.create_mesh(id)
	multiplayer.multiplayer_peer = rtc_peer

# WebRTC connection stuff
func createPeer(id: int):
	if id != client_id:
		var ext_peer: WebRTCPeerConnection = WebRTCPeerConnection.new()
		ext_peer.initialize({
			"iceServers": [
				{"urls": ["stun:stun.l.google.com:19302"]},
				{"urls": ["stun:stun1.l.google.com:19302"]},
				{
					"urls": ["turn:openrelay.metered.ca:80"],
					"username": "openrelayproject",
					"credential": "openrelayproject"
				}
			]
		})
		
		var check_connection = func():
			await get_tree().create_timer(0.5).timeout
			for i in range(20):  # Check for 10 seconds
				if rtc_peer.has_peer(id):
					var state = rtc_peer.get_peer(id).connection.get_connection_state()
					var _ice_state = rtc_peer.get_peer(id).connection.get_gathering_state()
					if state == WebRTCPeerConnection.STATE_CONNECTED:
						print("WebRTC CONNECTED to peer " + str(id))
						break
					elif state == WebRTCPeerConnection.STATE_FAILED:
						print("WebRTC FAILED to connect to peer " + str(id))
						break
				await get_tree().create_timer(0.5).timeout
		
		check_connection.call()
		
		ext_peer.session_description_created.connect(self.offer_created.bind(id))
		ext_peer.ice_candidate_created.connect(self.ice_candidate_created.bind(id))
		rtc_peer.add_peer(ext_peer, id)
		
		if id < rtc_peer.get_unique_id():
			ext_peer.create_offer()

func offer_created(type: String, data, id: int):
	if !rtc_peer.has_peer(id):
		return
	
	rtc_peer.get_peer(id).connection.set_local_description(type, data)
	
	if type == "offer":
		send_offer(id, data)
	else:
		send_answer(id, data)

func send_offer(id: int, data):
	var message = {
		"peer": id,
		"org_peer": client_id,
		"message": Message.OFFER,
		"data": data,
		"lobby": lobby_id
	}
	
	peer.put_packet(JSON.stringify(message).to_utf8_buffer())

func send_answer(id: int, data):
	var message = {
		"peer": id,
		"org_peer": client_id,
		"message": Message.ANSWER,
		"data": data,
		"lobby": lobby_id
	}
	
	peer.put_packet(JSON.stringify(message).to_utf8_buffer())

func ice_candidate_created(mid_name, index_name, sdp_name, id: int):
	var message = {
		"peer": id,
		"org_peer": client_id,
		"message": Message.CANDIDATE,
		"mid": mid_name,
		"index": index_name,
		"sdp": sdp_name,
		"lobby": lobby_id
	}
	
	peer.put_packet(JSON.stringify(message).to_utf8_buffer())

func connectToServer(ip, port):
	var err = peer.create_client("ws://" + ip + ":" + str(port))
	if err != OK:
		print("Failed to create WebSocket client: ", err)
		return
	print("Connecting to signaling server at ws://" + ip + ":" + str(port))

@rpc("any_peer", "call_local")
func start_game():
	print("Loading main scene...")
	var scene = load("res://scenes/main.tscn").instantiate()

	# List of autoload singletons to keep (don't delete these!)
	var autoloads = ["GameManager", "Client", "Server"]

	for child in get_tree().root.get_children():
		if child.name not in autoloads:
			child.queue_free()

	print("Adding main scene to tree...")
	get_tree().root.add_child(scene)

func create_lobby() -> bool:
	if not is_websocket_connected:
		print("Not connected to server yet! Please wait...")
		return false
	
	if client_id == 0:
		print("Waiting for server to assign client ID...")
		return false
	
	var message = {
		"user_id": client_id,
		"message": Message.CREATE_LOBBY,
		"name": "Player",  # You can customize this
		"ext_ip": get_external_ip()
	}
	peer.put_packet(JSON.stringify(message).to_utf8_buffer())
	print("Sent lobby creation request")
	return true

func join_lobby(lobbyId: String) -> bool:
	if not is_websocket_connected:
		print("Not connected to server yet! Please wait...")
		return false
	
	if client_id == 0:
		print("Waiting for server to assign client ID...")
		return false
	
	var message = {
		"user_id": client_id,
		"message": Message.JOIN_LOBBY,
		"lobby_id": lobbyId,
		"name": "Player",  # You can customize this
		"ext_ip": get_external_ip()
	}
	peer.put_packet(JSON.stringify(message).to_utf8_buffer())
	print("Sent lobby join request for lobby: ", lobbyId)
	return true
