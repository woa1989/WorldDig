extends Node2D

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var background: ColorRect = $Background

# 血量条设置
var max_health: int = 1
var current_health: int = 1
var grid_position: Vector2
var tile_size: int = 128

func _ready():
	# 初始化时隐藏血量条
	visible = false

func setup(grid_pos: Vector2, max_hp: int, current_hp: int):
	"""设置血量条参数"""
	grid_position = grid_pos
	max_health = max_hp
	current_health = current_hp
	
	# 设置进度条
	progress_bar.max_value = max_health
	progress_bar.value = current_health
	
	# 设置位置到瓦片中心上方
	var world_pos = grid_pos * tile_size + Vector2(tile_size * 0.5, tile_size * 0.5)

	global_position = world_pos + Vector2(0, -40) # 偏移到瓦片上方
	
	# 只有受损时才显示
	visible = current_health < max_health

func update_health(new_health: int):
	"""更新血量显示"""
	current_health = new_health
	progress_bar.value = current_health
	
	# 只有受损时才显示
	visible = current_health < max_health
	
	# 更新颜色（从绿色到红色）
	var health_ratio = float(current_health) / float(max_health)
	var color = Color.GREEN.lerp(Color.RED, 1.0 - health_ratio)
	progress_bar.modulate = color

func hide_health_bar():
	"""隐藏血量条"""
	visible = false
