extends Node
class_name RendezvousClient

# UDP connection from STUN
var udp: PacketPeerUDP
var host_ip: String
var host_port: int

var assigned_id: int = -1
var is_discovering: bool = false
var wrapper: UDPHolePunchWrapper

signal id_assigned(peer_id: int)
signal connection_ready()
signal connection_failed()

func discover_host(p_udp: PacketPeerUDP, p_host_ip: String, p_host_port: int) -> bool:
	"""Send discovery packet to host and wait for response"""
	udp = p_udp
	host_ip = p_host_ip
	host_port = p_host_port
	
	if !udp or !udp.is_bound():
		push_error("UDP not bound!")
		emit_signal("connection_failed")
		return false
	
	is_discovering = true
	
	print("Discovering host at %s:%d" % [host_ip, host_port])
	
	udp.set_dest_address(host_ip, host_port)
	
	# Generate a temporary local ID
	var temp_id = randi_range(1000, 9999)
	
	# Send discovery packets and wait for ID assignment
	for i in range(30):
		print("Sending discovery packet... attempt %d" % (i + 1))
		var discovery_msg = "DISCOVER:%d" % temp_id
		udp.put_packet(discovery_msg.to_utf8_buffer())
		
		await get_tree().create_timer(0.3).timeout
		
		# Check for response
		if _check_for_id_assignment():
			print("Received ID assignment: %d" % assigned_id)
			emit_signal("id_assigned", assigned_id)
			
			# Now establish the full hole punch
			await get_tree().create_timer(0.5).timeout
			return await _establish_connection()
	
	print("Discovery failed - no response from host")
	is_discovering = false
	emit_signal("connection_failed")
	return false

func _check_for_id_assignment() -> bool:
	"""Check if we received an ID assignment from host"""
	while udp.get_available_packet_count() > 0:
		var packet = udp.get_packet()
		var message = packet.get_string_from_utf8()
		
		if message.begins_with("ASSIGN_ID:"):
			var parts = message.split(":")
			if parts.size() >= 2:
				assigned_id = parts[1].to_int()
				return true
		elif message.begins_with("ping"):
			# Host is punching back, respond
			udp.put_packet("ping".to_utf8_buffer())
	
	return false

func _establish_connection() -> bool:
	"""Complete the hole punch connection with host"""
	print("Establishing connection with host...")
	
	wrapper = UDPHolePunchWrapper.new()
	add_child(wrapper)
	
	var success = await wrapper.connect_to_peer(udp, host_ip, host_port)
	
	if success:
		# Send ready confirmation
		await get_tree().create_timer(0.2).timeout
		udp.set_dest_address(host_ip, host_port)
		var ready_msg = "READY:%d" % assigned_id
		udp.put_packet(ready_msg.to_utf8_buffer())
		
		print("Connection established with host!")
		is_discovering = false
		emit_signal("connection_ready")
		return true
	else:
		print("Failed to establish connection")
		wrapper.queue_free()
		is_discovering = false
		emit_signal("connection_failed")
		return false

func get_assigned_id() -> int:
	return assigned_id

func disconnect_from_host():
	if wrapper:
		wrapper.stop()
		wrapper.queue_free()
		wrapper = null
	
	is_discovering = false
	assigned_id = -1
