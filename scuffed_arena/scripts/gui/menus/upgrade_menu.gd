extends Control

var UPGRADE_COUNT:int = 3

@onready var upgrade_box:HBoxContainer = $MarginContainer/VBoxContainer/UpgradeContainer
@onready var upgrade_scene:PackedScene = load("res://scenes/gui/upgrade.tscn")

func _ready() -> void:
	print("initializing upgrade menu")
	for i in range(UPGRADE_COUNT):
		var rand = randi() % UpgradeManager.Upgrades.size()
		var upgrade_button:UpgradeButton = upgrade_scene.instantiate()
		upgrade_box.add_child(upgrade_button)
		# complete as soon as an upgrade is chosen
		upgrade_button.pressed.connect(_on_complete)
		upgrade_button.upgrade = UpgradeManager.Upgrades[rand]

	# Set initial focus for controller navigation
	if upgrade_box.get_child_count() > 0:
		upgrade_box.get_child(0).grab_focus()

func _input(event: InputEvent) -> void:
	# Handle X button (button_index 2) to select focused upgrade
	if event is InputEventJoypadButton:
		if event.button_index == 2 and event.pressed:
			var focused_control = get_viewport().gui_get_focus_owner()
			if focused_control is UpgradeButton:
				focused_control.pressed.emit()
				get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	$MarginContainer/VBoxContainer/TimerBar.value = $Timer.time_left * 100 / $Timer.wait_time

func _on_complete() -> void:
	GameManager.spawn_client()
	queue_free()
