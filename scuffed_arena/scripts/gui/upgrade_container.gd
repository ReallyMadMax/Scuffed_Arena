extends Button
class_name UpgradeButton

@onready var upgrade_name:Label = %UpgradeName
@onready var upgrade_desc:RichTextLabel = %UpgradeDescription
@onready var upgrade_icon:TextureRect = %UpgradeIcon

var upgrade:Upgrade:
	set(_upgrade):
		upgrade = _upgrade
		upgrade_name.text = upgrade.name
		upgrade_desc.text = upgrade.description
		upgrade_icon.texture = upgrade.icon

func _on_pressed() -> void:
	GameManager.client_player.add_upgrade(upgrade)
