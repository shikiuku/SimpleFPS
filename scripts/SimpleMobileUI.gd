extends Control

# **シンプルモバイルUI v2.0.0 - 3エリア分割設計**

signal move_input(input: Vector2)
signal view_input(relative: Vector2)
signal shoot_pressed
signal jump_pressed
signal dash_pressed

# ジョイスティック関連
@onready var joystick_visual = $JoystickVisual
@onready var joystick_base = $JoystickVisual/Base
@onready var joystick_knob = $JoystickVisual/Knob

# ボタン関連
@onready var shoot_button = $ShootButton
@onready var jump_button = $JumpButton
@onready var dash_button = $DashButton

# タッチ管理
var active_touches = {}  # touch_id -> touch_data

# ボタンクールダウン管理（重複防止）
var button_cooldown = {}
const BUTTON_COOLDOWN_TIME = 0.05  # 50msクールダウン

# 定数 - 3エリア分割
const JOYSTICK_AREA_RATIO = 0.4  # 左40%
const VIEW_AREA_RATIO = 0.2      # 中央20%
const BUTTON_AREA_RATIO = 0.4    # 右40%
const JOYSTICK_MAX_DISTANCE = 60.0

func _ready():
	print("Simple Mobile UI - ジョイスティック、視点移動、ボタン付き")
	
	# ジョイスティック非表示
	if joystick_visual:
		joystick_visual.visible = false
	
	# ボタンのシグナル接続（即座反応のためbutton_downを使用）
	if shoot_button:
		shoot_button.button_down.connect(_on_shoot_button_down)
		print("Shoot button connected to button_down signal")
	if jump_button:
		jump_button.button_down.connect(_on_jump_button_down)
		print("Jump button connected to button_down signal")
	if dash_button:
		dash_button.button_down.connect(_on_dash_button_down)
		print("Dash button connected to button_down signal")
	
	print("Simple Mobile UI ready!")

# **3エリア分割タッチ処理 - 明確なエリア分け**
func _input(event):
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	
	var screen_size = get_viewport().get_visible_rect().size
	var touch_pos = event.position
	var touch_id = event.index
	
	# **3つのエリアを判定**
	var area_type = _get_touch_area(touch_pos, screen_size)
	
	print("TOUCH EVENT: ID=", touch_id, " Pos=", touch_pos, " Area=", area_type)
	
	# **ボタンエリアのタッチは完全にボタンに任せる**
	if area_type == "button":
		print("BUTTON AREA: Letting buttons handle touch ID=", touch_id)
		return  # イベント消費せず、ボタンに任せる
	
	# **ジョイスティック・視点エリアのタッチを処理**
	if event is InputEventScreenTouch and event.pressed:
		_handle_touch_start(touch_id, touch_pos, area_type)
		get_viewport().set_input_as_handled()
	
	elif event is InputEventScreenTouch and not event.pressed:
		_handle_touch_end(touch_id)
		get_viewport().set_input_as_handled()
	
	elif event is InputEventScreenDrag:
		_handle_touch_drag(touch_id, touch_pos, event.relative)
		get_viewport().set_input_as_handled()

# **3エリア判定関数**
func _get_touch_area(pos: Vector2, screen_size: Vector2) -> String:
	var joystick_boundary = screen_size.x * JOYSTICK_AREA_RATIO
	var view_boundary = screen_size.x * (JOYSTICK_AREA_RATIO + VIEW_AREA_RATIO)
	
	if pos.x < joystick_boundary:
		return "joystick"
	elif pos.x < view_boundary:
		return "view"
	else:
		return "button"

func _handle_touch_start(touch_id: int, pos: Vector2, area_type: String):
	if area_type == "joystick":
		# **ジョイスティックエリア（1本のみ）**
		if _has_joystick_touch():
			print("JOYSTICK: Already active, ignoring touch ID=", touch_id)
			return
		
		active_touches[touch_id] = {
			"type": "joystick",
			"center": pos
		}
		_show_joystick_at(pos)
		print("JOYSTICK START: ID=", touch_id)
		
	elif area_type == "view":
		# **視点操作エリア（1本のみ）**
		if _has_view_touch():
			print("VIEW: Already active, ignoring touch ID=", touch_id)
			return
		
		active_touches[touch_id] = {
			"type": "view",
			"last_pos": pos
		}
		print("VIEW START: ID=", touch_id)

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

func _handle_touch_drag(touch_id: int, pos: Vector2, _relative: Vector2):
	if touch_id not in active_touches:
		print("DRAG IGNORED: Unknown ID=", touch_id)
		return
	
	var touch_data = active_touches[touch_id]
	
	if touch_data.type == "joystick":
		_handle_joystick_drag(pos, touch_data.center)
		
	elif touch_data.type == "view":
		# 絶対座標で安全な視点計算
		_handle_view_drag(pos, touch_data)

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

# **視点処理 - 絶対座標ベースで相対移動を安全に計算**
func _handle_view_drag(current_pos: Vector2, touch_data: Dictionary):
	# 前回の位置との差を計算（相対座標を使わない）
	var last_pos = touch_data.last_pos
	var delta = current_pos - last_pos
	
	# 異常な移動量をフィルタリング（ジャンプ防止）
	var max_delta = 50.0  # 1フレームでの最大移動量
	if delta.length() > max_delta:
		print("VIEW: Abnormal delta detected, ignoring: ", delta)
		# 座標だけ更新して、視点変更はスキップ
		touch_data.last_pos = current_pos
		return
	
	# 通常の視点変更処理
	var view_input_vector = delta * 2.0  # 感度
	view_input.emit(view_input_vector)
	
	# 座標を更新
	touch_data.last_pos = current_pos
	print("VIEW: ", view_input_vector, " Delta: ", delta)

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

# **強制削除関数は削除 - 代わりにタッチを無視する方式に変更**

# **ボタン処理 - 即座反応 + クールダウン制御**
func _on_shoot_button_down():
	if _is_button_on_cooldown("shoot"):
		return
	
	print("SHOOT button down - IMMEDIATE RESPONSE!")
	shoot_pressed.emit()
	_set_button_cooldown("shoot")

func _on_jump_button_down():
	if _is_button_on_cooldown("jump"):
		return
	
	print("JUMP button down - IMMEDIATE RESPONSE!")
	jump_pressed.emit()
	_set_button_cooldown("jump")

func _on_dash_button_down():
	if _is_button_on_cooldown("dash"):
		return
	
	print("DASH button down - IMMEDIATE RESPONSE!")
	dash_pressed.emit()
	_set_button_cooldown("dash")

# クールダウン管理
func _is_button_on_cooldown(button_name: String) -> bool:
	if button_name in button_cooldown:
		var elapsed = Time.get_ticks_msec() / 1000.0 - button_cooldown[button_name]
		if elapsed < BUTTON_COOLDOWN_TIME:
			print("Button ", button_name, " on cooldown (", elapsed, "s)")
			return true
		else:
			button_cooldown.erase(button_name)
	return false

func _set_button_cooldown(button_name: String):
	button_cooldown[button_name] = Time.get_ticks_msec() / 1000.0

# **古いボタン領域チェック関数は削除 - 新しい3エリア分割システムを使用**

# **緊急リセット**
func _notification(what):
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		print("=== EMERGENCY RESET ===")
		active_touches.clear()
		_hide_joystick()
		move_input.emit(Vector2.ZERO)
