extends Node2D

# 矿井场景脚本
# 处理挖掘游戏的核心逻辑

@onready var tilemap
@onready var player

# 地形数据
var terrain_data = {}
var tile_size = 64
var map_width = 50
var map_height = 50

# 挖掘相关
var diggable_materials = ["dirt", "stone", "coal", "iron", "gold", "diamond"]

func _ready():
	# 初始化地形
	setup_tilemap()
	generate_terrain()
	
	# 实例化玩家
	setup_player()

func setup_tilemap():
	# 创建TileMap节点
	tilemap = TileMap.new()
	# 注释掉预加载，稍后需要创建tileset资源
	# tilemap.tile_set = preload("res://terrain_tileset.tres")
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
	# 更新TileMap的显示
	for x in range(map_width):
		for y in range(map_height):
			var terrain_material = terrain_data[x][y]
			if terrain_material != "air":
				# 根据材料类型设置不同的tile
				var tile_id = get_tile_id_for_material(terrain_material)
				# 暂时注释掉，需要tileset资源
				# tilemap.set_cell(0, Vector2i(x, y), 0, Vector2i(tile_id, 0))

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

func dig_tile(world_pos):
	# 挖掘指定位置的方块
	var tile_pos = Vector2i(world_pos / tile_size)
	
	if tile_pos.x >= 0 and tile_pos.x < map_width and tile_pos.y >= 0 and tile_pos.y < map_height:
		var terrain_material = terrain_data[tile_pos.x][tile_pos.y]
		
		if terrain_material in diggable_materials:
			# 移除方块
			terrain_data[tile_pos.x][tile_pos.y] = "air"
			# tilemap.set_cell(0, tile_pos, -1)  # 清除tile
			
			# 给玩家奖励
			give_reward_for_material(terrain_material)
			
			return true
	
	return false

func give_reward_for_material(terrain_material):
	# 根据挖掘的材料给予奖励
	var reward = GameManager.get_material_value(terrain_material)
	
	# 添加金币到GameManager
	GameManager.add_money(reward)
	
	print("挖掘到 " + terrain_material + "，获得 " + str(reward) + " 金币")

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		# ESC键返回城镇
		GameManager.change_scene("res://Scenes/TownScene/TownScene.tscn")
