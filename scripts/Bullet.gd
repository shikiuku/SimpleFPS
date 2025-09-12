extends RigidBody3D

@export var speed = 30.0
@export var lifetime = 10.0
@export var damage = 25  # 1発25ダメージ（4発で倒せる）

var direction = Vector3.ZERO
@onready var mesh_instance = $MeshInstance3D

func _ready():
	# 一定時間後に削除
	var timer = Timer.new()
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.connect("timeout", _on_lifetime_timeout)
	add_child(timer)
	timer.start()
	
	# 重力を有効にする
	gravity_scale = 1.0
	
	# 衝突検出を有効にする
	body_entered.connect(_on_body_entered)

func _physics_process(_delta):
	# 地面の下に落ちすぎたら削除
	if global_position.y < -50:
		queue_free()

func set_velocity(dir: Vector3):
	direction = dir
	linear_velocity = direction * speed

func _on_lifetime_timeout():
	queue_free()

# プレイヤーの色に合わせて弾丸の色を設定
func set_bullet_color(color: Color):
	if mesh_instance:
		var material = StandardMaterial3D.new()
		material.albedo_color = color
		material.emission = color * 0.3  # 少し光らせる
		mesh_instance.set_surface_override_material(0, material)

func _on_body_entered(body):
	print("Bullet hit: ", body.name)
	
	# プレイヤーに当たった場合
	if body.has_method("take_damage"):
		body.take_damage(damage)
		print("Dealt ", damage, " damage to ", body.name)
		
		# 弾丸を削除
		queue_free()
	# 地面や壁に当たった場合
	elif not body.name.begins_with("Bullet"):
		print("Bullet hit environment: ", body.name)
		queue_free()
