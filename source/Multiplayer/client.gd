extends Node

#Constants
const NONCE_LENGTH = 128
const HMAC_LENGTH = 32

#"Custom" (local) multiplayer implementation
var cmultiplayer: SceneMultiplayer
var enet_peer: ENetMultiplayerPeer

#Client information
var admin
var ip
var port
var index

#Authentication
var cryptography = Crypto.new()
var code
var authentication_data

#Initialization
signal connection_update(type: bool)
var init_step := 0

#Game state
var client_info : Dictionary = {}
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



func _handle_server_packet(id: int, packet: PackedByteArray):
	if id != 1:
		return
	var type = packet.decode_u8(0)
	match type:
		pt.INIT_INFO:
			var req = packet.decode_u8(1)
			if req == 0:
				init_recieve_game_data(packet)
			elif req == 1:
				init_recieve_client_info(packet)
			elif req == 2:
				init_new_client(packet)

func init_new_client(packet: PackedByteArray):
	var nc_id = packet.decode_s64(2)
	var nc_data = packet.decode_var(10)
	client_info[nc_id] = nc_data
	debug("Recieved new client " + str(nc_id) + ".", MSG_OK)

func init_recieve_game_data(packet: PackedByteArray):
	game_state = packet.decode_var(2)
	init_step += 1

func init_recieve_client_info(packet: PackedByteArray):
	client_info = packet.decode_var(2)
	init_step += 1
	var callback = PackedByteArray()
	callback.resize(2)
	callback.encode_u8(0,pt.INIT_INFO)
	callback.encode_u8(1, 0 if init_step == 2 else 1)
	if init_step == 2:
		debug("Recieved valid init information.", MSG_OK)
	else:
		debug("Recieved invalid init information.", MSG_ERROR)
	cmultiplayer.send_bytes(callback,1,MultiplayerPeer.TRANSFER_MODE_RELIABLE,ch.INIT)
















func debug(msg, type: int):
	var color = ""
	match type:
		0:
			color = "dark_gray"
		1:
			color = "indian_red"
		2:
			color = "light_green"
	print_rich("[color=" + color + "][Client][/color] " + str(msg))

func close():
	return 0

func init():
	cmultiplayer.peer_authenticating.connect(_handle_peer_authenticating)
	cmultiplayer.set_auth_callback(authenticate)
	cmultiplayer.peer_authentication_failed.connect(_handle_authentication_failed)
	cmultiplayer.connected_to_server.connect(_handle_connected_to_server)
	cmultiplayer.connection_failed.connect(_handle_connection_failed)
	cmultiplayer.server_disconnected.connect(_handle_server_disconnected)
	cmultiplayer.peer_packet.connect(_handle_server_packet)
	var err = enet_peer.create_client(ip, port)
	if err != OK:
		return -1
	cmultiplayer.multiplayer_peer = enet_peer
	var res = await self.connection_update
	if res:
		debug("Client created.", MSG_OK)
		return 0
	else:
		return -2

func _handle_authentication_failed(peer):
	debug("Authentication failed. (Client/server disagreement)", MSG_ERROR)
	failed_authentication()

func _handle_peer_authenticating(peer):
	if code == "":
		debug("Skipping authentication.", MSG_INFO)
		cmultiplayer.complete_auth(peer)
		return
	debug("Starting authentication...", MSG_INFO)
	authentication_data = cryptography.generate_random_bytes(NONCE_LENGTH)
	cmultiplayer.send_auth(peer, authentication_data)

func authenticate(peer, data: PackedByteArray):
	if data.size() != NONCE_LENGTH:
		if data.size() == 1:
			index = data.decode_u8(0)
			debug("Completing authentication...", MSG_INFO)
			cmultiplayer.complete_auth(peer)
		else:
			debug("Authentication failed. (Incorrect nonce length).", MSG_ERROR)
			failed_authentication()
	else:
		@warning_ignore("shadowed_global_identifier")
		var hash = cryptography.hmac_digest(HashingContext.HASH_SHA256, str(code).to_utf8_buffer(), authentication_data + data)
		cmultiplayer.send_auth(peer, hash)

func failed_authentication():
	debug("Returning to menu...", MSG_INFO)
	Persist.client_failed_authentication()

func _handle_connected_to_server():
	connection_update.emit(true)

func _handle_connection_failed():
	connection_update.emit(false)

func _handle_server_disconnected():
	debug("Server disconnected.", MSG_ERROR)
	#Persist.client_failed_authentication()

func _process(delta: float) -> void:
	if not cmultiplayer:
		return
	cmultiplayer.poll()

func _ready():
	cmultiplayer = MultiplayerAPI.create_default_interface()
	cmultiplayer.set_root_path("/root/Client")
	enet_peer = ENetMultiplayerPeer.new()
