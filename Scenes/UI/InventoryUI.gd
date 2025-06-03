extends Control

@onready var item_list: VBoxContainer = $Background/VBoxContainer/ScrollContainer/ItemList
@onready var money_label: Label = $Background/VBoxContainer/MoneyLabel

var is_visible_inventory = false

func _ready():
	# 连接到GameManager的信号
	var game_manager = get_node("/root/GameManager")
	if game_manager:
		game_manager.inventory_changed.connect(_on_inventory_changed)
		game_manager.money_changed.connect(_on_money_changed)
	
	# 初始状态设为隐藏
	visible = false
	
	# 更新显示
	update_inventory_display()
	update_money_display()

func _input(event):
	# 按I键切换背包显示
	if event.is_action_pressed("inventory"):
		toggle_inventory()

func toggle_inventory():
	"""切换背包显示状态"""
	is_visible_inventory = !is_visible_inventory
	visible = is_visible_inventory
	
	if is_visible_inventory:
		update_inventory_display()
		update_money_display()

func _on_inventory_changed():
	"""当背包内容改变时更新显示"""
	if visible:
		update_inventory_display()

func _on_money_changed(new_amount):
	"""当金币改变时更新显示"""
	if money_label:
		money_label.text = "金币: " + str(new_amount)

func update_money_display():
	"""更新金币显示"""
	var game_manager = get_node("/root/GameManager")
	if game_manager and money_label:
		money_label.text = "金币: " + str(game_manager.get_money())

func update_inventory_display():
	"""更新背包物品显示"""
	if not item_list:
		return
	
	# 清空现有显示
	for child in item_list.get_children():
		child.queue_free()
	
	# 获取背包数据
	var game_manager = get_node("/root/GameManager")
	if not game_manager:
		return
	
	var inventory = game_manager.get_all_items()
	
	# 为每个物品创建显示条目
	for item_name in inventory:
		var quantity = inventory[item_name]
		if quantity > 0:
			create_item_entry(item_name, quantity)

func create_item_entry(item_name: String, quantity: int):
	"""创建物品条目"""
	var container = HBoxContainer.new()
	item_list.add_child(container)
	
	# 物品名称标签
	var name_label = Label.new()
	name_label.text = get_item_display_name(item_name)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(name_label)
	
	# 数量标签
	var quantity_label = Label.new()
	quantity_label.text = str(quantity)
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	container.add_child(quantity_label)
	
	# 出售按钮（如果物品可以出售）
	if can_sell_item(item_name):
		var sell_button = Button.new()
		sell_button.text = "出售"
		sell_button.custom_minimum_size = Vector2(50, 0)
		sell_button.pressed.connect(_on_sell_item.bind(item_name))
		container.add_child(sell_button)

func get_item_display_name(item_name: String) -> String:
	"""获取物品的显示名称"""
	match item_name:
		"stone":
			return "石头"
		"iron_ore":
			return "铁矿"
		"gold_ore":
			return "金矿"
		"torch":
			return "火把"
		"coin":
			return "金币"
		_:
			return item_name

func can_sell_item(item_name: String) -> bool:
	"""检查物品是否可以出售"""
	match item_name:
		"torch":
			return false # 火把不能出售
		_:
			return true

func _on_sell_item(item_name: String):
	"""出售物品"""
	var game_manager = get_node("/root/GameManager")
	if game_manager and game_manager.has_method("sell_item"):
		game_manager.sell_item(item_name, 1)
		update_inventory_display()
		update_money_display()
