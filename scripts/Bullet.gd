extends Area3D

@export var speed = 30.0
@export var lifetime = 10.0
@export var damage = 25  # 1発25ダメージ（4発で倒せる）

var direction = Vector3.ZERO
var shooter_id = -1  # 射撃者のID
@onready var mesh_instance = $MeshInstance3D

func _ready():
	# 一定時間後に削除
	var timer = Timer.new()
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.connect("timeout", _on_lifetime_timeout)
	add_child(timer)
	timer.start()
	
	# Area3Dの衝突検出を有効にする
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# 衝突レイヤーを設定（弾丸レイヤー）
	collision_layer = 4  # layer 3 (Projectiles)
	collision_mask = 3   # layer 1 (Player) + layer 2 (Environment)
	
	print("Bullet initialized - collision_layer: ", collision_layer, " collision_mask: ", collision_mask)

func _physics_process(delta):
	# 地面の下に落ちすぎたら削除
	if global_position.y < -50:
		queue_free()
	
	# 弾丸を移動させる
	if direction != Vector3.ZERO:
		# 重力を追加
		direction.y -= 9.8 * delta
		global_position += direction * speed * delta

func set_velocity(dir: Vector3):
	direction = dir

func _on_lifetime_timeout():
	queue_free()

# プレイヤーの色に合わせて弾丸の色を設定
func set_bullet_color(color: Color):
	if mesh_instance:
		var material = StandardMaterial3D.new()
		material.albedo_color = color
		material.emission = color * 0.3  # 少し光らせる
		mesh_instance.set_surface_override_material(0, material)

var has_hit = false  # 一度だけヒット処理をするフラグ

func _on_body_entered(body):
	if has_hit:  # すでにヒット処理済みなら無視
		return
		
	print("=== BULLET HIT ===")
	print("Bullet hit body: ", body.name, " (Type: ", body.get_class(), ")")
	print("Shooter ID: ", shooter_id, " Hit body name: ", body.name)
	print("Body has take_damage method: ", body.has_method("take_damage"))
	
	has_hit = true  # ヒット処理済みフラグを立てる
	
	# プレイヤーに当たった場合
	if body.has_method("take_damage"):
		# 自分の弾が自分に当たった場合は無視
		var hit_player_id = body.name.to_int()
		if shooter_id == hit_player_id:
			print("Bullet hit shooter (", shooter_id, ") - ignoring self damage")
			has_hit = false  # 自分の弾の場合はフラグをリセット
			return
		
		print("Calling take_damage with ", damage, " damage on ", body.name)
		body.take_damage(damage)
		print("Successfully dealt ", damage, " damage to ", body.name)
		
		# 弾丸を削除
		queue_free()
	# 地面や壁に当たった場合
	elif not body.name.begins_with("Bullet"):
		print("Bullet hit environment object: ", body.name, " - destroying bullet")
		queue_free()
	else:
		print("Bullet hit another bullet - ignoring")
		has_hit = false  # 弾同士の衝突の場合はフラグをリセット

func _on_area_entered(area):
	print("Bullet hit area: ", area.name)
	# Areaとの衝突でも弾丸を削除
	if not area.name.begins_with("Bullet"):
		queue_free()
