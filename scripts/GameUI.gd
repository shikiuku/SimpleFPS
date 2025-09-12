extends CanvasLayer

@onready var version_label = $VersionLabel
@onready var player_count_label = $PlayerCountLabel
@onready var health_label = $HealthLabel

# ゲームのバージョン
const VERSION = "v1.7.27"

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
	
	print("DEBUG: update_health_display called")
	print("DEBUG: HealthLabel exists: ", health_label != null)
	print("DEBUG: HealthLabel visible: ", health_label.visible if health_label else "N/A")
	print("DEBUG: HealthLabel position: ", health_label.position if health_label else "N/A")
	
	# ローカルプレイヤーのHPを取得
	var local_player = get_local_player()
	print("DEBUG: Local player found: ", local_player != null)
	
	if local_player:
		print("DEBUG: Player name: ", local_player.name)
		print("DEBUG: Has get_health method: ", local_player.has_method("get_health"))
		print("DEBUG: Has get_max_health method: ", local_player.has_method("get_max_health"))
		print("DEBUG: Has is_dead property: ", "is_dead" in local_player)
	
	if local_player and local_player.has_method("get_health") and local_player.has_method("get_max_health"):
		var current_hp = local_player.get_health()
		var max_hp = local_player.get_max_health()
		
		print("DEBUG: HP values - Current: ", current_hp, " Max: ", max_hp)
		
		# HPバーの色を変更（低いほど赤く）
		var health_percentage = float(current_hp) / float(max_hp)
		var color = Color.WHITE
		
		if health_percentage <= 0.25:
			color = Color.RED
		elif health_percentage <= 0.5:
			color = Color.ORANGE
		elif health_percentage <= 0.75:
			color = Color.YELLOW
		
		health_label.text = "HP: " + str(current_hp) + "/" + str(max_hp)
		health_label.modulate = color
		print("DEBUG: Set health text to: ", health_label.text)
		
		# 死亡時の表示
		if local_player.is_dead:
			health_label.text = "DEAD - Respawning..."
			health_label.modulate = Color.RED
			print("DEBUG: Player is dead, showing death message")
	else:
		health_label.text = "HP: --/--"
		health_label.modulate = Color.WHITE
		print("DEBUG: No valid local player found, showing default HP")

func get_local_player():
	# ローカルプレイヤー（権限を持つプレイヤー）を探す
	var current_scene = get_tree().current_scene
	print("DEBUG: Current scene: ", current_scene.name)
	print("DEBUG: Current scene children count: ", current_scene.get_children().size())
	
	# まずPlayersノードを探す
	var players_node = current_scene.get_node_or_null("Players")
	print("DEBUG: Players node found: ", players_node != null)
	if players_node != null:
		print("DEBUG: Players node children count: ", players_node.get_children().size())
		for child in players_node.get_children():
			print("DEBUG: Checking child in Players: ", child.name, " Type: ", child.get_class())
			if child.has_method("is_multiplayer_authority"):
				print("DEBUG: Child has is_multiplayer_authority method, authority: ", child.is_multiplayer_authority())
				if child.is_multiplayer_authority():
					print("Found local player in Players node: ", child.name)
					return child
	
	# Playersノードがない場合、シーン直下を探す
	print("DEBUG: Searching scene root children...")
	for child in current_scene.get_children():
		print("DEBUG: Checking scene child: ", child.name, " Type: ", child.get_class())
		if child.has_method("is_multiplayer_authority"):
			print("DEBUG: Scene child has is_multiplayer_authority method, authority: ", child.is_multiplayer_authority())
			if child.is_multiplayer_authority():
				print("Found local player in scene root: ", child.name)
				return child
		
		# 孫ノードまで探す（TestLevelなどの子ノード内にプレイヤーがいる場合）
		print("DEBUG: Checking grandchildren of: ", child.name)
		for grandchild in child.get_children():
			print("DEBUG: Checking grandchild: ", grandchild.name, " Type: ", grandchild.get_class())
			if grandchild.has_method("is_multiplayer_authority"):
				print("DEBUG: Grandchild has is_multiplayer_authority method, authority: ", grandchild.is_multiplayer_authority())
				if grandchild.is_multiplayer_authority():
					print("Found local player in grandchild: ", grandchild.name, " (parent: ", child.name, ")")
					return grandchild
	
	print("No local player found")
	return null