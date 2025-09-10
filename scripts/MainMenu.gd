extends Control

@onready var status_label = $VBoxContainer/StatusLabel

func _ready():
	# サーバーモードかどうかを確認
	var server_mode = OS.get_environment("SERVER_MODE")
	if server_mode == "true":
		print("MainMenu: サーバーモード検出、ServerMainシーンに切り替え")
		get_tree().change_scene_to_file("res://scenes/ServerMain.tscn")
		return
	
	# 自動接続開始
	status_label.text = "サーバーに自動接続中..."
	print("MainMenu: 自動接続を開始します")
	
	# 少し待ってから接続開始（UIが表示されるのを待つ）
	await get_tree().create_timer(1.0).timeout
	_start_auto_connect()

func _start_auto_connect():
	# サーバーアドレスを環境変数から取得（優先順位：環境変数 > デバッグビルド > 手動入力）
	var server_address = OS.get_environment("GAME_SERVER_URL")
	
	if server_address == "":
		# テスト用に直接Railwayサーバーに接続
		server_address = "sublime-perception-production.up.railway.app"  # 最新URL
		print("Railway サーバーに直接接続します")
	
	status_label.text = "Railwayサーバーに接続中..."
	
	print("MainMenu: ", server_address, " に接続を試行します")
	
	# NetworkManagerを使用して接続
	NetworkManager.start_client(server_address)
	
	# 接続成功のシグナルを待機
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	
	# タイムアウト処理（10秒）
	await get_tree().create_timer(10.0).timeout
	if not multiplayer.has_multiplayer_peer() or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		status_label.text = "接続に失敗しました - サーバーを開始してください"
		print("MainMenu: 接続タイムアウト")

func _on_connected_to_server():
	# 接続成功時にシーン移行
	status_label.text = "接続成功！ゲーム開始..."
	print("MainMenu: サーバー接続成功")
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://scenes/TestLevel.tscn")
