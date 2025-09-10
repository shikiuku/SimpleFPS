extends Node3D

# プレイヤーシーンの参照
var player_scene = preload("res://scenes/SimpleFPSPlayer.tscn")

func _ready():
	print("TestLevel: _ready() start")
	# マルチプレイヤーイベントに接続
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	
	print("TestLevel ready, multiplayer ID: ", multiplayer.get_unique_id())
	print("Is server: ", multiplayer.is_server())
	print("TestLevel: NetworkManager call")
	
	# NetworkManagerに通知
	if NetworkManager:
		NetworkManager.notify_test_level_if_ready()
	else:
		print("TestLevel: NetworkManager not found!")

func _on_player_connected(peer_id: int):
	print("Player connected: ", peer_id)
	if multiplayer.is_server():
		# サーバーが新しいプレイヤーをスポーン
		spawn_player(peer_id)

func _on_player_disconnected(peer_id: int):
	print("Player disconnected: ", peer_id)
	# プレイヤーを削除
	var player_node = get_node_or_null(str(peer_id))
	if player_node:
		player_node.queue_free()

func spawn_player(peer_id: int):
	# 既存のプレイヤーをチェック
	if has_node(str(peer_id)):
		print("Player already exists: ", peer_id)
		return
	
	# プレイヤーを生成
	var player = player_scene.instantiate()
	player.name = str(peer_id)
	
	# ランダムな位置に配置（サーバーも含めて）
	var spawn_position = Vector3(randf_range(-5, 5), 2, randf_range(-5, 5))
	player.position = spawn_position
	
	# シーンに追加
	add_child(player, true)
	
	# 権限を設定（重要）
	player.set_multiplayer_authority(peer_id)
	
	print("Player spawned: ", player.name, " at ", player.position, " Authority: ", player.get_multiplayer_authority())
	
	# 位置が正しく設定されているか再確認
	await get_tree().process_frame
	print("Player position confirmed: ", player.name, " at ", player.global_position)

# サーバーが開始されたときに呼び出される
func start_multiplayer_session():
	print("TestLevel: start_multiplayer_session() started")
	
	# 自分のプレイヤーを必ず生成（サーバーでもクライアントでも）
	var my_id = multiplayer.get_unique_id()
	print("TestLevel: spawn my player ID: ", my_id)
	spawn_player(my_id)
	
	# サーバーの場合は既存のピアも生成
	if multiplayer.is_server():
		for peer_id in multiplayer.get_peers():
			print("TestLevel: spawn existing peer player ID: ", peer_id)
			spawn_player(peer_id)
	else:
		# クライアントの場合はサーバー（ID: 1）も生成
		print("TestLevel: spawn server player ID: 1")
		spawn_player(1)
