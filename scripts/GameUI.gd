extends CanvasLayer

@onready var version_label = $VersionLabel
@onready var player_count_label = $PlayerCountLabel
@onready var health_bar = $HealthBar
@onready var health_label = $HealthBar/HealthLabel
@onready var ammo_bar = $AmmoBar
@onready var ammo_label = $AmmoBar/AmmoLabel
@onready var dash_bar = $DashBar
@onready var dash_label = $DashBar/DashLabel
@onready var jump_label = $JumpLabel
@onready var kill_notification_label = $KillNotificationLabel

# ゲームのバージョン
const VERSION = "v1.7.20"

func _ready():
	# バージョンを表示
	version_label.text = "Version: " + VERSION
	
	# プレイヤー数の初期設定
	update_player_count()
	
	# HP表示の初期設定
	update_health_display()
	
	# 弾数表示の初期設定
	update_ammo_display(50, 50)
	
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
	update_jump_display()

func update_player_count():
	var peer_count = 0
	
	# マルチプレイヤーが有効な場合
	if multiplayer.has_multiplayer_peer():
		var peers = multiplayer.get_peers()
		peer_count = peers.size()
		
		# Player1（サーバー側）を除外してカウント
		for peer_id in peers:
			if peer_id == 1:  # Player1はサーバー側なので除外
				peer_count -= 1
		
		# 自分をカウントに追加（自分がPlayer1でない場合）
		if multiplayer.get_unique_id() != 1:
			peer_count += 1
	else:
		peer_count = 1  # ローカルモードの場合は自分だけ
	
	player_count_label.text = "Players: " + str(peer_count) + "/8"
	
	# デバッグ情報
	if multiplayer.has_multiplayer_peer():
		var peers = multiplayer.get_peers()
		var my_id = multiplayer.get_unique_id()
		print("All peers: ", peers, " My ID: ", my_id, " Real players: ", peer_count)

func update_health_display():
	# HealthBarとHealthLabelが存在するか確認
	if not health_bar or not health_label:
		print("ERROR: HealthBar or HealthLabel not found!")
		return
	
	# ローカルプレイヤーのHPを取得
	var local_player = get_local_player()
	
	if local_player and local_player.has_method("get_health") and local_player.has_method("get_max_health"):
		var current_hp = local_player.get_health()
		var max_hp = local_player.get_max_health()
		
		# HPバーの値を更新
		health_bar.max_value = max_hp
		health_bar.value = current_hp
		
		# HPバーの色を変更（低いほど赤く）
		var health_percentage = float(current_hp) / float(max_hp)
		var bar_color = Color.WHITE
		var text_color = Color.WHITE
		
		if health_percentage <= 0.25:
			bar_color = Color.RED
			text_color = Color.WHITE
		elif health_percentage <= 0.5:
			bar_color = Color.ORANGE
			text_color = Color.WHITE
		elif health_percentage <= 0.75:
			bar_color = Color.YELLOW
			text_color = Color.BLACK
		else:
			bar_color = Color.GREEN
			text_color = Color.WHITE
		
		# ProgressBarの色を設定
		health_bar.modulate = bar_color
		
		# テキストの更新と色設定
		health_label.text = "♥ HP: " + str(current_hp) + "/" + str(max_hp)
		health_label.modulate = text_color
		
		# 死亡時の表示
		if local_player.is_dead:
			health_label.text = "💀 DEAD - Respawning..."
			health_label.modulate = Color.RED
			health_bar.modulate = Color.RED
			health_bar.value = 0
	else:
		health_label.text = "♥ HP: --/--"
		health_label.modulate = Color.WHITE
		health_bar.modulate = Color.WHITE
		health_bar.value = 0

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

# キル通知を表示する関数
func show_kill_notification(killer_color: String, victim_color: String):
	if not kill_notification_label:
		print("ERROR: KillNotificationLabel not found!")
		return
	
	# キル通知メッセージを作成
	var message = killer_color + " killed " + victim_color
	kill_notification_label.text = message
	kill_notification_label.visible = true
	
	# 色を設定（キラーの色を使用）
	var notification_color = get_color_from_name(killer_color)
	kill_notification_label.modulate = notification_color
	
	print("Kill notification displayed: ", message)
	
	# 3秒後に非表示にする
	var timer = Timer.new()
	timer.wait_time = 3.0
	timer.one_shot = true
	timer.timeout.connect(_hide_kill_notification)
	add_child(timer)
	timer.start()

# ダメージ通知を表示する関数
func show_damage_notification(attacker_color: String, victim_color: String, damage: int, remaining_hp: int):
	if not kill_notification_label:
		print("ERROR: KillNotificationLabel not found!")
		return
	
	# ダメージ通知メッセージを作成
	var message = attacker_color + " hit " + victim_color + " (-" + str(damage) + " HP: " + str(remaining_hp) + ")"
	kill_notification_label.text = message
	kill_notification_label.visible = true
	
	# 色を設定（攻撃者の色を使用）
	var notification_color = get_color_from_name(attacker_color)
	kill_notification_label.modulate = notification_color
	
	print("Damage notification displayed: ", message)
	
	# 2秒後に非表示にする（キル通知より短め）
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.one_shot = true
	timer.timeout.connect(_hide_kill_notification)
	add_child(timer)
	timer.start()

func _hide_kill_notification():
	if kill_notification_label:
		kill_notification_label.visible = false
		kill_notification_label.text = ""

# 色名から実際の色を取得
func get_color_from_name(color_name: String) -> Color:
	match color_name:
		"RED":
			return Color.RED
		"BLUE":
			return Color.BLUE
		"GREEN":
			return Color.GREEN
		"YELLOW":
			return Color.YELLOW
		"MAGENTA":
			return Color.MAGENTA
		"CYAN":
			return Color.CYAN
		"ORANGE":
			return Color.ORANGE
		"PURPLE":
			return Color.PURPLE
		_:
			return Color.WHITE

# 弾回収通知を表示する関数
func show_ammo_pickup_notification():
	if not kill_notification_label:
		print("ERROR: KillNotificationLabel not found!")
		return
	
	# 弾回収通知メッセージを作成
	var message = "弾を回収しました"
	kill_notification_label.text = message
	kill_notification_label.visible = true
	
	# 色を設定（緑色で表示）
	kill_notification_label.modulate = Color.GREEN
	
	print("Ammo pickup notification displayed: ", message)
	
	# 2秒後に非表示にする
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.one_shot = true
	timer.timeout.connect(_hide_kill_notification)
	add_child(timer)
	timer.start()

# 弾数表示を更新する関数
func update_ammo_display(current_ammo: int, max_ammo: int):
	# AmmoBarとAmmoLabelが存在するか確認
	if not ammo_bar or not ammo_label:
		print("ERROR: AmmoBar or AmmoLabel not found!")
		return
	
	# 弾数バーの値を更新
	ammo_bar.max_value = max_ammo
	ammo_bar.value = current_ammo
	
	# 弾数バーの色を変更（少ないほど赤く）
	var ammo_percentage = float(current_ammo) / float(max_ammo)
	var bar_color = Color.WHITE
	var text_color = Color.WHITE
	
	if ammo_percentage <= 0.2:
		bar_color = Color.RED
		text_color = Color.WHITE
	elif ammo_percentage <= 0.4:
		bar_color = Color.ORANGE
		text_color = Color.WHITE
	elif ammo_percentage <= 0.6:
		bar_color = Color.YELLOW
		text_color = Color.BLACK
	else:
		bar_color = Color.BLUE
		text_color = Color.WHITE
	
	# ProgressBarの色を設定
	ammo_bar.modulate = bar_color
	
	# テキストの更新と色設定
	ammo_label.text = "🔫 Ammo: " + str(current_ammo) + "/" + str(max_ammo)
	ammo_label.modulate = text_color
	
	print("Updated ammo display - Ammo: ", current_ammo, "/", max_ammo, " Color: ", bar_color)

# ダッシュ表示を更新する関数
func update_dash_display():
	# DashBarとDashLabelが存在するか確認
	if not dash_bar or not dash_label:
		print("ERROR: DashBar or DashLabel not found!")
		return
	
	# ローカルプレイヤーを取得
	var local_player = get_local_player()
	
	if local_player and local_player.has_method("get_dash_charge") and local_player.has_method("get_dash_charge_time"):
		var current_charge = local_player.get_dash_charge()
		var max_charge = local_player.get_dash_charge_time()
		var is_dashing = false
		
		# ダッシュ中かどうかも取得
		if local_player.has_method("is_dash_active"):
			is_dashing = local_player.is_dash_active()
		
		# ダッシュバーの値を更新
		dash_bar.max_value = max_charge
		dash_bar.value = current_charge
		
		# ダッシュバーの色を変更（チャージ量に応じて）
		var charge_percentage = current_charge / max_charge
		var bar_color = Color.WHITE
		var text_color = Color.WHITE
		var label_text = ""
		
		if is_dashing:
			bar_color = Color.PURPLE
			text_color = Color.WHITE
			label_text = "⚡ DASH: Active!"
		elif charge_percentage >= 1.0:
			bar_color = Color.CYAN
			text_color = Color.BLACK
			label_text = "⚡ DASH: Ready"
		elif charge_percentage >= 0.5:
			bar_color = Color.YELLOW
			text_color = Color.BLACK
			label_text = "⚡ DASH: " + str(int(charge_percentage * 100)) + "%"
		else:
			bar_color = Color.RED
			text_color = Color.WHITE
			label_text = "⚡ DASH: " + str(int(charge_percentage * 100)) + "%"
		
		# ProgressBarの色を設定
		dash_bar.modulate = bar_color
		
		# テキストの更新と色設定
		dash_label.text = label_text
		dash_label.modulate = text_color
	else:
		dash_label.text = "⚡ DASH: --"
		dash_label.modulate = Color.WHITE
		dash_bar.modulate = Color.WHITE
		dash_bar.value = 0

# ジャンプ表示を更新する関数
func update_jump_display():
	# JumpLabelが存在するか確認
	if not jump_label:
		print("ERROR: JumpLabel not found!")
		return
	
	# ローカルプレイヤーを取得
	var local_player = get_local_player()
	
	if local_player and local_player.has_method("get_jump_count") and local_player.has_method("get_max_jump_count"):
		var current_count = local_player.get_jump_count()
		var max_count = local_player.get_max_jump_count()
		var is_on_floor = false
		
		# 地面にいるかどうかも取得
		if local_player.has_method("is_on_floor"):
			is_on_floor = local_player.is_on_floor()
		
		# ジャンプ回数に応じて表示と色を変更
		var text_color = Color.WHITE
		var label_text = ""
		
		if is_on_floor:
			text_color = Color.GREEN
			label_text = "🦘 JUMP: Ready (3)"
		else:
			var remaining = max_count - current_count
			if remaining > 0:
				text_color = Color.YELLOW
				label_text = "🦘 JUMP: " + str(remaining) + " left"
			else:
				text_color = Color.RED
				label_text = "🦘 JUMP: None"
		
		# テキストの更新と色設定
		jump_label.text = label_text
		jump_label.modulate = text_color
	else:
		jump_label.text = "🦘 JUMP: --"
		jump_label.modulate = Color.WHITE