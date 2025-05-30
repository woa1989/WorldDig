extends Node

# 游戏管理器单例
# 管理全局游戏状态，如金币、升级等

signal money_changed(new_amount)

var player_money = 100 # 初始金币
var player_health = 100
var player_max_health = 100

# 装备和升级
var pickaxe_level = 1
var pickaxe_damage = 10
var movement_speed = 200

# 游戏设置
var current_scene = ""

func _ready():
	# 设置为自动加载单例
	pass

func add_money(amount):
	player_money += amount
	money_changed.emit(player_money)
	print("获得 " + str(amount) + " 金币，总计: " + str(player_money))

func spend_money(amount):
	if player_money >= amount:
		player_money -= amount
		money_changed.emit(player_money)
		return true
	else:
		print("金币不足！")
		return false

func get_money():
	return player_money

func upgrade_pickaxe():
	var cost = pickaxe_level * 50
	if spend_money(cost):
		pickaxe_level += 1
		pickaxe_damage += 5
		print("镐子升级到等级 " + str(pickaxe_level))
		return true
	return false

func upgrade_health():
	var cost = 100
	if spend_money(cost):
		player_max_health += 20
		player_health = player_max_health
		print("生命值上限提升到 " + str(player_max_health))
		return true
	return false

func heal_player(amount):
	player_health = min(player_health + amount, player_max_health)

func damage_player(amount):
	player_health = max(player_health - amount, 0)
	if player_health <= 0:
		player_died()

func player_died():
	print("玩家死亡！")
	# 重置到城镇
	get_tree().change_scene_to_file("res://Scenes/TownScene/TownScene.tscn")

func change_scene(scene_path):
	current_scene = scene_path
	get_tree().change_scene_to_file(scene_path)

func get_material_value(material):
	# 返回材料的价值
	match material:
		"dirt":
			return 1
		"stone":
			return 2
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
