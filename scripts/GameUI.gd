extends CanvasLayer

@onready var version_label = $VersionLabel
@onready var player_count_label = $PlayerCountLabel
@onready var health_label = $HealthLabel

# ゲームのバージョン
const VERSION = "v1.7.31"

func _ready():
	# バージョンを表示
	version_label.text = "Version: " + VERSION
	
	# プレイヤー数の初期設定
	update_player_count()
	
	# HP表示の初期設定
	update_health_display()
	
	# プレイヤー数とHPを定期的に更新
	var timer = Timer.new()
	timer.wait_time = 0.1  # HPは頻繁に更新
	timer.timeout.connect(_on_update_timer)
	timer.autostart = true
	add_child(timer)
	
	print("GameUI initialized - Version: ", VERSION)

func _on_update_timer():
	update_player_count()
	update_health_display()

func update_player_count():
	var peer_count = 1  # 自分
	
	# マルチプレイヤーが有効な場合
	if multiplayer.has_multiplayer_peer():
		peer_count = multiplayer.get_peers().size() + 1  # +1 for self
	
	player_count_label.text = "Players: " + str(peer_count) + "/8"
	
	# デバッグ情報
	if multiplayer.has_multiplayer_peer():
		var peers = multiplayer.get_peers()
		print("Connected peers: ", peers, " Total players: ", peer_count)

func update_health_display():
	# HealthLabelが存在するか確認
	if not health_label:
		print("ERROR: HealthLabel not found!")
		return
	
	# ローカルプレイヤーのHPを取得
	var local_player = get_local_player()
	
	if local_player and local_player.has_method("get_health") and local_player.has_method("get_max_health"):
		var current_hp = local_player.get_health()
		var max_hp = local_player.get_max_health()
		
		# HPバーの色を変更（低いほど赤く）
		var health_percentage = float(current_hp) / float(max_hp)
		var color = Color.WHITE
		
		if health_percentage <= 0.25:
			color = Color.RED
		elif health_percentage <= 0.5:
			color = Color.ORANGE
		elif health_percentage <= 0.75:
			color = Color.YELLOW
		
		health_label.text = "♥ HP: " + str(current_hp) + "/" + str(max_hp)
		health_label.modulate = color
		
		# 死亡時の表示
		if local_player.is_dead:
			health_label.text = "💀 DEAD - Respawning..."
			health_label.modulate = Color.RED
	else:
		health_label.text = "♥ HP: --/--"
		health_label.modulate = Color.WHITE

func get_local_player():
	# ローカルプレイヤー（権限を持つプレイヤー）を探す
	var current_scene = get_tree().current_scene
	
	# まずPlayersノードを探す
	var players_node = current_scene.get_node_or_null("Players")
	if players_node != null:
		for child in players_node.get_children():
			if child.has_method("is_multiplayer_authority") and child.is_multiplayer_authority():
				return child
	
	# Playersノードがない場合、シーン直下を探す
	for child in current_scene.get_children():
		if child.has_method("is_multiplayer_authority") and child.is_multiplayer_authority():
			return child
		
		# 孫ノードまで探す（TestLevelなどの子ノード内にプレイヤーがいる場合）
		for grandchild in child.get_children():
			if grandchild.has_method("is_multiplayer_authority") and grandchild.is_multiplayer_authority():
				return grandchild
	
	return null