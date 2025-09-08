extends Node

const MAX_CLIENTS = 4

var enet_peer: ENetMultiplayerPeer

func init():
	multiplayer.connected_to_server.connect(_handle_connected_to_server)
	multiplayer.connection_failed.connect(_handle_connection_failed)
	multiplayer.server_disconnected.connect(_handle_server_disconnected)
	var err = enet_peer.create_client('localhost',50000)
	print(err)
	multiplayer.multiplayer_peer = enet_peer

func _handle_connected_to_server():
	print("Connected to the server.")

func _handle_connection_failed():
	print("Failed to connect to the server.")

func _handle_server_disconnected():
	print("Server disconnected.")

func _ready():
	enet_peer = ENetMultiplayerPeer.new()
