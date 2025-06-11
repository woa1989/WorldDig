class_name PlayerHealth
extends Node

# 血量系统管理
signal health_changed(new_health: int, max_health: int)
signal died

var max_health = 3
var current_health = 3
var health_bar_show_timer = 0.0
var health_bar_show_duration = 3.0
var is_invulnerable = false
var invulnerability_timer = 0
var invulnerability_duration = 600 # 毫秒

@onready var health_bar = get_parent().get_node("HealthBar")
@onready var animated_sprite = get_parent().get_node("AnimatedSprite2D")

func _ready():
	update_health_bar()

func _process(delta):
	# 处理无敌时间
	if is_invulnerable:
		invulnerability_timer += delta * 1000
		if invulnerability_timer >= invulnerability_duration:
			end_invulnerability()
		else:
			# 闪烁效果
			update_blink_effect()
	
	# 处理血条显示逻辑
	handle_health_bar_display()

func take_damage(damage: int) -> bool:
	"""接受伤害，返回是否成功受伤"""
	if is_invulnerable:
		print("[DEBUG] 💫 无敌状态，免疫伤害")
		return false
	
	current_health -= damage
	current_health = max(0, current_health)
	
	# 发送血量变化信号
	health_changed.emit(current_health, max_health)
	
	# 更新血条并显示
	update_health_bar()
	show_health_bar()
	
	# 设置无敌状态
	start_invulnerability()
	
	# 播放受伤动画
	play_hurt_animation()
	
	# 检查是否死亡
	if current_health <= 0:
		die()
		return true
	
	return true

func heal(amount: int):
	"""治疗"""
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)
	update_health_bar()
	show_health_bar()

func start_invulnerability():
	"""开始无敌状态"""
	is_invulnerable = true
	invulnerability_timer = 0
	print("[DEBUG] 💫 开始无敌状态")

func end_invulnerability():
	"""结束无敌状态"""
	is_invulnerable = false
	invulnerability_timer = 0
	set_shader_blink_intensity(0.0)
	print("[DEBUG] 💫 无敌状态结束")

func update_blink_effect():
	"""更新闪烁效果"""
	if int(invulnerability_timer / 100) % 2 == 0:
		set_shader_blink_intensity(0.8)
	else:
		set_shader_blink_intensity(0.0)

func set_shader_blink_intensity(intensity: float):
	"""设置闪烁强度"""
	if animated_sprite and animated_sprite.material:
		animated_sprite.material.set_shader_parameter("blink_intensity", intensity)

func update_health_bar():
	"""更新血条显示"""
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		# 设置血条颜色
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color.RED
		health_bar.add_theme_stylebox_override("fill", style_box)

func show_health_bar():
	"""显示血条"""
	health_bar_show_timer = 0.0
	if health_bar:
		health_bar.visible = true

func handle_health_bar_display():
	"""处理血条显示逻辑"""
	if health_bar:
		# 血量不足时持续显示
		if current_health < max_health:
			health_bar.visible = true
		else:
			# 满血时显示一段时间后隐藏
			health_bar_show_timer += get_process_delta_time()
			if health_bar_show_timer >= health_bar_show_duration:
				health_bar.visible = false

func play_hurt_animation():
	"""播放受伤动画"""
	var player = get_parent()
	if player.has_method("play_anim"):
		player.play_anim("Hurt")
		# 连接动画完成信号
		if animated_sprite and not animated_sprite.animation_finished.is_connected(_on_hurt_animation_finished):
			animated_sprite.animation_finished.connect(_on_hurt_animation_finished, CONNECT_ONE_SHOT)

func _on_hurt_animation_finished():
	"""受伤动画完成"""
	var player = get_parent()
	if player.is_on_floor():
		if abs(player.velocity.x) > 50.0:
			player.play_anim("Walk")
		else:
			player.play_anim("Idle")

func die():
	"""玩家死亡"""
	print("[DEBUG] 💀 玩家死亡")
	died.emit()
	
	var player = get_parent()
	if player.has_method("play_anim"):
		player.play_anim("Dying")
	
	# 禁用物理处理
	player.set_physics_process(false)
