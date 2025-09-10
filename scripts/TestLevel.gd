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
	print("=== PLAYER CONNECTED EVENT ===")
	print("Player connected: ", peer_id)
	print("Is server: ", multiplayer.is_server())
	print("My ID: ", multiplayer.get_unique_id())
	
	# 新しく接続したプレイヤーをスポーン
	spawn_player(peer_id)
	
	# 新しく接続したプレイヤーに既存のプレイヤーを見せる
	var my_id = multiplayer.get_unique_id()
	if not has_node(str(my_id)):
		print("Spawning myself for new player: ", my_id)
		spawn_player(my_id)
	
	# 他の既存プレイヤーもスポーン（重複しないよう確認）
	for existing_peer_id in multiplayer.get_peers():
		if existing_peer_id != peer_id and not has_node(str(existing_peer_id)):
			print("Spawning existing player for new player: ", existing_peer_id)
			spawn_player(existing_peer_id)
	
	var player_count = 0
	for child in get_children():
		if child.name.is_valid_int():
			player_count += 1
	print("Total players after connection: ", player_count)
	print("================================")

func _on_player_disconnected(peer_id: int):
	print("Player disconnected: ", peer_id)
	# プレイヤーを削除
	var player_node = get_node_or_null(str(peer_id))
	if player_node:
		player_node.queue_free()

func spawn_player(peer_id: int):
	# 既存のプレイヤーをチェック（重複防止）
	var existing_player = get_node_or_null(str(peer_id))
	if existing_player:
		print("Player already exists: ", peer_id, " - removing old one")
		existing_player.queue_free()
		await get_tree().process_frame  # 削除を待つ
	
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
	
	# 自分のプレイヤーのみを生成
	var my_id = multiplayer.get_unique_id()
	print("TestLevel: spawn my player ID: ", my_id)
	print("TestLevel: existing peers: ", multiplayer.get_peers())
	
	# 自分をスポーン
	spawn_player(my_id)
	
	# 既存の接続済みプレイヤーをすべてスポーン
	for peer_id in multiplayer.get_peers():
		print("TestLevel: spawn existing peer player ID: ", peer_id)
		spawn_player(peer_id)
	
	# 現在のプレイヤー状況を表示
	print_player_status()

func print_player_status():
	print("=== CURRENT PLAYERS ===")
	print("My ID: ", multiplayer.get_unique_id())
	print("Connected peers: ", multiplayer.get_peers())
	
	var player_nodes = []
	for child in get_children():
		if child.name.is_valid_int():
			player_nodes.append(child.name)
	
	print("Player nodes in scene: ", player_nodes)
	print("========================")
