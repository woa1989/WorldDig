extends CharacterBody2D

# 简化版玩家控制脚本
# 只处理左右移动和跳跃

@onready var animated_sprite = $AnimatedSprite2D

# 移动相关变量
var speed = 300.0
var jump_velocity = -400.0
var gravity = 980.0

# 状态变量
var facing_direction = 1 # 1为右，-1为左

# 初始化函数
func _ready():
	# 设置碰撞层和碰撞掩码
	# collision_layer = 1  # 玩家在第1层
	collision_mask = 16   # 玩家可以与第16层（地面）碰撞
	
	# 设置初始动画
	if animated_sprite:
		animated_sprite.play("Idle")

func _physics_process(delta):
	# 添加重力
	if not is_on_floor():
		velocity.y += gravity * delta

	# 处理跳跃
	handle_jump()
	
	# 处理左右移动
	handle_movement()

	# 应用移动
	move_and_slide()
	
	# 更新动画
	update_animation()

# 处理跳跃逻辑
func handle_jump():
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

# 处理左右移动逻辑
func handle_movement():
	var direction = Input.get_axis("left", "right")
	
	if direction != 0:
		# 设置水平速度
		velocity.x = direction * speed
		
		# 更新面向方向
		facing_direction = direction
		
		# 翻转精灵
		if animated_sprite:
			animated_sprite.flip_h = (facing_direction < 0)
	else:
		# 没有输入时停止水平移动
		velocity.x = move_toward(velocity.x, 0, speed)

# 更新动画状态
func update_animation():
	if not animated_sprite:
		return
	
	# 在地面上时根据移动状态选择动画
	if is_on_floor():
		if abs(velocity.x) > 10.0: # 如果在移动
			if animated_sprite.animation != "Walk":
				animated_sprite.play("Walk")
		else: # 如果静止
			if animated_sprite.animation != "Idle":
				animated_sprite.play("Idle")