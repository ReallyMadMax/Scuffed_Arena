extends Control

@onready var slots: Array = $GridContainer.get_children()
var is_open = true
var inv: Inv = null

func _ready():
	print("inv_Control ready")
	# Find the local player and use their inventory
	await get_tree().process_frame  # Wait one frame for players to spawn
	var local_player = get_local_player()
	if local_player and local_player.inv:
		inv = local_player.inv
		inv.update.connect(update_slots)
		update_slots()
	else:
		print("Warning: Could not find local player or inventory!")

func get_local_player():
	# Find the player node that belongs to this client
	var main = get_tree().get_root().get_node_or_null("Main")
	if not main:
		return null

	for child in main.get_children():
		if child is player_class:
			# Check if this is the local player
			if str(child.name).to_int() == multiplayer.get_unique_id():
				return child
	return null

func update_slots():
	if not inv:
		return
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
