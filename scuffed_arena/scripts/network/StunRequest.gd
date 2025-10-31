extends Node

# Configuration
@export var local_port: int = 50000  # Port to bind locally
@export var stunServer_ip: String = "stun.l.google.com"
@export var stunServer_port: int = 19302

# UDP connection
var udp: PacketPeerUDP = null

# Public address info
var public_ip: String = ""
var public_port: int = 0

signal stun_completed(success: bool, ip: String, port: int)

func initiate_stun_request() -> void:
	udp = PacketPeerUDP.new()
	
	if udp.is_bound():
		print("Error, UDP is already bound!")
		emit_signal("stun_completed", false, "", 0)
		return
	
	var bind_status = udp.bind(local_port, "0.0.0.0")  # Only use IPv4 address
	if bind_status != OK:
		print("Bind Failed: ", error_string(bind_status))
		emit_signal("stun_completed", false, "", 0)
		return
	
	print("Bound to port at: ", local_port)
	udp.set_dest_address(stunServer_ip, stunServer_port)
	
	var request_package = stun_request_package()
	var requestTransactionID = request_package.transactionID
	var requestMessage = request_package.requestMessage
	
	udp.put_packet(requestMessage)
	print("Requesting STUN...")
	
	var timeout = Time.get_ticks_msec() + 5000
	while udp.get_available_packet_count() == 0:
		if Time.get_ticks_msec() > timeout:
			print("STUN failed...")
			emit_signal("stun_completed", false, "", 0)
			return
		else:
			await get_tree().create_timer(0.1).timeout
	
	print("Response found!")
	var responseMessage = udp.get_packet()
	var responseType = responseMessage.decode_u16(0)
	var responseTransactionID = responseMessage.slice(8, 20)
	
	if responseType != 0x0101 or responseTransactionID != requestTransactionID:
		print("Received invalid STUN binding response!")
		emit_signal("stun_completed", false, "", 0)
		return
	
	var responseAddress = parse_stun_response(responseMessage.slice(24))
	print("STUN was successful!")
	print("Public IP Address: ", responseAddress.address)
	print("Public port: ", responseAddress.port)
	
	# Store the public address
	public_ip = responseAddress.address
	public_port = responseAddress.port
	
	emit_signal("stun_completed", true, public_ip, public_port)

func stun_request_package() -> Dictionary:
	var transactionID = PackedByteArray()
	for n in 12:
		transactionID.append(randi_range(0, 255))
	
	var buffer = PackedByteArray()
	buffer.resize(20)
	
	var message = StreamPeerBuffer.new()
	message.data_array = buffer
	message.big_endian = true
	message.put_u64(0x0001000000000000)
	message.put_data(transactionID)
	
	return {
		"requestMessage": message.data_array,
		"transactionID": transactionID
	}

func parse_stun_response(attributes: PackedByteArray) -> Dictionary:
	var streamBuffer = StreamPeerBuffer.new()
	streamBuffer.data_array = attributes
	streamBuffer.big_endian = true
	
	var address_type = streamBuffer.get_u16()
	var discovered_port = streamBuffer.get_u16()
	var discovered_address = ""
	
	if address_type == 0x01:
		var address = []
		for n in 4:
			address.push_back(streamBuffer.get_u8())
		discovered_address = ".".join(address)
	
	return {
		"address": discovered_address,
		"port": discovered_port
	}
