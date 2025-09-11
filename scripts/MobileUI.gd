extends CanvasLayer

signal move_input(direction: Vector2)
signal look_input(delta: Vector2)
signal shoot_pressed
signal jump_pressed

@onready var joystick_visual = $JoystickVisual
@onready var shoot_button = $ShootButton
@onready var jump_button = $JumpButton

# アナログスティック
@onready var joystick_base = $JoystickVisual/JoystickBase
@onready var joystick_knob = $JoystickVisual/JoystickBase/JoystickKnob

# **プロ仕様：厳密な領域分離システム**
var joystick_touch_id = -1  # 左領域専用
var view_touch_id = -1      # 右領域専用

# ジョイスティック設定
var joystick_center = Vector2.ZERO
var joystick_radius = 50.0
var joystick_dead_zone = 8.0
var joystick_knob_size = Vector2(30, 30)

# 視点操作設定
var look_sensitivity = 0.003

func _ready():
	print("=== MobileUI PRO ZONE SYSTEM INITIALIZED ===")
	
	# ボタン接続（シンプル）
	if shoot_button:
		shoot_button.pressed.connect(_on_shoot_pressed)
	if jump_button:
		jump_button.pressed.connect(_on_jump_pressed)
	
	# ジョイスティック初期化
	if joystick_base and joystick_knob:
		joystick_visual.visible = false
		_reset_joystick_knob()
	
	print("Pro zone system ready!")

# **メインタッチハンドラー：完全統一管理**
func _input(event):
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	
	# **即座にイベント消費** - 最優先
	get_viewport().set_input_as_handled()
	
	var screen_size = get_viewport().get_visible_rect().size
	var touch_pos = event.position
	
	# **厳密な画面分割**
	var is_left_zone = touch_pos.x < screen_size.x * 0.5   # 左50%：移動専用
	var is_right_zone = touch_pos.x >= screen_size.x * 0.5  # 右50%：視点専用
	
	# **タッチ開始処理**
	if event is InputEventScreenTouch and event.pressed:
		print("=== UNIFIED TOUCH START ===")
		print("ID: ", event.index, " Pos: ", touch_pos, " Left: ", is_left_zone, " Right: ", is_right_zone)
		
		# ボタン領域チェック（右下領域）
		if _is_button_area(touch_pos, screen_size):
			print("BUTTON AREA: Touch in button zone")
			_handle_button_touch(touch_pos)
			return
		
		# 左領域：移動ジョイスティック専用
		if is_left_zone and joystick_touch_id == -1:
			joystick_touch_id = event.index
			joystick_center = touch_pos
			_show_joystick_at_position(touch_pos)
			print("JOYSTICK ZONE: Started ID ", event.index)
		
		# 右領域：視点操作専用（ボタン領域除く）
		elif is_right_zone and view_touch_id == -1:
			view_touch_id = event.index
			print("VIEW ZONE: Started ID ", event.index)
		
		else:
			print("ZONE BLOCKED: Left occupied=", joystick_touch_id != -1, " Right occupied=", view_touch_id != -1)
	
	# **タッチ終了処理**
	elif event is InputEventScreenTouch and not event.pressed:
		print("=== UNIFIED TOUCH END ===")
		
		# 自分の担当領域かチェック
		if event.index == joystick_touch_id:
			joystick_touch_id = -1
			_hide_joystick()
			move_input.emit(Vector2.ZERO)
			print("JOYSTICK ZONE: Ended ID ", event.index)
		elif event.index == view_touch_id:
			view_touch_id = -1
			print("VIEW ZONE: Ended ID ", event.index)
		else:
			print("IGNORED: Unknown touch end ID ", event.index)
	
	# **ドラッグ処理**
	elif event is InputEventScreenDrag:
		var current_is_left = event.position.x < screen_size.x * 0.5
		var current_is_right = event.position.x >= screen_size.x * 0.5
		
		# ジョイスティックドラッグ（左領域内の自分のタッチのみ）
		if event.index == joystick_touch_id and current_is_left:
			_handle_joystick_drag(event.position)
		
		# 視点操作ドラッグ（右領域内の自分のタッチのみ）
		elif event.index == view_touch_id and current_is_right:
			_handle_view_drag(event.relative)
		
		else:
			# 領域違反や無効なドラッグは完全無視
			print("ZONE VIOLATION: Ignored drag ID ", event.index)

# **ボタン領域判定**
func _is_button_area(pos: Vector2, screen_size: Vector2) -> bool:
	# 右下コーナーの140x120エリア
	var button_area = Rect2(screen_size.x - 150, screen_size.y - 120, 150, 120)
	return button_area.has_point(pos)

# **ボタンタッチ処理**
func _handle_button_touch(pos: Vector2):
	# SHOOTボタン領域（右下）
	if shoot_button and shoot_button.get_global_rect().has_point(pos):
		print("BUTTON: Shoot pressed")
		shoot_pressed.emit()
	# JUMPボタン領域（右上）
	elif jump_button and jump_button.get_global_rect().has_point(pos):
		print("BUTTON: Jump pressed") 
		jump_pressed.emit()

# **ジョイスティック表示**
func _show_joystick_at_position(pos: Vector2):
	if joystick_visual:
		joystick_visual.position = pos - Vector2(joystick_radius, joystick_radius)
		joystick_visual.visible = true
		_reset_joystick_knob()

# **ジョイスティック非表示**
func _hide_joystick():
	if joystick_visual:
		joystick_visual.visible = false

# **ジョイスティックドラッグ処理**
func _handle_joystick_drag(touch_pos: Vector2):
	var offset = touch_pos - joystick_center
	var distance = offset.length()
	
	if distance > joystick_radius:
		offset = offset.normalized() * joystick_radius
	
	var input_vector = Vector2.ZERO
	if distance > joystick_dead_zone:
		input_vector = offset / joystick_radius
	
	move_input.emit(input_vector)
	_update_joystick_visual(offset)
	print("JOYSTICK: Input ", input_vector)

# **視点操作ドラッグ処理**
func _handle_view_drag(relative_movement: Vector2):
	var look_delta = relative_movement * look_sensitivity
	look_input.emit(look_delta)
	print("VIEW: Delta ", look_delta)

# **ジョイスティック表示更新**
func _update_joystick_visual(offset: Vector2):
	if joystick_knob and joystick_base:
		var base_center = joystick_base.size / 2
		var knob_pos = base_center + offset - joystick_knob_size / 2
		joystick_knob.position = knob_pos

# **ジョイスティックノブリセット**
func _reset_joystick_knob():
	if joystick_knob and joystick_base:
		var base_center = joystick_base.size / 2
		joystick_knob.position = base_center - joystick_knob_size / 2

# **ボタンハンドラー**
func _on_shoot_pressed():
	print("Shoot button pressed")
	shoot_pressed.emit()

func _on_jump_pressed():
	print("Jump button pressed")
	jump_pressed.emit()

# **緊急リセット機能**
func _notification(what):
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		print("=== FOCUS LOST: EMERGENCY RESET ===")
		joystick_touch_id = -1
		view_touch_id = -1
		_hide_joystick()
		move_input.emit(Vector2.ZERO)