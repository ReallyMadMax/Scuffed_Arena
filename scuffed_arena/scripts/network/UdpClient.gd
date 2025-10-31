extends Node
class_name UDPHolePunchWrapper

# Reference to the UDP connection from StunRequest
var udp : PacketPeerUDP
var peer_ip : String
var peer_port : int

# Keep alive timer
var keep_alive_timer : Timer = Timer.new()

signal connection_established
signal connection_failed

func _ready():
	add_child(keep_alive_timer)
	keep_alive_timer.wait_time = 2.0
	keep_alive_timer.timeout.connect(_on_alive_timer_timeout)

func connect_to_peer(p_udp: PacketPeerUDP, p_peer_ip: String, p_peer_port: int) -> bool:
	udp = p_udp
	peer_ip = p_peer_ip
	peer_port = p_peer_port
	
	if !udp or !udp.is_bound():
		print("Error! UDP is not bound")
		emit_signal("connection_failed")
		return false
	
	udp.set_dest_address(peer_ip, peer_port)
	print("Set dest address at: ", peer_ip, ":", str(peer_port))
	
	var connection := false
	
	# Establish UDP hole punch
	for i in range(50):
		print("Waiting for peer... attempt #", str(i))
		udp.put_packet("ping".to_utf8_buffer())
		await get_tree().create_timer(0.3).timeout
		
		if udp.get_available_packet_count() > 0:
			var packet = udp.get_packet()
			var parsed_packet = packet.get_string_from_utf8()
			if parsed_packet.begins_with("ping"):
				udp.put_packet("ping".to_utf8_buffer())
				print("UDP connection established!")
				connection = true
				break
	
	if !connection:
		print("Connection failed!")
		emit_signal("connection_failed")
		return false
	
	# Start keep alive
	keep_alive_timer.start()
	emit_signal("connection_established")
	print("Hole punch successful!")
	return true

func _on_alive_timer_timeout():
	if udp and udp.is_bound():
		udp.put_packet("keep_alive".to_utf8_buffer())

func get_local_port() -> int:
	if udp and udp.is_bound():
		return udp.get_local_port()
	return 0

func stop():
	if keep_alive_timer:
		keep_alive_timer.stop()
	if udp and udp.is_bound():
		udp.close()
