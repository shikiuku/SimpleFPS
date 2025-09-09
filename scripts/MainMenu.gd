extends Control

@onready var host_button = $VBoxContainer/HostButton
@onready var client_button = $VBoxContainer/ClientButton
@onready var ip_input = $VBoxContainer/IPInput
@onready var status_label = $VBoxContainer/StatusLabel

func _ready():
	host_button.pressed.connect(_on_host_button_pressed)
	client_button.pressed.connect(_on_client_button_pressed)
	
	# プラットフォームに応じてデフォルトIPを設定
	if OS.get_name() == "Web":
		ip_input.text = "外部サーバーのIPを入力してください"
		ip_input.placeholder_text = "例: 192.168.1.100"
		# Webプラットフォームでは外部接続が必要
		status_label.text = "Web版：外部のデスクトップサーバーに接続してください"
	else:
		ip_input.text = "127.0.0.1"

func _on_host_button_pressed():
	# Webプラットフォームではサーバーホストは無効
	if OS.get_name() == "Web":
		status_label.text = "Web版ではサーバーホストはサポートされていません"
		return
	
	status_label.text = "ホストを開始中..."
	print("MainMenu: ホストボタンが押されました")
	
	# シングルトンのNetworkManagerを使用
	NetworkManager.start_host()
	
	# ゲームシーンに移行
	await get_tree().create_timer(0.5).timeout
	print("MainMenu: TestLevelシーンに移行します")
	get_tree().change_scene_to_file("res://scenes/TestLevel.tscn")

func _on_client_button_pressed():
	var ip = ip_input.text.strip_edges()
	if ip.is_empty():
		status_label.text = "IPアドレスを入力してください"
		return
	
	status_label.text = "接続中..."
	
	# シングルトンのNetworkManagerを使用
	NetworkManager.start_client(ip)
	
	# 接続成功のシグナルを待機
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	
	# タイムアウト処理
	await get_tree().create_timer(5.0).timeout
	if not multiplayer.has_multiplayer_peer():
		status_label.text = "接続に失敗しました"

func _on_connected_to_server():
	# 接続成功時にシーン移行
	get_tree().change_scene_to_file("res://scenes/TestLevel.tscn")
