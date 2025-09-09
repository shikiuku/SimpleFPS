extends Node

# シングルトンとして使用

const PORT = 7000
const MAX_PLAYERS = 8

func _ready():
	# 手動でstart_host()またはstart_client()を呼び出すまで待機
	pass

func start_host():
	# 既にマルチプレイヤーがアクティブな場合は完全にリセット
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer = null
		await get_tree().process_frame
	
	# 新しいピアを作成
	var multiplayer_peer = ENetMultiplayerPeer.new()
	var error = multiplayer_peer.create_server(PORT, MAX_PLAYERS)
	if error != OK:
		print("Failed to create server, error code: ", error)
		return
	
	multiplayer.multiplayer_peer = multiplayer_peer
	
	# 同期頻度を上げる
	Engine.max_fps = 60
	print("Host started on port ", PORT)
	
	# TestLevelに移動した時にサーバーのプレイヤーをスポーン
	call_deferred("notify_test_level_if_ready")

func start_client(address = "127.0.0.1"):
	# 既にマルチプレイヤーがアクティブな場合は完全にリセット
	if multiplayer.has_multiplayer_peer():
		if multiplayer.connected_to_server.is_connected(_on_connected_to_server):
			multiplayer.connected_to_server.disconnect(_on_connected_to_server)
		multiplayer.multiplayer_peer = null
		await get_tree().process_frame
	
	# 新しいピアを作成
	var multiplayer_peer = ENetMultiplayerPeer.new()
	var error = multiplayer_peer.create_client(address, PORT)
	if error != OK:
		print("Failed to create client, error code: ", error)
		return
	
	multiplayer.multiplayer_peer = multiplayer_peer
	
	# 同期頻度を上げる
	Engine.max_fps = 60
	print("Connecting to ", address, ":", PORT)
	
	# 接続成功時の処理
	multiplayer.connected_to_server.connect(_on_connected_to_server)

func _on_connected_to_server():
	print("Connected to server!")

func notify_test_level_if_ready():
	# TestLevelシーンにいるかチェック
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.name == "TestLevel":
		# TestLevelに対してマルチプレイヤーセッション開始を通知
		if main_scene.has_method("start_multiplayer_session"):
			main_scene.start_multiplayer_session()
		else:
			print("TestLevel doesn't have start_multiplayer_session method")
