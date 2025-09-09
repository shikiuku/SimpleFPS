extends Node

# シングルトンとして使用

const PORT = 7000
const MAX_PLAYERS = 8

# プラットフォーム判定
var is_web_platform: bool

func _ready():
	# Webプラットフォームかどうかを判定
	is_web_platform = OS.get_name() == "Web"
	print("Platform: ", OS.get_name(), " (is_web: ", is_web_platform, ")")
	
	if is_web_platform:
		print("Web platform detected - using WebSocketMultiplayerPeer")
	else:
		print("Desktop platform detected - using ENetMultiplayerPeer")

func start_host():
	# 既にマルチプレイヤーがアクティブな場合は完全にリセット
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer = null
		await get_tree().process_frame
	
	var multiplayer_peer
	var error
	
	if is_web_platform:
		# Web版ではサーバーホストは無効
		print("Web版ではサーバーホストはサポートされていません")
		return
	else:
		# デスクトップ版: ENetMultiplayerPeer を使用
		multiplayer_peer = ENetMultiplayerPeer.new()
		error = multiplayer_peer.create_server(PORT, MAX_PLAYERS)
		print("ENetサーバーをポート ", PORT, " で開始中...")
	
	if error != OK:
		print("サーバー作成に失敗しました。エラーコード: ", error)
		return
	
	multiplayer.multiplayer_peer = multiplayer_peer
	
	# 同期頻度を上げる
	Engine.max_fps = 60
	print("サーバーが正常に開始されました。ポート: ", PORT)
	
	# TestLevelに移動した時にサーバーのプレイヤーをスポーン
	call_deferred("notify_test_level_if_ready")

func start_client(address = "127.0.0.1"):
	# 既にマルチプレイヤーがアクティブな場合は完全にリセット
	if multiplayer.has_multiplayer_peer():
		if multiplayer.connected_to_server.is_connected(_on_connected_to_server):
			multiplayer.connected_to_server.disconnect(_on_connected_to_server)
		multiplayer.multiplayer_peer = null
		await get_tree().process_frame
	
	var multiplayer_peer
	var error
	
	if is_web_platform:
		# Web版: WebSocketMultiplayerPeer を使用
		multiplayer_peer = WebSocketMultiplayerPeer.new()
		var url = "ws://" + address + ":" + str(PORT)
		error = multiplayer_peer.create_client(url)
		print("WebSocketサーバーに接続中: ", url)
	else:
		# デスクトップ版: ENetMultiplayerPeer を使用
		multiplayer_peer = ENetMultiplayerPeer.new()
		error = multiplayer_peer.create_client(address, PORT)
		print("ENetサーバーに接続中: ", address, ":", PORT)
	
	if error != OK:
		print("クライアント作成に失敗しました。エラーコード: ", error)
		return
	
	multiplayer.multiplayer_peer = multiplayer_peer
	
	# 同期頻度を上げる
	Engine.max_fps = 60
	print("クライアント接続中...")
	
	# 接続成功時の処理
	multiplayer.connected_to_server.connect(_on_connected_to_server)

func _on_connected_to_server():
	print("サーバーに接続しました！")

func notify_test_level_if_ready():
	# TestLevelシーンにいるかチェック
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.name == "TestLevel":
		# TestLevelに対してマルチプレイヤーセッション開始を通知
		if main_scene.has_method("start_multiplayer_session"):
			main_scene.start_multiplayer_session()
		else:
			print("TestLevel doesn't have start_multiplayer_session method")
