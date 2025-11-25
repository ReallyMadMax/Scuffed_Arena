extends Control

@onready var IpAddress = $HBoxContainer/Control/StartBox/IpAddress
@onready var StartClient = $HBoxContainer/Control/StartBox/StartClient
@onready var StartBox = $HBoxContainer/Control/StartBox

func _ready() -> void:
	# Set initial focus to IP address field for controller navigation
	IpAddress.grab_focus()

func _input(event):
	# Handle back navigation with controller B button or ESC
	if event.is_action_pressed("ui_cancel"):
		go_back()

func go_back():
	var scene = load("res://scenes/gui/menus/start_menu.tscn").instantiate()
	get_tree().root.add_child(scene)
	queue_free()

func _on_start_client_button_down() -> void:
	start_client(IpAddress.text)

func start_client(ip:String) -> void:
	Client.connectToServer(ip, 6000)
	while(!Client.join_lobby(Server.LOBBY_ID)):
		await get_tree().create_timer(1.0).timeout

func _on_ip_address_text_changed(new_text: String) -> void:
	StartClient.disabled = new_text.is_empty()
	# Set focus neighbor so users can navigate to button with controller
	if not new_text.is_empty():
		IpAddress.focus_neighbor_bottom = IpAddress.get_path_to(StartClient)
		IpAddress.focus_next = IpAddress.get_path_to(StartClient)
