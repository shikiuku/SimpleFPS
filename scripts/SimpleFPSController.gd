extends CharacterBody3D

@export var walk_speed = 5.0
@export var run_speed = 8.0
@export var jump_velocity = 8.0
@export var mouse_sensitivity = 0.002

@onready var camera = $CameraHolder/Camera3D
@onready var camera_holder = $CameraHolder

# 弾丸のプリロード
var bullet_scene = preload("res://scenes/Bullet.tscn")

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	if event is InputEventMouseMotion:
		# マウスでカメラ回転
		camera_holder.rotate_y(-event.relative.x * mouse_sensitivity)
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
	# 重力を追加
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
	
	# 移動速度を決定（走るかどうか）
	var current_speed = run_speed if Input.is_action_pressed("run") else walk_speed
	
	# カメラの向きに基づいて移動方向を計算
	var direction = Vector3.ZERO
	if input_dir != Vector2.ZERO:
		direction = camera_holder.global_basis * Vector3(input_dir.x, 0, input_dir.y)
		direction = direction.normalized()
	
	# 移動を適用
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed * delta * 3)
		velocity.z = move_toward(velocity.z, 0, current_speed * delta * 3)

	move_and_slide()

func shoot():
	var bullet = bullet_scene.instantiate()
	get_parent().add_child(bullet)
	
	# 弾丸の位置をカメラの前に設定
	bullet.global_position = camera.global_position + camera.global_transform.basis.z * -0.5
	
	# 弾丸の方向と速度を設定（カメラの前方向）
	var shoot_direction = -camera.global_transform.basis.z
	bullet.set_velocity(shoot_direction)