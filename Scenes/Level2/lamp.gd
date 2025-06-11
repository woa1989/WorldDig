extends CharacterBody2D

# 移动速度
const SPEED = 800.0

# 处理物理移动
func _physics_process(_delta):
	# 获取输入向量
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_axis("left", "right")
	input_vector.y = Input.get_axis("up", "down")
	
	# 归一化输入向量，确保对角线移动速度一致
	input_vector = input_vector.normalized()
	
	# 设置速度
	velocity = input_vector * SPEED
	
	# 移动并处理碰撞
	move_and_slide()
	
	
