extends CharacterBody3D

@export var walk_speed = 5.0
@export var run_speed = 8.0
@export var jump_velocity = 8.0
@export var mouse_sensitivity = 0.002

# 同期用プロパティ（MultiplayerSynchronizerで使用）
@export var sync_position := Vector3.ZERO
@export var sync_rotation_y := 0.0

@onready var camera = $CameraHolder/Camera3D
@onready var camera_holder = $CameraHolder
@onready var mesh_instance = $MeshInstance3D
@onready var multiplayer_synchronizer = $MultiplayerSynchronizer

# 弾丸のプリロード
var bullet_scene = preload("res://scenes/Bullet.tscn")

func _ready():
	# マルチプレイヤーのピアが存在するまで待機
	await get_tree().process_frame
	
	# peer_idを取得してノード名に設定（重要：ユニークにするため）
	var peer_id = name.to_int()
	set_multiplayer_authority(peer_id)
	
	# MultiplayerSynchronizerの設定
	call_deferred("setup_multiplayer")
	
	print("Player _ready: ", name, " Authority: ", get_multiplayer_authority())

func setup_multiplayer():
	if multiplayer_synchronizer:
		multiplayer_synchronizer.public_visibility = true
	
	# 権限に基づいて初期化
	if is_multiplayer_authority():
		# 自分のプレイヤー（ローカル）
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

func _input(event):
	# 自分のプレイヤーのみが入力を処理
	if not is_multiplayer_authority():
		return
		
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
	
	# 射撃
	if event.is_action_pressed("shoot"):
		shoot()

func _physics_process(delta):
	if is_multiplayer_authority():
		# 自分のプレイヤーのみ物理処理を行う
		handle_movement(delta)
		
		# 同期用変数を更新
		sync_position = global_position
		sync_rotation_y = rotation.y
		
		# デバッグ: 同期データを送信していることを確認
		if name == "1" and Engine.get_process_frames() % 60 == 0:  # 1秒に1回
			print("送信中 - Player: ", name, " Pos: ", sync_position, " Rot: ", sync_rotation_y)
	else:
		# リモートプレイヤーは同期された値を適用
		var old_pos = global_position
		global_position = global_position.lerp(sync_position, 0.1)
		rotation.y = lerp_angle(rotation.y, sync_rotation_y, 0.1)
		
		# デバッグ: 同期データを受信していることを確認
		if name == "1" and Engine.get_process_frames() % 60 == 0:  # 1秒に1回
			print("受信中 - Player: ", name, " 受信Pos: ", sync_position, " 現在Pos: ", global_position)

func handle_movement(delta):
	# 重力を適用
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	
	# ジャンプ
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# 移動入力を取得
	var input_dir = Vector2.ZERO
	if Input.is_action_pressed("move_forward"):
		input_dir.y -= 1
	if Input.is_action_pressed("move_backward"):
		input_dir.y += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1
	
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
	var bullet = bullet_scene.instantiate()
	get_parent().add_child(bullet)
	
	# 弾丸の位置をカメラの前に設定
	bullet.global_position = camera.global_position + camera.global_transform.basis.z * -0.5
	
	# 弾丸の方向と速度を設定
	var shoot_direction = -camera.global_transform.basis.z
	bullet.set_velocity(shoot_direction)
