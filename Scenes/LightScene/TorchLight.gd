extends Node2D

@onready var point_light: PointLight2D = $PointLight2D
@onready var sprite: Sprite2D = $Sprite2D

var flicker_timer = 0.0
var base_energy = 1.0
var flicker_intensity = 0.2

func _ready():
	setup_torch_light()

func setup_torch_light():
	"""设置火把光源属性"""
	if point_light:
		point_light.energy = base_energy
		point_light.texture_scale = 1.5
		point_light.color = Color(1.0, 0.7, 0.3, 1) # 温暖的橙色光
		
		# 设置光源范围
		if point_light.texture:
			point_light.texture_scale = 2.0

func _process(delta):
	"""添加火把闪烁效果"""
	if point_light:
		flicker_timer += delta * 8.0 # 闪烁速度
		
		# 使用正弦波创建自然的闪烁效果
		var flicker = sin(flicker_timer) * flicker_intensity
		point_light.energy = base_energy + flicker
		
		# 轻微的颜色变化
		var color_variation = sin(flicker_timer * 1.3) * 0.1
		point_light.color = Color(1.0, 0.7 + color_variation, 0.3, 1)
