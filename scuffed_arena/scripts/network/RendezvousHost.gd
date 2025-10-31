extends Node
class_name RendezvousHost

# UDP connection from STUN
var udp: PacketPeerUDP
var is_listening: bool = false

# Track all connected peers
var connected_peers: Dictionary = {}  # peer_id -> {ip: String, port: int, wrapper: UDPHolePunchWrapper}
var next_peer_id: int = 2  # Start from 2 (1 is reserved for host)

# Keep alive timer
var keep_alive_timer: Timer = Timer.new()

signal peer_discovered(peer_id: int, peer_ip: String, peer_port: int)
signal peer_ready(peer_id: int)
signal peer_lost(peer_id: int)

func _ready():
	add_child(keep_alive_timer)
	keep_alive_timer.wait_time = 2.0
	keep_alive_timer.timeout.connect(_send_keep_alives)

func start_listening(p_udp: PacketPeerUDP):
	"""Start listening for incoming peer discovery packets"""
	udp = p_udp
	
	if !udp or !udp.is_bound():
		push_error("UDP not bound!")
		return false
	
	is_listening = true
	keep_alive_timer.start()
	
	# Start polling for incoming connections
	_poll_for_peers()
	
	print("Host listening for peers on port: ", udp.get_local_port())
	return true

func _poll_for_peers():
	"""Continuously poll for new peer connections"""
	while is_listening:
		await get_tree().create_timer(0.1).timeout
		_check_incoming_packets()

func _check_incoming_packets():
	"""Check for incoming discovery packets from new peers"""
	if !udp or !is_listening:
		return
	
	while udp.get_available_packet_count() > 0:
		var packet = udp.get_packet()
		var peer_address = udp.get_packet_ip()
		var peer_port = udp.get_packet_port()
		
		var message = packet.get_string_from_utf8()
		
		# Check if this is a discovery packet
		if message.begins_with("DISCOVER:"):
			_handle_discovery(message, peer_address, peer_port)
		elif message.begins_with("READY:"):
			_handle_ready(message, peer_address, peer_port)

func _handle_discovery(message: String, peer_ip: String, peer_port: int):
	"""Handle discovery packet from a new peer"""
	# Extract peer's local ID from message (format: "DISCOVER:client_local_id")
	var parts = message.split(":")
	if parts.size() < 2:
		return
	
	# Check if we already know this peer
	var peer_key = "%s:%d" % [peer_ip, peer_port]
	for peer_id in connected_peers:
		var peer_data = connected_peers[peer_id]
		if "%s:%d" % [peer_data.ip, peer_data.port] == peer_key:
			# Already connected, just respond
			_send_discovery_response(peer_ip, peer_port, peer_id)
			return
	
	# New peer discovered!
	var assigned_id = next_peer_id
	next_peer_id += 1
	
	print("New peer discovered at %s:%d - Assigned ID: %d" % [peer_ip, peer_port, assigned_id])
	
	# Send response with assigned ID
	_send_discovery_response(peer_ip, peer_port, assigned_id)
	
	# Start hole punching back to this peer
	await get_tree().create_timer(0.2).timeout
	_punch_back_to_peer(assigned_id, peer_ip, peer_port)
	
	emit_signal("peer_discovered", assigned_id, peer_ip, peer_port)

func _send_discovery_response(peer_ip: String, peer_port: int, assigned_id: int):
	"""Send response back to discovered peer with their assigned ID"""
	if !udp:
		return
	
	var original_dest = udp.get_packet_ip()
	var original_port = udp.get_packet_port()
	
	udp.set_dest_address(peer_ip, peer_port)
	var response = "ASSIGN_ID:%d" % assigned_id
	udp.put_packet(response.to_utf8_buffer())
	
	# Restore original destination if needed
	if original_dest and original_port:
		udp.set_dest_address(original_dest, original_port)

func _punch_back_to_peer(peer_id: int, peer_ip: String, peer_port: int):
	"""Establish UDP hole punch back to the peer"""
	print("Punching back to peer %d at %s:%d" % [peer_id, peer_ip, peer_port])
	
	var wrapper = UDPHolePunchWrapper.new()
	add_child(wrapper)
	
	var success = await wrapper.connect_to_peer(udp, peer_ip, peer_port)
	
	if success:
		connected_peers[peer_id] = {
			"ip": peer_ip,
			"port": peer_port,
			"wrapper": wrapper
		}
		print("Successfully punched back to peer %d" % peer_id)
	else:
		print("Failed to punch back to peer %d" % peer_id)
		wrapper.queue_free()

func _handle_ready(message: String, peer_ip: String, peer_port: int):
	"""Handle ready confirmation from peer"""
	var parts = message.split(":")
	if parts.size() < 2:
		return
	
	var peer_id = parts[1].to_int()
	
	if connected_peers.has(peer_id):
		print("Peer %d is ready!" % peer_id)
		emit_signal("peer_ready", peer_id)

func _send_keep_alives():
	"""Send keep alive to all connected peers"""
	for peer_id in connected_peers:
		var peer_data = connected_peers[peer_id]
		if peer_data.wrapper:
			# The wrapper handles keep alive automatically
			pass

func get_peer_count() -> int:
	return connected_peers.size()

func get_peer_ids() -> Array:
	return connected_peers.keys()

func stop_listening():
	is_listening = false
	keep_alive_timer.stop()
	
	# Clean up all wrappers
	for peer_id in connected_peers:
		var peer_data = connected_peers[peer_id]
		if peer_data.wrapper:
			peer_data.wrapper.stop()
			peer_data.wrapper.queue_free()
	
	connected_peers.clear()
