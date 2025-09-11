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

# **正しいマルチタッチ管理**
var active_touches = {}  # touch_id -> {"type": "joystick"/"view", "data": {...}}

# ジョイスティック設定
var joystick_radius = 50.0
var joystick_dead_zone = 8.0
var joystick_knob_size = Vector2(30, 30)

# 視点操作設定
var look_sensitivity = 0.003

func _ready():
	print("=== MobileUI CORRECT MULTITOUCH SYSTEM ===")
	
	# ボタン接続
	if shoot_button:
		shoot_button.pressed.connect(_on_shoot_pressed)
	if jump_button:
		jump_button.pressed.connect(_on_jump_pressed)
	
	# ジョイスティック初期化
	if joystick_visual:
		joystick_visual.visible = false
		if joystick_knob and joystick_base:
			_reset_joystick_knob()
	
	print("Correct multitouch system ready!")

# **正しいマルチタッチ処理**
func _input(event):
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	
	var screen_size = get_viewport().get_visible_rect().size
	var touch_pos = event.position
	var touch_id = event.index
	
	# 画面分割
	var is_left_zone = touch_pos.x < screen_size.x * 0.5
	var is_right_zone = touch_pos.x >= screen_size.x * 0.5
	
	print("Touch event: ID=", touch_id, " Pos=", touch_pos, " Left=", is_left_zone)
	
	# **タッチ開始**
	if event is InputEventScreenTouch and event.pressed:
		_handle_touch_start(touch_id, touch_pos, is_left_zone, is_right_zone, screen_size)
	
	# **タッチ終了**
	elif event is InputEventScreenTouch and not event.pressed:
		_handle_touch_end(touch_id)
	
	# **ドラッグ**
	elif event is InputEventScreenDrag:
		_handle_touch_drag(touch_id, event.position, event.relative)

func _handle_touch_start(touch_id: int, pos: Vector2, is_left: bool, is_right: bool, screen_size: Vector2):
	# **最優先：ボタン領域チェック**
	if _is_button_area(pos, screen_size):
		_handle_button_touch(pos)
		get_viewport().set_input_as_handled()
		print("BUTTON: Touch consumed - no other processing")
		return
	
	# **安全な境界線設定** - ボタン領域を除外した左右分割
	var safe_boundary_x = screen_size.x * 0.6  # 右40%はボタン用に確保
	var is_safe_left = pos.x < safe_boundary_x
	var is_safe_right = pos.x > safe_boundary_x and not _is_button_area(pos, screen_size)
	
	# 左領域：ジョイスティック（安全領域のみ）
	if is_safe_left and not _has_joystick_touch():
		active_touches[touch_id] = {
			"type": "joystick",
			"center": pos,
			"start_pos": pos
		}
		_show_joystick_at_position(pos)
		print("JOYSTICK: Started ID ", touch_id, " at ", pos)
		get_viewport().set_input_as_handled()
	
	# 右領域：視点操作（ボタン領域以外の安全領域のみ）
	# **重要：視点操作は1本の指のみ** - 2本目以降は完全拒否
	elif is_safe_right and not _has_view_touch():
		active_touches[touch_id] = {
			"type": "view",
			"last_pos": pos
		}
		print("VIEW: Started ID ", touch_id, " at ", pos, " (ONLY ONE FINGER ALLOWED)")
		get_viewport().set_input_as_handled()
	
	else:
		var reason = ""
		if _has_view_touch():
			reason = "VIEW_BUSY (only 1 finger allowed for view control)"
		elif _has_joystick_touch():
			reason = "JOYSTICK_BUSY"
		elif not is_safe_left and not is_safe_right:
			reason = "UNSAFE_ZONE"
		print("IGNORED: Touch rejected - ", reason, " SafeLeft=", is_safe_left, " SafeRight=", is_safe_right)

func _handle_touch_end(touch_id: int):
	if touch_id in active_touches:
		var touch_data = active_touches[touch_id]
		
		if touch_data.type == "joystick":
			_hide_joystick()
			move_input.emit(Vector2.ZERO)
			print("JOYSTICK: Ended ID ", touch_id)
		
		elif touch_data.type == "view":
			print("VIEW: Ended ID ", touch_id)
		
		active_touches.erase(touch_id)
		get_viewport().set_input_as_handled()
	else:
		print("IGNORED: Unknown touch end ID ", touch_id)

func _handle_touch_drag(touch_id: int, pos: Vector2, relative: Vector2):
	if touch_id not in active_touches:
		print("DRAG IGNORED: Unknown touch ID ", touch_id)
		return
	
	var touch_data = active_touches[touch_id]
	
	if touch_data.type == "joystick":
		_handle_joystick_drag(pos, touch_data.center)
		get_viewport().set_input_as_handled()
	
	elif touch_data.type == "view":
		_handle_view_drag(relative)
		get_viewport().set_input_as_handled()
	
	else:
		print("DRAG ERROR: Unknown touch type ", touch_data.type)

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

# **ボタン領域判定**
func _is_button_area(pos: Vector2, screen_size: Vector2) -> bool:
	var button_area = Rect2(screen_size.x - 150, screen_size.y - 120, 150, 120)
	return button_area.has_point(pos)

# **ボタンタッチ処理**
func _handle_button_touch(pos: Vector2):
	if shoot_button and shoot_button.get_global_rect().has_point(pos):
		print("BUTTON: Shoot pressed")
		shoot_pressed.emit()
	elif jump_button and jump_button.get_global_rect().has_point(pos):
		print("BUTTON: Jump pressed") 
		jump_pressed.emit()

# **ジョイスティック表示**
func _show_joystick_at_position(pos: Vector2):
	if joystick_visual:
		# JoystickVisualを正しいサイズに設定（ジョイスティックの直径）
		var joystick_size = joystick_radius * 2
		joystick_visual.size = Vector2(joystick_size, joystick_size)
		# タッチ位置を中心にして配置
		joystick_visual.position = pos - Vector2(joystick_radius, joystick_radius)
		joystick_visual.visible = true
		_reset_joystick_knob()
		print("JOYSTICK: Showed at ", pos, " Size: ", joystick_visual.size)

# **ジョイスティック非表示**
func _hide_joystick():
	if joystick_visual:
		joystick_visual.visible = false
		print("JOYSTICK: Hidden")

# **ジョイスティックドラッグ処理**
func _handle_joystick_drag(touch_pos: Vector2, center: Vector2):
	var offset = touch_pos - center
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
		active_touches.clear()
		_hide_joystick()
		move_input.emit(Vector2.ZERO)
