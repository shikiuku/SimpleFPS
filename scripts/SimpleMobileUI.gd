extends Control

# **シンプルモバイルUI v1.0.0 - ジョイスティックと視点移動のみ**

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
const BUTTON_COOLDOWN_TIME = 0.05  # 50msクールダウン（より短時間で連続操作可能）

# 定数
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

# **マルチタッチ対応タッチ処理 - ボタンとジョイスティックの並行操作を許可**
func _unhandled_input(event):
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	
	var screen_size = get_viewport().get_visible_rect().size
	var touch_pos = event.position
	var touch_id = event.index
	
	# **ボタン領域チェック - ボタン領域内のタッチはボタンに優先権を与える**
	if _is_in_button_area(touch_pos):
		print("BUTTON AREA: Touch ", touch_id, " is in button area - letting UI handle")
		# ボタン領域のタッチはUIに任せるが、イベントは消費しない
		return  
	
	# **シンプルな画面分割: 左50% = ジョイスティック、右50% = 視点**
	var is_left_side = touch_pos.x < screen_size.x * 0.5
	
	print("NON-BUTTON TOUCH: ID=", touch_id, " Pos=", touch_pos, " Side=", "LEFT" if is_left_side else "RIGHT")
	
	# タッチ開始
	if event is InputEventScreenTouch and event.pressed:
		_handle_touch_start(touch_id, touch_pos, is_left_side)
		# ジョイスティック/視点操作のイベントのみ消費
		get_viewport().set_input_as_handled()
	
	# タッチ終了
	elif event is InputEventScreenTouch and not event.pressed:
		_handle_touch_end(touch_id)
		get_viewport().set_input_as_handled()
	
	# ドラッグ
	elif event is InputEventScreenDrag:
		_handle_touch_drag(touch_id, touch_pos, event.relative)
		get_viewport().set_input_as_handled()

func _handle_touch_start(touch_id: int, pos: Vector2, is_left_side: bool):
	if is_left_side:
		# **左側 = ジョイスティック（1本のみ） - 既存タッチがある場合は無視**
		if _has_joystick_touch():
			print("JOYSTICK: Already has active joystick touch, ignoring new touch ID=", touch_id)
			return
		
		active_touches[touch_id] = {
			"type": "joystick",
			"center": pos
		}
		_show_joystick_at(pos)
		print("JOYSTICK START: ID=", touch_id, " - Buttons should still work!")
		
	else:
		# **右側 = 視点操作 - ボタン領域は既に除外済み**
		# ボタン領域内のタッチは_unhandled_inputでフィルタ済みなのでここには来ない
		
		# **視点（1本のみ） - 既存タッチがある場合は無視**
		if _has_view_touch():
			print("VIEW: Already has active view touch, ignoring new touch ID=", touch_id)
			return
		
		active_touches[touch_id] = {
			"type": "view",
			"last_pos": pos
		}
		print("VIEW START: ID=", touch_id, " - Buttons should still work!")

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
		# ドラッグ中にボタン領域に入ったら視点操作を中断
		if _is_in_button_area(pos):
			print("VIEW: Entered button area, ending view touch")
			active_touches.erase(touch_id)
			return
		
		# relativeを使わず、絶対座標で計算
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

# **ボタン領域チェック - より堅牢な判定**
func _is_in_button_area(pos: Vector2) -> bool:
	if not shoot_button or not jump_button:
		print("BUTTON CHECK: Buttons not found")
		return false
	
	# ボタンのグローバル位置とサイズを取得
	var shoot_rect = Rect2(shoot_button.global_position, shoot_button.size)
	var jump_rect = Rect2(jump_button.global_position, jump_button.size)
	
	# ダッシュボタンも追加（存在する場合）
	var dash_rect = Rect2()
	if dash_button:
		dash_rect = Rect2(dash_button.global_position, dash_button.size)
	
	# より大きなマージンでボタンを押しやすく（30ピクセル）
	var margin = 30
	shoot_rect = shoot_rect.grow(margin)
	jump_rect = jump_rect.grow(margin)
	if dash_button:
		dash_rect = dash_rect.grow(margin)
	
	var in_shoot = shoot_rect.has_point(pos)
	var in_jump = jump_rect.has_point(pos)
	var in_dash = dash_button and dash_rect.has_point(pos)
	var in_button_area = in_shoot or in_jump or in_dash
	
	if in_button_area:
		print("BUTTON CHECK: Touch in button area - Shoot:", in_shoot, " Jump:", in_jump, " Dash:", in_dash, " Pos:", pos)
	
	return in_button_area

# **緊急リセット**
func _notification(what):
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		print("=== EMERGENCY RESET ===")
		active_touches.clear()
		_hide_joystick()
		move_input.emit(Vector2.ZERO)
