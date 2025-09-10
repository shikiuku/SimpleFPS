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
@onready var joystick_knob = $JoystickVisual/JoystickKnob

var movement_touch_index = -1
var view_touch_index = -1
var movement_start_pos = Vector2.ZERO
var last_view_pos = Vector2.ZERO

var joystick_radius = 50.0
var joystick_dead_zone = 10.0

# ジョイスティックの状態
var joystick_center_pos = Vector2.ZERO
var joystick_touch_index = -1
var knob_initial_pos = Vector2.ZERO

func _ready():
	print("=== MobileUI INITIALIZATION ===")
	print("Always showing UI (no platform detection)")
	
	# ボタン接続（シンプルで確実な方法）
	shoot_button.pressed.connect(_on_shoot_pressed)
	jump_button.pressed.connect(_on_jump_pressed)
	
	# ジョイスティック接続
	if joystick_base:
		joystick_base.gui_input.connect(_on_joystick_input)
		
		# ジョイスティックの初期位置を設定
		joystick_center_pos = joystick_base.position + joystick_base.size / 2
		knob_initial_pos = joystick_knob.position
	
	# タッチエリア接続
	movement_area.gui_input.connect(_on_movement_input)
	view_area.gui_input.connect(_on_view_input)
	
	print("MobileUI setup complete!")
	print("Shoot button: ", shoot_button)
	print("Jump button: ", jump_button)
	print("Movement area: ", movement_area)
	print("View area: ", view_area)

# _is_mobile()関数は削除済み - 常にモバイルUIを表示

# ジョイスティックのイベント処理
func _on_joystick_input(event: InputEvent):
	if not joystick_base or not joystick_knob:
		return
		
	if event is InputEventScreenTouch:
		if event.pressed and joystick_touch_index == -1:
			# ジョイスティックタッチ開始
			joystick_touch_index = event.index
			var touch_pos = event.position
			_update_joystick_knob(touch_pos)
			print("Joystick touch started at: ", touch_pos)
		elif not event.pressed and event.index == joystick_touch_index:
			# ジョイスティックタッチ終了
			joystick_touch_index = -1
			_reset_joystick()
			move_input.emit(Vector2.ZERO)
			print("Joystick touch ended")
	
	elif event is InputEventScreenDrag and event.index == joystick_touch_index:
		# ドラッグ中
		var touch_pos = event.position
		_update_joystick_knob(touch_pos)

func _update_joystick_knob(touch_pos: Vector2):
	if not joystick_base or not joystick_knob:
		return
		
	# ジョイスティックベースの中心からの相対位置を計算
	var joystick_base_global = joystick_base.global_position + joystick_base.size / 2
	var delta = touch_pos - joystick_base_global
	var distance = delta.length()
	
	# 半径内に制限
	if distance > joystick_radius:
		delta = delta.normalized() * joystick_radius
		distance = joystick_radius
	
	# ノブの位置を更新
	var knob_pos = knob_initial_pos + delta
	joystick_knob.position = knob_pos
	
	# 入力値を計算（デッドゾーン適用）
	if distance > joystick_dead_zone:
		var input_strength = (distance - joystick_dead_zone) / (joystick_radius - joystick_dead_zone)
		var normalized_input = delta.normalized() * input_strength
		move_input.emit(normalized_input)
		print("Joystick input: ", normalized_input)
	else:
		move_input.emit(Vector2.ZERO)

func _reset_joystick():
	if joystick_knob:
		# ノブを初期位置に戻す
		joystick_knob.position = knob_initial_pos

func _on_shoot_pressed():
	print("SHOOT BUTTON PRESSED!")
	shoot_pressed.emit()

func _on_jump_pressed():
	print("JUMP BUTTON PRESSED!")
	jump_pressed.emit()

func _on_movement_input(event: InputEvent):
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
			var final_input = direction * strength
			move_input.emit(final_input)
			print("Movement input: ", final_input)

func _on_view_input(event: InputEvent):
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
		var final_input = delta * 0.002  # マウス感度と同様
		look_input.emit(final_input)
		print("Look input: ", final_input)
