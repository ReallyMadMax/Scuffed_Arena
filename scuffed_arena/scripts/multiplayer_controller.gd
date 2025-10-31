extends Control

@export var Address = "127.0.0.1"
@export var port = 6000

# UI Elements
@onready var line_edit = $Username
@onready var host_button = $Host
@onready var join_button = $Join
@onready var start_game_button = $StartGame
@onready var stun_button = $StunButton
@onready var peer_ip_input = $Address
@onready var peer_port_input = $Port
@onready var status_label = $StatusLabel

var peer
var use_hole_punching = false
var hole_punch_wrapper : UDPHolePunchWrapper

func _ready():
	multiplayer.peer_connected.connect(player_connected)
	multiplayer.peer_disconnected.connect(player_disconnected)
	multiplayer.connected_to_server.connect(connected_to_server)
	multiplayer.connection_failed.connect(connection_failed)
	
	# Connect STUN button
	if stun_button:
		stun_button.pressed.connect(_on_stun_button_pressed)
	
	status_label.text = "Ready. Choose local or hole punch mode."

# this gets called on the server and the clients
func player_connected(id):
	print("Player Connected " + str(id))
	status_label.text = "Player Connected: " + str(id)
	
# this gets called on the server and the clients
func player_disconnected(id):
	print("Player Disconnected " + str(id))
	status_label.text = "Player Disconnected: " + str(id)

# only on clients
func connected_to_server():
	send_player_info.rpc_id(1, line_edit.text, multiplayer.get_unique_id())
	print("Connected to server")
	status_label.text = "Connected to server!"

# only on clients
func connection_failed():
	print("Could not connect")
	status_label.text = "Connection failed!"

@rpc("any_peer")
func send_player_info(player_name, id):
	if !GameManager.Players.has(id):
		GameManager.Players[id] = {
			"name": player_name,
			"id": id,
			"score": 0
		}
	
	if multiplayer.is_server():
		for i in GameManager.Players:
			send_player_info.rpc(GameManager.Players[i].name, i)

@rpc("any_peer", "call_local")
func start_game():
	var scene = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(scene)
	self.hide()

# === STUN / Hole Punching Functions ===

func _on_stun_button_pressed() -> void:
	status_label.text = "Requesting STUN..."
	use_hole_punching = true
	
	# Make STUN request
	StunRequest.initiate_stun_request()
	
	# Wait for STUN to complete
	await get_tree().create_timer(3.0).timeout
	
	if StunRequest.public_ip and StunRequest.public_port:
		status_label.text = "Your IP: %s:%d\nShare this with peer!" % [StunRequest.public_ip, StunRequest.public_port]
		
		# Enable hole punch mode
		host_button.text = "Host (Hole Punch)"
		join_button.text = "Join (Hole Punch)"
		
		# Show peer IP/Port inputs
		if peer_ip_input:
			peer_ip_input.visible = true
			peer_ip_input.placeholder_text = "Peer's Public IP"
		if peer_port_input:
			peer_port_input.visible = true
			peer_port_input.placeholder_text = "Peer's Public Port"
	else:
		status_label.text = "STUN request failed!"
		use_hole_punching = false

# === Modified Host Function ===

func _on_host_button_down() -> void:
	if use_hole_punching:
		_host_with_hole_punch()
	else:
		_host_local()

func _host_local():
	# Original local hosting code
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, 8)
	if error != OK:
		print("Cannot host: " + str(error))
		status_label.text = "Cannot host: " + str(error)
		return
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	
	multiplayer.set_multiplayer_peer(peer)
	print("Waiting for players")
	status_label.text = "Hosting on port " + str(port)
	send_player_info(line_edit.text, multiplayer.get_unique_id())

func _host_with_hole_punch():
	var peer_ip = peer_ip_input.text if peer_ip_input else ""
	var peer_port_str = peer_port_input.text if peer_port_input else ""
	
	if peer_ip.is_empty() or peer_port_str.is_empty():
		status_label.text = "Please enter peer's IP and port!"
		return
	
	var peer_port_val = peer_port_str.to_int()
	
	status_label.text = "Establishing hole punch as host..."
	
	# First establish UDP hole punch
	hole_punch_wrapper = UDPHolePunchWrapper.new()
	add_child(hole_punch_wrapper)
	
	var success = await hole_punch_wrapper.connect_to_peer(StunRequest.udp, peer_ip, peer_port_val)
	
	if !success:
		status_label.text = "Hole punch failed!"
		return
	
	# Now create ENet server on the same port
	await get_tree().create_timer(0.5).timeout  # Small delay
	
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(StunRequest.local_port, 2)
	if error != OK:
		print("Cannot create ENet server: " + str(error))
		status_label.text = "Cannot create server: " + str(error)
		return
	
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.set_multiplayer_peer(peer)
	
	status_label.text = "Hole punch successful! Hosting..."
	send_player_info(line_edit.text, multiplayer.get_unique_id())

# === Modified Join Function ===

func _on_join_button_down() -> void:
	if use_hole_punching:
		_join_with_hole_punch()
	else:
		_join_local()

func _join_local():
	# Original local joining code
	peer = ENetMultiplayerPeer.new()
	peer.create_client(Address, port)
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.set_multiplayer_peer(peer)
	status_label.text = "Connecting to " + Address + ":" + str(port)

func _join_with_hole_punch():
	var peer_ip = peer_ip_input.text if peer_ip_input else ""
	var peer_port_str = peer_port_input.text if peer_port_input else ""
	
	if peer_ip.is_empty() or peer_port_str.is_empty():
		status_label.text = "Please enter peer's IP and port!"
		return
	
	var peer_port_val = peer_port_str.to_int()
	
	status_label.text = "Establishing hole punch as client..."
	
	# First establish UDP hole punch
	hole_punch_wrapper = UDPHolePunchWrapper.new()
	add_child(hole_punch_wrapper)
	
	var success = await hole_punch_wrapper.connect_to_peer(StunRequest.udp, peer_ip, peer_port_val)
	
	if !success:
		status_label.text = "Hole punch failed!"
		return
	
	# Now create ENet client to connect through the punched hole
	await get_tree().create_timer(0.5).timeout  # Small delay
	
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(peer_ip, peer_port_val, 0, 0, 0, StunRequest.local_port)
	if error != OK:
		print("Cannot create ENet client: " + str(error))
		status_label.text = "Cannot create client: " + str(error)
		return
	
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.set_multiplayer_peer(peer)
	
	status_label.text = "Hole punch successful! Connecting..."

func _on_start_game_button_down() -> void:
	start_game.rpc()
