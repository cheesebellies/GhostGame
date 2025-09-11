class_name Server
extends Node

const NONCE_LENGTH = 128
const HMAC_LENGTH = 32


var max_clients = 4
var port = 50000
var description: String
var code

var authentication_info: Dictionary = {}
var client_info: Dictionary = {}
var cryptography = Crypto.new()

var enet_peer: ENetMultiplayerPeer

enum {MSG_INFO, MSG_ERROR, MSG_OK}

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
	multiplayer.peer_connected.connect(_handle_peer_connected)
	multiplayer.peer_disconnected.connect(_handle_peer_disconnected)
	multiplayer.peer_authenticating.connect(_handle_peer_authenticating)
	multiplayer.set_auth_callback(authenticate_client)
	multiplayer.peer_authentication_failed.connect(_handle_authentication_failed)
	var res = enet_peer.create_server(port, max_clients)
	if res != 0:
		return -1
	multiplayer.multiplayer_peer = enet_peer
	debug("Server started.", MSG_OK)
	MultiplayerController.update_scanner_players(len(multiplayer.get_peers()),max_clients, description)
	return port

func authenticate_client(peer, data: PackedByteArray):
	var ip = multiplayer.multiplayer_peer.get_peer(peer).get_remote_address()
	if not ip in authentication_info.keys():
		authentication_info[ip] = {'attempts': 0}
		if data.size() != NONCE_LENGTH:
			debug("Authentication failed for peer " + str(peer) + " at " + ip + ". (Incorrect nonce length) Attempt 1/3.", MSG_ERROR)
			fail_authentication(peer)
		else:
			var nonce := cryptography.generate_random_bytes(NONCE_LENGTH)
			multiplayer.send_auth(peer, nonce)
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
			var hash = cryptography.hmac_digest(HashingContext.HASH_SHA256, str(code).to_ascii_buffer(), authentication_info[ip]['combined_nonce'])
			if cryptography.constant_time_compare(hash, data):
				var to_send = PackedByteArray()
				to_send.resize(1)
				to_send.encode_u8(0,len(client_info))
				multiplayer.send_auth(peer, to_send)
				multiplayer.complete_auth(peer)
				authentication_info.erase(ip)
				debug("Peer " + str(peer) + ": step 2/2 passed.", MSG_INFO)
			else:
				debug("Authentication failed for peer " + str(peer) + " at " + ip + ". (Incorrect HMAC hash) Attempt " + str(authentication_info[ip]['attempts']) + "/3.", MSG_ERROR)
				fail_authentication(peer)

func fail_authentication(peer):
	multiplayer.disconnect_peer(peer)
	debug("Disconnected peer " + str(peer) + ".", MSG_INFO)

func _handle_peer_authenticating(peer):
	if code == '':
		debug("Skipping authentication for peer " + str(peer) + " at " + multiplayer.multiplayer_peer.get_peer(peer).get_remote_address() + ".", MSG_INFO)
		multiplayer.complete_auth(peer)
		return
	debug("Authenticating peer " + str(peer) + " at " + multiplayer.multiplayer_peer.get_peer(peer).get_remote_address(),MSG_INFO)

func _handle_authentication_failed(peer):
	debug("Authentication failed for peer " + str(peer) + ".", MSG_ERROR)

func close():
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	debug("Closed.", MSG_OK)
	return 0

func _handle_peer_disconnected(id):
	MultiplayerController.update_scanner_players(len(multiplayer.get_peers()),max_clients)
	print("Peer disconnected: " + str(id))

func _handle_peer_connected(id):
	MultiplayerController.update_scanner_players(len(multiplayer.get_peers()),max_clients)
	client_info[id] = {'index': len(client_info), 'admin': len(client_info) == 0}
	debug("Authentication successful for peer " + str(id) + " at " + multiplayer.multiplayer_peer.get_peer(id).get_remote_address() + ".", MSG_OK)

func _ready():
	get_tree().set_multiplayer(MultiplayerAPI.create_default_interface(),self.get_path())
	enet_peer = ENetMultiplayerPeer.new()
