extends SceneTree

func _ready():
	print("=== WebRTC Support Test ===")
	
	# WebRTCMultiplayerPeer の存在確認
	var webrtc_peer = null
	if ClassDB.class_exists("WebRTCMultiplayerPeer"):
		print("✓ WebRTCMultiplayerPeer is available")
		webrtc_peer = WebRTCMultiplayerPeer.new()
		print("✓ WebRTCMultiplayerPeer instance created successfully")
	else:
		print("✗ WebRTCMultiplayerPeer is NOT available")
	
	# WebRTCPeerConnection の存在確認
	if ClassDB.class_exists("WebRTCPeerConnection"):
		print("✓ WebRTCPeerConnection is available")
	else:
		print("✗ WebRTCPeerConnection is NOT available")
		
	# WebRTCDataChannel の存在確認  
	if ClassDB.class_exists("WebRTCDataChannel"):
		print("✓ WebRTCDataChannel is available")
	else:
		print("✗ WebRTCDataChannel is NOT available")
	
	# プラットフォーム確認
	print("Platform: ", OS.get_name())
	
	quit()