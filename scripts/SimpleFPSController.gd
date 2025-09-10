extends CharacterBody3D

@export var walk_speed = 5.0
@export var run_speed = 8.0
@export var jump_velocity = 8.0
@export var mouse_sensitivity = 0.002

# 同期用プロパティ（RPC同期で使用）
@export var sync_position := Vector3.ZERO
@export var sync_rotation_y := 0.0

@onready var camera = $CameraHolder/Camera3D
@onready var camera_holder = $CameraHolder
@onready var mesh_instance = $MeshInstance3D

# 弾丸のプリロード
var bullet_scene = preload("res://scenes/Bullet.tscn")

# モバイル入力関連
var mobile_movement = Vector2.ZERO
var mobile_ui: CanvasLayer = null

func _ready():
	# マルチプレイヤーのピアが存在するまで待機
	await get_tree().process_frame
	
	# peer_idを取得してノード名に設定（重要：ユニークにするため）
	var peer_id = name.to_int()
	set_multiplayer_authority(peer_id)
	
	# 初期位置を設定（重要！）
	sync_position = global_position
	sync_rotation_y = rotation.y
	
	# MultiplayerSynchronizerの設定
	call_deferred("setup_multiplayer")
	
	print("Player _ready: ", name, " Authority: ", get_multiplayer_authority(), " Position: ", global_position)

func setup_multiplayer():
	# 権限に基づいて初期化
	if is_multiplayer_authority():
		# 自分のプレイヤー（ローカル）
		setup_mobile_ui()
		setup_game_ui()
		
		# マウス入力がある場合はマウスをキャプチャ
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		
		camera.current = true
		mesh_instance.visible = false
		print("Local player initialized: ", name, " (BLUE - INVISIBLE TO SELF)")
	else:
		# 他のプレイヤー（リモート）
		camera.current = false
		# 赤色マテリアル適用
		var new_material = StandardMaterial3D.new()
		new_material.albedo_color = Color.RED
		mesh_instance.set_surface_override_material(0, new_material)
		print("Remote player initialized: ", name, " (RED - VISIBLE)")

# _is_mobile()関数は削除済み - 常にモバイルUIを表示

func setup_mobile_ui():
	print("Setting up mobile UI (always enabled)...")
	
	# モバイルUI を読み込み
	var mobile_ui_scene = preload("res://scenes/MobileUI.tscn")
	mobile_ui = mobile_ui_scene.instantiate()
	get_tree().current_scene.add_child(mobile_ui)
	
	# シグナルを接続
	mobile_ui.move_input.connect(_on_mobile_move_input)
	mobile_ui.look_input.connect(_on_mobile_look_input)
	mobile_ui.shoot_pressed.connect(_on_mobile_shoot)
	mobile_ui.jump_pressed.connect(_on_mobile_jump)
	
	print("Mobile UI setup complete!")
	print("Mobile UI signals connected:")
	print("  - move_input: ", mobile_ui.move_input.is_connected(_on_mobile_move_input))
	print("  - look_input: ", mobile_ui.look_input.is_connected(_on_mobile_look_input))
	print("  - shoot_pressed: ", mobile_ui.shoot_pressed.is_connected(_on_mobile_shoot))
	print("  - jump_pressed: ", mobile_ui.jump_pressed.is_connected(_on_mobile_jump))

func setup_game_ui():
	# GameUIを読み込み（全プレイヤーで共有、1回だけ作成）
	if get_tree().current_scene.get_node_or_null("GameUI") == null:
		var game_ui_scene = preload("res://scenes/GameUI.tscn")
		var game_ui = game_ui_scene.instantiate()
		get_tree().current_scene.add_child(game_ui)
		print("GameUI added to scene")

func _on_mobile_move_input(direction: Vector2):
	mobile_movement = direction
	print("Mobile move input: ", direction)

func _on_mobile_look_input(delta: Vector2):
	if is_multiplayer_authority():
		# マウス操作と同じロジック
		rotate_y(-delta.x)
		camera.rotate_x(-delta.y)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))

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

func _input(event):
	# 自分のプレイヤーのみが入力を処理
	if not is_multiplayer_authority():
		return
	
	# マウス操作（PCとタッチ両対応）
	if event is InputEventMouseMotion:
		# マウスでカメラ回転
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))
	
	if event.is_action_pressed("mouseMode"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# キーボード・マウス射撃
	if event.is_action_pressed("shoot"):
		shoot()

func _physics_process(delta):
	if is_multiplayer_authority():
		# 自分のプレイヤーのみ物理処理を行う
		handle_movement(delta)
		
		# 同期用変数を更新（毎フレーム）
		sync_position = global_position
		sync_rotation_y = rotation.y
		
		# RPC経由で位置を送信（確実に全員に届ける）
		if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
			update_remote_position.rpc(sync_position, sync_rotation_y)
		
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
	# 重力を適用
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	
	# ジャンプ（PC + モバイル対応）
	var should_jump = (Input.is_action_just_pressed("jump") or mobile_jump_requested) and is_on_floor()
	if should_jump:
		velocity.y = jump_velocity
		mobile_jump_requested = false  # リセット

	# 移動入力を取得（PC＋モバイル対応）
	var input_dir = Vector2.ZERO
	
	# PC入力
	if Input.is_action_pressed("move_forward"):
		input_dir.y -= 1
	if Input.is_action_pressed("move_backward"):
		input_dir.y += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1
	
	# モバイル入力を追加（常に有効）
	if mobile_movement != Vector2.ZERO:
		input_dir = mobile_movement
	
	# 移動速度を決定
	var current_speed = run_speed if Input.is_action_pressed("run") else walk_speed
	
	# プレイヤーの向きに基づいて移動方向を計算
	var direction = Vector3.ZERO
	if input_dir != Vector2.ZERO:
		direction = global_basis * Vector3(input_dir.x, 0, input_dir.y)
		direction = direction.normalized()
	
	# 移動を適用
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed * delta * 3)
		velocity.z = move_toward(velocity.z, 0, current_speed * delta * 3)

	# 物理移動実行
	move_and_slide()

func shoot():
	# 射撃位置と方向を計算
	var shoot_position = camera.global_position + camera.global_transform.basis.z * -0.5
	var shoot_direction = -camera.global_transform.basis.z
	
	# ローカルで弾丸を生成
	_spawn_bullet(shoot_position, shoot_direction)
	
	# 他のプレイヤーにも弾丸を生成させる
	if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
		spawn_bullet_remote.rpc(shoot_position, shoot_direction)

# 弾丸を実際に生成する関数
func _spawn_bullet(position: Vector3, direction: Vector3):
	var bullet = bullet_scene.instantiate()
	get_parent().add_child(bullet)
	bullet.global_position = position
	bullet.set_velocity(direction)

# RPC関数：位置同期を受信
@rpc("any_peer", "unreliable")
func update_remote_position(new_position: Vector3, new_rotation: float):
	# 権限チェック：自分の位置は更新しない
	if not is_multiplayer_authority():
		sync_position = new_position
		sync_rotation_y = new_rotation

# RPC関数：他のプレイヤーの弾丸を生成
@rpc("any_peer", "reliable")
func spawn_bullet_remote(position: Vector3, direction: Vector3):
	# 他のプレイヤーの弾丸を生成
	_spawn_bullet(position, direction)
