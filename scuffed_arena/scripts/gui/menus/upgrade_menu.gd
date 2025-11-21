extends MarginContainer

func _process(_delta: float) -> void:
	$VBoxContainer/TimerBar.value = $Timer.time_left * 100 / $Timer.wait_time

func _on_timer_timeout() -> void:
	pass # respawn player and close menu
