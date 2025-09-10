extends CanvasLayer

@onready var version_label = $VersionLabel
@onready var player_count_label = $PlayerCountLabel

# ゲームのバージョン
const VERSION = "v1.5.0"

func _ready():
	# バージョンを表示
	version_label.text = "Version: " + VERSION
	
	# プレイヤー数の初期設定
	update_player_count()
	
	# プレイヤー数を定期的に更新
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_on_update_timer)
	timer.autostart = true
	add_child(timer)
	
	print("GameUI initialized - Version: ", VERSION)

func _on_update_timer():
	update_player_count()

func update_player_count():
	var peer_count = 1  # 自分
	
	# マルチプレイヤーが有効な場合
	if multiplayer.has_multiplayer_peer():
		peer_count = multiplayer.get_peers().size() + 1  # +1 for self
	
	player_count_label.text = "Players: " + str(peer_count) + "/4"
	
	# デバッグ情報
	if multiplayer.has_multiplayer_peer():
		var peers = multiplayer.get_peers()
		print("Connected peers: ", peers, " Total players: ", peer_count)