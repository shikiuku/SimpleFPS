extends CanvasLayer

signal move_input(direction: Vector2)
signal look_input(delta: Vector2)
signal shoot_pressed
signal jump_pressed

@onready var movement_area = $MovementArea
@onready var view_area = $ViewArea
@onready var joystick_visual = $JoystickVisual
@onready var shoot_button = $ButtonLayer/ShootButton
@onready var jump_button = $ButtonLayer/JumpButton

# アナログスティック
@onready var joystick_base = $JoystickVisual/JoystickBase
@onready var joystick_knob = $JoystickVisual/JoystickBase/JoystickKnob

# タッチ管理
var joystick_touch_id = -1
var view_touch_id = -1
var active_touch_ids = {}  # アクティブなタッチを追跡
var button_touch_ids = []  # ボタンのタッチIDを追跡
var is_any_button_pressed = false  # いずれかのボタンが押されているか

# ジョイスティック設定
var joystick_center = Vector2.ZERO
var joystick_radius = 50.0
var joystick_dead_zone = 10.0
var knob_center_offset = Vector2(15, 15)  # ノブのサイズの半分

func _ready():
	print("=== MobileUI INITIALIZATION ===")
	
	# ボタン接続（タッチ追跡も追加）
	if shoot_button:
		shoot_button.pressed.connect(_on_shoot_pressed)
		shoot_button.button_down.connect(_on_shoot_button_down)
		shoot_button.button_up.connect(_on_shoot_button_up)
		print("Shoot button connected")
	if jump_button:
		jump_button.pressed.connect(_on_jump_pressed)
		jump_button.button_down.connect(_on_jump_button_down)
		jump_button.button_up.connect(_on_jump_button_up)
		print("Jump button connected")
	
	# ジョイスティック初期化
	if joystick_base and joystick_knob:
		# ジョイスティックの中心位置を計算
		joystick_center = joystick_base.position + joystick_base.size / 2
		print("Joystick center: ", joystick_center)
		
		# ノブを中心に配置
		_reset_knob()
	
	# タッチ入力接続
	if movement_area:
		movement_area.gui_input.connect(_on_movement_touch)
		print("Movement area connected")
	if view_area:
		view_area.gui_input.connect(_on_view_touch)
		print("View area connected")
	
	print("MobileUI setup complete!")

# 全てのタッチ状態をクリーンアップ
func _cleanup_all_touches():
	print("=== CLEANUP ALL TOUCHES ===")
	joystick_touch_id = -1
	view_touch_id = -1
	active_touch_ids.clear()
	button_touch_ids.clear()
	_reset_knob()
	move_input.emit(Vector2.ZERO)

# フォーカス失った時のクリーンアップ
func _notification(what):
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_cleanup_all_touches()

func _reset_knob():
	if joystick_knob and joystick_base:
		# ノブをベースの中心に配置
		var base_center = joystick_base.size / 2
		joystick_knob.position = base_center - knob_center_offset

# ジョイスティックエリア内かどうかを判定
func _is_position_in_joystick_area(global_pos: Vector2) -> bool:
	if not joystick_base:
		return false
	
	# ジョイスティックのグローバル位置を取得
	var joystick_global_pos = joystick_base.global_position
	var joystick_size = joystick_base.size
	var joystick_rect = Rect2(joystick_global_pos, joystick_size)
	
	# マージンを追加してより確実に分離
	joystick_rect = joystick_rect.grow(20)
	
	return joystick_rect.has_point(global_pos)

func _on_movement_touch(event: InputEvent):
	if not joystick_base or not joystick_knob:
		return
		
	if event is InputEventScreenTouch:
		if event.pressed and joystick_touch_id == -1:
			# 他の操作と競合していないかチェック
			if not active_touch_ids.has(event.index):
				# タッチ開始
				joystick_touch_id = event.index
				active_touch_ids[event.index] = "joystick"
				_update_joystick(event.position)
				print("Joystick touch started: ", event.position, " ID: ", event.index)
		elif not event.pressed and event.index == joystick_touch_id:
			# タッチ終了
			joystick_touch_id = -1
			active_touch_ids.erase(event.index)
			_reset_knob()
			move_input.emit(Vector2.ZERO)
			print("Joystick touch ended ID: ", event.index)
	
	elif event is InputEventScreenDrag and event.index == joystick_touch_id:
		# ドラッグ中（自分のタッチIDのみ処理）
		if active_touch_ids.get(event.index) == "joystick":
			_update_joystick(event.position)

func _update_joystick(touch_pos: Vector2):
	if not joystick_base or not joystick_knob:
		return
	
	# MovementAreaでのタッチ位置を、JoystickBaseの中心からの相対位置に変換
	var base_center = joystick_base.size / 2
	var touch_relative_to_base = touch_pos - base_center
	var distance = touch_relative_to_base.length()
	
	print("Touch pos: ", touch_pos, " Base center: ", base_center, " Relative: ", touch_relative_to_base, " Distance: ", distance)
	
	# 半径内に制限
	if distance > joystick_radius:
		touch_relative_to_base = touch_relative_to_base.normalized() * joystick_radius
		distance = joystick_radius
	
	# ノブの位置を更新（ベース内での相対位置、ノブのサイズを考慮）
	var new_knob_pos = base_center + touch_relative_to_base - knob_center_offset
	joystick_knob.position = new_knob_pos
	
	# 入力値を計算（デッドゾーン適用）
	if distance > joystick_dead_zone:
		var strength = (distance - joystick_dead_zone) / (joystick_radius - joystick_dead_zone)
		var direction = touch_relative_to_base.normalized() * strength
		move_input.emit(direction)
		print("=== MOVE INPUT EMITTED ===")
		print("Joystick move: ", direction)
		print("Touch pos: ", touch_pos, " Distance: ", distance)
	else:
		move_input.emit(Vector2.ZERO)

func _on_view_touch(event: InputEvent):
	if event is InputEventScreenTouch:
		if event.pressed and view_touch_id == -1:
			# 他の操作と競合していないかチェック
			if not active_touch_ids.has(event.index):
				# ジョイスティックエリア内の場合は視点操作を開始しない
				if _is_position_in_joystick_area(event.position):
					print("View touch ignored - position in joystick area: ", event.position)
					return
				
				# 視点操作開始
				view_touch_id = event.index
				active_touch_ids[event.index] = "view"
				print("View touch started: ", event.position, " ID: ", event.index)
		elif not event.pressed and event.index == view_touch_id:
			# 視点操作終了
			view_touch_id = -1
			active_touch_ids.erase(event.index)
			print("View touch ended ID: ", event.index)
	
	elif event is InputEventScreenDrag and event.index == view_touch_id:
		# 視点ドラッグ（自分のタッチIDのみ処理）
		if active_touch_ids.get(event.index) == "view":
			# ボタンが押されている時やジョイスティック使用中は感度を下げる
			var base_sensitivity = 0.00035
			var sensitivity_modifier = 1.0
			
			# ジョイスティックが使用中の場合は感度を下げる
			if joystick_touch_id != -1:
				sensitivity_modifier *= 0.5
				
			# ボタンが押されている時も感度を下げる
			if is_any_button_pressed:
				sensitivity_modifier *= 0.3
			
			var sensitivity = base_sensitivity * sensitivity_modifier
			var delta = event.relative * sensitivity
			
			# 過度な動きを制限（視点がバグらないように）
			var max_delta = 0.08
			if joystick_touch_id != -1 or is_any_button_pressed:
				max_delta = 0.03
			delta = delta.limit_length(max_delta)
			
			look_input.emit(delta)
			print("=== LOOK INPUT EMITTED ===")
			print("Look delta: ", delta, " ID: ", event.index)
			print("Joystick active: ", joystick_touch_id != -1, " Button pressed: ", is_any_button_pressed)
			print("Event position: ", event.position, " Relative: ", event.relative)

func _on_shoot_pressed():
	print("SHOOT BUTTON PRESSED!")
	shoot_pressed.emit()

func _on_jump_pressed():
	print("JUMP BUTTON PRESSED!")
	jump_pressed.emit()

# ボタン状態の追跡
func _on_shoot_button_down():
	is_any_button_pressed = true
	print("Shoot button DOWN - reducing view sensitivity")

func _on_shoot_button_up():
	is_any_button_pressed = false
	print("Shoot button UP - restoring view sensitivity")

func _on_jump_button_down():
	is_any_button_pressed = true
	print("Jump button DOWN - reducing view sensitivity")

func _on_jump_button_up():
	is_any_button_pressed = false
	print("Jump button UP - restoring view sensitivity")
