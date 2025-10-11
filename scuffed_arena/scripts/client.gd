extends Node

enum Message {
	ID,
	JOIN,
	USER_CONNECTED,
	USER_DISCONNECTED,
	LOBBY,
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
			
		if data.message == Message.LOBBY:
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
		#TODO: this is what need need to figure out for pure p2p
		ext_peer.initialize({
			"ice_server" : [{ "urls": ["stun:stun.l.google.com:19302"]}]
		})
		print("binding id " + str(id) + " my id " + str(client_id))
	
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



func connectToServer(ip):
	peer.create_client("ws://"+ip+":6000")
	print("started Client")


func _on_start_client_button_down() -> void:
	connectToServer($IpAddress.text)


func _on_ping_button_down() -> void:
	start_game.rpc()

@rpc("any_peer", "call_local")
func start_game():
	var scene = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(scene)

func _on_join_lobby_button_down() -> void:
	var message = {
		"id" : client_id,
		"message" : Message.LOBBY,
		"name" : "",
		"lobby_id" : $LobbyID.text
	}
	peer.put_packet(JSON.stringify(message).to_utf8_buffer())
