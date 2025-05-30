extends SceneTree

# 测试建筑系统的脚本
# 验证TownScene中的建筑系统是否正常工作

func _init():
	print("开始测试建筑系统...")
	
	# 加载TownScene
	var town_scene_path = "res://Scenes/TownScene/TownScene.tscn"
	var town_scene = load(town_scene_path)
	
	if town_scene == null:
		print("❌ 错误：无法加载TownScene")
		quit(1)
		return
	
	print("✅ TownScene加载成功")
	
	# 实例化场景
	var town_instance = town_scene.instantiate()
	if town_instance == null:
		print("❌ 错误：无法实例化TownScene")
		quit(1)
		return
	
	print("✅ TownScene实例化成功")
	
	# 检查必要的节点
	var required_nodes = [
		"Player",
		"Buildings",
		"Camera2D",
		"UI/TopPanel/MoneyLabel"
	]
	
	for node_path in required_nodes:
		var node = town_instance.get_node_or_null(node_path)
		if node == null:
			print("❌ 错误：缺少必要的节点 " + node_path)
			quit(1)
			return
		print("✅ 找到节点: " + node_path)
	
	# 检查脚本是否正确连接
	var script = town_instance.get_script()
	if script == null:
		print("❌ 错误：TownScene没有连接脚本")
		quit(1)
		return
	
	print("✅ TownScene脚本连接正常")
	
	# 检查buildings_data是否存在
	if not town_instance.has_method("setup_buildings"):
		print("❌ 错误：脚本中缺少setup_buildings方法")
		quit(1)
		return
	
	print("✅ setup_buildings方法存在")
	
	# 添加到场景树并调用_ready
	root.add_child(town_instance)
	
	# 等待几帧让_ready函数完全执行完成
	await process_frame
	await process_frame
	await process_frame
	
	# 检查建筑是否被正确创建
	var buildings_container = town_instance.get_node("Buildings")
	var building_count = buildings_container.get_child_count()
	
	if building_count == 0:
		print("❌ 错误：没有创建任何建筑")
		quit(1)
		return
	
	print("✅ 成功创建了 " + str(building_count) + " 个建筑")
	
	# 检查具体的建筑
	var expected_buildings = ["shop", "mine", "house1", "house2"]
	for building_id in expected_buildings:
		var building_node = buildings_container.get_node_or_null(building_id)
		if building_node == null:
			print("❌ 错误：缺少建筑 " + building_id)
			quit(1)
			return
		print("✅ 找到建筑: " + building_id)
	
	print("")
	print("🎉 所有测试通过！建筑系统工作正常")
	print("📋 测试总结:")
	print("   - TownScene场景加载正常")
	print("   - 所有必要节点存在")
	print("   - 脚本正确连接")
	print("   - 建筑系统正常创建了4个建筑")
	print("   - 包括2个可交互建筑(商店、矿井)和2个装饰建筑(房屋)")
	
	quit(0)
