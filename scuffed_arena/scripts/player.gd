@abstract
class_name Player
extends CharacterBody2D

signal death
#signal damage_taken


@export var speed = 300
@export var health = 1000
@export var basic_attack_cd = 1
@export var heavy_attack_cd = 5
@export var block_cd = 10
@export var dash_cd = 5

@onready var animation_tree : AnimationTree = $AnimationTree
# Load the Ability script as a resource so that it can be used in sub player characters
@onready var ability = preload("res://scripts/ability.gd")

var direction : Vector2

var upgrades:Array = []

func _ready():
	super._ready()  # Call parent _ready to initialize current_health
	animation_tree.active = true
	$MultiplayerSynchronizer.set_multiplayer_authority(str(name).to_int())
	if str(name).to_int() != multiplayer.get_unique_id():
		remove_child($Camera2D)

	# Don't process input if player is dead
	if is_dead:
		return

	if not Engine.is_editor_hint():
		# Test keybind: Press 'g' to damage yourself
		if Input.is_action_just_pressed("test"):
			print("Test key pressed! Dealing damage...")
			take_damage(250)  # Deal 250 damage to self

		var dir = Input.get_vector("move_left", "move_right", "move_up", "move_down").normalized();
		if dir:
			direction = dir
			velocity = direction * speed
		else:
			print("This is MY character - keeping camera and control")
			light_mask = 1
			visibility_layer = 1
			GameManager.client_player = self

func update_animation_parameters():
	if (velocity == Vector2.ZERO):
		animation_tree["parameters/conditions/is_idle"] = true
		animation_tree["parameters/conditions/is_moving"] = false
	else:
		animation_tree["parameters/conditions/is_idle"] = false
		animation_tree["parameters/conditions/is_moving"] = true
	
	if Input.is_action_just_pressed("attack"):
		animation_tree["parameters/conditions/attack"] = true
	else:
		animation_tree["parameters/conditions/attack"] = false
	
	animation_tree["parameters/Idle/blend_position"] = direction
	animation_tree["parameters/Move/blend_position"] = direction
	animation_tree["parameters/Attack/blend_position"] = direction

func hit(source: Player):
	source.on_hit(self)

@rpc("any_peer", "call_local")
func take_damage(amount: int, source: Player):
	health -= amount
	print("Player took ", amount, " damage. Health: ", health)
	for upgrade in upgrades:
		upgrade.on_damage_taken(self, amount, source)
	if health <= 0:
		die(source)

@rpc("any_peer", "call_local")
func die(source: Player):
	print("Player died!")
	death.emit(self)
	source.on_kill(self)
	# Add death logic here (respawn, game over, etc.)

# happens on every instance of damage dealth
func on_damage_dealt(damage: float) -> void:
	for upgrade in upgrades:
		upgrade.on_damage_dealt(self, damage)

func on_kill(enemy: Player) -> void:
	for upgrade in upgrades:
		upgrade.on_kill(self, enemy)

# happens the first time you hit someone
func on_hit(enemy: Player) -> void:
	for upgrade in upgrades:
		upgrade.on_hit(self, enemy)

func add_upgrade(upgrade:Upgrade) -> void:
	upgrades.append(upgrade)
