extends CharacterBody2D


enum State {
	WALKING,
	DEAD
}

const WALK_SPEED = 122.0
const SHOOT_INTERVAL = 2.0 # 射击间隔2秒
var _state := State.WALKING
var _shoot_timer := 0.0 # 射击计时器

# 敌人属性
var max_health = 3 # 最大生命值
var current_health = 3 # 当前生命值


@onready var gravity: int = ProjectSettings.get("physics/2d/default_gravity")
@onready var platform_detector := $PlatformDetector as RayCast2D
@onready var floor_detector_left := $FloorDetectorLeft as RayCast2D
@onready var floor_detector_right := $FloorDetectorRight as RayCast2D
@onready var sprite := $Sprite2D as Sprite2D
@onready var animation_player := $AnimationPlayer as AnimationPlayer
@onready var gun := $Sprite2D/Gun # 获取枪械节点引用
@onready var health_bar := $Sprite2D/HealthBar as ProgressBar # 获取血量条引用

func _ready():
	# 初始化敌人
	current_health = max_health
	# 初始化血量条
	update_health_bar()
	print("[DEBUG] 敌人初始化完成，生命值: ", current_health)


func _physics_process(delta: float) -> void:
	if _state == State.WALKING and velocity.is_zero_approx():
		velocity.x = WALK_SPEED

	velocity.y += gravity * delta

	# 悬崖检测逻辑优化
	if not floor_detector_left.is_colliding():
		velocity.x = abs(WALK_SPEED)
	elif not floor_detector_right.is_colliding():
		velocity.x = - abs(WALK_SPEED)

	# 墙壁检测逻辑：敌人collision_mask现在只包含环境层，所以is_on_wall()只会在碰到墙壁时触发
	if is_on_wall():
		print("[DEBUG] 敌人检测到墙壁，掉头")
		velocity.x = - velocity.x

	move_and_slide()

	if velocity.x > 0.0:
		sprite.scale.x = 3.0
	elif velocity.x < 0.0:
		sprite.scale.x = -3.0

	# 射击逻辑
	if _state == State.WALKING:
		_shoot_timer += delta
		if _shoot_timer >= SHOOT_INTERVAL:
			_shoot_timer = 0.0
			# 根据敌人朝向确定射击方向
			var shoot_direction = 1.0 if velocity.x > 0.0 else -1.0
			gun.shoot(shoot_direction)

	var animation := get_new_animation()
	if animation != animation_player.current_animation:
		animation_player.play(animation)


# 受到伤害函数
func take_damage(damage, attacker = null):
	print("[DEBUG] 敌人受到攻击 - 伤害: ", damage, ", 攻击者: ", attacker)
	
	# 如果已经死亡，不再受伤害
	if _state == State.DEAD:
		print("[DEBUG] 敌人已死亡，忽略伤害")
		return
	
	# 应用伤害
	current_health -= damage
	current_health = max(0, current_health)
	update_health_bar() # 更新血量条显示
	print("[DEBUG] 敌人当前生命值: ", current_health)
	
	# 检查是否死亡
	if current_health <= 0:
		print("[DEBUG] 敌人死亡")
		destroy()

func destroy() -> void:
	_state = State.DEAD
	velocity = Vector2.ZERO
	print("[DEBUG] 敌人开始死亡流程")
	
	# 播放死亡动画
	animation_player.play("destory")
	
	# 等待动画播放完毕后销毁敌人
	await animation_player.animation_finished
	print("[DEBUG] 敌人死亡动画播放完毕，准备销毁")
	queue_free()

# 更新血量条显示
func update_health_bar():
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		# 根据血量百分比改变颜色
		var health_percent = float(current_health) / float(max_health)
		if health_percent > 0.6:
			health_bar.modulate = Color.GREEN
		elif health_percent > 0.3:
			health_bar.modulate = Color.YELLOW
		else:
			health_bar.modulate = Color.RED


func get_new_animation() -> StringName:
	var animation_new: StringName
	if _state == State.WALKING:
		if velocity.x == 0:
			animation_new = &"idle"
		else:
			animation_new = &"walk"
	else:
		animation_new = &"destory"
	return animation_new
