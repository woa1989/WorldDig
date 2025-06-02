extends CharacterBody2D

# 玩家控制脚本
# 处理移动、跳跃、挖掘等操作

@onready var animated_sprite = $AnimatedSprite2D
@onready var collision_shape = $CollisionShape2D
@onready var mining_light: Light2D # Reference to the Light2D node

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

# 光照相关
var light_duration = 60.0 # 1分钟
var current_light_time = 0.0
var is_light_active = true

func _ready():
	# 设置初始动画
	if animated_sprite:
		animated_sprite.play("idle")

	# 创建并配置 Light2D 节点
	mining_light = Light2D.new()
	mining_light.name = "MiningLight"
	mining_light.color = Color(1.0, 1.0, 0.5) # Yellow
	mining_light.energy = 1.0
	mining_light.range = 250.0
	mining_light.texture_scale = 0.2 # Make the default texture softer
	mining_light.shadow_enabled = true
	add_child(mining_light)

	# 初始化光照时间
	current_light_time = light_duration

func _physics_process(delta):
	# 光照计时器逻辑
	if is_light_active:
		current_light_time -= delta
		if current_light_time <= 0:
			is_light_active = false
			if mining_light:
				mining_light.energy = 0.1 # Dim the light
			# Optionally, notify GameManager or MineScene to switch to global dim light
			# For now, just dimming player's light.
			print("Player light dimmed.")

	# 重力
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# 跳跃
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		if animated_sprite:
			animated_sprite.play("jump_start")
	
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
			if animated_sprite and animated_sprite.animation != "walking":
				animated_sprite.play("walking")
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		
		# 播放空闲动画（如果在地面且不在挖掘）
		if is_on_floor() and not is_digging:
			if animated_sprite and animated_sprite.animation != "idle":
				animated_sprite.play("idle")
	
	# 挖掘
	handle_digging(delta)
	
	move_and_slide()

func handle_digging(delta):
	# 更新挖掘计时器
	if dig_timer > 0:
		dig_timer -= delta
	
	# 检测挖掘输入
	if Input.is_action_pressed("dig"): # J键挖掘
		if dig_timer <= 0:
			perform_dig()
			dig_timer = dig_cooldown
			
			# 播放攻击动画
			if animated_sprite and not is_digging:
				is_digging = true
				animated_sprite.play("attacking")
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
				animated_sprite.play("attacking")
				# 创建一个计时器来结束挖掘动画
				var timer = get_tree().create_timer(0.5)
				timer.timeout.connect(_on_dig_animation_finished)

func perform_dig():
	# 向下挖掘
	var dig_position = global_position + Vector2(0, dig_range)
	attempt_dig(dig_position)

func perform_forward_dig():
	# 向前挖掘
	var dig_position = global_position + Vector2(facing_direction * dig_range, 0)
	attempt_dig(dig_position)

func attempt_dig(world_position):
	# 尝试在指定位置挖掘
	var mine_scene = get_parent()
	if mine_scene and mine_scene.has_method("dig_tile"):
		var success = mine_scene.dig_tile(world_position)
		if success:
			# 挖掘成功的视觉/音效反馈
			print("挖掘成功！")
		else:
			print("无法挖掘此位置")

func _on_dig_animation_finished():
	# 挖掘动画结束
	is_digging = false
	if is_on_floor():
		if velocity.x != 0:
			animated_sprite.play("walking")
		else:
			animated_sprite.play("idle")

func take_damage(amount):
	# 受伤
	var game_manager = get_node("/root/GameManager")
	if game_manager:
		game_manager.damage_player(amount)
	
	# 播放受伤动画
	if animated_sprite:
		animated_sprite.play("hurt")
		animated_sprite.animation_finished.connect(_on_hurt_animation_finished, CONNECT_ONE_SHOT)

func _on_hurt_animation_finished():
	# 受伤动画结束，返回正常状态
	if is_on_floor():
		if velocity.x != 0:
			animated_sprite.play("walking")
		else:
			animated_sprite.play("idle")

func die():
	# 死亡
	if animated_sprite:
		animated_sprite.play("dying")
		# 禁用控制
		set_physics_process(false)
