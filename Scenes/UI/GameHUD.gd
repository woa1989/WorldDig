extends Control

@onready var money_label: Label = $TopPanel/HBoxContainer/LeftInfo/MoneyLabel
@onready var health_label: Label = $TopPanel/HBoxContainer/LeftInfo/HealthLabel
@onready var depth_label: Label = $TopPanel/HBoxContainer/RightInfo/DepthLabel
@onready var torch_count_label = $BottomPanel/QuickBar/TorchCount

var player: CharacterBody2D
var surface_level = 10 # 地表高度

func _ready():
	# 连接到GameManager的信号
	var game_manager = get_node("/root/GameManager")
	if game_manager:
		game_manager.money_changed.connect(_on_money_changed)
		game_manager.inventory_changed.connect(_on_inventory_changed)
	
	# 查找玩家
	player = get_node("../../Player")
	
	# 初始更新显示
	update_all_displays()

func _process(_delta):
	# 定期更新深度显示
	update_depth_display()

func update_all_displays():
	"""更新所有显示内容"""
	update_money_display()
	update_health_display()
	update_depth_display()
	update_quick_bar()

func _on_money_changed(new_amount):
	"""当金币改变时更新显示"""
	if money_label:
		money_label.text = "金币: " + str(new_amount)

func _on_inventory_changed():
	"""当背包内容改变时更新快速栏"""
	update_quick_bar()

func update_money_display():
	"""更新金币显示"""
	var game_manager = get_node("/root/GameManager")
	if game_manager and money_label:
		money_label.text = "金币: " + str(game_manager.get_money())

func update_health_display():
	"""更新生命值显示"""
	var game_manager = get_node("/root/GameManager")
	if game_manager and health_label:
		health_label.text = "生命: " + str(game_manager.player_health) + "/" + str(game_manager.player_max_health)

func update_depth_display():
	"""更新深度显示"""
	if not player or not depth_label:
		return
	
	# 计算深度（基于玩家Y坐标和地表高度）
	var depth = max(0, int((player.global_position.y / 128.0) - surface_level))
	depth_label.text = "深度: " + str(depth) + "m"

func update_quick_bar():
	"""更新快速栏显示"""
	var game_manager = get_node("/root/GameManager")
	if game_manager and torch_count_label:
		# 更新火把数量
		var torch_count = game_manager.get_item_count("torch")
		torch_count_label.text = "火把: " + str(torch_count) + " [T]"
