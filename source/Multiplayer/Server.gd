class_name Server
extends Node

var max_clients = 4
var port_target: int = 50000
var port_max: int = 50020
var chosen_port: int

var enet_peer: ENetMultiplayerPeer

func init():
	multiplayer.peer_connected.connect(_handle_peer_connected)
	multiplayer.peer_disconnected.connect(_handle_peer_disconnected)
	
	chosen_port = port_target
	var port_found = false
	while chosen_port <= port_max:
		var res = enet_peer.create_server(chosen_port, max_clients)
		if res != 0:
			chosen_port += 1
		else:
			port_found = true
			break
	
	if port_found:
		multiplayer.multiplayer_peer = enet_peer
		return chosen_port
	return -1

func close():
	# Returns 0 for success and other ints for error
	print_debug("IMPLEMENT ME: closing server.")
	return 9

func _handle_peer_disconnected(id):
	print("Peer disconnected: " + str(id))

func _handle_peer_connected(id):
	print("Peer connected: " + str(id))

func _ready():
	enet_peer = ENetMultiplayerPeer.new()
