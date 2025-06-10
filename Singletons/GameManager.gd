extends Node

# 游戏管理器单例
# 管理全局游戏状态，如金币、升级等

signal money_changed(new_amount)
signal inventory_changed()

var player_money = 100 # 初始金币
var player_health = 3
var player_max_health = 3

# 装备和升级
var pickaxe_level = 1
var pickaxe_damage = 10
var movement_speed = 200

# 背包系统
var inventory = {} # 物品名称 -> 数量
var max_inventory_slots = 20

# 游戏设置
var current_scene = ""

func _ready():
	# 设置为自动加载单例
	# 初始化背包
	initialize_inventory()

func initialize_inventory():
	"""初始化背包"""
	if inventory.is_empty():
		inventory = {
			"stone": 0,
			"iron_ore": 0,
			"gold_ore": 0,
			"torch": 5, # 初始给玩家5个火把
			"coin": 0
		}

func add_item(item_name: String, quantity: int = 1) -> bool:
	"""添加物品到背包"""
	if inventory.has(item_name):
		inventory[item_name] += quantity
	else:
		inventory[item_name] = quantity
	
	inventory_changed.emit()
	
	# 某些物品有特殊处理
	match item_name:
		"coin":
			add_money(quantity * 10) # 每个金币价值10货币
	
	return true

func remove_item(item_name: String, quantity: int = 1) -> bool:
	"""从背包移除物品"""
	if not inventory.has(item_name) or inventory[item_name] < quantity:
		return false
	
	inventory[item_name] -= quantity
	if inventory[item_name] <= 0:
		inventory[item_name] = 0
	
	inventory_changed.emit()
	return true

func get_item_count(item_name: String) -> int:
	"""获取物品数量"""
	return inventory.get(item_name, 0)

func has_item(item_name: String, quantity: int = 1) -> bool:
	"""检查是否有足够的物品"""
	return get_item_count(item_name) >= quantity

func get_all_items() -> Dictionary:
	"""获取所有物品"""
	return inventory.duplicate()

func sell_item(item_name: String, quantity: int = 1) -> bool:
	"""出售物品"""
	if not has_item(item_name, quantity):
		return false
	
	var value = get_material_value(item_name) * quantity
	if remove_item(item_name, quantity):
		add_money(value)
		return true
	
	return false

func add_money(amount):
	player_money += amount
	money_changed.emit(player_money)

func spend_money(amount):
	if player_money >= amount:
		player_money -= amount
		money_changed.emit(player_money)
		return true
	else:
		return false

func get_money():
	return player_money

func upgrade_pickaxe():
	var cost = pickaxe_level * 50
	if spend_money(cost):
		pickaxe_level += 1
		pickaxe_damage += 5
		return true
	return false

func upgrade_health():
	var cost = 100
	if spend_money(cost):
		player_max_health += 20
		player_health = player_max_health
		return true
	return false

func heal_player(amount):
	player_health = min(player_health + amount, player_max_health)

func damage_player(amount):
	player_health = max(player_health - amount, 0)
	if player_health <= 0:
		player_died()

func player_died():
	# 使用call_deferred延迟场景切换，避免在物理回调期间移除CollisionObject节点
	get_tree().call_deferred("change_scene_to_file", "res://Scenes/TownScene/TownScene.tscn")

func change_scene(scene_path):
	current_scene = scene_path
	get_tree().change_scene_to_file(scene_path)

func get_material_value(material):
	# 返回材料的价值
	match material:
		"stone":
			return 1
		"iron_ore":
			return 8
		"gold_ore":
			return 20
		"torch":
			return 5
		"coin":
			return 10
		"dirt":
			return 1
		"coal":
			return 5
		"iron":
			return 10
		"gold":
			return 25
		"diamond":
			return 50
		_:
			return 0
