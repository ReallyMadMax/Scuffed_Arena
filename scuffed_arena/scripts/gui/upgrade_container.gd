extends Button
class_name UpgradeButton

var upgrade:Upgrade:
	set(_upgrade):
		upgrade = _upgrade
		$MarginContainer/Container/UpgradeName.text = upgrade.name
		$MarginContainer/Container/UpgradeDescription.text = upgrade.description
		$MarginContainer/Container/UpgradeIcon.texture = upgrade.icon

func _on_pressed() -> void:
	GameManager.client_player.add_upgrade(upgrade)
