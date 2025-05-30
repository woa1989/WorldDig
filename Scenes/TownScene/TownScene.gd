extends Node2D

# 城镇场景脚本
# 管理城镇的各种功能，包括商店、矿井入口等

@onready var money_label = $UI/TopPanel/MoneyLabel
@onready var shop = $Buildings/Shop
@onready var mine_entrance = $Buildings/MineEntrance

func _ready():
	# 连接GameManager的信号
	GameManager.money_changed.connect(_on_money_changed)
	
	# 初始化UI
	update_money_display()
	
	# 添加建筑物的交互区域
	setup_building_interactions()

func _input(event):
	# 处理按键输入
	if event.is_action_pressed("ui_cancel"):
		# ESC键返回开始菜单
		GameManager.change_scene("res://Scenes/StartScene/StartScene.tscn")

func setup_building_interactions():
	# 为商店添加交互区域
	var shop_area = Area2D.new()
	var shop_collision = CollisionShape2D.new()
	var shop_shape = RectangleShape2D.new()
	shop_shape.size = Vector2(150, 180)
	shop_collision.shape = shop_shape
	shop_area.add_child(shop_collision)
	shop_area.position = Vector2(175, 540) # 商店中心位置
	shop_area.body_entered.connect(_on_shop_area_entered)
	add_child(shop_area)
	
	# 为矿井入口添加交互区域
	var mine_area = Area2D.new()
	var mine_collision = CollisionShape2D.new()
	var mine_shape = RectangleShape2D.new()
	mine_shape.size = Vector2(200, 130)
	mine_collision.shape = mine_shape
	mine_area.add_child(mine_collision)
	mine_area.position = Vector2(900, 565) # 矿井入口中心位置
	mine_area.body_entered.connect(_on_mine_area_entered)
	add_child(mine_area)

func _on_shop_area_entered(body):
	if body.name == "Player":
		print("进入商店")
		# 切换到商店场景
		GameManager.change_scene("res://Scenes/ShopScene/ShopScene.tscn")

func _on_mine_area_entered(body):
	if body.name == "Player":
		print("进入矿井")
		# 切换到挖掘场景
		GameManager.change_scene("res://Scenes/MineScene/MineScene.tscn")

func _on_money_changed(_new_amount):
	update_money_display()

func update_money_display():
	money_label.text = "金币: " + str(GameManager.get_money())
