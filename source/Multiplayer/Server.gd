extends Node

#Constants
const NONCE_LENGTH = 128
const HMAC_LENGTH = 32

#"Custom" (local) multiplayer implementation
var cmultiplayer: SceneMultiplayer
var enet_peer: ENetMultiplayerPeer

#Server information
var max_clients = 4
var port = 50000
var description: String
var code: String

#Authentication
var authentication_info: Dictionary = {}
var cryptography = Crypto.new()

#Initialization
var initialized_peers : Array[int] = []
var sending_state : Array[int] = []
var initializing : Array[int] = []
var initialized : Array[int] = []

#Game state
var client_info: Dictionary = {}
var game_state: Dictionary = {}

#Enums
enum {MSG_INFO, MSG_ERROR, MSG_OK}
enum ch {
	WORLDEVENT,	# Reliable
	POSITIONAL,	# Unreliable ordered
	PHYSICS,		# Unreliable ordered
	PLAYEREVENT,# Reliable
	CHAT,		# Reliable
	VOICE,		# Unreliable ordered
	INIT,		# Typically reliable, unreliable for init failure
	DEBUG		# Reliable
}
enum pt {
	PLAYER_INPUT,
	INIT_INFO,
	STATE_UPDATE,
	EVENT,
	CHAT_MESSAGE,
	SPAWN_DESPAWN,
	LOBBY_MATCHMAKING,
	PING,
	SCORE_STATS,
	ERROR_NOTIFICATION,
	CUSTOM_SYNC
}


'''
Packet Reference:

CLIENT INITIALIZATION:
	1. Client sends a request to the server to be initialized
X	2. Server validates the information
X	2a. If invalid, send a callback to the client, remove any client_info
		for the peer, and disconnect the peer
X	2b. If valid, send a callback and continue
x	3. Send information about client to peers
x	4. Send information about game state to client
x	5. Send information about peers to client
	6. Send initialization request for client to peers
	7. Send initialization request for each peer to client
	8. Set client state to active
	
'''





func _handle_peer_packet(id: int, packet: PackedByteArray):
	var type = packet.decode_u8(0)
	match type:
		pt.INIT_INFO:
			var start = packet.decode_u8(1) == 0
			if start:
				sending_state.append(id)
				if len(sending_state) == 0:
					initialized_peers = client_info.keys()
					
				if len(initializing) == 0:
					init_client_validate(id, packet)
			#else:
				##init_complete_initialization(id, packet)




func init_client_validate(id: int, packet: PackedByteArray):
	if not client_connected(id):
		debug("{init} Client " + str(id) + " not connected.", MSG_ERROR)
	var offset = 1
	var username_len = packet.decode_u8(offset)
	offset += 1
	var username = packet.slice(offset, offset + username_len).get_string_from_utf8()
	offset += username_len
	var character_model = packet.decode_u8(offset)
	# TODO: insert character model & username validation here
	var success = true
	client_info[id]['username'] = username
	client_info[id]['character_model'] = character_model
	init_client_validate_callback(id, success)

func init_client_validate_callback(id: int, success: bool):
	if success:
		debug("{init} Client " + str(id) + ": init info validated.", MSG_INFO)
		var packet = PackedByteArray()
		packet.resize(2)
		packet.encode_u8(0,pt.INIT_INFO)
		packet.encode_u8(0,0)
		cmultiplayer.send_bytes(packet,id,MultiplayerPeer.TRANSFER_MODE_RELIABLE, ch.INIT)
	else:
		debug("{init} Client " + str(id) + ": init info invalid.", MSG_ERROR)
		var packet = PackedByteArray()
		packet.resize(2)
		packet.encode_u8(0,pt.INIT_INFO)
		packet.encode_u8(0,1)
		cmultiplayer.send_bytes(packet,id,MultiplayerPeer.TRANSFER_MODE_UNRELIABLE, ch.INIT)
		cmultiplayer.disconnect_peer(id)
		sending_state.erase(id)
		client_info.erase(id)
		return
	var client_state = client_info.get(id)
	if not client_state:
		debug("Client " + str(id) + " does not exist.", MSG_ERROR)
		return -1
	var packet := PackedByteArray()
	packet.resize(2)
	packet.encode_u8(0,pt.INIT_INFO)
	packet.encode_u8(1,1)
	packet += var_to_bytes(client_state)
	for peer in cmultiplayer.get_peers():
		if peer != id:
			cmultiplayer.send_bytes(packet, peer, MultiplayerPeer.TRANSFER_MODE_RELIABLE, ch.INIT)
	packet = PackedByteArray()
	packet.resize(2)
	packet.encode_u8(0,pt.INIT_INFO)
	packet.encode_u8(0,2)
	packet += var_to_bytes(game_state)
	cmultiplayer.send_bytes(packet, id, MultiplayerPeer.TRANSFER_MODE_RELIABLE, ch.INIT)
	var peerdata: Array[PackedByteArray] = []
	for peer in cmultiplayer.get_peers():
		if peer != id:
			peerdata.append(var_to_bytes(client_info[peer]))
	packet = PackedByteArray()
	packet.resize(3+(len(peerdata)*4))
	packet.encode_u8(0,pt.INIT_INFO)
	packet.encode_u8(1,3)
	packet.encode_u8(2,len(peerdata))
	var offset = 3
	for i in peerdata:
		packet.encode_u32(offset, len(i))
		offset += 4
		packet += i
	cmultiplayer.send_bytes(packet, id, MultiplayerPeer.TRANSFER_MODE_RELIABLE, ch.INIT)
	
























func client_connected(id: int):
	return client_info[id]['connected']

func _process(_delta: float) -> void:
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
	var res = enet_peer.create_server(port, max_clients, len(ch))
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
			@warning_ignore('shadowed_global_identifier')
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
	cmultiplayer.set_root_path("/root/Server")
	enet_peer = ENetMultiplayerPeer.new()
	print("1sthread" + str(OS.get_thread_caller_id()))
