extends Control

@onready var LobbyID = $HBoxContainer/Control/JoinBox/LobbyID
@onready var IpAddress = $HBoxContainer/Control/StartBox/IpAddress
@onready var StartClient = $HBoxContainer/Control/StartBox/StartClient
@onready var StartBox = $HBoxContainer/Control/StartBox
@onready var JoinBox = $HBoxContainer/Control/JoinBox

func _on_join_lobby_button_down() -> void:
	Client.join_lobby(LobbyID.text)

func _on_start_client_button_down() -> void:
	start_client(IpAddress.text)

func start_client(ip:String) -> void:
	Client.connectToServer(ip, 6000)
	StartBox.visible = false
	JoinBox.visible = true

func _on_ip_address_text_changed(new_text: String) -> void:
	StartClient.disabled = new_text.is_empty()
