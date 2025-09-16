extends Node

const NONCE_LENGTH = 128
const HMAC_LENGTH = 32

var cmultiplayer: SceneMultiplayer

var max_clients = 4
var port = 50000
var description: String
var code

var authentication_info: Dictionary = {}
var cryptography = Crypto.new()

var client_info: Dictionary = {}

var enet_peer: ENetMultiplayerPeer

enum {MSG_INFO, MSG_ERROR, MSG_OK}

enum {
	PT_PLAYER_INPUT,
	PT_INIT_INFO,
	PT_STATE_UPDATE,
	PT_EVENT,
	PT_CHAT_MESSAGE,
	PT_SPAWN_DESPAWN,
	PT_LOBBY_MATCHMAKING,
	PT_PING,
	PT_SCORE_STATS,
	PT_ERROR_NOTIFICATION,
	PT_CUSTOM_SYNC
}

func _handle_peer_packet(id: int, packet: PackedByteArray):
	var type = packet.decode_u8(0)
	match type:
		PT_INIT_INFO:
			pt_handle_player_initialization(id, packet)



func pt_handle_player_initialization(id: int, packet: PackedByteArray):
	if not client_connected(id):
		debug("{pt_handle_player_initialization} Client " + str(id) + " not connected.", MSG_ERROR)
	var offset = 1
	var username_len = packet.decode_u8(offset)
	offset += 1
	var username = packet.slice(offset, offset + username_len).get_string_from_utf8()
	offset += username_len
	var character_model = packet.decode_u8(offset)
	# TODO: insert character model & username validation here
	client_info[id]['username'] = username
	client_info[id]['character_model'] = character_model








func client_connected(id: int):
	return client_info[id]['connected']

func _process(delta: float) -> void:
	if not cmultiplayer:
		return
	cmultiplayer.poll()

func debug(msg, type: int):
	var color = ""
	match type:
		0:
			color = "dark_gray"
		1:
			color = "indian_red"
		2:
			color = "light_green"
	print_rich("[color=" + color + "][Server][/color] " + str(msg))

func init():
	cmultiplayer.peer_connected.connect(_handle_peer_connected)
	cmultiplayer.peer_disconnected.connect(_handle_peer_disconnected)
	cmultiplayer.peer_authenticating.connect(_handle_peer_authenticating)
	cmultiplayer.peer_packet.connect(_handle_peer_packet)
	cmultiplayer.set_auth_callback(authenticate_client)
	cmultiplayer.peer_authentication_failed.connect(_handle_authentication_failed)
	var res = enet_peer.create_server(port, max_clients)
	if res != 0:
		return -1
	cmultiplayer.multiplayer_peer = enet_peer
	debug("Server started.", MSG_OK)
	MultiplayerController.update_scanner_players(len(cmultiplayer.get_peers()),max_clients, description)
	return port

func authenticate_client(peer, data: PackedByteArray):
	var ip = cmultiplayer.multiplayer_peer.get_peer(peer).get_remote_address()
	if not ip in authentication_info.keys():
		authentication_info[ip] = {'attempts': 0}
		if data.size() != NONCE_LENGTH:
			debug("Authentication failed for peer " + str(peer) + " at " + ip + ". (Incorrect nonce length) Attempt 1/3.", MSG_ERROR)
			fail_authentication(peer)
		else:
			var nonce := cryptography.generate_random_bytes(NONCE_LENGTH)
			cmultiplayer.send_auth(peer, nonce)
			authentication_info[ip]['combined_nonce'] = data + nonce
			debug("Peer " + str(peer) + ": step 1/2 passed.", MSG_INFO)
	else:
		authentication_info[ip]['attempts'] += 1
		if authentication_info[ip]['attempts'] > 3:
			debug("Authentication failed for peer " + str(peer) + " at " + ip + ". Maximum attempts exceeded (" + str(authentication_info[ip]['attempts']) + ").", MSG_ERROR)
			fail_authentication(peer)
			return
		if data.size() != HMAC_LENGTH:
			debug("Authentication failed for peer " + str(peer) + " at " + ip + ". (Incorrect HMAC length) Attempt " + str(authentication_info[ip]['attempts']) + "/3.", MSG_ERROR)
			fail_authentication(peer)
		else:
			var hash = cryptography.hmac_digest(HashingContext.HASH_SHA256, str(code).to_utf8_buffer(), authentication_info[ip]['combined_nonce'])
			if cryptography.constant_time_compare(hash, data):
				var to_send = PackedByteArray()
				to_send.resize(1)
				to_send.encode_u8(0,len(client_info))
				cmultiplayer.send_auth(peer, to_send)
				cmultiplayer.complete_auth(peer)
				authentication_info.erase(ip)
				debug("Peer " + str(peer) + ": step 2/2 passed.", MSG_INFO)
			else:
				debug("Authentication failed for peer " + str(peer) + " at " + ip + ". (Incorrect HMAC hash) Attempt " + str(authentication_info[ip]['attempts']) + "/3.", MSG_ERROR)
				fail_authentication(peer)

func fail_authentication(peer):
	cmultiplayer.disconnect_peer(peer)
	debug("Disconnected peer " + str(peer) + ".", MSG_INFO)

func _handle_peer_authenticating(peer):
	if code == '':
		debug("Skipping authentication for peer " + str(peer) + " at " + cmultiplayer.multiplayer_peer.get_peer(peer).get_remote_address() + ".", MSG_INFO)
		cmultiplayer.complete_auth(peer)
		return
	debug("Authenticating peer " + str(peer) + " at " + cmultiplayer.multiplayer_peer.get_peer(peer).get_remote_address(),MSG_INFO)

func _handle_authentication_failed(peer):
	debug("Authentication failed for peer " + str(peer) + ".", MSG_ERROR)

func close():
	cmultiplayer.multiplayer_peer.close()
	cmultiplayer.multiplayer_peer = null
	debug("Closed.", MSG_OK)
	return 0

func _handle_peer_disconnected(id):
	MultiplayerController.update_scanner_players(len(cmultiplayer.get_peers()),max_clients, description)
	client_info[id]['connected'] = false
	print("Peer disconnected: " + str(id))

func _handle_peer_connected(id):
	MultiplayerController.update_scanner_players(len(cmultiplayer.get_peers()),max_clients, description)
	client_info[id] = {'index': len(client_info), 'admin': len(client_info) == 0, 'connected': false}
	debug("Authentication successful for peer " + str(id) + " at " + cmultiplayer.multiplayer_peer.get_peer(id).get_remote_address() + ".", MSG_OK)

func _ready():
	cmultiplayer = MultiplayerAPI.create_default_interface()
	enet_peer = ENetMultiplayerPeer.new()
	print("1sthread" + str(OS.get_thread_caller_id()))
