extends CharacterBody3D

@export var walk_speed = 5.0
@export var run_speed = 8.0
@export var jump_velocity = 8.0
@export var mouse_sensitivity = 0.002  # PC用マウス感度

# ダッシュシステム
@export var dash_speed = 20.0         # ダッシュ時の速度
@export var dash_duration = 0.3      # ダッシュの持続時間（秒）
@export var dash_charge_time = 3.0   # フルチャージまでの時間（秒）
var dash_charge = 3.0                # 現在のダッシュチャージ量
var is_dashing = false               # ダッシュ中かどうか
var dash_timer = 0.0                 # ダッシュタイマー
var dash_direction = Vector3.ZERO    # ダッシュ方向

# 三段ジャンプシステム
@export var max_jump_count = 3        # 最大ジャンプ回数（三段ジャンプ）
@export var second_jump_velocity = 7.0  # 2回目ジャンプの力
@export var third_jump_velocity = 6.0   # 3回目ジャンプの力
var current_jump_count = 0           # 現在のジャンプ回数
var was_on_floor_last_frame = false  # 前フレームで地面にいたか

# 同期用プロパティ（RPC同期で使用）
@export var sync_position := Vector3.ZERO
@export var sync_rotation_y := 0.0
@export var sync_rotation_x := 0.0

@onready var camera = $CameraHolder/Camera3D
@onready var camera_holder = $CameraHolder
@onready var mesh_instance = $MeshInstance3D
@onready var gun_model = $CameraHolder/GunModel
@onready var gun_tip = $CameraHolder/GunModel/GunTip
@onready var health_bar_ui = $HealthBarUI/SubViewport/HealthBarControl/PlayerHealthBar
@onready var health_label_ui = $HealthBarUI/SubViewport/HealthBarControl/PlayerHealthBar/PlayerHealthLabel

# 視点回転を絶対値で管理
var current_y_rotation = 0.0  # 水平回転
var current_x_rotation = 0.0  # 垂直回転

# 弾丸のプリロード
var bullet_scene = preload("res://scenes/Bullet.tscn")

# 銃の反動アニメーション関連
var gun_original_position: Vector3
var gun_original_rotation: Vector3  # 銃の元の回転位置
var gun_recoil_tween: Tween
const RECOIL_DISTANCE = -0.3  # 反動で後退する距離（大幅に増加）
const RECOIL_DURATION = 0.12  # 反動の持続時間（秒）
const RECOIL_RETURN_DURATION = 0.18  # 元の位置に戻る時間（秒）
const RECOIL_ROTATION = -0.15  # 反動の回転角度（ラジアン、約8.6度）

# HPシステム
@export var max_health = 100
var current_health = 100
var is_dead = false
var respawn_timer: Timer = null

# 弾数システム
@export var max_ammo = 50
var current_ammo = 50
var reload_timer: Timer = null

# モバイル入力関連
var mobile_movement = Vector2.ZERO
var mobile_ui: Control = null
var mobile_dash_requested = false

func _ready():
	# 衝突レイヤーを強制設定（.tscnファイルの設定が消える問題の対策）
	collision_layer = 1  # Player layer
	collision_mask = 3   # Player + Environment layers
	print("Player collision settings - layer: ", collision_layer, " mask: ", collision_mask)
	
	# マルチプレイヤーのピアが存在するまで待機
	await get_tree().process_frame
	
	# peer_idを取得してノード名に設定（重要：ユニークにするため）
	var peer_id = name.to_int()
	set_multiplayer_authority(peer_id)
	
	# プレイヤーの衝突設定を強制的に設定（.tscnファイルが設定を失うため）
	collision_layer = 1  # Player layer
	collision_mask = 3   # Player (1) + Environment (2)
	print("Player collision settings - layer: ", collision_layer, " mask: ", collision_mask)
	
	# 初期位置を設定（重要！）
	sync_position = global_position
	sync_rotation_y = rotation.y
	sync_rotation_x = camera.rotation.x
	
	# 視点回転の初期値を設定
	current_y_rotation = rotation.y
	current_x_rotation = camera.rotation.x
	
	# HPシステムの初期化
	current_health = max_health
	is_dead = false
	
	# 弾数システムの初期化
	current_ammo = max_ammo
	setup_reload_timer()
	
	# ダッシュシステムの初期化
	dash_charge = dash_charge_time  # フル充電状態でスタート
	
	# 三段ジャンプシステムの初期化
	current_jump_count = 0
	was_on_floor_last_frame = is_on_floor()
	
	# 銃の反動アニメーション初期化
	if gun_model:
		gun_original_position = gun_model.position
		gun_original_rotation = gun_model.rotation  # 元の回転も保存
		gun_recoil_tween = create_tween()
		print("Gun recoil system initialized - Original position: ", gun_original_position, " Original rotation: ", gun_original_rotation)
	
	# プレイヤー上部のHP表示を初期化
	call_deferred("update_overhead_health_display")
	
	# リスポーン処理をチェック（死亡シーンから戻ってきた場合）
	if RespawnManager.should_respawn and is_multiplayer_authority():
		call_deferred("handle_respawn_return")
	
	# MultiplayerSynchronizerの設定
	call_deferred("setup_multiplayer")
	
	print("Player _ready: ", name, " Authority: ", get_multiplayer_authority(), " Position: ", global_position)

func setup_multiplayer():
	# 権限に基づいて初期化
	if is_multiplayer_authority():
		# 自分のプレイヤー（ローカル）
		setup_mobile_ui()
		setup_game_ui()
		
		# PC環境ではマウスキャプチャーを設定
		if not _is_mobile_platform():
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			print("PC mode: Mouse captured for camera control")
		
		camera.current = true
		mesh_instance.visible = false
		
		# 自分のプレイヤーには頭上HP表示は不要なので非表示
		if $HealthBarUI:
			$HealthBarUI.visible = false
			print("Overhead health display hidden for local player")
		
		# 自分の銃の色をプレイヤーIDに基づく色に設定
		if gun_model:
			var my_player_id = name.to_int()
			var my_color = get_player_color(my_player_id)
			var gun_material = StandardMaterial3D.new()
			gun_material.albedo_color = my_color
			gun_model.set_surface_override_material(0, gun_material)
			print("Local player gun color set to: ", get_color_name(my_color), " (Player ID: ", my_player_id, ")")
		
		print("Local player initialized: ", name, " (", get_color_name(get_player_color(name.to_int())), " - INVISIBLE TO SELF)")
	else:
		# 他のプレイヤー（リモート）
		camera.current = false
		
		var player_id = name.to_int()
		
		# Player1（サーバー側）は表示しない
		if player_id == 1:
			mesh_instance.visible = false
			# Player1のHP表示も非表示
			if $HealthBarUI:
				$HealthBarUI.visible = false
			print("Server player (Player1) - HIDDEN")
			return
		
		mesh_instance.visible = true
		
		# 他のプレイヤーにはHP表示を表示
		if $HealthBarUI:
			$HealthBarUI.visible = true
			print("Overhead health display enabled for remote player: ", name)
		
		# プレイヤーIDに基づいて色を決定
		var player_color = get_player_color(player_id)
		var new_material = StandardMaterial3D.new()
		new_material.albedo_color = player_color
		mesh_instance.set_surface_override_material(0, new_material)
		
		# 銃の色もプレイヤーの色に設定
		if gun_model:
			var gun_material = StandardMaterial3D.new()
			gun_material.albedo_color = player_color
			gun_model.set_surface_override_material(0, gun_material)
		
		
		print("Remote player initialized: ", name, " (", get_color_name(player_color), " - VISIBLE)")

# プレイヤー色管理
func get_player_color(player_id: int) -> Color:
	# プレイヤーID（ピアID）に基づいて色を決定
	var colors = [
		Color.RED,      # 赤
		Color.BLUE,     # 青  
		Color.GREEN,    # 緑
		Color.YELLOW,   # 黄
		Color.MAGENTA,  # マゼンタ
		Color.CYAN,     # シアン
		Color.ORANGE,   # オレンジ
		Color.PURPLE    # 紫
	]
	
	# プレイヤーIDを色配列のインデックスにマッピング
	var color_index = player_id % colors.size()
	return colors[color_index]

func get_color_name(color: Color) -> String:
	# 色に対応する名前を返す
	if color == Color.RED:
		return "RED"
	elif color == Color.BLUE:
		return "BLUE"
	elif color == Color.GREEN:
		return "GREEN"
	elif color == Color.YELLOW:
		return "YELLOW"
	elif color == Color.MAGENTA:
		return "MAGENTA"
	elif color == Color.CYAN:
		return "CYAN"
	elif color == Color.ORANGE:
		return "ORANGE"
	elif color == Color.PURPLE:
		return "PURPLE"
	else:
		return "UNKNOWN"

# PC/モバイル両対応 - 環境に応じてUIと操作を切り替え

func setup_mobile_ui():
	# モバイル環境またはWebの場合のみモバイルUIを表示
	if _is_touch_device():
		print("Setting up mobile UI...")
		
		# シンプルモバイルUI を読み込み
		var mobile_ui_scene = preload("res://scenes/SimpleMobileUI.tscn")
		mobile_ui = mobile_ui_scene.instantiate()
		get_tree().current_scene.add_child(mobile_ui)
		
		# シグナルを接続（シンプルUI版 - ジョイスティック、視点、ボタン）
		mobile_ui.move_input.connect(_on_mobile_move_input)
		mobile_ui.view_input.connect(_on_mobile_view_input)
		mobile_ui.shoot_pressed.connect(_on_mobile_shoot)
		mobile_ui.jump_pressed.connect(_on_mobile_jump)
		mobile_ui.dash_pressed.connect(_on_mobile_dash)
		
		print("Mobile UI setup complete!")
	else:
		print("PC environment detected - Mobile UI disabled")

func setup_game_ui():
	# GameUIを読み込み（全プレイヤーで共有、1回だけ作成）
	if get_tree().current_scene.get_node_or_null("GameUI") == null:
		var game_ui_scene = preload("res://scenes/GameUI.tscn")
		var game_ui = game_ui_scene.instantiate()
		get_tree().current_scene.add_child(game_ui)
		print("GameUI added to scene")

func _on_mobile_move_input(direction: Vector2):
	if is_multiplayer_authority():
		mobile_movement = direction
		print("Mobile move input received - direction: ", direction, " Authority: ", get_multiplayer_authority())

# シンプルUI用の視点操作処理
func _on_mobile_view_input(delta: Vector2):
	if is_multiplayer_authority():
		print("Mobile view input: ", delta)
		
		# 絶対値で回転を管理（飛ばされる問題を根本解決）
		current_y_rotation -= delta.x * 0.0024  # 感度調整（1.2倍に調整）
		current_x_rotation -= delta.y * 0.0024
		
		# 垂直回転は-90度から90度に制限
		current_x_rotation = clamp(current_x_rotation, deg_to_rad(-90), deg_to_rad(90))
		
		# 実際の回転を適用
		rotation.y = current_y_rotation
		camera.rotation.x = current_x_rotation
		# 銃の向きもカメラの上下回転に合わせる
		if gun_model:
			gun_model.rotation.x = current_x_rotation
		
		print("Camera rotation set - Y: ", current_y_rotation, " X: ", current_x_rotation)

# 旧版視点操作機能（後方互換性のため残す）
func _on_mobile_look_input(delta: Vector2):
	if is_multiplayer_authority():
		print("Mobile look input: ", delta)
		
		# 絶対値で回転を管理（飛ばされる問題を根本解決）
		current_y_rotation -= delta.x
		current_x_rotation -= delta.y
		
		# 垂直回転は-90度から90度に制限
		current_x_rotation = clamp(current_x_rotation, deg_to_rad(-90), deg_to_rad(90))
		
		# 実際の回転を適用
		rotation.y = current_y_rotation
		camera.rotation.x = current_x_rotation
		# 銃の向きもカメラの上下回転に合わせる
		if gun_model:
			gun_model.rotation.x = current_x_rotation
		
		print("Camera rotation set - Y: ", current_y_rotation, " X: ", current_x_rotation)

func _on_mobile_shoot():
	if is_multiplayer_authority():
		print("Mobile shoot triggered - calling shoot()")
		shoot()
		print("Mobile shoot completed")

var mobile_jump_requested = false

func _on_mobile_jump():
	if is_multiplayer_authority():
		print("Mobile jump triggered!")
		mobile_jump_requested = true

func _on_mobile_dash():
	if is_multiplayer_authority():
		print("Mobile dash triggered!")
		mobile_dash_requested = true

func _input(event):
	# 自分のプレイヤーのみが入力を処理
	if not is_multiplayer_authority():
		return
	
	# PC環境でのマウス視点操作
	if event is InputEventMouseMotion and not _is_mobile_platform():
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			# 絶対値で回転を管理
			current_y_rotation -= event.relative.x * mouse_sensitivity
			current_x_rotation -= event.relative.y * mouse_sensitivity
			
			# 垂直回転は-90度から90度に制限
			current_x_rotation = clamp(current_x_rotation, deg_to_rad(-90), deg_to_rad(90))
			
			# 実際の回転を適用
			rotation.y = current_y_rotation
			camera.rotation.x = current_x_rotation
			# 銃の向きもカメラの上下回転に合わせる
			if gun_model:
				gun_model.rotation.x = current_x_rotation
	
	# PC用の射撃操作（タッチデバイスでは無効）
	if event.is_action_pressed("shootAction") and not _is_touch_device():
		shoot()
	
	# PC用のダッシュ操作（Shiftキー、タッチデバイスでは無効）
	if event.is_action_pressed("run") and not _is_touch_device():
		try_dash()
	
	# ESCキーでマウスモード切り替え（PC環境のみ）
	if event.is_action_pressed("ui_cancel") and not _is_mobile_platform():
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# タッチイベントはMobileUIに任せる（処理済みにはしない）
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return

func _unhandled_input(event):
	# 自分のプレイヤーのみが入力を処理
	if not is_multiplayer_authority():
		return
		
	# すべてのタッチイベントをブロック（スマホ用アプリなのでボタンのみ）
	if event is InputEventScreenTouch:
		return

# モバイルプラットフォームかどうかを判定
func _is_mobile_platform() -> bool:
	# モバイルプラットフォームの場合
	if OS.has_feature("mobile"):
		return true
	return false

# タッチデバイスかどうかを判定（Web含む）
func _is_touch_device() -> bool:
	# Webブラウザの場合はタッチデバイスと見なす
	if OS.has_feature("web"):
		return true
	# モバイルプラットフォームの場合
	if OS.has_feature("mobile"):
		return true
	return false

func _physics_process(delta):
	if is_multiplayer_authority():
		# 死亡中は物理処理をスキップ
		if is_dead:
			return
		
		# ダッシュシステムの更新
		update_dash_system(delta)
		
		# 自分のプレイヤーのみ物理処理を行う
		handle_movement(delta)
		
		# 同期用変数を更新（毎フレーム）
		sync_position = global_position
		sync_rotation_y = rotation.y
		sync_rotation_x = current_x_rotation
		
		# RPC経由で位置を送信（より確実な方法）
		var current_peers = multiplayer.get_peers()
		if multiplayer.has_multiplayer_peer() and current_peers.size() > 0:
			# 全ピアに対してRPCを送信（ピアIDをチェックして存在する場合のみ）
			for peer_id in current_peers:
				var peer_node = get_parent().get_node_or_null(str(peer_id))
				if peer_node != null and peer_node.is_inside_tree():
					update_remote_position.rpc_id(peer_id, sync_position, sync_rotation_y, sync_rotation_x)
				else:
					# ピアが見つからない場合のデバッグ情報（頻度を下げる）
					if Engine.get_process_frames() % 300 == 0:  # 5秒に1回
						print("WARN: Peer node not found - ID:", peer_id, " Parent:", get_parent().name)
		
		# デバッグ: 同期データを送信していることを確認（頻度を下げる）
		if Engine.get_process_frames() % 300 == 0:  # 5秒に1回
			print("送信中 - Player: ", name, " Pos: ", sync_position, " Rot: ", sync_rotation_y, " Authority: ", get_multiplayer_authority(), " IsMoving: ", velocity.length() > 0.1)
	else:
		# リモートプレイヤーは同期された値を適用
		global_position = global_position.lerp(sync_position, 0.1)
		rotation.y = lerp_angle(rotation.y, sync_rotation_y, 0.1)
		
		
		# デバッグ: 同期データを受信していることを確認（頻度を下げる）
		if Engine.get_process_frames() % 300 == 0:  # 5秒に1回
			print("受信中 - Player: ", name, " 受信Pos: ", sync_position, " 現在Pos: ", global_position)

func handle_movement(delta):
	# 三段ジャンプの地面判定処理
	var is_currently_on_floor = is_on_floor()
	
	# 地面に着地した瞬間にジャンプカウントをリセット
	if is_currently_on_floor and not was_on_floor_last_frame:
		current_jump_count = 0
		print("Landed on ground! Jump count reset to: ", current_jump_count)
	
	was_on_floor_last_frame = is_currently_on_floor
	
	# 重力を適用
	if not is_currently_on_floor:
		velocity.y += get_gravity().y * delta
	
	# 三段ジャンプ処理（PC: スペース / タッチデバイス: ボタン）
	var should_jump = false
	if not _is_touch_device():
		# PC環境：スペースキーが押された瞬間をチェック
		should_jump = Input.is_action_just_pressed("jump")
	else:
		# タッチデバイス環境：ボタンが押された瞬間
		should_jump = mobile_jump_requested
		
	if should_jump and current_jump_count < max_jump_count:
		# ジャンプ回数に応じて威力を調整
		var jump_power = jump_velocity
		if current_jump_count == 1:
			jump_power = second_jump_velocity
		elif current_jump_count == 2:
			jump_power = third_jump_velocity
		
		velocity.y = jump_power
		current_jump_count += 1
		mobile_jump_requested = false  # モバイル用リセット
		
		print("Jump executed! Count: ", current_jump_count, "/", max_jump_count, " Power: ", jump_power)
		
		# ジャンプ回数UIを更新
		update_jump_display()
	elif should_jump:
		print("Cannot jump - already used all ", max_jump_count, " jumps")
		mobile_jump_requested = false  # モバイル用リセット

	# 移動入力を取得
	var input_dir = Vector2.ZERO
	
	if not _is_touch_device():
		# PC環境：WASD入力
		input_dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		input_dir.y = Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward")
	else:
		# タッチデバイス環境：ジョイスティック入力
		input_dir = mobile_movement
		# デバッグ出力を追加（頻度を下げる）
		if Engine.get_process_frames() % 60 == 0:  # 1秒に1回
			print("Touch device movement - mobile_movement: ", mobile_movement, " input_dir: ", input_dir)
	
	# ダッシュ処理（PC・モバイル両対応）
	var dash_requested = false
	if not _is_touch_device():
		# PC環境では何もしない（Shiftは走りで使用）
		pass
	else:
		# タッチデバイス環境：ダッシュボタン
		dash_requested = mobile_dash_requested
		mobile_dash_requested = false  # リセット
	
	if dash_requested:
		try_dash()
	
	# 移動速度を決定
	var current_speed = walk_speed
	if not _is_touch_device() and Input.is_action_pressed("run") and not is_dashing:
		current_speed = run_speed
	elif is_dashing:
		current_speed = dash_speed
	
	# プレイヤーの向きに基づいて移動方向を計算
	var direction = Vector3.ZERO
	if is_dashing:
		# ダッシュ中は保存された方向を使用
		direction = dash_direction
	elif input_dir != Vector2.ZERO:
		direction = global_basis * Vector3(input_dir.x, 0, input_dir.y)
		direction = direction.normalized()
	
	# 移動を適用
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		if not is_dashing:
			velocity.x = move_toward(velocity.x, 0, current_speed * delta * 3)
			velocity.z = move_toward(velocity.z, 0, current_speed * delta * 3)

	# 物理移動実行
	move_and_slide()
	
	# 拾える弾をチェック（プレイヤーの当たり判定を拡大して検出）
	check_nearby_pickable_bullets()

# ダッシュシステム関数群
func update_dash_system(delta):
	# ダッシュチャージを回復（ダッシュ中でない時のみ）
	if not is_dashing and dash_charge < dash_charge_time:
		dash_charge = min(dash_charge + delta, dash_charge_time)
	
	# ダッシュタイマー更新
	if is_dashing:
		dash_timer += delta
		if dash_timer >= dash_duration:
			stop_dash()
	
	# ダッシュチャージのUI更新
	update_dash_display()

func try_dash():
	# 死亡中、ダッシュ中、チャージが足りない場合は実行しない
	if is_dead or is_dashing or dash_charge < dash_charge_time:
		return
	
	# 現在の移動方向を取得
	var input_dir = Vector2.ZERO
	if not _is_touch_device():
		# PC環境：WASD入力
		input_dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		input_dir.y = Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward")
	else:
		# タッチデバイス環境：ジョイスティック入力
		input_dir = mobile_movement
	
	# 入力がない場合は前方にダッシュ
	if input_dir == Vector2.ZERO:
		input_dir = Vector2(0, -1)  # 前方
	
	# ダッシュ方向を設定
	dash_direction = global_basis * Vector3(input_dir.x, 0, input_dir.y)
	dash_direction = dash_direction.normalized()
	
	# ダッシュ開始
	is_dashing = true
	dash_timer = 0.0
	dash_charge = 0.0  # チャージ消費
	
	print("Dash started! Direction: ", dash_direction, " Speed: ", dash_speed)

func stop_dash():
	is_dashing = false
	dash_timer = 0.0
	dash_direction = Vector3.ZERO
	print("Dash ended")

# 銃の反動アニメーション関数
func play_gun_recoil():
	if not gun_model:
		print("ERROR: gun_model not found - cannot play recoil animation")
		return
	
	print("Playing gun recoil animation - Original pos: ", gun_original_position, " Current pos: ", gun_model.position)
	
	# 既存のアニメーションを停止
	if gun_recoil_tween:
		gun_recoil_tween.kill()
	
	# 連射対策: 銃を強制的に元の位置に戻す（回転はカメラに合わせる）
	gun_model.position = gun_original_position
	# 銃の回転はカメラの上下回転に合わせる（視点移動でセットされた現在の回転を維持）
	gun_model.rotation.x = current_x_rotation
	
	# 新しいTweenを作成（シーケンシャル）
	gun_recoil_tween = create_tween()
	
	# 反動アニメーション：銃の現在の向きでの後ろ向きに移動
	# 銃の現在のtransformを使って後ろ向きベクトルを計算
	var gun_backward = gun_model.transform.basis.z  # 銃の後ろ向き（Z軸正方向）
	var recoil_direction = gun_backward * (-RECOIL_DISTANCE)  # 銃の向きの後ろ向きに反動
	var recoil_position = gun_original_position + recoil_direction
	print("Recoil animation - Gun backward: ", gun_backward, " Recoil direction: ", recoil_direction, " Moving to: ", recoil_position)
	
	# 現在のカメラ回転を基準に反動回転を計算（カメラの向きに合わせる）
	var current_gun_rotation = gun_model.rotation
	var recoil_rotation = Vector3(current_x_rotation + RECOIL_ROTATION, 0, 0)  # 現在のカメラ回転 + 約8.6度上向き
	var return_rotation = Vector3(current_x_rotation, 0, 0)  # 元のカメラ回転に戻る
	print("Recoil animation - Current rotation: ", current_gun_rotation, " Recoil rotation: ", recoil_rotation, " Return rotation: ", return_rotation)
	
	# 位置のアニメーション：後退 → 復帰（チェーン）
	gun_recoil_tween.tween_property(gun_model, "position", recoil_position, RECOIL_DURATION)
	gun_recoil_tween.tween_property(gun_model, "position", gun_original_position, RECOIL_RETURN_DURATION)
	
	# 回転用の別のTweenを作成（パラレル）- カメラの回転に合わせる
	var rotation_tween = create_tween()
	rotation_tween.tween_property(gun_model, "rotation", recoil_rotation, RECOIL_DURATION * 0.7)
	rotation_tween.tween_property(gun_model, "rotation", return_rotation, RECOIL_RETURN_DURATION * 1.2)

# 銃の色をリセットする関数
func _reset_gun_color():
	if gun_model:
		# 元の灰色マテリアルに戻す
		var original_material = StandardMaterial3D.new()
		original_material.albedo_color = Color(0.3, 0.3, 0.3, 1)  # 元の灰色
		gun_model.set_surface_override_material(0, original_material)
		print("Gun color reset to original gray")

func shoot():
	# 死亡中は射撃できない
	if is_dead:
		return
	
	# 弾がない場合は射撃できない
	if current_ammo <= 0:
		print("No ammo! Cannot shoot. Current ammo: ", current_ammo)
		return
	
	print("===== SHOOT FUNCTION CALLED =====")
	print("Player: ", name, " Authority: ", is_multiplayer_authority())
	
	# 反動アニメーションを再生
	play_gun_recoil()
	
	# 弾数を減らす
	current_ammo -= 1
	print("Shot fired! Ammo remaining: ", current_ammo, "/", max_ammo)
	
	# 銃の反動アニメーションを再生
	play_gun_recoil()
	
	# 弾数表示を更新
	update_ammo_display()
	
	# 弾数に応じて銃の色を更新
	update_gun_color_based_on_ammo()
	
	# 射撃位置と方向を計算（銃の先端から）
	var shoot_position = gun_tip.global_position
	var shoot_direction = -camera.global_transform.basis.z
	var shooter_id = name.to_int()
	
	# ローカルで弾丸を生成（自分の色）
	_spawn_bullet(shoot_position, shoot_direction, shooter_id)
	
	# 他のプレイヤーにも弾丸を生成させる
	var current_peers = multiplayer.get_peers()
	if multiplayer.has_multiplayer_peer() and current_peers.size() > 0:
		# 全ピアに対してRPCを送信
		for peer_id in current_peers:
			var peer_node = get_parent().get_node_or_null(str(peer_id))
			if peer_node != null and peer_node.is_inside_tree():
				spawn_bullet_remote.rpc_id(peer_id, shoot_position, shoot_direction, shooter_id)
			else:
				print("WARN: Cannot send bullet RPC - Peer node not found (ID: ", peer_id, ")")

# 弾丸を実際に生成する関数
func _spawn_bullet(position: Vector3, direction: Vector3, player_id: int = -1):
	var bullet = bullet_scene.instantiate()
	get_parent().add_child(bullet)
	bullet.global_position = position
	bullet.set_velocity(direction)
	
	# プレイヤーの色に合わせて弾丸の色を設定
	var bullet_player_id = player_id
	if bullet_player_id == -1:
		bullet_player_id = name.to_int()  # 自分のIDを使用
	
	# 射撃者IDを設定（重要：ダメージ処理で使用）
	bullet.shooter_id = bullet_player_id
	
	var player_color = get_player_color(bullet_player_id)
	bullet.set_bullet_color(player_color)
	
	print("Spawned bullet - Shooter ID: ", bullet_player_id, " Color: ", get_color_name(player_color))

# RPC関数：位置同期を受信
@rpc("any_peer", "unreliable")
func update_remote_position(new_position: Vector3, new_rotation_y: float, new_rotation_x: float = 0.0):
	# 権限チェック：自分の位置は更新しない
	if not is_multiplayer_authority():
		# ノードがシーンツリーに正しく存在することを確認
		if is_inside_tree():
			sync_position = new_position
			sync_rotation_y = new_rotation_y
			sync_rotation_x = new_rotation_x
		else:
			print("ERROR: Received RPC for node not in tree: ", name)

# RPC関数：他のプレイヤーの弾丸を生成
@rpc("any_peer", "reliable")
func spawn_bullet_remote(position: Vector3, direction: Vector3, shooter_id: int):
	# ノードがシーンツリーに正しく存在することを確認
	if is_inside_tree():
		# 他のプレイヤーの弾丸を生成（射撃者の色で）
		_spawn_bullet(position, direction, shooter_id)
	else:
		print("ERROR: Received bullet RPC for node not in tree: ", name)

# HPシステム関数群
func take_damage(amount: int):
	print("=== TAKE DAMAGE CALLED ===")
	print("Player: ", name, " is_dead: ", is_dead, " current_health: ", current_health)
	print("Damage amount: ", amount)
	
	if is_dead:
		print("Player is already dead - ignoring damage")
		return
	
	current_health -= amount
	print("Player ", name, " took ", amount, " damage. Health: ", current_health, "/", max_health)
	
	# プレイヤー上部のHP表示を更新
	update_overhead_health_display()
	
	if current_health <= 0:
		print("Player health reached 0 - calling die()")
		die()
	else:
		print("Player still alive with ", current_health, " HP")

func die():
	if is_dead:
		return
		
	is_dead = true
	current_health = 0
	print("Player ", name, " died!")
	
	# ローカルプレイヤーのみ死亡シーンに切り替え
	if is_multiplayer_authority():
		# 現在のシーンパスを保存
		var current_scene_path = get_tree().current_scene.scene_file_path
		if current_scene_path == "":
			current_scene_path = "res://scenes/TestLevel.tscn"  # フォールバック
		
		print("Switching to death scene - current scene: ", current_scene_path)
		
		# 死亡シーンに切り替える前に現在のシーンパスを保存
		var death_scene = preload("res://scenes/DeathScene.tscn")
		var death_instance = death_scene.instantiate()
		death_instance.set_original_scene(current_scene_path)
		
		# シーンを切り替え
		get_tree().current_scene.queue_free()
		get_tree().root.add_child(death_instance)
		get_tree().current_scene = death_instance
	else:
		# リモートプレイヤーは従来通りの処理
		set_physics_process(false)
		visible = false
		
		# 3秒後にリスポーン
		respawn_timer = Timer.new()
		respawn_timer.wait_time = 3.0
		respawn_timer.one_shot = true
		respawn_timer.timeout.connect(respawn)
		add_child(respawn_timer)
		respawn_timer.start()
		
		print("Remote player death - respawn timer started")

func respawn():
	print("Player ", name, " respawning...")
	
	# HPを回復
	current_health = max_health
	is_dead = false
	
	# 弾数を回復
	current_ammo = max_ammo
	
	# プレイヤーを再有効化
	set_physics_process(true)
	visible = true
	
	# スポーン位置にリセット（今は元の位置に戻す）
	global_position = Vector3(0, 2, 0)
	velocity = Vector3.ZERO
	
	# プレイヤー上部のHP表示を更新
	update_overhead_health_display()
	
	# 弾数表示を更新
	update_ammo_display()
	
	# 弾数に応じて銃の色を更新
	update_gun_color_based_on_ammo()
	
	# タイマーを削除
	if respawn_timer:
		respawn_timer.queue_free()
		respawn_timer = null
	
	print("Player ", name, " respawned with full health and ammo")

func get_health() -> int:
	return current_health

func get_max_health() -> int:
	return max_health

# 死亡シーンから戻ってきた時のリスポーン処理
func handle_respawn_return():
	print("Player returned from death scene - performing respawn")
	
	# HPを完全回復
	current_health = max_health
	is_dead = false
	
	# 弾数を完全回復
	current_ammo = max_ammo
	
	# スポーン位置にリセット
	global_position = RespawnManager.get_respawn_position()
	velocity = Vector3.ZERO
	
	# プレイヤーを有効化
	set_physics_process(true)
	visible = true
	
	# プレイヤー上部のHP表示を更新
	update_overhead_health_display()
	
	# 弾数表示を更新
	update_ammo_display()
	
	# 弾数に応じて銃の色を更新
	update_gun_color_based_on_ammo()
	
	# リスポーンフラグをクリア
	RespawnManager.clear_respawn_flag()
	
	print("Player respawned successfully at position: ", global_position)

# プレイヤー上部のHP表示を更新する関数
func update_overhead_health_display():
	# ノードが存在するかチェック
	if health_bar_ui == null or health_label_ui == null:
		return
	
	# HPバーの値を更新
	health_bar_ui.max_value = max_health
	health_bar_ui.value = current_health
	
	# HPラベルの文字を更新
	health_label_ui.text = str(current_health)
	
	# HPバーの色を体力に応じて変更
	var health_percentage = float(current_health) / float(max_health)
	var bar_color = Color.WHITE
	
	if health_percentage <= 0.25:
		bar_color = Color.RED
	elif health_percentage <= 0.5:
		bar_color = Color.ORANGE
	elif health_percentage <= 0.75:
		bar_color = Color.YELLOW
	else:
		bar_color = Color.GREEN
	
	# ProgressBarの色を変更
	health_bar_ui.modulate = bar_color
	
	print("Updated overhead health display for ", name, " - HP: ", current_health, "/", max_health, " Color: ", bar_color)

# 弾数システム関数群
func setup_reload_timer():
	# リロードタイマーを作成
	reload_timer = Timer.new()
	reload_timer.wait_time = 3.0  # 3秒間隔
	reload_timer.one_shot = false  # 繰り返し実行
	reload_timer.timeout.connect(_on_reload_timer_timeout)
	add_child(reload_timer)
	reload_timer.start()
	print("Reload timer started - refill 1 ammo every 3 seconds")

func _on_reload_timer_timeout():
	# 弾数が最大でない場合のみリロード
	if current_ammo < max_ammo:
		current_ammo += 1
		print("Ammo reloaded: ", current_ammo, "/", max_ammo, " (every 3 seconds)")
	
	# GameUIがある場合は弾数表示を更新
	update_ammo_display()
	
	# 弾数に応じて銃の色を更新
	update_gun_color_based_on_ammo()

func update_ammo_display():
	# GameUIの弾数表示を更新
	var game_ui = get_tree().current_scene.get_node_or_null("GameUI")
	if game_ui and is_multiplayer_authority():
		game_ui.update_ammo_display(current_ammo, max_ammo)

func update_dash_display():
	# GameUIのダッシュチャージ表示を更新
	var game_ui = get_tree().current_scene.get_node_or_null("GameUI")
	if game_ui and is_multiplayer_authority() and game_ui.has_method("update_dash_display"):
		game_ui.update_dash_display()

func get_ammo() -> int:
	return current_ammo

func get_max_ammo() -> int:
	return max_ammo

# 弾を追加する関数（白い弾を拾った時用）
func add_ammo(amount: int):
	current_ammo = min(current_ammo + amount, max_ammo)
	print("Added ", amount, " ammo. Current ammo: ", current_ammo, "/", max_ammo)
	update_ammo_display()
	
	# 弾数に応じて銃の色を更新
	update_gun_color_based_on_ammo()

# 近くの拾える弾をチェックする関数（プレイヤーの当たり判定を拡大）
func check_nearby_pickable_bullets():
	# 自分のプレイヤーでない場合は拾わない
	if not is_multiplayer_authority():
		return
	
	# PhysicsサーバーでSphereシェイプを使って周辺の弾を検索
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	
	# 球形の検出範囲を作成（プレイヤーの当たり判定を拡大）
	var shape = SphereShape3D.new()
	shape.radius = 1.5  # プレイヤーの周辺1.5メートル以内
	query.shape = shape
	query.transform = Transform3D(Basis(), global_position)
	
	# 拾い物レイヤー（layer 8）のみを検出
	query.collision_mask = 8  # bit 3 = 8
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	# 重複検出
	var results = space_state.intersect_shape(query)
	
	# 見つかった弾を処理
	for result in results:
		var body = result["collider"]
		if body and body.has_method("_handle_collision") and body.get("is_pickable"):
			# 弾が拾える状態の場合、弾の衝突処理を呼び出す
			print("Player detected pickable bullet: ", body.name, " at distance: ", global_position.distance_to(body.global_position))
			body._handle_collision(self)
			break  # 一度に1つずつ拾う

# GameUIから呼ばれる関数群
func get_dash_charge():
	return dash_charge

func get_dash_charge_time():
	return dash_charge_time

func is_dash_active():
	return is_dashing

# ジャンプ関連のアクセサ関数群
func get_jump_count():
	return current_jump_count

func get_max_jump_count():
	return max_jump_count

func update_jump_display():
	# GameUIのジャンプ表示を更新
	var game_ui = get_tree().current_scene.get_node_or_null("GameUI")
	if game_ui and is_multiplayer_authority() and game_ui.has_method("update_jump_display"):
		game_ui.update_jump_display()

# 銃の色を弾数に基づいて更新する関数
func update_gun_color_based_on_ammo():
	print("=== update_gun_color_based_on_ammo() called ===")
	
	if not gun_model:
		print("ERROR: gun_model not found!")
		return
	
	print("gun_model found: ", gun_model.name)
	
	# 基本のプレイヤー色を取得
	var player_id = name.to_int()
	var base_color = get_player_color(player_id)
	
	# 弾数の割合を計算（0.0 から 1.0）
	var ammo_percentage = float(current_ammo) / float(max_ammo)
	
	# 弾数に応じた色と透明度の変化
	var adjusted_color: Color
	
	if ammo_percentage > 0.8:
		# 弾数80%以上：元の色（完全不透明）
		adjusted_color = base_color
	elif ammo_percentage > 0.6:
		# 弾数60-80%：少し薄く
		adjusted_color = Color(base_color.r * 0.9, base_color.g * 0.9, base_color.b * 0.9, 0.9)
	elif ammo_percentage > 0.4:
		# 弾数40-60%：もう少し薄く
		adjusted_color = Color(base_color.r * 0.8, base_color.g * 0.8, base_color.b * 0.8, 0.8)
	elif ammo_percentage > 0.2:
		# 弾数20-40%：かなり薄く
		adjusted_color = Color(base_color.r * 0.6, base_color.g * 0.6, base_color.b * 0.6, 0.6)
	else:
		# 弾数20%以下：赤色で半透明
		adjusted_color = Color(1.0, 0.2, 0.2, 0.4)
	
	
	# 銃のマテリアルを更新
	var gun_material = StandardMaterial3D.new()
	gun_material.albedo_color = adjusted_color
	
	# 透明度が1.0未満の場合、透明設定を有効にする
	if adjusted_color.a < 1.0:
		gun_material.flags_transparent = true
		gun_material.flags_unshaded = false
		gun_material.no_depth_test = false
	
	gun_model.set_surface_override_material(0, gun_material)
	
	# 現在のマテリアルも確認
	var current_material = gun_model.get_surface_override_material(0)
	if current_material:
		print("Material applied successfully. Current material color: ", current_material.albedo_color)
	else:
		print("ERROR: Failed to apply material!")
	
	print("Gun color updated - Ammo: ", current_ammo, "/", max_ammo, " (", int(ammo_percentage * 100), "%)")
	print("Base color: ", base_color, " -> Adjusted color: ", adjusted_color)
	print("=== End update_gun_color_based_on_ammo() ===")
