extends Control

@onready var countdown_label = $CountdownLabel
@onready var death_message = $DeathMessage

var countdown_time = 3.0
var original_scene_path = ""

func _ready():
	# 死亡メッセージを表示
	death_message.text = "💀 YOU DIED 💀"
	
	# カウントダウンを開始
	countdown_time = 3.0
	update_countdown_display()
	
	# タイマーを設定
	var timer = Timer.new()
	timer.wait_time = 0.1  # 0.1秒ごとに更新
	timer.timeout.connect(_on_timer_timeout)
	timer.autostart = true
	add_child(timer)
	
	print("Death scene started - countdown: ", countdown_time, " seconds")

func _on_timer_timeout():
	countdown_time -= 0.1
	update_countdown_display()
	
	if countdown_time <= 0:
		# カウントダウン終了 - 元のシーンに戻る
		respawn_player()

func update_countdown_display():
	var seconds = max(0, ceil(countdown_time))
	countdown_label.text = "Respawning in " + str(seconds) + "..."

func set_original_scene(scene_path: String):
	original_scene_path = scene_path
	print("Original scene path set: ", original_scene_path)

func respawn_player():
	print("Respawn time reached - returning to game")
	
	# リスポーンフラグをグローバルに設定
	RespawnManager.should_respawn = true
	RespawnManager.respawn_position = Vector3(0, 2, 0)
	
	# 元のシーンに戻る
	if original_scene_path != "":
		get_tree().change_scene_to_file(original_scene_path)
	else:
		# フォールバック: メインシーンに戻る
		get_tree().change_scene_to_file("res://scenes/TestLevel.tscn")