extends Node

var client
var server
var create_server_ok = true
enum {MSG_INFO, MSG_ERROR, MSG_OK}

const server_node = preload("res://Multiplayer/server.tscn")
const client_node = preload("res://Multiplayer/client.tscn")

func debug(msg, type: int):
	var color = ""
	match type:
		0:
			color = "dark_gray"
		1:
			color = "indian_red"
		2:
			color = "light_green"
	print_rich("[color=" + color + "][MultiplayerController][/color] " + str(msg))

func _ready():
	debug("Ready.", MSG_INFO)

func stop_server():
	if (not server) or (not create_server_ok):
		debug("No server to close.", MSG_ERROR)
		return 0
	debug("Closing server...", MSG_INFO)
	create_server_ok = false
	server.close()
	var wdel = func helper():
		server.free()
		create_server_ok = true
		server = null
	wdel.call_deferred()
	debug("Server closed. Server Node will be deleted at the end of the next frame.", MSG_OK)

func initialize_server(port_target: int, port_max: int, max_clients: int):
	if server and create_server_ok:
		debug("Failed to open a new server, as there is already an open server (port " + str(server.chosen_port) + ").", MSG_ERROR)
		return -1
	server = server_node.instantiate()
	server.name = "Server"
	server.port_target = port_target
	server.port_max = port_max
	server.max_clients = max_clients
	get_tree().root.add_child(server)
	var chosen_port = server.init()
	if chosen_port == -1:
		debug("Failed to open a server on ports " + str(port_target) + "-" + str(port_max) + ".", MSG_ERROR)
		server.free()
		return -1
	debug("Successfully opened a server on port " + str(chosen_port) + ".", MSG_OK)
	return chosen_port
