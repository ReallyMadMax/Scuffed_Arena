@abstract
class_name player_class
extends CharacterBody2D

@export var speed = 300
@export var health = 1000
@export var basic_attack_cd = 1
@export var heavy_attack_cd = 5
@export var block_cd = 10
@export var dash_cd = 5

@onready var animation_tree : AnimationTree = $AnimationTree
# Load the Ability script as a resource so that it can be used in sub player characters
@onready var Ability = preload("res://scripts/ability.gd")

var direction : Vector2

@abstract
# initialize basic vars here
func _init() 

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
