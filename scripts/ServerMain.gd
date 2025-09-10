extends Node

# Railway用サーバーメインシーン
var PORT = 8080  # デフォルトポート（Railway標準）
const MAX_PLAYERS = 8

func _ready():
	# Railway環境変数からポート番号を取得
	var env_port = OS.get_environment("PORT")
	if env_port != "":
		PORT = int(env_port)
		print("Using Railway PORT: ", PORT)
	else:
		print("Using default PORT: ", PORT)
	
	print("=== Godot Multiplayer Server Starting ===")
	print("Protocol: WebSocket")
	print("Port: ", PORT)
	print("Max Players: ", MAX_PLAYERS)
	
	# ヘッドレスモードかチェック
	if DisplayServer.get_name() == "headless":
		print("Running in headless mode - perfect for server!")
	
	start_server()

func start_server():
	# WebSocketMultiplayerPeer でサーバー作成（Railway対応）
	var multiplayer_peer = WebSocketMultiplayerPeer.new()
	var error = multiplayer_peer.create_server(PORT, "*", [], true)  # TLSなし、全IPから接続許可
	
	if error != OK:
		print("ERROR: Failed to create server. Error code: ", error)
		get_tree().quit(1)
		return
	
	# マルチプレイヤー設定
	multiplayer.multiplayer_peer = multiplayer_peer
	
	# プレイヤー接続/切断イベント
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	
	print("=== Server Started Successfully ===")
	print("Waiting for players to connect...")
	
	# サーバー状態を定期的に出力
	var timer = Timer.new()
	timer.wait_time = 30.0
	timer.timeout.connect(_print_server_status)
	add_child(timer)
	timer.start()

func _on_player_connected(peer_id: int):
	print("Player connected: ID=", peer_id)
	print("Total players: ", multiplayer.get_peers().size() + 1)

func _on_player_disconnected(peer_id: int):
	print("Player disconnected: ID=", peer_id)
	print("Total players: ", multiplayer.get_peers().size() + 1)

func _print_server_status():
	print("=== Server Status ===")
	print("Active connections: ", multiplayer.get_peers().size())
	print("Server ID: ", multiplayer.get_unique_id())
	print("===================")