extends CharacterBody2D

# 玩家控制脚本
# 处理移动、跳跃、挖掘等操作

@onready var animated_sprite = $AnimatedSprite2D
@onready var collision_shape = $CollisionShape2D

# 移动相关
var speed = 300.0
var jump_velocity = -400.0
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# 挖掘相关
var dig_range = 100.0
var dig_timer = 0.0
var dig_cooldown = 0.3

# 状态
var is_digging = false
var facing_direction = 1 # 1为右，-1为左

func _ready():
	# 设置初始动画
	if animated_sprite:
		animated_sprite.play("Idle")
		print("Player _ready: 动画精灵已设置为Idle")
	else:
		print("Player _ready: 找不到AnimatedSprite2D节点！")
	
	# 确保玩家可见
	visible = true
	modulate = Color.WHITE
	print("Player _ready: 玩家可见性设置完成")

func _physics_process(delta):
	# 重力
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# 跳跃
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		if animated_sprite:
			animated_sprite.play("jump")
	
	# 移动
	var direction = Input.get_axis("left", "right")
	if direction != 0:
		velocity.x = direction * speed
		facing_direction = direction
		
		# 翻转精灵
		if animated_sprite:
			animated_sprite.flip_h = direction < 0
			
		# 播放走路动画（如果在地面）
		if is_on_floor() and not is_digging:
			if animated_sprite and animated_sprite.animation != "Walk":
				animated_sprite.play("Walk")
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		
		# 播放空闲动画（如果在地面且不在挖掘）
		if is_on_floor() and not is_digging:
			if animated_sprite and animated_sprite.animation != "Idle":
				animated_sprite.play("Idle")
	
	# 挖掘
	handle_digging(delta)
	
	# 放置火把 - 添加新功能
	handle_torch_placement()
	
	move_and_slide()

func handle_digging(delta):
	# 更新挖掘计时器
	if dig_timer > 0:
		dig_timer -= delta
	
	# 检测挖掘输入 - J键 + 方向键挖掘
	if Input.is_action_pressed("dig"): # J键挖掘
		if dig_timer <= 0:
			# 获取方向输入
			var dig_direction = Vector2.ZERO
			if Input.is_action_pressed("left"):
				dig_direction.x = -1
			elif Input.is_action_pressed("right"):
				dig_direction.x = 1
			
			if Input.is_action_pressed("up"):
				dig_direction.y = -1
			elif Input.is_action_pressed("down"):
				dig_direction.y = 1
			
			# 如果没有方向输入，默认向下挖掘
			if dig_direction == Vector2.ZERO:
				dig_direction = Vector2(0, 1)
			
			perform_directional_dig(dig_direction)
			dig_timer = dig_cooldown
			
			# 播放攻击动画
			if animated_sprite and not is_digging:
				is_digging = true
				animated_sprite.play("Dig")
				# 根据挖掘方向翻转精灵
				if dig_direction.x != 0:
					animated_sprite.flip_h = dig_direction.x < 0
				# 创建一个计时器来结束挖掘动画
				var timer = get_tree().create_timer(0.5)
				timer.timeout.connect(_on_dig_animation_finished)
	
	# 检测向前挖掘（空格键 + 方向）
	if Input.is_action_pressed("jump") and is_on_floor() and facing_direction != 0:
		if dig_timer <= 0:
			perform_forward_dig()
			dig_timer = dig_cooldown
			
			# 播放攻击动画
			if animated_sprite and not is_digging:
				is_digging = true
				animated_sprite.play("Dig")
				# 创建一个计时器来结束挖掘动画
				var timer = get_tree().create_timer(0.5)
				timer.timeout.connect(_on_dig_animation_finished)

func perform_directional_dig(direction: Vector2):
	# 对角线挖掘时，调整距离以保持一致的挖掘范围
	if direction.x != 0 and direction.y != 0:
		direction = direction.normalized()
	
	# 计算挖掘位置
	var dig_position = global_position + direction * dig_range
	attempt_dig(dig_position)
	
	# 打印挖掘方向的调试信息
	var direction_name = ""
	if direction.y < 0:
		direction_name = "向上"
	elif direction.y > 0:
		direction_name = "向下"
	if direction.x < 0:
		direction_name += "向左"
	elif direction.x > 0:
		direction_name += "向右"
	print(direction_name, "挖掘！")

func perform_forward_dig():
	# 向前挖掘
	var dig_position = global_position + Vector2(facing_direction * dig_range, 0)
	attempt_dig(dig_position)

func attempt_dig(world_position):
	# 尝试在指定位置挖掘
	var mine_scene = get_parent()
	if mine_scene and mine_scene.has_method("dig_at_position"):
		var success = mine_scene.dig_at_position(world_position)
		if success:
			# 挖掘成功的视觉/音效反馈
			print("挖掘成功！")
		else:
			print("无法挖掘此位置")
	else:
		print("找不到MineScene或dig_at_position方法")

func _on_dig_animation_finished():
	# 挖掘动画结束
	is_digging = false
	if is_on_floor():
		if velocity.x != 0:
			animated_sprite.play("Walk")
		else:
			animated_sprite.play("Idle")

func take_damage(amount):
	# 受伤
	var game_manager = get_node("/root/GameManager")
	if game_manager:
		game_manager.damage_player(amount)
	
	# 播放受伤动画
	if animated_sprite:
		animated_sprite.play("Hurt")
		animated_sprite.animation_finished.connect(_on_hurt_animation_finished, CONNECT_ONE_SHOT)

func _on_hurt_animation_finished():
	# 受伤动画结束，返回正常状态
	if is_on_floor():
		if velocity.x != 0:
			animated_sprite.play("Walk")
		else:
			animated_sprite.play("Idle")

func die():
	# 死亡
	if animated_sprite:
		animated_sprite.play("Dying")
		# 禁用控制
		set_physics_process(false)

# 新增 - 处理放置火把
func handle_torch_placement():
	# 检测T键放置火把
	if Input.is_action_just_pressed("place_torch"):
		print("检测到T键按下，尝试放置火把")
		place_torch()

# 新增 - 放置火把
func place_torch():
	# 检查玩家是否有火把道具
	print("执行place_torch函数")
	var game_manager = get_node("/root/GameManager")
	if not game_manager:
		print("错误: 找不到GameManager")
		return
		
	print("检查火把数量...")
	var torch_count = game_manager.get_item_count("torch")
	print("火把数量:", torch_count)
	
	if game_manager.has_item("torch"):
		print("有火把可以放置")
		# 获取放置位置（就在玩家当前位置）
		var place_position = global_position
		print("尝试在位置放置:", place_position)
		
		# 获取矿场引用并尝试放置火把
		var mine_scene = get_parent()
		print("父场景:", mine_scene.name if mine_scene else "无")
		
		if mine_scene and mine_scene.has_method("place_torch"):
			print("尝试调用place_torch方法")
			# 尝试放置火把，如果失败，尝试在玩家附近寻找有效位置
			if mine_scene.place_torch(place_position):
				# 成功放置，消耗一个火把
				game_manager.remove_item("torch", 1)
				print("放置了一个火把！")
			else:
				# 尝试在玩家脚下放置
				var feet_position = global_position + Vector2(0, 50)
				print("尝试在脚下位置放置:", feet_position)
				if mine_scene.place_torch(feet_position):
					game_manager.remove_item("torch", 1)
					print("放置了一个火把在脚下!")
				else:
					print("无法在此处及附近放置火把")
		else:
			print("找不到放置火把功能，父场景没有place_torch方法")
	else:
		print("没有火把可以放置!")
