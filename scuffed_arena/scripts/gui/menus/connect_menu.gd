extends Control

@onready var IpAddress = $HBoxContainer/Control/StartBox/IpAddress
@onready var StartClient = $HBoxContainer/Control/StartBox/StartClient
@onready var StartBox = $HBoxContainer/Control/StartBox

func _on_start_client_button_down() -> void:
	start_client(IpAddress.text)

func start_client(ip:String) -> void:
	Client.connectToServer()
	while(!Client.join_lobby(Server.LOBBY_ID)):
		await get_tree().create_timer(1.0).timeout

func _on_ip_address_text_changed(new_text: String) -> void:
	StartClient.disabled = new_text.is_empty()
