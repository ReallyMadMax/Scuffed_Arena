extends Control

@onready var LobbyID = $HBoxContainer/Control/StartBox/LobbyCode
@onready var StartClient = $HBoxContainer/Control/StartBox/StartClient
@onready var StartBox = $HBoxContainer/Control/StartBox

func _ready() -> void:
	Client.connectToServer()

func start_client(id:String) -> void:
	if not id:
		id = "012345"
	
	while(!Client.join_lobby(id)):
		await get_tree().create_timer(1.0).timeout

func _on_ip_address_text_changed(new_text: String) -> void:
	StartClient.disabled = new_text.is_empty()

func _on_join_lobby_pressed() -> void:
	start_client(LobbyID.text)

func _on_lobby_code_text_changed(new_text: String) -> void:
	StartClient.disabled = new_text.is_empty()
