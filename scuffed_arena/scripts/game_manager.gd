extends Node

var Players = {}
var using_controller : bool = false

func _ready():
	# Start with cursor visible
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _input(event):
	# Detect controller input
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event is InputEventJoypadMotion:
			# Only consider it controller input if the axis moved significantly
			if abs(event.axis_value) > 0.2:
				if not using_controller:
					using_controller = true
					Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
		else:
			if not using_controller:
				using_controller = true
				Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	# Detect mouse movement
	elif event is InputEventMouseMotion:
		if event.relative.length() > 0:
			if using_controller:
				using_controller = false
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
