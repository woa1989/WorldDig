extends Area2D

# 子弹伤害值
var damage = 1
# 子弹是否正在销毁
var is_destroying = false

@onready var animation_player := $AnimationPlayer as AnimationPlayer

func _ready():
	# 连接碰撞信号
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta):
	# 如果子弹正在销毁，停止所有物理处理
	if is_destroying:
		return
		
	# 获取子弹速度并移动
	if has_meta("velocity"):
		var velocity = get_meta("velocity")
		var old_position = global_position
		global_position += velocity * delta
		
		# 调试输出子弹位置
		if randf() < 0.1: # 10% 概率输出位置，避免刷屏
			print("[DEBUG] 子弹位置: ", global_position, " 速度: ", velocity)
		
		# 检查是否撞墙
		check_wall_collision(old_position, global_position)

func _on_body_entered(body):
	# 如果子弹正在销毁，忽略新的碰撞
	if is_destroying:
		return
	handle_collision(body)

func _on_area_entered(area):
	# 如果子弹正在销毁，忽略新的碰撞
	if is_destroying:
		return
	# 如果碰撞区域的父节点是我们要检测的目标，就处理碰撞
	if area.get_parent():
		handle_collision(area.get_parent())

func handle_collision(body):
	# 如果子弹正在销毁，忽略碰撞
	if is_destroying:
		return
		
	# 检查子弹是否被反弹
	var is_reflected = has_meta("reflected") and get_meta("reflected")
	
	# 检测是否碰到墙壁瓦片
	if body is TileMapLayer or body is TileMap or body is StaticBody2D:
		print("[DEBUG] 子弹击中墙壁，销毁")
		destroy()
		return
	
	# 检测碰撞目标
	if body.has_method("take_damage"):
		print("[DEBUG] 子弹碰撞检测 - 目标: ", body.name, ", 脚本路径: ", body.get_script().get_path() if body.get_script() else "无脚本", ", 反弹状态: ", is_reflected)
		
		# 如果子弹被反弹，只伤害敌人；否则只伤害玩家
		if is_reflected:
			# 反弹的子弹：检查是否为敌人
			if body.get_script() and body.get_script().get_path().ends_with("enemy.gd"):
				print("[DEBUG] 反弹子弹击中敌人，造成伤害: ", damage * 2)
				body.take_damage(damage * 2, self) # 反弹子弹造成双倍伤害
				destroy()
			else:
				print("[DEBUG] 反弹子弹击中非敌人目标，忽略 - 目标类型: ", body.get_class())
		else:
			# 普通子弹：检查是否为玩家
			if body.get_script() and body.get_script().get_path().ends_with("player.gd"):
				print("[DEBUG] 普通子弹击中玩家")
				var was_blocked = body.take_damage(damage, self)
				if not was_blocked:
					# 玩家没有格挡，子弹消失
					print("[DEBUG] 玩家受到伤害，子弹消失")
					destroy()
				else:
					# 玩家成功格挡，子弹已被反弹，不需要销毁
					print("[DEBUG] 玩家成功格挡，子弹被反弹")
			else:
				print("[DEBUG] 普通子弹击中非玩家目标，忽略 - 目标类型: ", body.get_class())
	else:
		print("[DEBUG] 碰撞目标没有take_damage方法 - 目标: ", body.name, ", 类型: ", body.get_class())

func destroy() -> void:
	# 设置销毁标志，防止继续处理物理和碰撞
	is_destroying = true
	# 清除速度元数据，停止移动
	remove_meta("velocity")
	# 播放销毁动画
	animation_player.play(&"destory")

func check_wall_collision(from: Vector2, to: Vector2):
	# 如果子弹正在销毁，停止墙壁检测
	if is_destroying:
		return
		
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(from, to)
	# 检测第1层（MineScene墙壁）和第16层（RPG场景墙壁）
	query.collision_mask = 32769 # 1 + 32768 = 第1层 + 第16层
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	if result:
		print("[DEBUG] 子弹射线检测击中墙壁，销毁")
		print("[DEBUG] 撞击点: ", result.position, " 撞击物体: ", result.collider)
		destroy()
		return
	
	# 额外检查：直接查询当前位置是否有碰撞
	var shape_query = PhysicsPointQueryParameters2D.new()
	shape_query.position = global_position
	shape_query.collision_mask = 32769 # 检测第1层和第16层
	var point_results = space_state.intersect_point(shape_query)
	if point_results.size() > 0:
		print("[DEBUG] 子弹点检测击中墙壁，销毁")
		destroy()
