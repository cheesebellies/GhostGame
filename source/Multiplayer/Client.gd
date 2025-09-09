class_name Client
extends Node

var admin
var ip
var port

var enet_peer: ENetMultiplayerPeer

signal connection_update(type: bool)

func init():
	multiplayer.connected_to_server.connect(_handle_connected_to_server)
	multiplayer.connection_failed.connect(_handle_connection_failed)
	multiplayer.server_disconnected.connect(_handle_server_disconnected)
	var err = enet_peer.create_client(ip, port)
	if err != OK:
		return -1
	multiplayer.multiplayer_peer = enet_peer
	var res = await self.connection_update
	if res:
		return 0
	else:
		return -2
	

func _handle_connected_to_server():
	connection_update.emit(true)

func _handle_connection_failed():
	connection_update.emit(false)

func _handle_server_disconnected():
	print("Server disconnected.")

func _ready():
	get_tree().set_multiplayer(MultiplayerAPI.create_default_interface(),self.get_path())
	enet_peer = ENetMultiplayerPeer.new()
