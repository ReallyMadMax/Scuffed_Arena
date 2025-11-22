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

func _process(_delta: float) -> void:
	$MarginContainer/VBoxContainer/TimerBar.value = $Timer.time_left * 100 / $Timer.wait_time

func _on_complete() -> void:
	GameManager.spawn_client()
	queue_free()
