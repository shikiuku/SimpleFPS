extends CanvasLayer

signal move_input(direction: Vector2)
signal look_input(delta: Vector2)  # 視点操作信号を再実装
signal shoot_pressed
signal jump_pressed

@onready var movement_area = $MovementArea
@onready var view_area = $ViewArea  # 視点操作エリアを再実装
@onready var joystick_visual = $JoystickVisual
@onready var shoot_button = $ButtonLayer/ShootButton
@onready var jump_button = $ButtonLayer/JumpButton

# アナログスティック
@onready var joystick_base = $JoystickVisual/JoystickBase
@onready var joystick_knob = $JoystickVisual/JoystickBase/JoystickKnob

# タッチ管理
var joystick_touch_id = -1
var view_touch_id = -1  # 視点操作用タッチIDを再実装
var active_touch_ids = {}  # アクティブなタッチを追跡

# ジョイスティック設定（新版）
var joystick_center = Vector2.ZERO
var joystick_radius = 50.0
var joystick_dead_zone = 8.0
var joystick_knob_size = Vector2(30, 30)  # ノブのサイズ

# 視点操作設定
var look_sensitivity = 0.003  # 視点操作の感度

func _ready():
	print("=== MobileUI INITIALIZATION ===")
	
	# ボタン接続（タッチ追跡も追加）
	if shoot_button:
		shoot_button.pressed.connect(_on_shoot_pressed)
		shoot_button.button_down.connect(_on_shoot_button_down)
		shoot_button.button_up.connect(_on_shoot_button_up)
		shoot_button.gui_input.connect(_on_shoot_button_touch)
		print("Shoot button connected")
	if jump_button:
		jump_button.pressed.connect(_on_jump_pressed)
		jump_button.button_down.connect(_on_jump_button_down)
		jump_button.button_up.connect(_on_jump_button_up)
		jump_button.gui_input.connect(_on_jump_button_touch)
		print("Jump button connected")
	
	# ジョイスティック初期化（新版）
	if joystick_base and joystick_knob:
		# ジョイスティックの中心位置をグローバル座標で計算
		joystick_center = joystick_base.global_position + joystick_base.size / 2
		print("Joystick center (global): ", joystick_center)
		print("Joystick base pos: ", joystick_base.position, " size: ", joystick_base.size)
		print("Joystick base global pos: ", joystick_base.global_position)
		
		# ノブを中心に配置
		_reset_joystick_knob()
	
	# タッチ入力接続
	if movement_area:
		movement_area.gui_input.connect(_on_movement_touch)
		print("Movement area connected")
		print("Movement area position: ", movement_area.position)
		print("Movement area size: ", movement_area.size)
		print("Movement area global position: ", movement_area.global_position)
		print("Movement area visible: ", movement_area.visible)
		print("Movement area z_index: ", movement_area.z_index)
	else:
		print("ERROR: movement_area is null!")
	# 視点操作エリアの接続を再実装
	if view_area:
		view_area.gui_input.connect(_on_view_touch)
		print("View area connected")
		print("View area position: ", view_area.position)
		print("View area size: ", view_area.size)
		print("View area global position: ", view_area.global_position)
		print("View area visible: ", view_area.visible)
		print("View area z_index: ", view_area.z_index)
	else:
		print("ERROR: view_area is null!")
	
	print("MobileUI setup complete!")

# 全てのタッチ状態をクリーンアップ（シンプル版）
func _cleanup_all_touches():
	print("=== CLEANUP ALL TOUCHES ===")
	joystick_touch_id = -1
	view_touch_id = -1  # 視点操作用タッチIDもリセット
	active_touch_ids.clear()
	_reset_joystick_knob()
	move_input.emit(Vector2.ZERO)
	print("All touch states cleaned")

# フォーカス失った時のクリーンアップ
func _notification(what):
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_cleanup_all_touches()

# 新しいジョイスティックノブリセット関数
func _reset_joystick_knob():
	if joystick_knob and joystick_base:
		# ノブをベースの中心に配置
		var base_center = joystick_base.size / 2
		var knob_half_size = joystick_knob_size / 2
		joystick_knob.position = base_center - knob_half_size
		print("Joystick knob reset to center: ", joystick_knob.position)

# ジョイスティックエリア判定機能を削除（干渉防止機能無効化）

func _on_movement_touch(event: InputEvent):
	print("=== MOVEMENT TOUCH EVENT RECEIVED ===")
	print("Event type: ", event.get_class())
	print("Event: ", event)
	
	if not joystick_base or not joystick_knob:
		print("ERROR: joystick_base or joystick_knob is null!")
		return
		
	if event is InputEventScreenTouch:
		if event.pressed and joystick_touch_id == -1:
			# 他の操作と競合していないかチェック
			if not active_touch_ids.has(event.index):
				# ジョイスティック開始（シンプル版）
				joystick_touch_id = event.index
				active_touch_ids[event.index] = "joystick"
				_update_joystick(event.position)
				print("=== JOYSTICK TOUCH STARTED ===")
				print("Position: ", event.position, " ID: ", event.index)
			else:
				print("=== JOYSTICK TOUCH BLOCKED ===")
				print("Touch ID ", event.index, " already used by: ", active_touch_ids.get(event.index))
		elif not event.pressed and event.index == joystick_touch_id:
			# タッチ終了
			joystick_touch_id = -1
			active_touch_ids.erase(event.index)
			_reset_joystick_knob()
			move_input.emit(Vector2.ZERO)
			print("Joystick touch ended ID: ", event.index)
	
	elif event is InputEventScreenDrag and event.index == joystick_touch_id:
		# ドラッグ中（自分のタッチIDのみ処理）
		if active_touch_ids.get(event.index) == "joystick":
			_update_joystick(event.position)
	
	# PC環境でのマウス操作サポート
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and joystick_touch_id == -1:
			# マウスでのジョイスティック開始（PC環境用・シンプル版）
			joystick_touch_id = 0  # マウス用の固定ID
			active_touch_ids[0] = "joystick_mouse"
			_update_joystick(event.position)
			print("=== JOYSTICK MOUSE STARTED ===")
			print("Position: ", event.position)
		elif not event.pressed and joystick_touch_id == 0:
			# マウスでのジョイスティック終了
			joystick_touch_id = -1
			active_touch_ids.erase(0)
			_reset_joystick_knob()
			move_input.emit(Vector2.ZERO)
			print("Joystick mouse ended")
	
	elif event is InputEventMouseMotion and joystick_touch_id == 0:
		# マウスでのドラッグ中（PC環境用）
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_update_joystick(event.position)
			print("Joystick mouse drag: ", event.position)

# 完全に新しいジョイスティック更新関数
func _update_joystick(movement_area_touch_pos: Vector2):
	if not joystick_base or not joystick_knob or not movement_area:
		return
	
	# MovementAreaのローカル座標からJoystickBaseのローカル座標に変換
	var movement_area_global = movement_area.global_position + movement_area_touch_pos
	var joystick_base_global = joystick_base.global_position
	var touch_relative_to_joystick = movement_area_global - joystick_base_global
	
	# JoystickBaseの中心からの距離を計算
	var base_center_local = joystick_base.size / 2
	var offset_from_center = touch_relative_to_joystick - base_center_local
	var distance = offset_from_center.length()
	
	print("=== NEW JOYSTICK UPDATE ===")
	print("Movement touch pos: ", movement_area_touch_pos)
	print("Movement global: ", movement_area_global)
	print("Joystick base global: ", joystick_base_global)
	print("Offset from center: ", offset_from_center, " Distance: ", distance)
	
	# 半径内に制限
	var clamped_offset = offset_from_center
	if distance > joystick_radius:
		clamped_offset = offset_from_center.normalized() * joystick_radius
		distance = joystick_radius
	
	# ノブの位置を更新
	var knob_half_size = joystick_knob_size / 2
	var new_knob_pos = base_center_local + clamped_offset - knob_half_size
	joystick_knob.position = new_knob_pos
	
	# 入力値を計算（デッドゾーン適用）
	if distance > joystick_dead_zone:
		var strength = (distance - joystick_dead_zone) / (joystick_radius - joystick_dead_zone)
		var direction = clamped_offset.normalized() * strength
		move_input.emit(direction)
		print("=== MOVE INPUT EMITTED ===")
		print("Direction: ", direction, " Strength: ", strength)
	else:
		move_input.emit(Vector2.ZERO)
		print("=== MOVE INPUT ZERO (dead zone) ===")

# 視点操作機能を再実装
func _on_view_touch(event: InputEvent):
	print("=== VIEW TOUCH EVENT RECEIVED ===")
	print("Event type: ", event.get_class())
	print("Event: ", event)
	
	if event is InputEventScreenTouch:
		if event.pressed and view_touch_id == -1:
			# 他の操作と競合していないかチェック
			if not active_touch_ids.has(event.index):
				# 視点操作開始
				view_touch_id = event.index
				active_touch_ids[event.index] = "view_control"
				print("=== VIEW TOUCH STARTED ===")
				print("Position: ", event.position, " ID: ", event.index)
			else:
				print("=== VIEW TOUCH BLOCKED ===")
				print("Touch ID ", event.index, " already used by: ", active_touch_ids.get(event.index))
		elif not event.pressed and event.index == view_touch_id:
			# タッチ終了
			view_touch_id = -1
			active_touch_ids.erase(event.index)
			print("View touch ended ID: ", event.index)
	
	elif event is InputEventScreenDrag and event.index == view_touch_id:
		# ドラッグ中（自分のタッチIDのみ処理）
		if active_touch_ids.get(event.index) == "view_control":
			var delta = event.relative * look_sensitivity
			look_input.emit(delta)
			print("=== LOOK INPUT EMITTED ===")
			print("Relative: ", event.relative, " Delta: ", delta)
	
	# PC環境でのマウス操作サポート
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed and view_touch_id == -1:
			# マウスでの視点操作開始（PC環境用・右クリック）
			view_touch_id = 1  # マウス用の固定ID（右クリック用）
			active_touch_ids[1] = "view_control_mouse"
			print("=== VIEW MOUSE STARTED ===")
			print("Position: ", event.position)
		elif not event.pressed and view_touch_id == 1:
			# マウスでの視点操作終了
			view_touch_id = -1
			active_touch_ids.erase(1)
			print("View mouse ended")
	
	elif event is InputEventMouseMotion and view_touch_id == 1:
		# マウスでのドラッグ中（PC環境用・右クリック中）
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			var delta = event.relative * look_sensitivity
			look_input.emit(delta)
			print("View mouse drag: ", event.relative, " Delta: ", delta)

func _on_shoot_pressed():
	print("SHOOT BUTTON PRESSED!")
	shoot_pressed.emit()

func _on_jump_pressed():
	print("JUMP BUTTON PRESSED!")
	jump_pressed.emit()

# ボタン状態の追跡（簡略版）
var shoot_button_pressed = false
var jump_button_pressed = false

func _on_shoot_button_down():
	shoot_button_pressed = true
	print("Shoot button DOWN")

func _on_shoot_button_up():
	shoot_button_pressed = false
	print("Shoot button UP")

func _on_jump_button_down():
	jump_button_pressed = true
	print("Jump button DOWN")

func _on_jump_button_up():
	jump_button_pressed = false
	print("Jump button UP")

# ボタンタッチIDの追跡
func _on_shoot_button_touch(event: InputEvent):
	if event is InputEventScreenTouch:
		if event.pressed:
			active_touch_ids[event.index] = "shoot_button"
			print("=== SHOOT BUTTON TOUCH START ===")
			print("Touch ID: ", event.index, " Position: ", event.position)
		else:
			active_touch_ids.erase(event.index)
			print("=== SHOOT BUTTON TOUCH END ===")
			print("Touch ID: ", event.index)

func _on_jump_button_touch(event: InputEvent):
	if event is InputEventScreenTouch:
		if event.pressed:
			active_touch_ids[event.index] = "jump_button"
			print("=== JUMP BUTTON TOUCH START ===")
			print("Touch ID: ", event.index, " Position: ", event.position)
		else:
			active_touch_ids.erase(event.index)
			print("=== JUMP BUTTON TOUCH END ===")
			print("Touch ID: ", event.index)
