extends Node

signal connection_ready(peer_info: Dictionary)
signal hole_punch_failed(reason: String)

# Signaling server config
var signaling_server_url = "wss://your-signaling-server.com"  # WebSocket
var signaling_ws: WebSocketPeer

# Hole punching state
var local_port: int = 0
var punch_udp: PacketPeerUDP
var is_host: bool = false
var room_code: String = ""

# Peer info from signaling server
var peer_info = {
	"ip": "",
	"port": 0,
	"has_ipv6": false,
	"has_upnp": false
}

func _ready():
	punch_udp = PacketPeerUDP.new()

# Step 1: Connect to signaling server
func connect_to_signaling_server():
	signaling_ws = WebSocketPeer.new()
	var err = signaling_ws.connect_to_url(signaling_server_url)
	if err != OK:
		hole_punch_failed.emit("Failed to connect to signaling server")
		return
	print("Connecting to signaling server...")

func _process(_delta):
	if signaling_ws:
		signaling_ws.poll()
		var state = signaling_ws.get_ready_state()
		
		if state == WebSocketPeer.STATE_OPEN:
			while signaling_ws.get_available_packet_count():
				var packet = signaling_ws.get_packet()
				_handle_signaling_message(packet.get_string_from_utf8())
		elif state == WebSocketPeer.STATE_CLOSED:
			print("Signaling server disconnected")

# Step 2: Create or join a room
func create_room():
	is_host = true
	room_code = _generate_room_code()
	local_port = randi_range(49152, 65535)  # Use ephemeral port range
	
	var msg = JSON.stringify({
		"action": "create_room",
		"room_code": room_code,
		"port": local_port
	})
	signaling_ws.send_text(msg)
	print("Creating room: ", room_code)

func join_room(code: String):
	is_host = false
	room_code = code
	local_port = randi_range(49152, 65535)
	
	var msg = JSON.stringify({
		"action": "join_room",
		"room_code": room_code,
		"port": local_port
	})
	signaling_ws.send_text(msg)
	print("Joining room: ", room_code)

# Step 3: Handle signaling messages
func _handle_signaling_message(message: String):
	var json = JSON.new()
	var parse_result = json.parse(message)
	if parse_result != OK:
		return
	
	var data = json.data
	
	match data.get("type"):
		"room_created":
			print("Room created successfully: ", room_code)
			# Wait for peer to join
		
		"peer_joined":
			print("Peer joined, starting hole punch...")
			peer_info = data.get("peer_info", {})
			_start_hole_punch()
		
		"peer_info":
			print("Received peer info")
			peer_info = data.get("info", {})
			_start_hole_punch()
		
		"error":
			hole_punch_failed.emit(data.get("message", "Unknown error"))

# Step 4: Perform hole punch
func _start_hole_punch():
	print("Starting hole punch to ", peer_info.ip, ":", peer_info.port)
	
	# Bind to local port
	var err = punch_udp.bind(local_port)
	if err != OK:
		hole_punch_failed.emit("Failed to bind port " + str(local_port))
		return
	
	# Set destination
	punch_udp.set_dest_address(peer_info.ip, peer_info.port)
	
	# Send punch packets
	_send_punch_packets()

func _send_punch_packets():
	print("Sending punch packets...")
	# Send multiple packets to ensure at least one gets through
	for i in range(20):
		var punch_msg = "PUNCH:%s:%d" % [room_code, local_port]
		punch_udp.put_packet(punch_msg.to_utf8_buffer())
		await get_tree().create_timer(0.05).timeout
	
	print("Hole punch complete, creating multiplayer peer...")
	_create_multiplayer_peer()

# Step 5: Create ENet peer using punched hole
func _create_multiplayer_peer():
	var peer = ENetMultiplayerPeer.new()
	
	if is_host:
		var err = peer.create_server(local_port, 1)
		if err != OK:
			hole_punch_failed.emit("Failed to create server")
			return
		print("Created server on port ", local_port)
	else:
		var err = peer.create_client(
			peer_info.ip, 
			peer_info.port,
			0,  # channel_count
			0,  # in_bandwidth
			0,  # out_bandwidth  
			local_port  # CRITICAL: use the punched port
		)
		if err != OK:
			hole_punch_failed.emit("Failed to create client")
			return
		print("Created client connecting to ", peer_info.ip, ":", peer_info.port)
	
	multiplayer.multiplayer_peer = peer
	connection_ready.emit(peer_info)

# Helper functions
func _generate_room_code() -> String:
	var chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var code = ""
	for i in range(6):
		code += chars[randi() % chars.length()]
	return code

# Cleanup
func cleanup():
	if punch_udp:
		punch_udp.close()
	if signaling_ws:
		signaling_ws.close()
