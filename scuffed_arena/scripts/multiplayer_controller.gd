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
var rendezvous_host: RendezvousHost
var rendezvous_client: RendezvousClient

# Track connected peer IDs for multi-client support
var peer_id_map: Dictionary = {}  # ENet ID -> Rendezvous ID

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
		status_label.text = "Your IP: %s:%d\nShare this with peers!" % [StunRequest.public_ip, StunRequest.public_port]
		
		# Enable hole punch mode
		host_button.text = "Host (Rendezvous)"
		join_button.text = "Join (Rendezvous)"
		
		# Show peer IP/Port inputs only for joining
		if peer_ip_input:
			peer_ip_input.visible = false  # Host doesn't need to enter anything
			peer_ip_input.placeholder_text = "Host's Public IP"
		if peer_port_input:
			peer_port_input.visible = false
			peer_port_input.placeholder_text = "Host's Public Port"
	else:
		status_label.text = "STUN request failed!"
		use_hole_punching = false

# === Modified Host Function ===

func _on_host_button_down() -> void:
	if use_hole_punching:
		_host_with_rendezvous()
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

func _host_with_rendezvous():
	status_label.text = "Starting rendezvous host..."
	
	# Create rendezvous host
	rendezvous_host = RendezvousHost.new()
	add_child(rendezvous_host)
	
	# Connect signals
	rendezvous_host.peer_discovered.connect(_on_peer_discovered)
	rendezvous_host.peer_ready.connect(_on_peer_ready)
	
	# Start listening for peers
	var success = rendezvous_host.start_listening(StunRequest.udp)
	
	if !success:
		status_label.text = "Failed to start host!"
		return
	
	# Create ENet server
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(StunRequest.local_port, 8)
	if error != OK:
		print("Cannot create ENet server: " + str(error))
		status_label.text = "Cannot create server: " + str(error)
		return
	
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.set_multiplayer_peer(peer)
	
	status_label.text = "Hosting (Rendezvous)!\nWaiting for peers..."
	send_player_info(line_edit.text, multiplayer.get_unique_id())
	
	print("Rendezvous host started. Share your IP: %s:%d" % [StunRequest.public_ip, StunRequest.public_port])

func _on_peer_discovered(peer_id: int, peer_ip: String, peer_port: int):
	print("Peer discovered: ID=%d IP=%s:%d" % [peer_id, peer_ip, peer_port])
	status_label.text = "Peer discovered! ID: %d\nWaiting for connection..." % peer_id

func _on_peer_ready(peer_id: int):
	print("Peer %d is ready and connected!" % peer_id)
	status_label.text = "Peer %d connected!\nTotal peers: %d" % [peer_id, rendezvous_host.get_peer_count()]

# === Modified Join Function ===

func _on_join_button_down() -> void:
	if use_hole_punching:
		_join_with_rendezvous()
	else:
		_join_local()

func _join_local():
	# Original local joining code
	peer = ENetMultiplayerPeer.new()
	peer.create_client(Address, port)
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.set_multiplayer_peer(peer)
	status_label.text = "Connecting to " + Address + ":" + str(port)

func _join_with_rendezvous():
	# Show inputs for host IP/port
	if peer_ip_input:
		peer_ip_input.visible = true
	if peer_port_input:
		peer_port_input.visible = true
	
	var host_ip = peer_ip_input.text if peer_ip_input else ""
	var host_port_str = peer_port_input.text if peer_port_input else ""
	
	if host_ip.is_empty() or host_port_str.is_empty():
		status_label.text = "Please enter host's IP and port!"
		return
	
	var host_port_val = host_port_str.to_int()
	
	status_label.text = "Discovering host..."
	
	# Create rendezvous client
	rendezvous_client = RendezvousClient.new()
	add_child(rendezvous_client)
	
	# Connect signals
	rendezvous_client.id_assigned.connect(_on_id_assigned)
	rendezvous_client.connection_ready.connect(_on_client_ready)
	rendezvous_client.connection_failed.connect(_on_client_failed)
	
	# Discover host
	var success = await rendezvous_client.discover_host(StunRequest.udp, host_ip, host_port_val)
	
	if !success:
		status_label.text = "Failed to connect to host!"
		return

func _on_id_assigned(peer_id: int):
	print("Assigned ID by host: %d" % peer_id)
	status_label.text = "Assigned ID: %d\nEstablishing connection..." % peer_id

func _on_client_ready():
	print("Connection ready! Creating ENet client...")
	status_label.text = "Punching complete! Connecting via ENet..."
	
	var host_ip = peer_ip_input.text
	var host_port_val = peer_port_input.text.to_int()
	
	# Small delay before ENet
	await get_tree().create_timer(0.5).timeout
	
	# Now create ENet client
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(host_ip, host_port_val, 0, 0, 0, StunRequest.local_port)
	if error != OK:
		print("Cannot create ENet client: " + str(error))
		status_label.text = "Cannot create client: " + str(error)
		return
	
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.set_multiplayer_peer(peer)
	
	status_label.text = "Connected to host!"

func _on_client_failed():
	status_label.text = "Failed to connect!"

func _on_start_game_button_down() -> void:
	start_game.rpc()
