extends Control

var UPGRADE_COUNT:int = 3

@onready var upgrade_box:HBoxContainer = $MarginContainer/VBoxContainer/UpgradeContainer
@onready var upgrade_scene:PackedScene = load("res://scenes/gui/upgrade.tscn")
@onready var timer_bar:ProgressBar = $MarginContainer/VBoxContainer/TimerBar

var upgrade_timer:Timer

func reset():
	for upgrade in upgrade_box.get_children():
		upgrade.queue_free()
	
	upgrade_box.show()
	for i in range(UPGRADE_COUNT):
		var rand = randi() % UpgradeManager.Upgrades.size()
		var upgrade_button:UpgradeButton = upgrade_scene.instantiate()
		upgrade_box.add_child(upgrade_button)
		# complete as soon as an upgrade is chosen
		upgrade_button.pressed.connect(_on_complete)
		upgrade_button.upgrade = UpgradeManager.Upgrades[rand]

func _process(_delta: float) -> void:
	if upgrade_timer:
		timer_bar.value = upgrade_timer.time_left * 100 / upgrade_timer.wait_time

func _on_complete() -> void:
	for upgrade in upgrade_box.get_children():
		upgrade.hide()
