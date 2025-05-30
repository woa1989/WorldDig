extends Control

# 开始场景脚本
# 处理游戏开始和退出逻辑

func _ready():
	# 连接按钮信号
	$MainContainer/StartButton.pressed.connect(_on_start_button_pressed)
	$MainContainer/QuitButton.pressed.connect(_on_quit_button_pressed)

func _on_start_button_pressed():
	# 切换到城镇场景
	print("开始游戏")
	GameManager.change_scene("res://Scenes/TownScene/TownScene.tscn")

func _on_quit_button_pressed():
	# 退出游戏
	print("退出游戏")
	get_tree().quit()
