extends CharacterBody3D

@export var walk_speed = 5.0
@export var run_speed = 8.0
@export var jump_velocity = 8.0
@export var mouse_sensitivity = 0.002  # PC用マウス感度

# 同期用プロパティ（RPC同期で使用）
@export var sync_position := Vector3.ZERO
@export var sync_rotation_y := 0.0
@export var sync_rotation_x := 0.0

@onready var camera = $CameraHolder/Camera3D
@onready var camera_holder = $CameraHolder
@onready var mesh_instance = $MeshInstance3D
@onready var view_direction_line = $ViewDirectionLine
@onready var health_bar_ui = $HealthBarUI/SubViewport/HealthBarControl/PlayerHealthBar
@onready var health_label_ui = $HealthBarUI/SubViewport/HealthBarControl/PlayerHealthBar/PlayerHealthLabel

# 視点回転を絶対値で管理
var current_y_rotation = 0.0  # 水平回転
var current_x_rotation = 0.0  # 垂直回転

# 弾丸のプリロード
var bullet_scene = preload("res://scenes/Bullet.tscn")

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
		
		print("Local player initialized: ", name, " (BLUE - INVISIBLE TO SELF)")
	else:
		# 他のプレイヤー（リモート）
		camera.current = false
		
		var player_id = name.to_int()
		
		# Player1（サーバー側）は表示しない
		if player_id == 1:
			mesh_instance.visible = false
			if view_direction_line:
				view_direction_line.visible = false
			# Player1のHP表示も非表示
			if $HealthBarUI:
				$HealthBarUI.visible = false
			print("Server player (Player1) - HIDDEN")
			return
		
		mesh_instance.visible = true
		
		# 視点方向ラインを表示（他プレイヤーのみ、Player1以外）
		if view_direction_line:
			view_direction_line.visible = true
		
		# 他のプレイヤーにはHP表示を表示
		if $HealthBarUI:
			$HealthBarUI.visible = true
			print("Overhead health display enabled for remote player: ", name)
		
		# プレイヤーIDに基づいて色を決定
		var player_color = get_player_color(player_id)
		var new_material = StandardMaterial3D.new()
		new_material.albedo_color = player_color
		mesh_instance.set_surface_override_material(0, new_material)
		
		# 視点方向ラインも同じ色にする
		if view_direction_line:
			var line_material = StandardMaterial3D.new()
			line_material.albedo_color = player_color
			line_material.emission = player_color * 0.3  # 少し光らせる
			view_direction_line.set_surface_override_material(0, line_material)
		
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
	
	# PC用の射撃操作（タッチデバイスでは無効）
	if event.is_action_pressed("shootAction") and not _is_touch_device():
		shoot()
	
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
		
		# 視点方向ラインの向きを更新
		if view_direction_line and view_direction_line.visible:
			# 水平回転はプレイヤー全体と一緒に回転
			# 垂直回転は視点方向ラインだけに適用
			view_direction_line.rotation.x = sync_rotation_x
		
		# デバッグ: 同期データを受信していることを確認（頻度を下げる）
		if Engine.get_process_frames() % 300 == 0:  # 5秒に1回
			print("受信中 - Player: ", name, " 受信Pos: ", sync_position, " 現在Pos: ", global_position)

func handle_movement(delta):
	# 重力を適用
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	
	# ジャンプ処理（PC: スペース / タッチデバイス: ボタン）
	var should_jump = false
	if not _is_touch_device():
		# PC環境：スペースキー
		should_jump = Input.is_action_pressed("jump") and is_on_floor()
	else:
		# タッチデバイス環境：ボタン
		should_jump = mobile_jump_requested and is_on_floor()
		
	if should_jump:
		velocity.y = jump_velocity
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
	
	# 移動速度を決定
	var current_speed = walk_speed
	if not _is_touch_device() and Input.is_action_pressed("run"):
		current_speed = run_speed
	
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
	# 死亡中は射撃できない
	if is_dead:
		return
	
	# 弾がない場合は射撃できない
	if current_ammo <= 0:
		print("No ammo! Cannot shoot. Current ammo: ", current_ammo)
		return
		
	# 弾数を減らす
	current_ammo -= 1
	print("Shot fired! Ammo remaining: ", current_ammo, "/", max_ammo)
	
	# 弾数表示を更新
	update_ammo_display()
	
	# 射撃位置と方向を計算
	var shoot_position = camera.global_position + camera.global_transform.basis.z * -0.5
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

func update_ammo_display():
	# GameUIの弾数表示を更新
	var game_ui = get_tree().current_scene.get_node_or_null("GameUI")
	if game_ui and is_multiplayer_authority():
		game_ui.update_ammo_display(current_ammo, max_ammo)

func get_ammo() -> int:
	return current_ammo

func get_max_ammo() -> int:
	return max_ammo

# 弾を追加する関数（白い弾を拾った時用）
func add_ammo(amount: int):
	current_ammo = min(current_ammo + amount, max_ammo)
	print("Added ", amount, " ammo. Current ammo: ", current_ammo, "/", max_ammo)
	update_ammo_display()
