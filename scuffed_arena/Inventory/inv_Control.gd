extends Control

@onready var inv: Inv = preload("res://Inventory/playerInv.tres")
@onready var slots: Array = $GridContainer.get_children()
var is_open = true

func _ready():
	print("ready")
	inv.update.connect(update_slots)
	update_slots()

func update_slots():
	for i in range(min(inv.slots.size(), slots.size())):
		print("update ", i+1)
		slots[i].update(inv.slots[i])

func _process(_delta):
	if Input.is_action_just_pressed("OpenInv"):
		if is_open:
			close()
		else:
			open()
			
func open():
	self.visible = true
	is_open = true
	
func close():
	visible = false
	is_open = false
