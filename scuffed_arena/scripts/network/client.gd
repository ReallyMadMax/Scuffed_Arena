extends Node

signal player_connected(id:int)
signal lobby_joined(id:String)

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

# Use WebSocketPeer for signaling (not WebSocketMultiplayerPeer)
var peer:WebSocketPeer = WebSocketPeer.new()
var client_id:int = 0
var rtc_peer:WebRTCMultiplayerPeer = WebRTCMultiplayerPeer.new()
var lobby_id = ""
var _last_state = WebSocketPeer.STATE_CLOSED
var _close_logged = false

# RENDER CONFIGURATION
# Replace this with your Render app URL after deployment
const RENDER_URL = "wss://scuffedarena-server.onrender.com"
# Set to true to use Render, false to use local server
const USE_RENDER = true

func _ready() -> void:
	multiplayer.connected_to_server.connect(RTCServerConnected)
	multiplayer.peer_connected.connect(RTCPeerConnected)
	multiplayer.peer_disconnected.connect(RTCPeerDisconnected)

func RTCServerConnected():
	print("server conected")
	pass

func RTCPeerConnected(id):
	print("peer connected " + str(id))
	pass

func RTCPeerDisconnected(id):
	print("peer disconnected " + str(id))
	pass

func _process(_delta):
	peer.poll()
	
	var state = peer.get_ready_state()
	
	# Detect state changes
	if state != _last_state:
		_last_state = state
		_close_logged = false
		
		if state == WebSocketPeer.STATE_OPEN:
			print("[Client] WebSocket connection established")
	
	if state == WebSocketPeer.STATE_CLOSING:
		if !_close_logged:
			print("[Client] WebSocket closing...")
			_close_logged = true
	elif state == WebSocketPeer.STATE_CLOSED:
		if !_close_logged:
			var code = peer.get_close_code()
			var reason = peer.get_close_reason()
			print("[Client] WebSocket closed with code: %d, reason: %s" % [code, reason])
			_close_logged = true
	elif state != WebSocketPeer.STATE_OPEN:
		return

	while peer.get_available_packet_count() > 0:
		var packet = peer.get_packet()
		if packet.size() == 0:
			continue
		
		var dataString = packet.get_string_from_utf8()
		var data = JSON.parse_string(dataString)
		
		if data == null:
			print("[Client] Failed to parse JSON: " + dataString)
			continue
		
		print("[Client] Received: ", data)
		
		match data.message as Message:
			Message.ID:
				client_id = int(data.id)
				print("[Client] Assigned client ID: " + str(client_id))
				connected(client_id)
			
			Message.USER_CONNECTED:
				createPeer(data.sender_id)
			
			Message.JOIN_LOBBY:
				GameManager.Players = data.players
				lobby_id = data.lobby_id
				print("[Client] Joined lobby with " + str(data.players.size()) + " players")
				player_connected.emit(client_id)
				lobby_joined.emit(lobby_id)
			
			Message.CANDIDATE:
				if rtc_peer.has_peer(data.org_peer):
					print("Got candidate " + str(data.org_peer) + " my id is " + str(client_id))
					rtc_peer.get_peer(data.org_peer).connection.add_ice_candidate(data.mid, data.index, data.sdp)
			
			Message.OFFER:
				if rtc_peer.has_peer(data.org_peer):
					print("Got Offer " + str(data.org_peer) + " my id is " + str(client_id))
					rtc_peer.get_peer(data.org_peer).connection.set_remote_description("offer", data.data)
			
			Message.ANSWER:
				if rtc_peer.has_peer(data.org_peer):
					print("Got Answer " + str(data.org_peer) + " my id is " + str(client_id))
					rtc_peer.get_peer(data.org_peer).connection.set_remote_description("answer", data.data)


func connected(id:int):
	rtc_peer.create_mesh(id)
	multiplayer.multiplayer_peer = rtc_peer

#web RTC connection stuff
func createPeer(id:int):
	if id != client_id:
		var ext_peer : WebRTCPeerConnection = WebRTCPeerConnection.new()
		# WebRTC with STUN/TURN for NAT traversal
		ext_peer.initialize({
			"iceServers" : [
				# Google STUN servers for discovering public IP/port
				{ "urls": ["stun:stun.l.google.com:19302"]},
				{ "urls": ["stun:stun1.l.google.com:19302"]},
				{ "urls": ["stun:stun2.l.google.com:19302"]},
				# TURN relay servers for restrictive NATs (multiple ports for better compatibility)
				{
					"urls": [
						"turn:openrelay.metered.ca:80",
						"turn:openrelay.metered.ca:443",
						"turn:openrelay.metered.ca:3478",
						"turns:openrelay.metered.ca:443"  # TLS for secure networks
					],
					"username": "openrelayproject",
					"credential": "openrelayproject"
				}
			],
			"iceTransportPolicy": "all"  # Try all connection methods (direct, STUN, TURN)
		})
		
		# Monitor connection status
		var monitor_connection = func():
			await get_tree().create_timer(0.5).timeout
			print("[WebRTC] Starting connection to peer %d..." % id)

			for i in range(30):  # Monitor for 15 seconds
				if rtc_peer.has_peer(id):
					var connection = rtc_peer.get_peer(id).connection
					var conn_state = connection.get_connection_state()
					var gathering_state = connection.get_gathering_state()

					# Log state changes (only on iteration 0, 2, 4, etc. to reduce spam)
					if i % 2 == 0:
						print("[WebRTC] Peer %d - Connection: %s | Gathering: %s" % [
							id,
							_connection_state_name(conn_state),
							_gathering_state_name(gathering_state)
						])

					if conn_state == WebRTCPeerConnection.STATE_CONNECTED:
						print("[WebRTC] ✓ Successfully connected to peer %d" % id)
						break
					elif conn_state == WebRTCPeerConnection.STATE_FAILED:
						print("[WebRTC] ✗ Failed to connect to peer %d" % id)
						print("[WebRTC] → This likely means TURN server is needed or unreachable")
						print("[WebRTC] → Consider using a paid TURN service for better reliability")
						break
					elif conn_state == WebRTCPeerConnection.STATE_DISCONNECTED:
						print("[WebRTC] ⚠ Disconnected from peer %d" % id)
						break
				await get_tree().create_timer(0.5).timeout

			# Timeout reached
			if rtc_peer.has_peer(id):
				var final_state = rtc_peer.get_peer(id).connection.get_connection_state()
				if final_state != WebRTCPeerConnection.STATE_CONNECTED:
					print("[WebRTC] ⏱ Connection attempt to peer %d timed out (state: %s)" % [
						id, _connection_state_name(final_state)
					])

		monitor_connection.call()
		
		ext_peer.session_description_created.connect(self.offer_created.bind(id))
		ext_peer.ice_candidate_created.connect(self.ice_candidate_created.bind(id))
		rtc_peer.add_peer(ext_peer, id)
		
		if id < rtc_peer.get_unique_id():
			ext_peer.create_offer()

func offer_created(type:String, data, id:int):
	if !rtc_peer.has_peer(id):
		return
	
	rtc_peer.get_peer(id).connection.set_local_description(type, data)
	
	if type == "offer":
		send_offer(id, data)
	else:
		send_answer(id, data)

func send_offer(id:int, data):
	var message = {
		"peer" : id,
		"org_peer" : client_id,
		"message" : Message.OFFER,
		"data" : data,
		"lobby" : lobby_id
	}
	
	send_to_server(message)

func send_answer(id:int, data):
	var message = {
		"peer" : id,
		"org_peer" : client_id,
		"message" : Message.ANSWER,
		"data" : data,
		"lobby" : lobby_id
	}
	
	send_to_server(message)

func ice_candidate_created(mid_name, index_name, sdp_name, id:int):
	print("[WebRTC] ICE candidate created for peer %d (mid: %s)" % [id, mid_name])

	var message = {
		"peer" : id,
		"org_peer" : client_id,
		"message" : Message.CANDIDATE,
		"mid" : mid_name,
		"index" : index_name,
		"sdp" : sdp_name,
		"lobby" : lobby_id
	}

	send_to_server(message)

func send_to_server(data: Dictionary):
	if peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var json_string = JSON.stringify(data)
		peer.send_text(json_string)
	else:
		print("[Client] Cannot send - WebSocket not connected")

func connectToServer(ip = "", port = 0):
	# Reset state tracking
	_last_state = peer.get_ready_state()
	_close_logged = false
	
	var url = ""
	
	if USE_RENDER:
		# Connect to Render signaling server
		url = RENDER_URL
		print("[Client] Connecting to Render signaling server: " + url)
	else:
		# Use provided IP/port or fall back to local
		if ip.begins_with("ws://") or ip.begins_with("wss://"):
			url = ip  # Full URL provided (e.g., from ngrok)
		else:
			if ip == "":
				ip = "localhost"
			if port == 0:
				port = 6000
			url = "ws://" + ip + ":" + str(port)
		print("[Client] Connecting to local/custom signaling server: " + url)

	var err = peer.connect_to_url(url)
	if err != OK:
		print("[Client] Failed to connect: " + str(err))
	else:
		print("[Client] Connection initiated...")

func disconnect_from_server():
	if peer.get_ready_state() == WebSocketPeer.STATE_OPEN or peer.get_ready_state() == WebSocketPeer.STATE_CONNECTING:
		peer.close()
		print("[Client] Disconnecting from server...")

@rpc("any_peer", "call_local")
func start_game():
	print("Loading main scene...")
	var scene = load("res://scenes/main.tscn").instantiate()

	# List of autoload singletons to keep (don't delete these!) fuck
	# We probably need to change this so that it doesn't need to be modified every time a new singleton is added
	var autoloads = ["GameManager", "UpgradeManager", "Client"]

	for child in get_tree().root.get_children():
		if child.name not in autoloads:
			child.queue_free()

	print("Adding main scene to tree...")
	get_tree().root.add_child(scene)

func generate_lobby_id(length:int) -> String:
	var id = ""
	for i in range(length):
		id += str(randi_range(0, 9))
	return id

func create_lobby() -> bool:
	if peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
		print("[Client] Not connected to signaling server yet!")
		return false
	
	if client_id == 0:
		print("[Client] Waiting for server to assign client ID...")
		return false
	
	var new_lobby_id = generate_lobby_id(6)
	var message = {
		"id" : client_id,
		"message" : Message.CREATE_LOBBY,
		"name" : "gay monkey",
		"lobby_id" : new_lobby_id
	}
	send_to_server(message)
	print("[Client] Sent lobby create request " + new_lobby_id)
	return true

func join_lobby(new_lobby_id:String) -> bool:
	if peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
		print("[Client] Not connected to signaling server yet!")
		return false

	if client_id == 0:
		print("[Client] Waiting for server to assign client ID...")
		return false

	var message = {
		"id" : client_id,
		"message" : Message.JOIN_LOBBY,
		"name" : "",
		"lobby_id" : new_lobby_id
	}
	send_to_server(message)
	print("[Client] Sent lobby join request")
	return true

# Helper functions for readable state names
func _connection_state_name(state: int) -> String:
	match state:
		WebRTCPeerConnection.STATE_NEW: return "NEW"
		WebRTCPeerConnection.STATE_CONNECTING: return "CONNECTING"
		WebRTCPeerConnection.STATE_CONNECTED: return "CONNECTED"
		WebRTCPeerConnection.STATE_DISCONNECTED: return "DISCONNECTED"
		WebRTCPeerConnection.STATE_FAILED: return "FAILED"
		WebRTCPeerConnection.STATE_CLOSED: return "CLOSED"
		_: return "UNKNOWN"

func _ice_state_name(state: int) -> String:
	# In Godot 4.5, use the connection state (same as _connection_state_name)
	# ICE connection state is now merged with the main connection state
	return _connection_state_name(state)

func _gathering_state_name(state: int) -> String:
	match state:
		WebRTCPeerConnection.GATHERING_STATE_NEW: return "NEW"
		WebRTCPeerConnection.GATHERING_STATE_GATHERING: return "GATHERING"
		WebRTCPeerConnection.GATHERING_STATE_COMPLETE: return "COMPLETE"
		_: return "UNKNOWN"
