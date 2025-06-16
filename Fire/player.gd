extends CharacterBody2D

# 移动参数
const SPEED = 400.0
const JUMP_VELOCITY = -450.0

# 获取重力值
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var animated_sprite = $body

func _physics_process(delta):
	# 添加重力
	if not is_on_floor():
		velocity.y += gravity * delta

	# 处理跳跃
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# 处理左右移动
	var direction = Input.get_axis("left", "right")
	if direction != 0:
		velocity.x = direction * SPEED
		# 翻转精灵朝向
		animated_sprite.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# 更新动画
	update_animation()
	
	# 应用移动
	move_and_slide()

func update_animation():
	if not is_on_floor():
		animated_sprite.play("jump")
	elif velocity.x != 0:
		animated_sprite.play("run")
	else:
		animated_sprite.play("idle")
