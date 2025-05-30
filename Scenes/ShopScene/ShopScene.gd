extends Control

# 商店场景脚本
# 处理商店购买和升级逻辑

@onready var money_label
@onready var close_button
@onready var upgrade_container

var upgrade_items = [
	{
		"name": "升级镐子",
		"description": "提升挖掘伤害",
		"base_cost": 50,
		"type": "pickaxe"
	},
	{
		"name": "增加生命值",
		"description": "提升最大生命值",
		"base_cost": 100,
		"type": "health"
	},
	{
		"name": "移动速度",
		"description": "提升移动速度",
		"base_cost": 75,
		"type": "speed"
	}
]

func _ready():
	setup_ui()
	update_money_display()
	create_upgrade_buttons()
	
	# 连接GameManager信号
	GameManager.money_changed.connect(_on_money_changed)

func setup_ui():
	# 设置基本UI布局
	var main_panel = Panel.new()
	main_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	main_panel.size = Vector2(600, 400)
	add_child(main_panel)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_panel.add_child(vbox)
	
	# 标题
	var title = Label.new()
	title.text = "商店"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# 金币显示
	money_label = Label.new()
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(money_label)
	
	# 升级容器
	upgrade_container = VBoxContainer.new()
	vbox.add_child(upgrade_container)
	
	# 关闭按钮
	close_button = Button.new()
	close_button.text = "关闭"
	close_button.pressed.connect(_on_close_button_pressed)
	vbox.add_child(close_button)

func create_upgrade_buttons():
	for item in upgrade_items:
		var hbox = HBoxContainer.new()
		upgrade_container.add_child(hbox)
		
		var info_label = Label.new()
		var cost = get_upgrade_cost(item.type)
		info_label.text = item.name + " - " + item.description + " (费用: " + str(cost) + ")"
		hbox.add_child(info_label)
		
		var buy_button = Button.new()
		buy_button.text = "购买"
		buy_button.pressed.connect(_on_upgrade_pressed.bind(item.type))
		hbox.add_child(buy_button)

func get_upgrade_cost(upgrade_type):
	match upgrade_type:
		"pickaxe":
			return GameManager.pickaxe_level * 50
		"health":
			return 100
		"speed":
			return 75
		_:
			return 50

func _on_upgrade_pressed(upgrade_type):
	var success = false
	match upgrade_type:
		"pickaxe":
			success = GameManager.upgrade_pickaxe()
		"health":
			success = GameManager.upgrade_health()
		"speed":
			success = upgrade_speed()
	
	if success:
		# 更新升级按钮显示
		refresh_upgrade_buttons()

func upgrade_speed():
	var cost = 75
	if GameManager.spend_money(cost):
		GameManager.movement_speed += 20
		print("移动速度提升！")
		return true
	return false

func refresh_upgrade_buttons():
	# 清除现有按钮并重新创建
	for child in upgrade_container.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	create_upgrade_buttons()

func _on_money_changed(_new_amount):
	update_money_display()

func update_money_display():
	money_label.text = "金币: " + str(GameManager.get_money())

func _on_close_button_pressed():
	GameManager.change_scene("res://Scenes/TownScene/TownScene.tscn")

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		_on_close_button_pressed()
