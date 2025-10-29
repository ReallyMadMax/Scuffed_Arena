extends Node

signal lobby_created(lobbyID:String)
signal player_joined
signal player_left

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

var peer = WebSocketMultiplayerPeer.new()
var port = 6000
var users = {}
var lobby:Lobby
var LOBBY_ID:String = "BAHAHAHAHA"
var chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMMNOPQRSTUVWXYZ1234567890"
# External IP is only used for display purposes (so host knows what IP to share)
# WebRTC handles all NAT traversal, this is NOT used for hole punching
var ext_ip:String = ""

# C# Signaling Server Process
var signaling_server_pid: int = -1
var signaling_server_running: bool = false

func _ready():
	peer.connect("peer_connected", peer_connected)
	peer.connect("peer_disconnected", peer_disconnected)

	# Fetch external IP to display to the host (for sharing with other players)
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_ext_ip_fetched)
	http.request("https://ipv4.icanhazip.com")

func _exit_tree():
	# Clean up signaling server when game exits
	stop_signaling_server()

func _on_ext_ip_fetched(_result:int, response_code:int, _headers:PackedStringArray, body:PackedByteArray) -> void:
	if response_code == 200:
		ext_ip = body.get_string_from_utf8().strip_edges()
		print("[Server] External IP: %s (for display only, share this with other players)" % ext_ip)
	else:
		ext_ip = "Unable to fetch"
		print("[Server] Failed to get external IP, response code: %d" % response_code)

func _process(_delta):
	peer.poll()
	if peer.get_available_packet_count() > 0:
		var packet = peer.get_packet()
		if packet != null:
			var dataString = packet.get_string_from_utf8()
			var data = JSON.parse_string(dataString)
			if data.message == Message.CREATE_LOBBY:
				create_lobby(data)
			if data.message == Message.JOIN_LOBBY:
				join_lobby(data)
			
			if data.message == Message.OFFER || data.message == Message.ANSWER || data.message == Message.CANDIDATE:
				send_to_player(data.peer, data)
	

func peer_connected(id:int):
	print("peer connected : " + str(id))
	users[id] = {
		"id": id,
		"message" : Message.ID,
	}
	send_to_player(id, users[id])
	player_joined.emit()

func peer_disconnected(id:int):
	lobby.remove_player(id)
	users.erase(id)
	player_left.emit()

func create_lobby(user):
	user.lobby_id = LOBBY_ID
	lobby_created.emit(user.lobby_id)
	
	lobby = Lobby.new(user.id)
	
	join_lobby(user)

func join_lobby(user):
	lobby.add_player(user.id, user.name)

	for p in lobby.Players:
		send_connection_packet(user.id, p, null)
		send_connection_packet(p, user.id, null)
		
		var lobby_info = {
			"message" : Message.JOIN_LOBBY,
			"players" : lobby.Players,
			"lobby_id" : user.lobby_id
		}
		send_to_player(p, lobby_info)
	
	send_connection_packet(user.id, user.id, lobby)
	player_joined.emit()

func send_connection_packet(sender_id:int, receiver_id:int, new_lobby:Lobby):
	var data = {
		"message" : Message.USER_CONNECTED,
		"sender_id" : sender_id,
	}
	if new_lobby:
		data["host"] = new_lobby.HostId
		data["player"] = new_lobby.Players[sender_id]

	send_to_player(receiver_id, data)

func send_to_player(user_id:int, data):
	peer.get_peer(user_id).put_packet(JSON.stringify(data).to_utf8_buffer())

func generate_random_string():
	var result = ""
	for i in range(32):
		var random_idx = randi() % chars.length()
		result += chars[random_idx]
	return result

func start_server():
	peer.create_server(port)
	print("started server")

func _on_start_server_button_down():
	start_server()

# Auto-start C# Signaling Server
func start_signaling_server() -> bool:
	if signaling_server_running:
		print("[SignalingServer] Already running")
		return true

	# Determine the path to the signaling server
	# res:// points to scuffed_arena/, we need to go up one level to reach SignalingServer/
	var project_root = ProjectSettings.globalize_path("res://")
	var parent_dir = project_root.get_base_dir()  # /mnt/Extra/GODOT/Scuffed_Arena/scuffed_arena
	var signaling_server_path = parent_dir.get_base_dir() + "/SignalingServer"  # /mnt/Extra/GODOT/Scuffed_Arena/SignalingServer

	print("[SignalingServer] Starting from: " + signaling_server_path)

	# Check if SignalingServer directory exists
	if not DirAccess.dir_exists_absolute(signaling_server_path):
		print("[SignalingServer] ERROR: SignalingServer directory not found at: " + signaling_server_path)
		return false

	# Start the signaling server process (dotnet run will build automatically if needed)
	print("[SignalingServer] Launching server...")
	var args = ["run", "--project", signaling_server_path, str(port)]
	signaling_server_pid = OS.create_process("dotnet", args, false)

	if signaling_server_pid > 0:
		signaling_server_running = true
		print("[SignalingServer] Started successfully (PID: " + str(signaling_server_pid) + ")")
		print("[SignalingServer] Server running on port " + str(port))
		print("[SignalingServer] Connect using: ws://localhost:" + str(port))
		await get_tree().create_timer(2.0).timeout  # Give server time to build and start
		return true
	else:
		print("[SignalingServer] ERROR: Failed to start process")
		return false

func stop_signaling_server():
	if signaling_server_running and signaling_server_pid > 0:
		print("[SignalingServer] Stopping server (PID: " + str(signaling_server_pid) + ")")
		OS.kill(signaling_server_pid)
		signaling_server_pid = -1
		signaling_server_running = false
		print("[SignalingServer] Stopped")
