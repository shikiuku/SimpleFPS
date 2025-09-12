extends Control

# **シンプルモバイルUI v1.0.0 - ジョイスティックと視点移動のみ**

signal move_input(input: Vector2)
signal view_input(relative: Vector2)
signal shoot_pressed
signal jump_pressed

# ジョイスティック関連
@onready var joystick_visual = $JoystickVisual
@onready var joystick_base = $JoystickVisual/Base
@onready var joystick_knob = $JoystickVisual/Knob

# ボタン関連
@onready var shoot_button = $ShootButton
@onready var jump_button = $JumpButton

# タッチ管理
var active_touches = {}  # touch_id -> touch_data

# 定数
const JOYSTICK_MAX_DISTANCE = 60.0

func _ready():
	print("Simple Mobile UI - ジョイスティック、視点移動、ボタン付き")
	
	# ジョイスティック非表示
	if joystick_visual:
		joystick_visual.visible = false
	
	# ボタンのシグナル接続
	if shoot_button:
		shoot_button.pressed.connect(_on_shoot_button_pressed)
	if jump_button:
		jump_button.pressed.connect(_on_jump_button_pressed)
	
	print("Simple Mobile UI ready!")

# **シンプルなタッチ処理**
func _input(event):
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	
	var screen_size = get_viewport().get_visible_rect().size
	var touch_pos = event.position
	var touch_id = event.index
	
	# **シンプルな画面分割: 左50% = ジョイスティック、右50% = 視点**
	var is_left_side = touch_pos.x < screen_size.x * 0.5
	
	print("TOUCH: ID=", touch_id, " Pos=", touch_pos, " Side=", "LEFT" if is_left_side else "RIGHT")
	
	# タッチ開始
	if event is InputEventScreenTouch and event.pressed:
		_handle_touch_start(touch_id, touch_pos, is_left_side)
	
	# タッチ終了
	elif event is InputEventScreenTouch and not event.pressed:
		_handle_touch_end(touch_id)
	
	# ドラッグ
	elif event is InputEventScreenDrag:
		_handle_touch_drag(touch_id, touch_pos, event.relative)

func _handle_touch_start(touch_id: int, pos: Vector2, is_left_side: bool):
	if is_left_side:
		# **左側 = ジョイスティック（1本のみ） - 強制的に既存タッチを削除**
		if _has_joystick_touch():
			print("JOYSTICK: Forcing removal of existing touch")
			_force_remove_joystick_touches()
		
		active_touches[touch_id] = {
			"type": "joystick",
			"center": pos
		}
		_show_joystick_at(pos)
		print("JOYSTICK START: ID=", touch_id)
		
	else:
		# **右側 = 視点操作とボタン操作を区別**
		# ボタン領域かどうかをチェック
		if _is_in_button_area(pos):
			print("BUTTON AREA: Touch ignored in favor of UI buttons")
			return
		
		# **視点（1本のみ） - 強制的に既存タッチを削除**
		if _has_view_touch():
			print("VIEW: Forcing removal of existing touch")
			_force_remove_view_touches()
		
		active_touches[touch_id] = {
			"type": "view",
			"last_pos": pos
		}
		print("VIEW START: ID=", touch_id, " (SINGLE FINGER ENFORCED)")

func _handle_touch_end(touch_id: int):
	if touch_id not in active_touches:
		print("END IGNORED: Unknown ID=", touch_id)
		return
	
	var touch_data = active_touches[touch_id]
	
	if touch_data.type == "joystick":
		_hide_joystick()
		move_input.emit(Vector2.ZERO)
		print("JOYSTICK END: ID=", touch_id)
	
	elif touch_data.type == "view":
		print("VIEW END: ID=", touch_id)
	
	active_touches.erase(touch_id)

func _handle_touch_drag(touch_id: int, pos: Vector2, relative: Vector2):
	if touch_id not in active_touches:
		print("DRAG IGNORED: Unknown ID=", touch_id)
		return
	
	var touch_data = active_touches[touch_id]
	
	if touch_data.type == "joystick":
		_handle_joystick_drag(pos, touch_data.center)
		
	elif touch_data.type == "view":
		_handle_view_drag(relative)

# **ジョイスティック処理**
func _show_joystick_at(pos: Vector2):
	if not joystick_visual or not joystick_base:
		return
	
	joystick_visual.visible = true
	# Panelノードの場合は position を使用
	joystick_base.position = pos - joystick_base.size / 2

func _hide_joystick():
	if joystick_visual:
		joystick_visual.visible = false

func _handle_joystick_drag(current_pos: Vector2, center: Vector2):
	var offset = current_pos - center
	var distance = offset.length()
	
	if distance > JOYSTICK_MAX_DISTANCE:
		offset = offset.normalized() * JOYSTICK_MAX_DISTANCE
	
	# ノブ位置更新
	if joystick_knob:
		joystick_knob.global_position = center + offset - joystick_knob.size / 2
	
	# 移動入力送信
	var input_vector = offset / JOYSTICK_MAX_DISTANCE
	move_input.emit(input_vector)
	print("JOYSTICK: ", input_vector)

# **視点処理**
func _handle_view_drag(relative: Vector2):
	var view_input_vector = relative * 2.0  # 感度を4倍に上げる（0.5→2.0）
	view_input.emit(view_input_vector)
	print("VIEW: ", view_input_vector)

# **ヘルパー関数**
func _has_joystick_touch() -> bool:
	for touch_id in active_touches:
		if active_touches[touch_id].type == "joystick":
			return true
	return false

func _has_view_touch() -> bool:
	for touch_id in active_touches:
		if active_touches[touch_id].type == "view":
			return true
	return false

# **強制削除関数**
func _force_remove_joystick_touches():
	var to_remove = []
	for touch_id in active_touches:
		if active_touches[touch_id].type == "joystick":
			to_remove.append(touch_id)
	
	for touch_id in to_remove:
		print("FORCE REMOVE JOYSTICK: ID=", touch_id)
		active_touches.erase(touch_id)
	
	_hide_joystick()
	move_input.emit(Vector2.ZERO)

func _force_remove_view_touches():
	var to_remove = []
	for touch_id in active_touches:
		if active_touches[touch_id].type == "view":
			to_remove.append(touch_id)
	
	for touch_id in to_remove:
		print("FORCE REMOVE VIEW: ID=", touch_id)
		active_touches.erase(touch_id)

# **ボタン処理**
func _on_shoot_button_pressed():
	print("SHOOT button pressed!")
	shoot_pressed.emit()

func _on_jump_button_pressed():
	print("JUMP button pressed!")
	jump_pressed.emit()

# **ボタン領域チェック**
func _is_in_button_area(pos: Vector2) -> bool:
	if not shoot_button or not jump_button:
		return false
	
	# ボタンのグローバル位置とサイズを取得
	var shoot_rect = Rect2(shoot_button.global_position, shoot_button.size)
	var jump_rect = Rect2(jump_button.global_position, jump_button.size)
	
	# 少し余裕を持たせる（20ピクセル）
	var margin = 20
	shoot_rect = shoot_rect.grow(margin)
	jump_rect = jump_rect.grow(margin)
	
	return shoot_rect.has_point(pos) or jump_rect.has_point(pos)

# **緊急リセット**
func _notification(what):
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		print("=== EMERGENCY RESET ===")
		active_touches.clear()
		_hide_joystick()
		move_input.emit(Vector2.ZERO)
