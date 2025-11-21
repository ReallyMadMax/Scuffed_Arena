extends PanelContainer

@export var upgrade:Upgrade

func _ready() -> void:
	$MarginContainer/Container/UpgradeName.text = upgrade.name
	$MarginContainer/Container/UpgradeDescription.text = upgrade.description
	$MarginContainer/Container/UpgradeIcon.texture = upgrade.icon

func _on_pressed() -> void:
	GameManager.client_player.add_upgrade(upgrade)
