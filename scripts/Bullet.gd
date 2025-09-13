extends RigidBody3D

@export var speed = 30.0
@export var lifetime = 30.0  # 30秒に延長
@export var damage = 25  # 1発25ダメージ（4発で倒せる）
@export var fade_start_time = 4.0  # 4秒後からフェード開始

var direction = Vector3.ZERO
var shooter_id = -1  # 射撃者のID
var original_color = Color.WHITE  # 元の色を保存
var is_pickable = false  # 拾えるかどうか
var lifetime_timer = 0.0  # 経過時間を追跡

@onready var mesh_instance = $MeshInstance3D

func _ready():
	# 一定時間後に削除
	var timer = Timer.new()
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.connect("timeout", _on_lifetime_timeout)
	add_child(timer)
	timer.start()
	
	# RigidBody3Dでは_integrate_forcesで衝突検出
	
	# 衝突レイヤーを設定（弾丸レイヤー）
	# layer 3 = bit 2 = 4, layer 1 = bit 0 = 1, layer 2 = bit 1 = 2
	collision_layer = 4  # layer 3 (Projectiles)
	collision_mask = 3   # layer 1 (Player = bit 0) + layer 2 (Environment = bit 1)
	
	# RigidBody3Dの設定
	gravity_scale = 1.0   # リアルな弾道 - 重力の影響を受ける
	continuous_cd = true  # 連続衝突検出を有効化
	contact_monitor = true  # 接触監視を有効化
	max_contacts_reported = 10  # 最大接触報告数
	
	# フレーム遅延後に再度確実に設定（Godotの初期化順序問題を回避）
	call_deferred("_ensure_physics_settings")
	
	print("Bullet initialized - collision_layer: ", collision_layer, " collision_mask: ", collision_mask)
	print("Binary representation - layer: ", String.num(collision_layer, 2), " mask: ", String.num(collision_mask, 2))

func _ensure_physics_settings():
	# 物理設定を確実に適用
	collision_layer = 4
	collision_mask = 3
	gravity_scale = 1.0
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 10
	print("Physics settings ensured - gravity_scale: ", gravity_scale, " contact_monitor: ", contact_monitor)

# レイキャストを使った追加の衝突検出
var last_position = Vector3.ZERO

func check_raycast_collision():
	if last_position == Vector3.ZERO:
		last_position = global_position
		return
		
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(last_position, global_position)
	query.collision_mask = 3  # PlayerとEnvironmentレイヤー
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	var result = space_state.intersect_ray(query)
	if result:
		print("Raycast hit: ", result.collider.name)
		_handle_collision(result.collider)
	
	last_position = global_position

func _physics_process(delta):
	# 地面の下に落ちすぎたら削除
	if global_position.y < -50:
		queue_free()
		return
	
	# 経過時間を更新
	lifetime_timer += delta
	
	# 4秒経ったら一気に白くして拾えるようにする
	if lifetime_timer >= fade_start_time and not is_pickable:
		# 一気に白くする
		if mesh_instance:
			var material = mesh_instance.get_surface_override_material(0)
			if material:
				material.albedo_color = Color.WHITE
				material.emission = Color.WHITE * 0.1  # 少し光らせる
		
		# 拾えるようにする
		is_pickable = true
		# 衝突マスクにプレイヤーレイヤーを追加（拾われる用）
		collision_layer = collision_layer | 8  # 拾い物レイヤーを追加
		
		# 弾の当たり判定は元のまま（浮かないようにするため）
		print("Bullet collision stays at original size to prevent floating")
		
		print("Bullet turned white instantly and is now pickable (after 4 seconds)")
	
	# レイキャスト衝突検出
	if not has_hit and not is_pickable:  # 拾える状態になったら攻撃判定を無効化
		check_raycast_collision()

func set_velocity(dir: Vector3):
	linear_velocity = dir * speed

func _on_lifetime_timeout():
	queue_free()

# プレイヤーの色に合わせて弾丸の色を設定
func set_bullet_color(color: Color):
	original_color = color  # 元の色を保存
	if mesh_instance:
		var material = StandardMaterial3D.new()
		material.albedo_color = color
		material.emission = color * 0.3  # 少し光らせる
		mesh_instance.set_surface_override_material(0, material)

var has_hit = false  # 一度だけヒット処理をするフラグ

func _integrate_forces(state):
	# 衝突を検出
	var contact_count = state.get_contact_count()
	
	# デバッグ: フレームごとに弾丸の状態をチェック
	if randf() < 0.01:  # 1%の確率で状態出力（スパム防止）
		print("Bullet physics update - pos: ", global_position, " vel: ", linear_velocity, " contacts: ", contact_count)
	
	if contact_count > 0:
		print("=== BULLET CONTACT DETECTED ===")
		print("Bullet has ", contact_count, " contacts at position: ", global_position)
		print("Bullet velocity: ", linear_velocity)
		
		for i in range(contact_count):
			var contact = state.get_contact_collider_object(i)
			var contact_name = contact.name if contact else "null"
			var contact_class = contact.get_class() if contact else "null"
			
			print("Contact ", i, ": ", contact_name, " (", contact_class, ")")
			if contact:
				print("Contact collision_layer: ", contact.collision_layer, " collision_mask: ", contact.collision_mask)
			
			if contact and not has_hit:
				_handle_collision(contact)
				break

func _handle_collision(body):
	if has_hit:  # すでにヒット処理済みなら無視
		return
		
	print("=== BULLET HIT ===")
	print("Bullet hit body: ", body.name, " (Type: ", body.get_class(), ")")
	print("Body collision layer: ", body.collision_layer, " mask: ", body.collision_mask)
	print("Shooter ID: ", shooter_id, " Hit body name: ", body.name)
	print("Is pickable: ", is_pickable)
	print("Body has take_damage method: ", body.has_method("take_damage"))
	print("Body is CharacterBody3D: ", body is CharacterBody3D)
	
	has_hit = true  # ヒット処理済みフラグを立てる
	
	# プレイヤーに当たった場合
	if body is CharacterBody3D and body.has_method("take_damage"):
		# 白い弾（拾える状態）の場合
		if is_pickable:
			print("=== PICKING UP WHITE BULLET ===")
			# プレイヤーに弾を補充
			if body.has_method("add_ammo"):
				body.add_ammo(1)  # 1発補充
				print("Player ", body.name, " picked up 1 ammo")
			
			# 弾回収通知を表示（ローカルプレイヤーの場合のみ）
			if body.is_multiplayer_authority():
				show_ammo_pickup_notification()
			
			# 弾を削除
			call_deferred("queue_free")
			return
		# 自分の弾が自分に当たった場合は無視
		var hit_player_id = body.name.to_int()
		print("Hit player ID: ", hit_player_id, " vs Shooter ID: ", shooter_id)
		
		if shooter_id == hit_player_id:
			print("Bullet hit shooter (", shooter_id, ") - ignoring self damage")
			has_hit = false  # 自分の弾の場合はフラグをリセット
			return
		
		print("=== DEALING DAMAGE ===")
		print("Calling take_damage with ", damage, " damage on ", body.name)
		
		# ダメージを与える前にHPをチェック（キル判定のため）
		var victim_health_before = body.get_health()
		var victim_will_die = (victim_health_before - damage) <= 0
		
		body.take_damage(damage)
		print("Successfully dealt ", damage, " damage to ", body.name)
		
		# キル判定 - 被害者が死亡した場合
		if victim_will_die:
			show_kill_notification(shooter_id, hit_player_id)
		else:
			# キルではない場合、ダメージ通知を表示
			var victim_health_after = body.get_health()
			show_damage_notification(shooter_id, hit_player_id, damage, victim_health_after)
		
		# 弾丸を削除
		call_deferred("queue_free")
	# 地面や壁に当たった場合（削除しない）
	elif not body.name.begins_with("Bullet"):
		print("Bullet hit environment object: ", body.name, " - bullet continues flying")
		# 壁に当たっても弾丸は削除しない（プレイヤーに当たった時のみ削除）
		has_hit = false  # 継続して他の物体との衝突も検出可能にする
	else:
		print("Bullet hit another bullet - ignoring")
		has_hit = false  # 弾同士の衝突の場合はフラグをリセット

# キル通知を表示する関数
func show_kill_notification(killer_id: int, victim_id: int):
	print("=== KILL NOTIFICATION ===")
	print("Killer ID: ", killer_id, " Victim ID: ", victim_id)
	
	# GameUIを取得
	var current_scene = get_tree().current_scene
	var game_ui = current_scene.get_node_or_null("GameUI")
	
	if not game_ui:
		print("ERROR: GameUI not found - cannot show kill notification")
		return
	
	# プレイヤーの色名を取得
	var killer_color = get_player_color_name(killer_id)
	var victim_color = get_player_color_name(victim_id)
	
	print("Kill notification: ", killer_color, " killed ", victim_color)
	
	# GameUIのキル通知機能を呼び出し
	game_ui.show_kill_notification(killer_color, victim_color)

# ダメージ通知を表示する関数
func show_damage_notification(attacker_id: int, victim_id: int, damage_amount: int, remaining_hp: int):
	print("=== DAMAGE NOTIFICATION ===")
	print("Attacker ID: ", attacker_id, " Victim ID: ", victim_id, " Damage: ", damage_amount, " HP: ", remaining_hp)
	
	# GameUIを取得
	var current_scene = get_tree().current_scene
	var game_ui = current_scene.get_node_or_null("GameUI")
	
	if not game_ui:
		print("ERROR: GameUI not found - cannot show damage notification")
		return
	
	# プレイヤーの色名を取得
	var attacker_color = get_player_color_name(attacker_id)
	var victim_color = get_player_color_name(victim_id)
	
	print("Damage notification: ", attacker_color, " hit ", victim_color, " (-", damage_amount, " HP: ", remaining_hp, ")")
	
	# GameUIのダメージ通知機能を呼び出し
	game_ui.show_damage_notification(attacker_color, victim_color, damage_amount, remaining_hp)

# 弾回収通知を表示する関数
func show_ammo_pickup_notification():
	print("=== AMMO PICKUP NOTIFICATION ===")
	
	# GameUIを取得
	var current_scene = get_tree().current_scene
	var game_ui = current_scene.get_node_or_null("GameUI")
	
	if not game_ui:
		print("ERROR: GameUI not found - cannot show ammo pickup notification")
		return
	
	print("Ammo pickup notification: bullet collected")
	
	# GameUIの弾回収通知機能を呼び出し
	game_ui.show_ammo_pickup_notification()

# プレイヤーIDから色名を取得する関数
func get_player_color_name(player_id: int) -> String:
	# SimpleFPSControllerと同じ色配列を使用
	var color_names = [
		"RED",      # 赤
		"BLUE",     # 青  
		"GREEN",    # 緑
		"YELLOW",   # 黄
		"MAGENTA",  # マゼンタ
		"CYAN",     # シアン
		"ORANGE",   # オレンジ
		"PURPLE"    # 紫
	]
	
	var color_index = player_id % color_names.size()
	return color_names[color_index]
