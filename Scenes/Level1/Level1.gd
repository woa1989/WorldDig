extends Node2D

# 迷宫生成器脚本
# 使用19:0瓦片生成不可穿越不可破坏的迷宫墙壁
# 使用11:5瓦片填充泥土到迷宫中

@onready var maze_layer = $Map/Maze
@onready var dirt_layer = $Map/Dirt
@onready var player = $Player

# 迷宫参数
var maze_width = 21  # 迷宫宽度（奇数）
var maze_height = 21  # 迷宫高度（奇数）
var cell_size = 1  # 每个迷宫单元的瓦片大小

# 瓦片ID
var wall_tile_id = Vector2i(19, 0)  # 迷宫墙壁瓦片
var dirt_tile_id = Vector2i(11, 5)  # 泥土瓦片

# 迷宫数据：0=通道，1=墙壁
var maze_data = []

# 入口和出口位置
var entrance_pos = Vector2i(1, 1)  # 入口位置
var exit_pos = Vector2i(19, 19)  # 出口位置

func _ready():
	"""场景准备完成时调用"""
	generate_maze()
	fill_maze_with_tiles()
	setup_player_position()

func generate_maze():
	"""生成迷宫数据使用递归回溯算法"""
	# 初始化迷宫数据，全部设为墙壁
	maze_data.clear()
	for y in range(maze_height):
		var row = []
		for x in range(maze_width):
			row.append(1)  # 1表示墙壁
		maze_data.append(row)
	
	# 设置入口和出口
	entrance_pos = Vector2i(1, 1)
	exit_pos = Vector2i(maze_width - 2, maze_height - 2)
	
	# 从入口开始生成迷宫
	maze_data[entrance_pos.y][entrance_pos.x] = 0  # 设为通道
	
	# 使用栈进行递归回溯
	var stack = []
	var current = entrance_pos
	
	while true:
		var neighbors = get_unvisited_neighbors(current)
		
		if neighbors.size() > 0:
			# 随机选择一个邻居
			var next = neighbors[randi() % neighbors.size()]
			
			# 将当前位置压入栈
			stack.push_back(current)
			
			# 移除当前位置和选择的邻居之间的墙壁
			remove_wall_between(current, next)
			
			# 移动到下一个位置
			current = next
			maze_data[current.y][current.x] = 0
		else:
			# 如果没有未访问的邻居，回溯
			if stack.size() == 0:
				break
			current = stack.pop_back()
	
	# 确保出口可达
	ensure_exit_reachable()

func get_unvisited_neighbors(pos: Vector2i) -> Array:
	"""获取未访问的邻居（距离为2的位置）"""
	var neighbors = []
	var directions = [Vector2i(0, -2), Vector2i(2, 0), Vector2i(0, 2), Vector2i(-2, 0)]  # 上右下左
	
	for dir in directions:
		var neighbor = pos + dir
		if is_valid_position(neighbor) and maze_data[neighbor.y][neighbor.x] == 1:
			neighbors.append(neighbor)
	
	return neighbors

func is_valid_position(pos: Vector2i) -> bool:
	"""检查位置是否在迷宫范围内"""
	return pos.x >= 1 and pos.x < maze_width - 1 and pos.y >= 1 and pos.y < maze_height - 1

func ensure_exit_reachable():
	"""确保出口可达，如果不可达则强制创建路径"""
	# 设置出口为通道
	maze_data[exit_pos.y][exit_pos.x] = 0
	
	# 检查出口是否可达
	if not is_path_exists(entrance_pos, exit_pos):
		# 如果不可达，创建一条简单路径
		create_forced_path(entrance_pos, exit_pos)

func is_path_exists(start: Vector2i, end: Vector2i) -> bool:
	"""使用BFS检查两点之间是否存在路径"""
	var visited = {}
	var queue = [start]
	visited[start] = true
	
	var directions = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	
	while queue.size() > 0:
		var current = queue.pop_front()
		
		if current == end:
			return true
		
		for dir in directions:
			var next = current + dir
			if is_valid_maze_position(next) and not visited.has(next) and maze_data[next.y][next.x] == 0:
				visited[next] = true
				queue.push_back(next)
	
	return false

func is_valid_maze_position(pos: Vector2i) -> bool:
	"""检查位置是否在迷宫数据范围内"""
	return pos.x >= 0 and pos.x < maze_width and pos.y >= 0 and pos.y < maze_height

func create_forced_path(start: Vector2i, end: Vector2i):
	"""强制创建从起点到终点的路径"""
	# 创建一条L形路径：先水平移动，再垂直移动
	var current = start
	
	# 水平移动到出口的x坐标
	while current.x != end.x:
		if current.x < end.x:
			current.x += 1
		else:
			current.x -= 1
		maze_data[current.y][current.x] = 0
	
	# 垂直移动到出口的y坐标
	while current.y != end.y:
		if current.y < end.y:
			current.y += 1
		else:
			current.y -= 1
		maze_data[current.y][current.x] = 0

func remove_wall_between(pos1: Vector2i, pos2: Vector2i):
	"""移除两个位置之间的墙壁"""
	var wall_pos = Vector2i(floor((pos1.x + pos2.x) / 2.0), floor((pos1.y + pos2.y) / 2.0))
	maze_data[wall_pos.y][wall_pos.x] = 0

func fill_maze_with_tiles():
	"""根据迷宫数据填充瓦片"""
	# 清空现有瓦片
	maze_layer.clear()
	dirt_layer.clear()
	
	# 根据迷宫数据放置瓦片
	for y in range(maze_height):
		for x in range(maze_width):
			var tile_pos = Vector2i(x, y)
			
			if maze_data[y][x] == 1:
				# 墙壁：放置不可穿越的迷宫瓦片
				maze_layer.set_cell(tile_pos, 0, wall_tile_id)
			else:
				# 通道：放置泥土瓦片
				dirt_layer.set_cell(tile_pos, 0, dirt_tile_id)
	
	# 确保入口和出口的边界开放
	create_entrance_and_exit()

func regenerate_maze():
	"""重新生成迷宫（可供外部调用）"""
	generate_maze()
	fill_maze_with_tiles()

func get_maze_data() -> Array:
	"""获取迷宫数据（供其他脚本使用）"""
	return maze_data

func create_entrance_and_exit():
	"""创建入口和出口的开放通道"""
	# 在迷宫边界创建入口（左上角）
	maze_layer.erase_cell(Vector2i(0, 1))  # 移除入口处的墙壁
	maze_layer.erase_cell(Vector2i(1, 0))  # 移除入口上方的墙壁
	
	# 在迷宫边界创建出口（右下角）
	maze_layer.erase_cell(Vector2i(maze_width - 1, maze_height - 2))  # 移除出口处的墙壁
	maze_layer.erase_cell(Vector2i(maze_width - 2, maze_height - 1))  # 移除出口下方的墙壁

func get_entrance_position() -> Vector2i:
	"""获取入口位置"""
	return entrance_pos

func get_exit_position() -> Vector2i:
	"""获取出口位置"""
	return exit_pos

func setup_player_position():
	"""设置玩家初始位置"""
	if player:
		# 将玩家放置在入口位置，x轴向右偏移两个瓦片（256像素）
		var player_pos = Vector2(
			(entrance_pos.x + 2) * 128,  # 向右偏移2个瓦片，每个瓦片128像素
			entrance_pos.y
		)
		player.global_position = player_pos

func is_wall_at_position(world_pos: Vector2) -> bool:
	"""检查世界坐标位置是否为墙壁"""
	var tile_pos = maze_layer.local_to_map(world_pos)
	if tile_pos.x >= 0 and tile_pos.x < maze_width and tile_pos.y >= 0 and tile_pos.y < maze_height:
		return maze_data[tile_pos.y][tile_pos.x] == 1
	return true  # 超出范围视为墙壁
