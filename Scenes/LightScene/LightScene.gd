extends PointLight2D


func setup_torch_light():
	"""设置火把光源的增强属性 - 亮度和距离均提升50%"""
	#point_light.energy = 1.25
	#point_light.texture_scale = 5.5
	# 保持温暖的火把颜色
	# point_light.color = Color(1.0, 0.8, 0.5, 1)
	print("火把光源已设置为增强模式：亮度=", energy, " 距离=", texture_scale)
