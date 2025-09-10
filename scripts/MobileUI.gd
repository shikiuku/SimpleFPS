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
var is_any_button_pressed = false  # いずれかのボタンが押されているか

# ジョイスティック設定（新版）
var joystick_center = Vector2.ZERO
var joystick_radius = 50.0
var joystick_dead_zone = 8.0
var joystick_knob_size = Vector2(30, 30)  # ノブのサイズ

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
	if view_area:
		view_area.gui_input.connect(_on_view_touch)
		print("View area connected")
	
	print("MobileUI setup complete!")

# 全てのタッチ状態をクリーンアップ
func _cleanup_all_touches():
	print("=== CLEANUP ALL TOUCHES ===")
	print("Previous active touch IDs: ", active_touch_ids)
	joystick_touch_id = -1
	view_touch_id = -1
	active_touch_ids.clear()
	is_any_button_pressed = false
	shoot_button_pressed = false
	jump_button_pressed = false
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

# 改善されたジョイスティックエリア判定
func _is_position_in_joystick_area(view_area_touch_pos: Vector2) -> bool:
	if not joystick_base or not view_area:
		return false
	
	# ViewAreaのローカル座標をグローバル座標に変換
	var view_area_global = view_area.global_position + view_area_touch_pos
	
	# ジョイスティックのグローバル位置と範囲を取得
	var joystick_global_pos = joystick_base.global_position
	var joystick_size = joystick_base.size
	var joystick_rect = Rect2(joystick_global_pos, joystick_size)
	
	# 確実な分離のためマージンを追加
	joystick_rect = joystick_rect.grow(30)
	
	var is_in_area = joystick_rect.has_point(view_area_global)
	if is_in_area:
		print("=== JOYSTICK AREA CONFLICT DETECTED ===")
		print("View touch pos: ", view_area_touch_pos)
		print("View global: ", view_area_global)
		print("Joystick rect: ", joystick_rect)
	
	return is_in_area

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
				print("=== JOYSTICK TOUCH STARTED ===")
				print("Position: ", event.position, " ID: ", event.index)
				print("Active touches: ", active_touch_ids)
				# イベントを消費してViewAreaに伝わらないようにする
				accept_event()
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
			# イベントを消費してViewAreaに伝わらないようにする
			accept_event()

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

func _on_view_touch(event: InputEvent):
	# 既にジョイスティックが使用中の場合は全てのViewAreaイベントを無視
	if joystick_touch_id != -1:
		print("=== VIEW AREA EVENT BLOCKED - JOYSTICK ACTIVE ===")
		return
	
	if event is InputEventScreenTouch:
		if event.pressed and view_touch_id == -1:
			# 他の操作と競合していないかチェック
			if not active_touch_ids.has(event.index):
				# ジョイスティックエリア内の場合は視点操作を開始しない
				if _is_position_in_joystick_area(event.position):
					print("=== VIEW TOUCH IGNORED - IN JOYSTICK AREA ===")
					print("Position: ", event.position)
					return
				
				# 視点操作開始
				view_touch_id = event.index
				active_touch_ids[event.index] = "view"
				print("=== VIEW TOUCH STARTED ===")
				print("Position: ", event.position, " ID: ", event.index)
				print("Active touches: ", active_touch_ids)
			else:
				print("=== VIEW TOUCH BLOCKED ===")
				print("Touch ID ", event.index, " already used by: ", active_touch_ids.get(event.index))
		elif not event.pressed and event.index == view_touch_id:
			# 視点操作終了
			view_touch_id = -1
			active_touch_ids.erase(event.index)
			print("View touch ended ID: ", event.index)
	
	elif event is InputEventScreenDrag and event.index == view_touch_id:
		# 視点ドラッグ（自分のタッチIDのみ処理）
		if active_touch_ids.get(event.index) == "view":
			# ジョイスティック使用中は視点操作を完全に無効化
			if joystick_touch_id != -1:
				print("=== VIEW INPUT BLOCKED - JOYSTICK ACTIVE ===")
				return
			
			# ボタンが押されている時も視点操作を大幅に制限
			var base_sensitivity = 0.00008  # 元の約1/4に大幅減少
			var sensitivity_modifier = 1.0
			
			# ボタンが押されている時は更に感度を下げる
			if is_any_button_pressed:
				sensitivity_modifier *= 0.15  # 0.3 → 0.15 に更に制限
			
			var sensitivity = base_sensitivity * sensitivity_modifier
			var delta = event.relative * sensitivity
			
			# 過度な動きを更に厳しく制限
			var max_delta = 0.02  # 0.08 → 0.02 に大幅制限
			if is_any_button_pressed:
				max_delta = 0.008  # ボタン押下中は更に制限
			delta = delta.limit_length(max_delta)
			
			look_input.emit(delta)
			print("=== LOOK INPUT EMITTED (SAFE MODE) ===")
			print("Look delta: ", delta, " Sensitivity: ", sensitivity)
			print("Button pressed: ", is_any_button_pressed)
			print("Event relative: ", event.relative)

func _on_shoot_pressed():
	print("SHOOT BUTTON PRESSED!")
	shoot_pressed.emit()

func _on_jump_pressed():
	print("JUMP BUTTON PRESSED!")
	jump_pressed.emit()

# ボタン状態の追跡（改善版）
var shoot_button_pressed = false
var jump_button_pressed = false

func _on_shoot_button_down():
	shoot_button_pressed = true
	is_any_button_pressed = true
	print("Shoot button DOWN - reducing view sensitivity")

func _on_shoot_button_up():
	shoot_button_pressed = false
	is_any_button_pressed = jump_button_pressed  # 他のボタンがまだ押されているかチェック
	print("Shoot button UP - view sensitivity: ", "reduced" if is_any_button_pressed else "normal")

func _on_jump_button_down():
	jump_button_pressed = true
	is_any_button_pressed = true
	print("Jump button DOWN - reducing view sensitivity")

func _on_jump_button_up():
	jump_button_pressed = false
	is_any_button_pressed = shoot_button_pressed  # 他のボタンがまだ押されているかチェック
	print("Jump button UP - view sensitivity: ", "reduced" if is_any_button_pressed else "normal")

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
