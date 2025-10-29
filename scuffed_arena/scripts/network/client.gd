extends Node

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

var peer:WebSocketMultiplayerPeer = WebSocketMultiplayerPeer.new()
var client_id:int = 0
var rtc_peer:WebRTCMultiplayerPeer = WebRTCMultiplayerPeer.new()
var lobby_id = ""

func _ready() -> void:
	multiplayer.connected_to_server.connect(RTCServerConnected)
	multiplayer.peer_connected.connect(RTCPeerConnected)
	multiplayer.peer_disconnected.connect(RTCPeerDisconnected)

func RTCServerConnected(_id):
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
	if peer.get_available_packet_count() > 0:
		var packet = peer.get_packet()
		if packet == null:
			return
		
		var dataString = packet.get_string_from_utf8()
		var data = JSON.parse_string(dataString)
		print(data)
		if data.message == Message.ID:
			client_id = data.id
			print("client id: " + str(client_id))
			connected(client_id)
		if data.message == Message.USER_CONNECTED:
			createPeer(data.sender_id)
		
		if data.message == Message.JOIN_LOBBY:
			GameManager.Players = data.players
			lobby_id = data.lobby_id
		
		if data.message == Message.CANDIDATE:
			if rtc_peer.has_peer(data.org_peer):
				print("Got candidate " + str(data.org_peer) + "my id is " + str(client_id))
				rtc_peer.get_peer(data.org_peer).connection.add_ice_candidate(data.mid, data.index, data.sdp)
		if data.message == Message.OFFER:
			if rtc_peer.has_peer(data.org_peer):
				print("Got Offer " + str(data.org_peer) + "my id is " + str(client_id))
				rtc_peer.get_peer(data.org_peer).connection.set_remote_description("offer", data.data)
		if data.message == Message.ANSWER:
			if rtc_peer.has_peer(data.org_peer):
				print("Got Answer " + str(data.org_peer) + "my id is " + str(client_id))
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
	
	peer.put_packet(JSON.stringify(message).to_utf8_buffer())

func send_answer(id:int, data):
	var message = {
		"peer" : id,
		"org_peer" : client_id,
		"message" : Message.ANSWER,
		"data" : data,
		"lobby" : lobby_id
	}
	
	peer.put_packet(JSON.stringify(message).to_utf8_buffer())

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

	peer.put_packet(JSON.stringify(message).to_utf8_buffer())

func connectToServer(ip, port):
	# Support both full URLs (ws://... or wss://...) and IP:Port
	var url = ""
	if ip.begins_with("ws://") or ip.begins_with("wss://"):
		url = ip  # Full URL provided (e.g., from ngrok)
	else:
		url = "ws://" + ip + ":" + str(port)  # Traditional IP:Port

	print("[Client] Connecting to signaling server: " + url)
	peer.create_client(url)
	print("started Client")

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
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		print("Not connected to server yet! Please wait...")
		return false
	
	if client_id == 0:
		print("Waiting for server to assign client ID...")
		return false
	
	var message = {
		"id" : client_id,
		"message" : Message.CREATE_LOBBY,
		"name" : "",
		"lobby_id" : Server.LOBBY_ID
	}
	peer.put_packet(JSON.stringify(message).to_utf8_buffer())
	print("Sent lobby join request")
	return true

func join_lobby(_lobbyId:String) -> bool:
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		print("Not connected to server yet! Please wait...")
		return false

	if client_id == 0:
		print("Waiting for server to assign client ID...")
		return false

	var message = {
		"id" : client_id,
		"message" : Message.JOIN_LOBBY,
		"name" : "",
		"lobby_id" : Server.LOBBY_ID
	}
	peer.put_packet(JSON.stringify(message).to_utf8_buffer())
	print("Sent lobby join request")
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
