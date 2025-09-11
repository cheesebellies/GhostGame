class_name Client
extends Node

const NONCE_LENGTH = 128
const HMAC_LENGTH = 32

var admin
var ip
var port
var index

var cryptography = Crypto.new()
var code
var authentication_data

var enet_peer: ENetMultiplayerPeer

signal connection_update(type: bool)

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
	print_rich("[color=" + color + "][Client][/color] " + str(msg))

func init():
	multiplayer.peer_authenticating.connect(_handle_peer_authenticating)
	multiplayer.set_auth_callback(authenticate)
	multiplayer.peer_authentication_failed.connect(_handle_authentication_failed)
	multiplayer.connected_to_server.connect(_handle_connected_to_server)
	multiplayer.connection_failed.connect(_handle_connection_failed)
	multiplayer.server_disconnected.connect(_handle_server_disconnected)
	var err = enet_peer.create_client(ip, port)
	if err != OK:
		return -1
	multiplayer.multiplayer_peer = enet_peer
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
		multiplayer.complete_auth(peer)
		return
	debug("Starting authentication...", MSG_INFO)
	authentication_data = cryptography.generate_random_bytes(NONCE_LENGTH)
	multiplayer.send_auth(peer, authentication_data)

func authenticate(peer, data: PackedByteArray):
	if data.size() != NONCE_LENGTH:
		if data.size() == 1:
			index = data.decode_u8(0)
			debug("Completing authentication...", MSG_INFO)
			multiplayer.complete_auth(peer)
		else:
			debug("Authentication failed. (Incorrect nonce length).", MSG_ERROR)
			failed_authentication()
	else:
		var hash = cryptography.hmac_digest(HashingContext.HASH_SHA256, str(code).to_ascii_buffer(), authentication_data + data)
		multiplayer.send_auth(peer, hash)

func failed_authentication():
	pass

func _handle_connected_to_server():
	connection_update.emit(true)

func _handle_connection_failed():
	connection_update.emit(false)

func _handle_server_disconnected():
	debug("Server disconnected.", MSG_ERROR)

func _ready():
	get_tree().set_multiplayer(MultiplayerAPI.create_default_interface(),self.get_path())
	enet_peer = ENetMultiplayerPeer.new()
