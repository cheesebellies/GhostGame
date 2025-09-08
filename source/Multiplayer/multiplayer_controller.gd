extends Node

var client
var server
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

func stop_server(retries: int = 10, force: bool = false):
	if not server:
		debug("No server to close.", MSG_ERROR)
		return 0
	if retries <= 0:
		retries = 1
	debug("Closing server...", MSG_INFO)
	for try in range(retries):
		debug("Attempt " + str(try) + "...", MSG_INFO)
		var res = server.close()
		if res != 0:
			debug("Attempt failed. (Code " + str(res) + ")", MSG_ERROR)
		else:
			if force:
				server.free()
			else:
				server.queue_free()
			server = null
			debug("Server " + ("forcefully " if force else "") + "closed.", MSG_OK)
			return 0
	if not force:
		debug("Failed to close server.", MSG_ERROR)
	else:
		server.free()
		server = null
		debug("Server forcefully closed.", MSG_OK)

func initialize_server(port_target: int, port_max: int, max_clients: int):
	if server:
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
