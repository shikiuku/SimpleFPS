extends RigidBody3D

@export var speed = 30.0
@export var lifetime = 10.0

var direction = Vector3.ZERO

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

func _physics_process(_delta):
	# 地面の下に落ちすぎたら削除
	if global_position.y < -50:
		queue_free()

func set_velocity(dir: Vector3):
	direction = dir
	linear_velocity = direction * speed

func _on_lifetime_timeout():
	queue_free()
