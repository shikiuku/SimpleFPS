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

func _ready():
	print("=== MobileUI INITIALIZATION ===")
	print("Always showing UI (no platform detection)")
	
	# ボタン接続（シンプルで確実な方法）
	shoot_button.pressed.connect(_on_shoot_pressed)
	jump_button.pressed.connect(_on_jump_pressed)
	
	# タッチエリア接続
	movement_area.gui_input.connect(_on_movement_input)
	view_area.gui_input.connect(_on_view_input)
	
	print("MobileUI setup complete!")
	print("Shoot button: ", shoot_button)
	print("Jump button: ", jump_button)
	print("Movement area: ", movement_area)
	print("View area: ", view_area)

# _is_mobile()関数は削除済み - 常にモバイルUIを表示

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