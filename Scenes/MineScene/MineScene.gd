extends Node2D

# 矿井场景脚本
# 处理挖掘游戏的核心逻辑

@onready var tilemap
@onready var player
@onready var ui_container
@onready var money_label
@onready var camera

# 地形数据
var terrain_data = {}
var tile_size = 64
var map_width = 50
var map_height = 50

# 挖掘相关
var diggable_materials = ["dirt", "stone", "coal", "iron", "gold", "diamond"]

func _ready():
	# 等待一帧确保GameManager加载
	await get_tree().process_frame
	
	# 初始化地形
	setup_tilemap()
	generate_terrain()
	
	# 实例化玩家
	setup_player()
	
	# 设置UI
	setup_ui()

func setup_tilemap():
	# 创建TileMap节点
	tilemap = TileMap.new()
	
	# 尝试加载预设的TileSet，如果不存在则创建一个基础的
	var tileset_path = "res://Scenes/MineScene/terrain_tileset.tres"
	var tileset = null
	
	if ResourceLoader.exists(tileset_path):
		tileset = load(tileset_path)
	else:
		# 创建一个基础的TileSet资源
		tileset = TileSet.new()
		
		# 创建基础的地形瓦片源
		var tile_source = TileSetAtlasSource.new()
		tile_source.texture_region_size = Vector2i(64, 64)
		
		# 添加瓦片源到TileSet
		tileset.add_source(tile_source, 0)
		
		# 为每种材料添加瓦片
		for i in range(6): # dirt, stone, coal, iron, gold, diamond
			tile_source.create_tile(Vector2i(i, 0))
	
	tilemap.tile_set = tileset
	add_child(tilemap)

func generate_terrain():
	# 生成地形数据
	for x in range(map_width):
		terrain_data[x] = {}
		for y in range(map_height):
			if y < 5:
				# 表面是空气
				terrain_data[x][y] = "air"
			elif y < 10:
				# 土壤层
				terrain_data[x][y] = "dirt"
			elif y < 20:
				# 石头层
				terrain_data[x][y] = "stone"
			else:
				# 深层，随机生成矿物
				var terrain_material = generate_random_material(y)
				terrain_data[x][y] = terrain_material
	
	# 更新TileMap显示
	update_tilemap_display()

func generate_random_material(depth):
	# 根据深度生成不同概率的材料
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var chance = rng.randf()
	
	if depth < 25:
		if chance < 0.7:
			return "stone"
		elif chance < 0.9:
			return "coal"
		else:
			return "iron"
	elif depth < 35:
		if chance < 0.5:
			return "stone"
		elif chance < 0.7:
			return "coal"
		elif chance < 0.9:
			return "iron"
		else:
			return "gold"
	else:
		if chance < 0.3:
			return "stone"
		elif chance < 0.5:
			return "coal"
		elif chance < 0.7:
			return "iron"
		elif chance < 0.9:
			return "gold"
		else:
			return "diamond"

func update_tilemap_display():
	# 更新TileMap的显示 - 使用简单的矩形表示不同材料
	for x in range(map_width):
		for y in range(map_height):
			var terrain_material = terrain_data[x][y]
			if terrain_material != "air":
				# 创建一个简单的ColorRect来表示方块
				create_terrain_block(x, y, terrain_material)

func get_color_for_material(terrain_material):
	# 返回材料对应的颜色
	match terrain_material:
		"dirt":
			return Color(0.6, 0.4, 0.2) # 棕色
		"stone":
			return Color(0.5, 0.5, 0.5) # 灰色
		"coal":
			return Color(0.2, 0.2, 0.2) # 黑色
		"iron":
			return Color(0.7, 0.7, 0.8) # 铁灰色
		"gold":
			return Color(1.0, 0.8, 0.0) # 金色
		"diamond":
			return Color(0.8, 0.9, 1.0) # 钻石蓝
		_:
			return Color.WHITE

func get_tile_id_for_material(terrain_material):
	# 返回材料对应的tile ID
	match terrain_material:
		"dirt":
			return 0
		"stone":
			return 1
		"coal":
			return 2
		"iron":
			return 3
		"gold":
			return 4
		"diamond":
			return 5
		_:
			return 0

func setup_player():
	# 加载玩家场景
	var player_scene = preload("res://Player/Player.tscn")
	player = player_scene.instantiate()
	player.position = Vector2(5 * tile_size, 2 * tile_size) # 在地表spawn
	add_child(player)
	
	# 设置相机跟随玩家
	setup_camera()

func setup_camera():
	# 创建相机并设置跟随玩家
	camera = Camera2D.new()
	camera.enabled = true
	camera.zoom = Vector2(0.8, 0.8) # 稍微放大视角
	
	# 设置相机限制
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = map_width * tile_size
	camera.limit_bottom = map_height * tile_size
	
	# 添加到玩家作为子节点
	if player:
		player.add_child(camera)

func setup_ui():
	# 创建UI容器
	ui_container = CanvasLayer.new()
	add_child(ui_container)
	
	# 创建金币显示
	money_label = Label.new()
	money_label.text = "金币: 100"
	money_label.position = Vector2(20, 20)
	money_label.add_theme_font_size_override("font_size", 24)
	ui_container.add_child(money_label)
	
	# 连接GameManager信号（如果存在）
	if has_node("/root/GameManager"):
		var game_manager = get_node("/root/GameManager")
		game_manager.money_changed.connect(_on_money_changed)
		_on_money_changed(game_manager.get_money())

func _on_money_changed(new_amount):
	if money_label:
		money_label.text = "金币: " + str(new_amount)

func dig_tile(world_pos):
	# 挖掘指定位置的方块
	var tile_pos = Vector2i(world_pos / tile_size)
	
	if tile_pos.x >= 0 and tile_pos.x < map_width and tile_pos.y >= 0 and tile_pos.y < map_height:
		var terrain_material = terrain_data[tile_pos.x][tile_pos.y]
		
		if terrain_material in diggable_materials:
			# 移除方块
			terrain_data[tile_pos.x][tile_pos.y] = "air"
			remove_terrain_block(tile_pos.x, tile_pos.y)
			
			# 给玩家奖励
			give_reward_for_material(terrain_material)
			
			return true
	
	return false

func give_reward_for_material(terrain_material):
	# 根据挖掘的材料给予奖励
	var game_manager = get_node("/root/GameManager")
	if game_manager:
		var reward = game_manager.get_material_value(terrain_material)
		
		# 添加金币到GameManager
		game_manager.add_money(reward)
		
		print("挖掘到 " + terrain_material + "，获得 " + str(reward) + " 金币")

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		# ESC键返回城镇
		var game_manager = get_node("/root/GameManager")
		if game_manager:
			game_manager.change_scene("res://Scenes/TownScene/TownScene.tscn")
		else:
			get_tree().change_scene_to_file("res://Scenes/TownScene/TownScene.tscn")

func create_terrain_block(x, y, terrain_material):
	# 创建一个表示地形方块的ColorRect
	var block = ColorRect.new()
	block.size = Vector2(tile_size, tile_size)
	block.position = Vector2(x * tile_size, y * tile_size)
	block.color = get_color_for_material(terrain_material)
	
	# 添加边框效果
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	add_child(block)
	
	# 存储方块引用以便后续删除
	if not has_meta("terrain_blocks"):
		set_meta("terrain_blocks", {})
	var blocks = get_meta("terrain_blocks")
	blocks[Vector2i(x, y)] = block

func remove_terrain_block(x, y):
	# 移除指定位置的地形方块
	if has_meta("terrain_blocks"):
		var blocks = get_meta("terrain_blocks")
		var pos = Vector2i(x, y)
		if pos in blocks:
			blocks[pos].queue_free()
			blocks.erase(pos)
