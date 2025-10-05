extends Node

#Constants
const NONCE_LENGTH = 128
const HMAC_LENGTH = 32
const INIT_TIMEOUT = 5.0

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
var init_queue: Array[int] = []
var current_init
signal next_init
signal client_callback(s: bool)

#Game state
var client_info: Dictionary = {}
var game_state: Dictionary = {}

#Game simulation
var simulator

#Enums
enum {MSG_INFO, MSG_ERROR, MSG_OK}
enum ch {
	WORLDEVENT,	# Reliable
	POSITIONAL,	# Unreliable ordered
	PHYSICS,		# Unreliable ordered
	PLAYEREVENT,# Reliable
	CHAT,		# Reliable
	VOICE,		# Unreliable ordered
	INIT,		# Reliable
	DEBUG		# Reliable
}
enum pt {
	PLAYER_INPUT,
	INIT_INFO,
	DEINIT_INFO,
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
enum gs {
	HUB,
	MCGUFFEYS
}


'''
TODO:
	- Client keeps track of all information updates to uninitialized/missing
	  players, if the count gets too high, ask server for info
	- Server scanner for private games
'''


func _handle_peer_packet(id: int, packet: PackedByteArray):
	var type = packet.decode_u8(0)
	match type:
		pt.INIT_INFO:
			if id == current_init:
				if packet.decode_u8(1) == 0:
					client_callback.emit(true)
				else:
					client_callback.emit(false)

func initialize_client(id: int):
	init_queue.append(id)
	for i in range(len(init_queue)-1):
		await self.next_init
	debug("init client " + str(id), MSG_INFO)
	current_init = id
	var packet = PackedByteArray()
	packet.resize(2)
	packet.encode_u8(0, pt.INIT_INFO)
	packet.encode_u8(1, 0)
	packet += var_to_bytes(game_state)
	cmultiplayer.send_bytes(packet,id,MultiplayerPeer.TRANSFER_MODE_RELIABLE,ch.INIT)
	packet.resize(2)
	packet.encode_u8(1, 1)
	var new_client_info = {}
	for cid in client_info.keys():
		if (cid == id) or client_active(cid):
			new_client_info[cid] = client_info[cid]
	packet += var_to_bytes(new_client_info)
	cmultiplayer.send_bytes(packet,id,MultiplayerPeer.TRANSFER_MODE_RELIABLE,ch.INIT)
	var res = await Tools.with_timeout(self.client_callback, 4)
	if not res[0] or not res[1][0]:
		debug("Client " + str(id) + (" failed to initialize in time. Aborting." if res[0] else " had an initialization error. Aborting."), MSG_ERROR)
		packet.resize(1)
		packet.encode_u8(0,pt.DEINIT_INFO)
		cmultiplayer.send_bytes(packet,id,MultiplayerPeer.TRANSFER_MODE_RELIABLE,ch.INIT)
		await Tools.wait(1)
		cmultiplayer.disconnect_peer(id)
		current_init = null
		init_queue.pop_front()
		self.next_init.emit()
	else:
		debug("Client " + str(id) + " initialized. Updating other clients.", MSG_OK)
		packet = PackedByteArray()
		packet.resize(10)
		packet.encode_u8(0, pt.INIT_INFO)
		packet.encode_u8(1,2)
		packet.encode_s64(2,id)
		packet += var_to_bytes(client_info[id])
		for peer in client_info.keys():
			if client_active(peer):
				cmultiplayer.send_bytes(packet,peer,MultiplayerPeer.TRANSFER_MODE_RELIABLE,ch.INIT)
		client_info[id]['active'] = true
		current_init = null
		init_queue.pop_front()
		self.next_init.emit()












func simulator_start():
	simulator = load("res://Multiplayer/simulator.tscn").instantiate()
	simulator.name = "Simulator"
	add_child(simulator)
	debug("Simulator started", MSG_OK)

func simulator_load_scene(scene: int):
	if not simulator:
		debug("Simulator does not exist.", MSG_ERROR)
		return -1
	if simulator.active:
		debug("Simulator already active.", MSG_ERROR)
		return -2
	var res = simulator.load_scene(scene)
	if res == 0:
		debug("Simulator loaded scene " + str(gs.find_key(scene)) + ".", MSG_OK)
		return 0
	else:
		debug("Simulator failed to load scene " + str(scene) + ". Simulator error code " + str(res) + ".", MSG_ERROR)
		return -3

func simulator_stop():
	if simulator:
		simulator.stop()
		simulator = null
	debug("Stopped simulator", MSG_OK)

func simulator_add_client(id: int):
	if not simulator:
		debug("Simulator does not exist.", MSG_ERROR)
		return -1
	if not simulator.active:
		debug("Simulator needs to be active.", MSG_ERROR)
		return -2
	if not client_connected(id):
		debug("Client " + str(id) + " needs to be connected.", MSG_ERROR)
		return -3
	var res = simulator.add_client(id, client_info[id])
	if res == 0:
		debug("Added client " + str(id) + " to simulator.", MSG_OK)
		return 0
	else:
		debug("Failed to add client " + str(id) + " to simulator. Simulator error code " + str(res) + ".", MSG_ERROR)
		return -4












func client_active(id: int):
	return client_connected(id) and client_info[id]['active']

func client_connected(id: int):
	return client_info.has(id) and client_info[id]['connected']

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
	cmultiplayer.server_relay = false
	debug("Server started.", MSG_OK)
	MultiplayerController.update_scanner_players(len(cmultiplayer.get_peers()),max_clients, description)
	return port

func authenticate_client(peer, data: PackedByteArray):
	if not peer in authentication_info.keys():
		authentication_info[peer] = {}
		if data.size() != NONCE_LENGTH:
			debug("Authentication failed for peer " + str(peer) + ". (Incorrect nonce length)", MSG_ERROR)
			fail_authentication(peer)
		else:
			var nonce := cryptography.generate_random_bytes(NONCE_LENGTH)
			cmultiplayer.send_auth(peer, nonce)
			authentication_info[peer]['combined_nonce'] = data + nonce
			debug("Peer " + str(peer) + ": step 1/2 passed.", MSG_INFO)
	else:
		if data.size() != HMAC_LENGTH:
			debug("Authentication failed for peer " + str(peer) + ". (Incorrect HMAC length)", MSG_ERROR)
			fail_authentication(peer)
		else:
			@warning_ignore('shadowed_global_identifier')
			var hash = cryptography.hmac_digest(HashingContext.HASH_SHA256, str(code).to_utf8_buffer(), authentication_info[peer]['combined_nonce'])
			if cryptography.constant_time_compare(hash, data):
				var to_send = PackedByteArray()
				to_send.resize(1)
				to_send.encode_u8(0,len(client_info))
				cmultiplayer.send_auth(peer, to_send)
				cmultiplayer.complete_auth(peer)
				authentication_info.erase(peer)
				debug("Peer " + str(peer) + ": step 2/2 passed.", MSG_INFO)
			else:
				debug("Authentication failed for peer " + str(peer) + ". (Incorrect HMAC hash)", MSG_ERROR)
				fail_authentication(peer)

func fail_authentication(peer):
	cmultiplayer.disconnect_peer(peer)
	authentication_info.erase(peer)
	debug("Disconnected peer " + str(peer) + ".", MSG_INFO)

func _handle_peer_authenticating(peer):
	if code == '':
		debug("Skipping authentication for peer " + str(peer) + ".", MSG_INFO)
		cmultiplayer.complete_auth(peer)
		return
	debug("Authenticating peer " + str(peer) + ".",MSG_INFO)

func _handle_authentication_failed(peer):
	debug("Authentication failed for peer " + str(peer) + ".", MSG_ERROR)

func close():
	if cmultiplayer.multiplayer_peer:
		cmultiplayer.multiplayer_peer.close()
		cmultiplayer.multiplayer_peer = null
	debug("Closed.", MSG_OK)
	return 0

func _handle_peer_disconnected(id):
	MultiplayerController.update_scanner_players(len(cmultiplayer.get_peers()),max_clients, description)
	client_info[id]['connected'] = false
	client_info[id]['active'] = false
	print("Peer disconnected: " + str(id))

func _handle_peer_connected(id):
	MultiplayerController.update_scanner_players(len(cmultiplayer.get_peers()),max_clients, description)
	if not client_info.has(id):
		client_info[id] = {'index': len(client_info), 'admin': len(client_info) == 0, 'connected': true, 'active': false}
	else:
		client_info[id]['connected'] = true
	initialize_client(id)
	debug("Peer " + str(id) + " connected from " + cmultiplayer.multiplayer_peer.get_peer(id).get_remote_address() + ".", MSG_OK)

#func cmultiplayer.send_bytes(bytes: PackedByteArray, id: int = 0, mode: int = 2, channel: int = 0):
	#cmultiplayer.send_bytes("<SD>".to_utf8_buffer() + bytes + "<ED>".to_utf8_buffer(),id,mode,channel)

func _ready():
	cmultiplayer = MultiplayerAPI.create_default_interface()
	cmultiplayer.set_root_path("/root/Server")
	enet_peer = ENetMultiplayerPeer.new()
