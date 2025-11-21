extends MarginContainer

func _ready() -> void:
	# complete as soon as an upgrade is chosen
	for upgrade_button:Button in $MarginContainer/VBoxContainer/UpgradeContainer.get_children():
		upgrade_button.pressed.connect(_on_complete)

func _process(_delta: float) -> void:
	$VBoxContainer/TimerBar.value = $Timer.time_left * 100 / $Timer.wait_time

func _on_complete() -> void:
	pass # respawn player and close menu
