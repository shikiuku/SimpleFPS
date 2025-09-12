extends CharacterBody3D

@export var walk_speed = 5.0
@export var run_speed = 8.0
@export var jump_velocity = 8.0
# @export var mouse_sensitivity = 0.002  # 視点操作機能削除

# 同期用プロパティ（RPC同期で使用）
@export var sync_position := Vector3.ZERO
@export var sync_rotation_y := 0.0

@onready var camera = $CameraHolder/Camera3D
@onready var camera_holder = $CameraHolder
@onready var mesh_instance = $MeshInstance3D

# 視点回転を絶対値で管理
var current_y_rotation = 0.0  # 水平回転
var current_x_rotation = 0.0  # 垂直回転

# 弾丸のプリロード
var bullet_scene = preload("res://scenes/Bullet.tscn")

# モバイル入力関連
var mobile_movement = Vector2.ZERO
var mobile_ui: Control = null

func _ready():
	# マルチプレイヤーのピアが存在するまで待機
	await get_tree().process_frame
	
	# peer_idを取得してノード名に設定（重要：ユニークにするため）
	var peer_id = name.to_int()
	set_multiplayer_authority(peer_id)
	
	# 初期位置を設定（重要！）
	sync_position = global_position
	sync_rotation_y = rotation.y
	
	# 視点回転の初期値を設定
	current_y_rotation = rotation.y
	current_x_rotation = camera.rotation.x
	
	# MultiplayerSynchronizerの設定
	call_deferred("setup_multiplayer")
	
	print("Player _ready: ", name, " Authority: ", get_multiplayer_authority(), " Position: ", global_position)

func setup_multiplayer():
	# 権限に基づいて初期化
	if is_multiplayer_authority():
		# 自分のプレイヤー（ローカル）
		setup_mobile_ui()
		setup_game_ui()
		
		# スマホ版専用のため、マウスモード設定は不要
		
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
	
	# シンプルモバイルUI を読み込み（ボタンなし版）
	var mobile_ui_scene = preload("res://scenes/SimpleMobileUI.tscn")
	mobile_ui = mobile_ui_scene.instantiate()
	get_tree().current_scene.add_child(mobile_ui)
	
	# シグナルを接続（シンプルUI版 - ジョイスティック、視点、ボタン）
	mobile_ui.move_input.connect(_on_mobile_move_input)
	mobile_ui.view_input.connect(_on_mobile_view_input)
	mobile_ui.shoot_pressed.connect(_on_mobile_shoot)
	mobile_ui.jump_pressed.connect(_on_mobile_jump)
	
	print("Simple Mobile UI setup complete!")
	print("Simple Mobile UI signals connected:")
	print("  - move_input: ", mobile_ui.move_input.is_connected(_on_mobile_move_input))
	print("  - view_input: ", mobile_ui.view_input.is_connected(_on_mobile_view_input))
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

# シンプルUI用の視点操作処理
func _on_mobile_view_input(delta: Vector2):
	if is_multiplayer_authority():
		print("Mobile view input: ", delta)
		
		# 絶対値で回転を管理（飛ばされる問題を根本解決）
		current_y_rotation -= delta.x * 0.002  # 感度調整
		current_x_rotation -= delta.y * 0.002
		
		# 垂直回転は-90度から90度に制限
		current_x_rotation = clamp(current_x_rotation, deg_to_rad(-90), deg_to_rad(90))
		
		# 実際の回転を適用
		rotation.y = current_y_rotation
		camera.rotation.x = current_x_rotation
		
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

func _input(event):
	# 自分のプレイヤーのみが入力を処理
	if not is_multiplayer_authority():
		return
	
	# PC用の射撃操作を削除 - モバイルボタンのみ使用
	# if event.is_action_pressed("shootAction"):
	# 	shoot()
	
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

# タッチデバイスかどうかを判定
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
		# 自分のプレイヤーのみ物理処理を行う
		handle_movement(delta)
		
		# 同期用変数を更新（毎フレーム）
		sync_position = global_position
		sync_rotation_y = rotation.y
		
		# RPC経由で位置を送信（より確実な方法）
		var current_peers = multiplayer.get_peers()
		if multiplayer.has_multiplayer_peer() and current_peers.size() > 0:
			# 全ピアに対してRPCを送信（ピアIDをチェックして存在する場合のみ）
			for peer_id in current_peers:
				var peer_node = get_parent().get_node_or_null(str(peer_id))
				if peer_node != null and peer_node.is_inside_tree():
					update_remote_position.rpc_id(peer_id, sync_position, sync_rotation_y)
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
	# 重力を適用
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	
	# ジャンプ（モバイルのみ）
	var should_jump = mobile_jump_requested and is_on_floor()
	if should_jump:
		velocity.y = jump_velocity
		mobile_jump_requested = false  # リセット

	# 移動入力を取得（モバイルのみ）
	var input_dir = Vector2.ZERO
	
	# モバイル入力のみ使用
	if mobile_movement != Vector2.ZERO:
		input_dir = mobile_movement
	
	# 移動速度を決定（常に歩行速度）
	var current_speed = walk_speed
	
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
	var current_peers = multiplayer.get_peers()
	if multiplayer.has_multiplayer_peer() and current_peers.size() > 0:
		# 全ピアに対してRPCを送信
		for peer_id in current_peers:
			var peer_node = get_parent().get_node_or_null(str(peer_id))
			if peer_node != null and peer_node.is_inside_tree():
				spawn_bullet_remote.rpc_id(peer_id, shoot_position, shoot_direction)
			else:
				print("WARN: Cannot send bullet RPC - Peer node not found (ID: ", peer_id, ")")

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
		# ノードがシーンツリーに正しく存在することを確認
		if is_inside_tree():
			sync_position = new_position
			sync_rotation_y = new_rotation
		else:
			print("ERROR: Received RPC for node not in tree: ", name)

# RPC関数：他のプレイヤーの弾丸を生成
@rpc("any_peer", "reliable")
func spawn_bullet_remote(position: Vector3, direction: Vector3):
	# ノードがシーンツリーに正しく存在することを確認
	if is_inside_tree():
		# 他のプレイヤーの弾丸を生成
		_spawn_bullet(position, direction)
	else:
		print("ERROR: Received bullet RPC for node not in tree: ", name)
