extends Node

var upgrades_group:ResourceGroup = load("res://resources/upgrades/upgrade_group.tres")
var Upgrades:Array = []

func _ready() -> void:
	Upgrades = upgrades_group.load_all()
