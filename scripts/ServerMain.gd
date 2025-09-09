extends Node

# Railway用サーバーメインシーン
const PORT = 7000
const MAX_PLAYERS = 8

func _ready():
	print("=== Godot Multiplayer Server Starting ===")
	print("Port: ", PORT)
	print("Max Players: ", MAX_PLAYERS)
	
	# ヘッドレスモードかチェック
	if DisplayServer.get_name() == "headless":
		print("Running in headless mode - perfect for server!")
	
	start_server()

func start_server():
	# ENetMultiplayerPeer でサーバー作成
	var multiplayer_peer = ENetMultiplayerPeer.new()
	var error = multiplayer_peer.create_server(PORT, MAX_PLAYERS)
	
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