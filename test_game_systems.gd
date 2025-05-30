extends Node

# 游戏功能测试脚本
# 用于验证核心系统是否正常工作

func _ready():
	print("=== 游戏系统测试开始 ===")
	
	# 测试GameManager
	test_game_manager()
	
	# 测试场景资源
	test_scene_resources()
	
	print("=== 游戏系统测试完成 ===")

func test_game_manager():
	print("\n--- 测试GameManager ---")
	
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		print("✅ GameManager加载成功")
		
		# 测试金币系统
		var initial_money = game_manager.get_money()
		print("初始金币: " + str(initial_money))
		
		game_manager.add_money(50)
		var new_money = game_manager.get_money()
		print("添加50金币后: " + str(new_money))
		
		if new_money == initial_money + 50:
			print("✅ 金币系统正常")
		else:
			print("❌ 金币系统异常")
		
		# 测试材料价值
		var dirt_value = game_manager.get_material_value("dirt")
		var gold_value = game_manager.get_material_value("gold")
		print("泥土价值: " + str(dirt_value) + ", 黄金价值: " + str(gold_value))
		
	else:
		print("❌ GameManager未找到")

func test_scene_resources():
	print("\n--- 测试场景资源 ---")
	
	var scenes = [
		"res://Scenes/StartScene/StartScene.tscn",
		"res://Scenes/TownScene/TownScene.tscn",
		"res://Scenes/MineScene/MineScene.tscn",
		"res://Scenes/ShopScene/ShopScene.tscn",
		"res://Player/Player.tscn"
	]
	
	for scene_path in scenes:
		if ResourceLoader.exists(scene_path):
			print("✅ " + scene_path + " 存在")
		else:
			print("❌ " + scene_path + " 缺失")

func test_player_assets():
	print("\n--- 测试玩家资源 ---")
	
	var asset_folders = [
		"res://Player/Assets/Attacking/",
		"res://Player/Assets/Walking/",
		"res://Player/Assets/Idle/"
	]
	
	for folder in asset_folders:
		if DirAccess.dir_exists_absolute(folder):
			print("✅ " + folder + " 存在")
		else:
			print("❌ " + folder + " 缺失")

# 可以从其他场景调用的测试函数
static func quick_test():
	print("🎮 快速系统检查...")
	
	# 检查GameManager
	var gm = Engine.get_singleton("GameManager") if Engine.has_singleton("GameManager") else null
	if not gm:
		gm = NodePath("/root/GameManager")
	
	if gm:
		print("✅ GameManager可访问")
	else:
		print("⚠️ GameManager可能未正确加载")
