extends CanvasLayer

signal move_input(direction: Vector2)
signal look_input(delta: Vector2)
signal shoot_pressed
signal jump_pressed

@onready var movement_area = $MovementArea
@onready var view_area = $ViewArea
@onready var joystick_visual = $JoystickVisual
@onready var shoot_button = $ShootButton
@onready var jump_button = $JumpButton

var movement_touch_index = -1
var view_touch_index = -1
var movement_start_pos = Vector2.ZERO
var last_view_pos = Vector2.ZERO

var joystick_radius = 60.0
var joystick_dead_zone = 10.0

func _is_mobile() -> bool:
	# モバイル環境の判定（Web版でもタッチ対応デバイスなら表示）
	return OS.get_name() == "Android" or OS.get_name() == "iOS" or OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()

func setup_touch_buttons():
	# 移動ジョイスティックエリア
	movement_area.gui_input.connect(_on_movement_area_input)
	
	# 視点操作エリア
	view_area.gui_input.connect(_on_view_area_input)
	
	# ボタンシグナルを接続
	shoot_button.pressed.connect(_on_shoot_button_pressed)
	jump_button.pressed.connect(_on_jump_button_pressed)
	
	# ボタンの見た目を設定
	_setup_button_visuals()

func _on_shoot_button_pressed():
	shoot_pressed.emit()

func _on_jump_button_pressed():
	jump_pressed.emit()

func _setup_button_visuals():
	# 射撃ボタンの見た目
	var shoot_stylebox = StyleBoxFlat.new()
	shoot_stylebox.bg_color = Color(1, 0, 0, 0.5)  # 半透明の赤
	shoot_stylebox.corner_radius_top_left = 30
	shoot_stylebox.corner_radius_top_right = 30
	shoot_stylebox.corner_radius_bottom_left = 30
	shoot_stylebox.corner_radius_bottom_right = 30
	
	# ジャンプボタンの見た目
	var jump_stylebox = StyleBoxFlat.new()
	jump_stylebox.bg_color = Color(0, 1, 0, 0.5)  # 半透明の緑
	jump_stylebox.corner_radius_top_left = 30
	jump_stylebox.corner_radius_top_right = 30
	jump_stylebox.corner_radius_bottom_left = 30
	jump_stylebox.corner_radius_bottom_right = 30

func _on_movement_area_input(event: InputEvent):
	if event is InputEventScreenTouch:
		if event.pressed and movement_touch_index == -1:
			# タッチ開始
			movement_touch_index = event.index
			movement_start_pos = event.position
			print("Movement touch started at: ", event.position)
		elif not event.pressed and event.index == movement_touch_index:
			# タッチ終了
			movement_touch_index = -1
			move_input.emit(Vector2.ZERO)
			print("Movement touch ended")
	
	elif event is InputEventScreenDrag and event.index == movement_touch_index:
		# ドラッグ中
		var delta = event.position - movement_start_pos
		var distance = delta.length()
		
		if distance > joystick_dead_zone:
			var direction = delta.normalized()
			var strength = min(distance / joystick_radius, 1.0)
			move_input.emit(direction * strength)

func _on_view_area_input(event: InputEvent):
	if event is InputEventScreenTouch:
		if event.pressed and view_touch_index == -1:
			# 視点操作開始
			view_touch_index = event.index
			last_view_pos = event.position
			print("View touch started at: ", event.position)
		elif not event.pressed and event.index == view_touch_index:
			# 視点操作終了
			view_touch_index = -1
			print("View touch ended")
	
	elif event is InputEventScreenDrag and event.index == view_touch_index:
		# ドラッグ中
		var delta = event.position - last_view_pos
		last_view_pos = event.position
		look_input.emit(delta * 0.002)  # マウス感度と同様

func _ready():
	# モバイルかどうか判定
	if not _is_mobile():
		visible = false
		return
	
	# TouchScreenButtonの設定
	setup_touch_buttons()
	
	# ジョイスティック表示用の描画設定
	joystick_visual.custom_minimum_size = Vector2(160, 160)
	
	print("Mobile UI initialized")