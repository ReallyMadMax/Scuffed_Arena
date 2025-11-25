extends Control

@onready var LobbyID = $HBoxContainer/Control/StartBox/LobbyCode
@onready var JoinLobby = $HBoxContainer/Control/StartBox/JoinLobby
@onready var StartBox = $HBoxContainer/Control/StartBox

func _ready() -> void:
	Client.connectToServer()
	Client.player_connected.connect(_on_player_joined)
	# Set initial focus to IP address field for controller navigation
	LobbyID.grab_focus()

func _input(event):
	# Handle back navigation with controller B button or ESC
	if event.is_action_pressed("ui_cancel"):
		go_back()

func go_back():
	var scene = load("res://scenes/gui/menus/start_menu.tscn").instantiate()
	get_tree().root.add_child(scene)
	queue_free()


func start_client(id:String) -> void:
	if not id:
		id = "012345"
	
	while(!Client.join_lobby(id)):
		await get_tree().create_timer(1.0).timeout

func _on_ip_address_text_changed(new_text: String) -> void:
	JoinLobby.disabled = new_text.is_empty()

func _on_join_lobby_pressed() -> void:
	start_client(LobbyID.text)

func _on_lobby_code_text_changed(new_text: String) -> void:
	JoinLobby.disabled = new_text.is_empty()

func _on_player_joined(_id:int):
	$HBoxContainer/Control/LobbyCount.text = "Player count " + str(GameManager.Players.size()) + "/8"
