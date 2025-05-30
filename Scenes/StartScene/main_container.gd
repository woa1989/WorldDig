extends VBoxContainer

@onready var StartBtn:Button = $StartButton
@onready var QuitBtn:Button = $QuitButton

func _ready() -> void:
	StartBtn.pressed.connect(_on_start_btn_pressed)
	QuitBtn.pressed.connect(_on_quit_btn_pressed)

func _on_start_btn_pressed() -> void:
	print("start")

func _on_quit_btn_pressed() -> void:
	get_tree().quit()
