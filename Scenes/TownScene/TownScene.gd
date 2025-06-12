extends Node2D

# 城镇场景脚本
# 管理城镇的各种功能，包括商店、矿井入口等

@onready var money_label = $UI/TopPanel/MoneyLabel
@onready var player = $Player

# 建筑物引用
@onready var shop_area = $Buildings/Shop/ShopArea
@onready var shop_hint = $Buildings/Shop/ShopHint
@onready var mine_area = $Buildings/Mine/MineArea
@onready var mine_hint = $Buildings/Mine/MineHint

# 建筑物场景路径
var building_scenes = {
	"shop": "res://Scenes/ShopScene/ShopScene.tscn",
	"mine": "res://Scenes/MineScene/MineScene.tscn"
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
	
	# 连接建筑物交互信号
	setup_building_interactions()
	
	# 设置相机跟随
	setup_camera()

func setup_building_interactions():
	# 连接商店交互信号
	if shop_area:
		shop_area.body_entered.connect(_on_shop_entered)
		shop_area.body_exited.connect(_on_shop_exited)
	
	# 连接矿井交互信号  
	if mine_area:
		mine_area.body_entered.connect(_on_mine_entered)
		mine_area.body_exited.connect(_on_mine_exited)

func _input(event):
	# 处理按键输入
	# 空格键进入建筑
	if event.is_action_pressed("ui_accept") and current_building:
		enter_building(current_building)

func enter_building(building_id: String):
	if building_scenes.has(building_id):
		var scene_path = building_scenes[building_id]
		var game_manager = get_node_or_null("/root/GameManager")
		if game_manager:
			game_manager.change_scene(scene_path)
		else:
			get_tree().change_scene_to_file(scene_path)

func setup_camera():
	# 设置相机跟随玩家
	var camera = $Camera2D
	if player and camera:
		# 将相机移动到玩家身上
		camera.reparent(player)
		camera.position = Vector2.ZERO
		camera.enabled = true
		camera.zoom = Vector2(0.8, 0.8)

# 商店交互
func _on_shop_entered(body):
	if body == player:
		current_building = "shop"
		if shop_hint:
			shop_hint.visible = true

func _on_shop_exited(body):
	if body == player:
		current_building = null
		if shop_hint:
			shop_hint.visible = false

# 矿井交互  
func _on_mine_entered(body):
	if body == player:
		current_building = "mine"
		if mine_hint:
			mine_hint.visible = true

func _on_mine_exited(body):
	if body == player:
		current_building = null
		if mine_hint:
			mine_hint.visible = false

func _on_money_changed(new_amount):
	if money_label:
		money_label.text = "金币: " + str(new_amount)
