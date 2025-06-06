extends Area2D

# 子弹伤害值
var damage = 1

@onready var animation_player := $AnimationPlayer as AnimationPlayer

func _ready():
	# 连接碰撞信号
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	# 获取子弹速度并移动
	if has_meta("velocity"):
		var velocity = get_meta("velocity")
		global_position += velocity * delta

func _on_body_entered(body):
	# 检查子弹是否被反弹
	var is_reflected = has_meta("reflected") and get_meta("reflected")
	
	# 检测碰撞目标
	if body.has_method("take_damage"):
		# 如果子弹被反弹，只伤害敌人；否则只伤害玩家
		if is_reflected:
			# 反弹的子弹：检查是否为敌人
			if body.get_script() and body.get_script().get_path().ends_with("enemy.gd"):
				print("[DEBUG] 反弹子弹击中敌人")
				body.take_damage(damage * 2, self) # 反弹子弹造成双倍伤害
				destroy()
			else:
				print("[DEBUG] 反弹子弹击中非敌人目标，忽略")
		else:
			# 普通子弹：检查是否为玩家
			if body.get_script() and body.get_script().get_path().ends_with("player.gd"):
				print("[DEBUG] 普通子弹击中玩家")
				body.take_damage(damage, self)
				destroy()
			else:
				print("[DEBUG] 普通子弹击中非玩家目标，忽略")

func destroy() -> void:
	animation_player.play(&"destory")
