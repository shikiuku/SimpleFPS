extends Node

# リスポーン管理用のグローバルクラス
var should_respawn = false
var respawn_position = Vector3(0, 2, 0)

func _ready():
	print("RespawnManager initialized")

func trigger_respawn():
	should_respawn = true
	print("Respawn triggered globally")

func clear_respawn_flag():
	should_respawn = false
	print("Respawn flag cleared")

func get_respawn_position() -> Vector3:
	return respawn_position

func set_respawn_position(pos: Vector3):
	respawn_position = pos
	print("Respawn position set to: ", respawn_position)