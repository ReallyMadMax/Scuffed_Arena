@abstract
class_name Player
extends CharacterBody2D

signal death
signal damage_taken

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

func _ready() -> void:
	# Only run multiplayer authority checks when in multiplayer mode
	if multiplayer.has_multiplayer_peer():
		var my_id = str(name).to_int()
		print("Setting authority - Node name: ", name, " -> ID: ", my_id, " | My multiplayer ID: ", multiplayer.get_unique_id())
		$MultiplayerSynchronizer.set_multiplayer_authority(my_id)
		if my_id != multiplayer.get_unique_id():
			print("Removing camera - not my character")
			remove_child($Camera2D)
			remove_child($PointLight2D)
			$Sprite2D.material = load("res://assets/materials/fog_of_war_mask.tres")
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
