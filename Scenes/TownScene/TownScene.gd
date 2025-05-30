extends Node2D

# 城镇场景脚本
# 管理城镇的各种功能，包括商店、矿井入口等

@onready var money_label = $UI/TopPanel/MoneyLabel
@onready var player = $Player
@onready var buildings_container = $Buildings

# 建筑物数据
var buildings_data = {
	"shop": {
		"name": "商店",
		"position": Vector2(200, 100),
		"size": Vector2(150, 120),
		"color": Color(0.8, 0.4, 0.2), # 棕色
		"scene_path": "res://Scenes/ShopScene/ShopScene.tscn"
	},
	"mine": {
		"name": "矿井入口",
		"position": Vector2(500, 100),
		"size": Vector2(120, 100),
		"color": Color(0.3, 0.3, 0.3), # 深灰色
		"scene_path": "res://Scenes/MineScene/MineScene.tscn"
	},
	"house1": {
		"name": "民居",
		"position": Vector2(-200, 50),
		"size": Vector2(100, 80),
		"color": Color(0.6, 0.6, 0.8), # 浅蓝色
		"scene_path": null # 纯装饰
	},
	"house2": {
		"name": "民居",
		"position": Vector2(-50, 50),
		"size": Vector2(100, 80),
		"color": Color(0.8, 0.6, 0.6), # 浅红色
		"scene_path": null # 纯装饰
	}
}

# 当前可交互的建筑
var current_building = null

func _ready():
	# 等待一帧确保所有节点加载完成
	await get_tree().process_frame
	
	# 连接GameManager的信号
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		game_manager.money_changed.connect(_on_money_changed)
		_on_money_changed(game_manager.get_money())
	else:
		if money_label:
			money_label.text = "金币: 100" # 默认值
	
	# 创建建筑物
	setup_buildings()
	
	# 设置相机跟随
	setup_camera()

func _input(event):
	# 处理按键输入
	if event.is_action_pressed("ui_cancel"):
		# ESC键返回开始菜单
		var game_manager = get_node_or_null("/root/GameManager")
		if game_manager:
			game_manager.change_scene("res://Scenes/StartScene/StartScene.tscn")
		else:
			get_tree().change_scene_to_file("res://Scenes/StartScene/StartScene.tscn")
	
	# 空格键进入建筑
	if event.is_action_pressed("ui_accept") and current_building:
		enter_building(current_building)

func enter_building(building_id: String):
	var building_info = buildings_data[building_id]
	if building_info.scene_path:
		print("进入 " + building_info.name)
		var game_manager = get_node_or_null("/root/GameManager")
		if game_manager:
			game_manager.change_scene(building_info.scene_path)
		else:
			get_tree().change_scene_to_file(building_info.scene_path)

func setup_buildings():
	# 清除现有的建筑物
	for child in buildings_container.get_children():
		child.queue_free()
	
	# 创建新的建筑物
	for building_id in buildings_data:
		var building_info = buildings_data[building_id]
		create_building(building_id, building_info)

func create_building(building_id: String, building_info: Dictionary):
	# 创建建筑物容器
	var building_node = Node2D.new()
	building_node.name = building_id
	building_node.position = building_info.position
	
	# 创建建筑物外观（ColorRect）
	var building_visual = ColorRect.new()
	building_visual.size = building_info.size
	building_visual.color = building_info.color
	building_visual.position = - building_info.size / 2 # 居中
	building_node.add_child(building_visual)
	
	# 添加建筑物标签
	var label = Label.new()
	label.text = building_info.name
	label.position = Vector2(-building_info.size.x / 2, -building_info.size.y / 2 - 30)
	label.add_theme_font_size_override("font_size", 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	building_node.add_child(label)
	
	# 如果是可交互建筑，添加交互区域
	if building_info.scene_path != null:
		var interaction_area = Area2D.new()
		var collision_shape = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		
		# 交互区域比建筑稍大
		shape.size = building_info.size + Vector2(50, 50)
		collision_shape.shape = shape
		interaction_area.add_child(collision_shape)
		
		# 连接信号
		interaction_area.body_entered.connect(_on_building_entered.bind(building_id))
		interaction_area.body_exited.connect(_on_building_exited.bind(building_id))
		
		building_node.add_child(interaction_area)
		
		# 添加交互提示（默认隐藏）
		var interaction_hint = Label.new()
		interaction_hint.text = "按空格键进入"
		interaction_hint.position = Vector2(-building_info.size.x / 2, building_info.size.y / 2 + 10)
		interaction_hint.add_theme_font_size_override("font_size", 14)
		interaction_hint.modulate = Color.YELLOW
		interaction_hint.visible = false
		interaction_hint.name = "InteractionHint"
		building_node.add_child(interaction_hint)
	
	buildings_container.add_child(building_node)

func setup_camera():
	# 设置相机跟随玩家
	var camera = $Camera2D
	if player and camera:
		# 将相机移动到玩家身上
		camera.reparent(player)
		camera.position = Vector2.ZERO
		camera.enabled = true
		camera.zoom = Vector2(0.8, 0.8)

func _on_building_entered(building_id: String, body):
	if body == player:
		current_building = building_id
		var building_node = buildings_container.get_node(building_id)
		var hint = building_node.get_node("InteractionHint")
		hint.visible = true
		
		print("接近 " + buildings_data[building_id].name)

func _on_building_exited(building_id: String, body):
	if body == player:
		current_building = null
		var building_node = buildings_container.get_node(building_id)
		var hint = building_node.get_node("InteractionHint")
		hint.visible = false

func _on_money_changed(new_amount):
	if money_label:
		money_label.text = "金币: " + str(new_amount)
