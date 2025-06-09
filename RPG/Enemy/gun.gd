extends Marker2D

const BULLET_VELOCITY = 850.0
const BULLET_RANGE = 500.0 # 子弹有效射程
const BULLET_SCEN = preload("res://RPG/Bullet/Bullet.tscn")

@onready var sound_shoot: AudioStreamPlayer2D = $Shoot
@onready var timer: Timer = $Cooldown

func shoot(direction: float = 1.0) -> bool:
	if not timer.is_stopped():
		return false
		
	var bullet = BULLET_SCEN.instantiate()
	bullet.global_position = global_position
	# 为Area2D子弹设置移动方向和速度
	bullet.set_meta("velocity", Vector2(direction * BULLET_VELOCITY, 0.0))
	
	# 计算子弹生命周期，使其在射程范围内自动销毁
	var bullet_lifetime = BULLET_RANGE / BULLET_VELOCITY
	
	bullet.set_as_top_level(true)
	add_child(bullet)
	
	# 设置子弹自动销毁计时器
	var destroy_timer = Timer.new()
	destroy_timer.wait_time = bullet_lifetime
	destroy_timer.one_shot = true
	destroy_timer.timeout.connect(_on_bullet_timeout.bind(bullet))
	bullet.add_child(destroy_timer)
	destroy_timer.start()
	
	# 启动冷却计时器
	timer.start()
	
	sound_shoot.play()
	return true


# 子弹超时回调函数
func _on_bullet_timeout(bullet: Node) -> void:
	if is_instance_valid(bullet):
		bullet.queue_free()
