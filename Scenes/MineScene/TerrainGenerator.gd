extends TileMapLayer

# 信号定义
signal torch_created(grid_pos: Vector2)

# 地形数据
var terrain_data = {}
var current_durability = {}
var dig_progress = {}

# 地图参数
var tile_size = 128
var map_width = 100
var map_height = 100
var surface_level = 10

var torch_tile = Vector2i(20, 0) # 火把瓦片 - 使用source_id = 1的20:0/0


var dirt_tile = Vector2i(6, 5) # 默认泥土瓦片 - 完全周围都有连接的中心泥土
var stone = Vector2i(11, 1) # 石头瓦片位置 - 使用13:6/0
var iron_ore = Vector2i(14, 6) # 铁矿瓦片 - 使用14:6/0
var gold_ore = Vector2i(13, 7) # 金矿瓦片 - 使用13:7/0
var chest = Vector2i(8, 0) # 宝箱瓦片位置 - 使用source_id = 1的8:0/0

# 地形系统
const TERRAIN_SET = 0 # 地形集索引
const TERRAIN_DIRT = 0 # 泥土地形索引

# 矿物生成概率 - 降低基础概率，让大部分区域是石头
var iron_ore_chance = 0.05 # 铁矿5%概率 (从15%降低)
var gold_ore_chance = 0.02 # 金矿2%概率 (从5%降低)
var chest_chance = 0.003 # 宝箱0.3%概率 (从1%降低)
var torch_chance = 0.03 # 火把3%概率 (从8%降低，减少密度)

# 火把密度控制参数
var min_torch_distance = 5 # 火把之间的最小距离
var torch_density_factor = 0.5 # 整体密度系数 (0.1-1.0)，值越小火把越少

# 引用其他层
var ore_layer: TileMapLayer
var player_spawn_position: Vector2

func _ready():
	print("TerrainGenerator _ready 开始")
	
	# 获取矿物层引用
	ore_layer = get_parent().get_node("Ore")
	
	# 设置玩家生成位置
	player_spawn_position = Vector2(map_width * tile_size / 2.0, surface_level * tile_size - tile_size)
	
	# 检查TileSet配置
	var tileset_res = tile_set
	if tileset_res:
		print("TileSet加载成功")
		print("TileSet名称: ", tileset_res.resource_name)
		
		# 简单测试瓦片设置
		print("Dirt瓦片：", dirt_tile)
		print("Stone瓦片：", stone)
	else:
		print("警告：未加载TileSet！")
	
	# 生成地形
	generate_terrain()
	print("地形生成完成")

func generate_terrain():
	"""生成完整的地形"""
	print("开始生成地形...")
	print("地图大小: ", map_width, "x", map_height, " 表面深度: ", surface_level)
	
	# 首先清空现有地形
	clear()
	if ore_layer:
		ore_layer.clear()
		print("ore_layer 引用正常")
	else:
		print("警告: ore_layer 引用为null!")
	
	var tiles_generated = 0
	var dirt_cells = [] # 收集所有泥土瓦片位置
	
	# 生成表面到地下的地形
	for x in range(map_width):
		for y in range(surface_level, map_height):
			var world_pos = Vector2(x, y)
			var is_near_spawn = is_position_near_spawn(world_pos)
			
			# 如果靠近生成点，创建空洞
			if is_near_spawn:
				continue
			
			# 根据深度决定生成什么
			generate_tile_at_position(world_pos)
			dirt_cells.append(Vector2i(int(x), int(y)))
			tiles_generated += 1
	
	# 批量设置所有泥土瓦片的地形连接
	if dirt_cells.size() > 0:
		print("批量设置 ", dirt_cells.size(), " 个泥土瓦片的地形连接")
		set_cells_terrain_connect(dirt_cells, TERRAIN_SET, TERRAIN_DIRT, false)
	
	print("生成了 ", tiles_generated, " 个瓦片")
	
	# 在dirt层生成火把
	generate_torches()
	
	print("地形生成完成，包含", terrain_data.size(), "个瓦片")

func is_position_near_spawn(pos: Vector2) -> bool:
	"""检查位置是否靠近生成点，用于创建初始空洞"""
	var spawn_grid = Vector2(map_width / 2.0, surface_level)
	
	# 创建一个椭圆形的空洞
	var hole_width = 4
	var hole_height = 3
	
	var dx = abs(pos.x - spawn_grid.x)
	var dy = abs(pos.y - spawn_grid.y)
	
	return (dx * dx) / (hole_width * hole_width) + (dy * dy) / (hole_height * hole_height) <= 1.0

func generate_tile_at_position(pos: Vector2):
	"""在指定位置生成瓦片"""
	var depth = pos.y - surface_level
	
	# 根据深度调整矿物概率 - 降低基础概率和深度影响
	var adjusted_chest_chance = chest_chance + (depth * 0.0005) # 降低深度影响
	var adjusted_gold_chance = gold_ore_chance + (depth * 0.001)
	var adjusted_iron_chance = iron_ore_chance + (depth * 0.002)
	
	# 生成随机数
	var rand = randf()
	
	# 修复概率判断逻辑 - 使用独立概率而不是累加概率
	if rand < adjusted_chest_chance:
		# 生成宝箱 (ore层, source_id=1)
		place_ore_tile(pos, chest, 1)
		terrain_data[pos] = {"type": "chest", "durability": 1}
	elif rand < adjusted_chest_chance + adjusted_gold_chance:
		# 生成金矿 (ore层, source_id=0)
		place_ore_tile(pos, gold_ore, 0)
		terrain_data[pos] = {"type": "gold_ore", "durability": 3}
	elif rand < adjusted_chest_chance + adjusted_gold_chance + adjusted_iron_chance:
		# 生成铁矿 (ore层, source_id=0)
		place_ore_tile(pos, iron_ore, 0)
		terrain_data[pos] = {"type": "iron_ore", "durability": 2}
	else:
		# 生成普通石头 (ore层, source_id=0) - 大部分应该是石头
		place_ore_tile(pos, stone, 0)
		terrain_data[pos] = {"type": "stone", "durability": 1}
	
	# 注意：不在这里单独放置泥土，而是在generate_terrain中批量处理

func generate_torches():
	"""在dirt层随机生成火把 - 根据深度递减，带距离控制"""
	var torch_count = 0
	var max_torches = int(map_width * map_height * torch_chance * torch_density_factor / 10)
	var placed_torches = [] # 记录已放置火把的位置
	
	print("火把生成开始，最大数量限制: ", max_torches)
	
	for x in range(map_width):
		for y in range(surface_level, map_height):
			var pos = Vector2(x, y)
			
			# 跳过生成点附近
			if is_position_near_spawn(pos):
				continue
			
			# 跳过没有地形数据的位置
			if not terrain_data.has(pos):
				continue
			
			# 检查与已有火把的距离
			if not is_valid_torch_position(pos, placed_torches):
				continue
			
			# 计算深度相关的火把概率
			var depth = y - surface_level
			var depth_factor = calculate_torch_probability_by_depth(depth)
			var adjusted_torch_chance = torch_chance * depth_factor * torch_density_factor
			
			# 随机生成火把，概率随深度递减
			if randf() < adjusted_torch_chance and torch_count < max_torches:
				# 放置火把瓦片在ore层
				place_ore_tile(pos, torch_tile, 1) # 使用source_id=1的torch_tile
				
				# 记录这个位置有火把
				terrain_data[pos]["has_torch"] = true
				placed_torches.append(pos)
				torch_count += 1
				
				# 发出信号通知创建光源
				torch_created.emit(pos)
				
				# 调试信息：显示不同深度的火把分布
				if depth <= 10:
					print("深度 ", depth, " 生成火把，概率: ", "%.3f" % adjusted_torch_chance)
	
	print("火把生成完成，总共生成了 ", torch_count, " 个火把 (密度系数: ", torch_density_factor, ")")

func is_valid_torch_position(pos: Vector2, existing_torches: Array) -> bool:
	"""检查火把位置是否有效（与其他火把保持最小距离）"""
	for torch_pos in existing_torches:
		var distance = pos.distance_to(torch_pos)
		if distance < min_torch_distance:
			return false
	return true

func calculate_torch_probability_by_depth(depth: int) -> float:
	"""根据深度计算火把生成概率的衰减因子"""
	# 深度0-5层: 100% 概率（洞口附近火把最多）
	if depth <= 5:
		return 1.0
	
	# 深度6-15层: 线性递减到50%
	elif depth <= 15:
		return 1.0 - (depth - 5) * 0.05 # 每层递减5%
	
	# 深度16-30层: 继续递减到20%
	elif depth <= 30:
		return 0.5 - (depth - 15) * 0.02 # 每层递减2%
	
	# 深度31-50层: 缓慢递减到5%
	elif depth <= 50:
		return 0.2 - (depth - 30) * 0.0075 # 每层递减0.75%
	
	# 深度50+层: 保持最低5%概率（深层仍有少量火把）
	else:
		return 0.05

# 火把密度控制函数
func set_torch_density(density: float):
	"""设置火把密度系数 (0.1-1.0)"""
	torch_density_factor = clamp(density, 0.1, 1.0)
	print("火把密度系数设置为: ", torch_density_factor)

func set_min_torch_distance(distance: int):
	"""设置火把之间的最小距离"""
	min_torch_distance = max(distance, 1)
	print("火把最小距离设置为: ", min_torch_distance)

func regenerate_torches_with_new_density():
	"""使用新的密度参数重新生成火把"""
	print("正在使用新密度参数重新生成火把...")
	
	# 清除现有火把
	clear_all_torches()
	
	# 重新生成火把
	generate_torches()

func clear_all_torches():
	"""清除所有现有火把"""
	var cleared_count = 0
	
	for pos in terrain_data:
		var tile_data = terrain_data[pos]
		if tile_data.get("has_torch", false):
			# 移除ore层的火把瓦片
			var cell_pos = Vector2i(int(pos.x), int(pos.y))
			if ore_layer:
				ore_layer.erase_cell(cell_pos)
			
			# 更新数据
			tile_data["has_torch"] = false
			cleared_count += 1
	
	print("清除了 ", cleared_count, " 个火把")

func place_dirt_tile(pos: Vector2, tile_coords: Vector2, source_id: int = 0):
	"""在dirt层放置瓦片"""
	set_cell(pos, source_id, tile_coords)
	# print("Dirt瓦片放置在: ", pos, " 坐标: ", tile_coords, " source_id: ", source_id)

func place_ore_tile(pos: Vector2, tile_coords: Vector2, source_id: int = 0):
	"""在ore层放置瓦片"""
	if ore_layer:
		var cell_pos = Vector2i(int(pos.x), int(pos.y))
		ore_layer.set_cell(cell_pos, source_id, tile_coords)
		print("Ore瓦片放置在: ", pos, " 坐标: ", tile_coords, " source_id: ", source_id)
	else:
		print("错误: ore_layer为null，无法放置瓦片")

func dig_at_position(world_pos: Vector2) -> bool:
	"""在世界坐标位置挖掘"""
	var grid_pos = local_to_map(to_local(world_pos))
	return dig_tile(grid_pos)

func dig_tile(grid_pos: Vector2) -> bool:
	"""挖掘指定网格位置的瓦片"""
	if not terrain_data.has(grid_pos):
		return false
	
	var tile_data = terrain_data[grid_pos]
	var tile_type = tile_data.get("type", "stone")
	var has_torch = tile_data.get("has_torch", false)
	
	# 如果有火把，只移除火把，不影响下层
	if has_torch:
		# 移除ore层的火把瓦片
		var cell_pos = Vector2i(int(grid_pos.x), int(grid_pos.y))
		if ore_layer:
			ore_layer.erase_cell(cell_pos)
		
		tile_data["has_torch"] = false
		
		# 给玩家火把物品
		add_item_to_inventory("torch")
		print("获得火把！")
		return true
	
	# 挖掘ore层的瓦片
	current_durability[grid_pos] = current_durability.get(grid_pos, tile_data.durability)
	current_durability[grid_pos] -= 1
	
	if current_durability[grid_pos] <= 0:
		# 完全挖掘，移除瓦片
		var cell_pos = Vector2i(int(grid_pos.x), int(grid_pos.y))
		
		# 移除ore层瓦片
		if ore_layer:
			ore_layer.erase_cell(cell_pos)
		
		# 移除dirt层瓦片
		erase_cell(cell_pos)
		
		# 更新周围瓦片的地形连接
		update_surrounding_terrain(cell_pos)
		
		# 给玩家对应的物品
		give_reward_for_tile(tile_type)
		
		# 从数据中移除
		terrain_data.erase(grid_pos)
		current_durability.erase(grid_pos)
		
		print("挖掘完成，获得:", tile_type)
		return true
	else:
		# 部分挖掘，显示破损效果
		show_damage_effect(grid_pos, current_durability[grid_pos], tile_data.durability)
		print("瓦片受损，剩余耐久度:", current_durability[grid_pos])
		return true

func give_reward_for_tile(tile_type: String):
	"""根据瓦片类型给予奖励"""
	match tile_type:
		"stone":
			add_item_to_inventory("stone")
		"iron_ore":
			add_item_to_inventory("iron_ore")
		"gold_ore":
			add_item_to_inventory("gold_ore")
		"chest":
			# 宝箱给予随机奖励
			var rewards = ["gold_ore", "iron_ore", "torch", "stone"]
			var reward = rewards[randi() % rewards.size()]
			add_item_to_inventory(reward)
			add_item_to_inventory("coin") # 额外金币

func add_item_to_inventory(item_name: String):
	"""添加物品到背包（需要实现背包系统）"""
	var game_manager = get_node("/root/GameManager")
	if game_manager and game_manager.has_method("add_item"):
		game_manager.add_item(item_name)
	else:
		print("获得物品:", item_name)

func show_damage_effect(_grid_pos: Vector2, _current_hp: int, _max_hp: int):
	"""显示瓦片受损效果（可以在这里添加视觉效果）"""
	# 这里可以添加粒子效果、音效等
	pass

func get_player_spawn_position() -> Vector2:
	"""获取玩家生成位置"""
	return Vector2(map_width * tile_size / 2.0, (surface_level - 1) * tile_size)

func place_dirt_with_terrain(pos: Vector2):
	"""放置泥土瓦片并使用自动地形连接"""
	# 将Vector2转换为Vector2i
	var cell_pos = Vector2i(int(pos.x), int(pos.y))
	
	# 使用Godot的地形系统设置瓦片
	# set_cells_terrain_connect(cells, terrain_set, terrain, ignore_empty_terrains)
	var cells_array = [cell_pos]
	set_cells_terrain_connect(cells_array, TERRAIN_SET, TERRAIN_DIRT, false)
	
	# 记录在terrain_data中这个位置已经生成了泥土
	if not terrain_data.has(pos):
		terrain_data[pos] = {"type": "dirt", "durability": 1}
	else:
		# 如果已经存在其他类型的数据，保留原有数据，只添加泥土属性
		terrain_data[pos]["has_dirt"] = true

	
# 辅助函数：检查指定位置是否有瓦片
func has_cell(pos: Vector2i) -> bool:
	return get_cell_source_id(pos) != -1

func update_surrounding_terrain(center: Vector2i):
	"""更新指定位置周围的瓦片地形连接"""
	print("更新周围地形连接，中心位置: ", center)
	
	# 收集需要更新的瓦片位置
	var cells_to_update = []
	
	# 更新中心及周围3x3区域的瓦片
	for y in range(center.y - 1, center.y + 2):
		for x in range(center.x - 1, center.x + 2):
			var cell_pos = Vector2i(x, y)
			
			# 检查这个位置是否有瓦片
			var source_id = get_cell_source_id(cell_pos)
			if source_id == -1: # 如果没有瓦片，跳过
				continue
			
			# 只更新dirt层的瓦片 (source_id = 0)
			if source_id == 0:
				cells_to_update.append(cell_pos)
	
	# 如果有需要更新的瓦片，使用地形系统重新连接
	if cells_to_update.size() > 0:
		set_cells_terrain_connect(cells_to_update, TERRAIN_SET, TERRAIN_DIRT, false)
		print("使用地形系统更新了 ", cells_to_update.size(), " 个瓦片")
