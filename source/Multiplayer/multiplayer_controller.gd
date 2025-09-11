extends Node

var client
var server
var scanner
var create_server_ok = true
var create_client_ok = true
var create_scanner_ok = true

var port_min = 50000
var port_max = 50100

enum {MSG_INFO, MSG_ERROR, MSG_OK}
enum {SCENE_HUB_LOADING, SCENE_MAIN_MENU, SCENE_TEST_WORLD, SCENE_HUB_WORLD}

const scene_reference := {
	SCENE_HUB_LOADING: 'res://Tests/temp_loading.tscn',
	SCENE_MAIN_MENU: 'res://Menu/main_menu.tscn',
	SCENE_HUB_WORLD: 'res://Tests/asset_test.tscn',
	SCENE_TEST_WORLD: 'res://Tests/asset_test.tscn'
}

const server_node = preload("res://Multiplayer/server.tscn")
const client_node = preload("res://Multiplayer/client.tscn")
const scanner_node = preload("res://Multiplayer/scanner.tscn")

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
	var p = await IP.resolve_hostname('localhost')
	print(p)
	var todo = """
	TODO:
		Edit scanner to have a confirmation echo
		Create simple packet system
			Ensure that it works with both singleplayer and multiplayer
		Create synchronization registry within MultiplayerController
	"""
	debug(todo, MSG_INFO)

func clear_data():
	var res
	var res2
	if server:
		res = stop_server()
	if client:
		res2 = close_client()
	return [res,res2]

func initialize_scanner():
	if not create_scanner_ok:
		debug("Failed to create a new scanner, as the previous scanner is still being deleted.", MSG_ERROR)
		return -1
	if scanner:
		debug("Failed to create a new scanner, as there is already a scanner in this session.", MSG_ERROR)
		return -1
	scanner = scanner_node.instantiate()
	scanner.name = "Scanner"
	add_child(scanner)
	return 0

func scanner_start_broadcast():
	if not server:
		debug("No open server, cannot start broadcast.", MSG_ERROR)
		return -1
	var port = server.port
	if port == -1:
		debug("Could not find an open port in the range " + str(port_min) + "-" + str(port_max) + " to start a Scanner broadcast.", MSG_ERROR)
		return -1
	var res = scanner.start_broadcast(53827, port, 1)
	if res != 0:
		debug("Could not start the broadcast, error code " + str(res) + ".", MSG_ERROR)
		return -1
	debug("Started broadcasting to port 53827 from port " + str(port) + ".", MSG_OK)
	return 0

func stop_server():
	if (not server) or (not create_server_ok):
		debug("No server to close.", MSG_ERROR)
		return -1
	debug("Closing server...", MSG_INFO)
	create_server_ok = false
	server.close()
	var wdel = func helper():
		server.free()
		create_server_ok = true
		server = null
	wdel.call_deferred()
	debug("Server closed. Server Node will be freed at the end of the next frame.", MSG_OK)
	return 0

func switch_scene(scene: int):
	var path = scene_reference.get(scene)
	if not path:
		return -1
	var res = get_tree().change_scene_to_packed(load(path))
	return res

func close_client():
	if (not client) or (not create_client_ok):
		debug("No client to close.", MSG_ERROR)
		return -1
	debug("Closing client...", MSG_INFO)
	create_client_ok = false
	client.close()
	var wdel = func helper():
		client.free()
		create_client_ok = true
		client = null
	wdel.call_deferred()
	debug("Client closed. Client Node will be freed at the end of the next frame.", MSG_OK)
	return 0

func initialize_client(is_admin: bool, ip: String, port: int, code: int = 0):
	if not create_client_ok:
		debug("Failed to create a new client, as the previous client is still being deleted.", MSG_ERROR)
		return -1
	if client:
		debug("Failed to create a new client, as there is already a client in this session.", MSG_ERROR)
		return -1
	client = client_node.instantiate()
	client.name = "Client"
	client.admin = is_admin
	client.ip = ip
	client.port = port
	client.code = code
	get_tree().root.add_child(client)
	var res = await client.init()
	if res == -2:
		debug("Failed to create a new client, server connection failed.", MSG_ERROR)
		return -2
	if res == -1:
		debug("Failed to create a new client.", MSG_ERROR)
		return -1
	debug("Successfully created a client.", MSG_OK)
	return 0

func initialize_server(max_clients: int, description: String = "", code: int = 0):
	if not create_server_ok:
		debug("Failed to open a new server, as the previous server is still being closed.", MSG_ERROR)
		return -1
	if server:
		debug("Failed to open a new server, as there is already an open server in this session. (port " + str(server.chosen_port) + ").", MSG_ERROR)
		return -1
	server = server_node.instantiate()
	server.name = "Server"
	server.description = description.left(16)
	var port = Tools.scan_for_port(port_min, port_max)
	if port == -1:
		debug("Failed to open a server on ports " + str(port_min) + "-" + str(port_max) + ".", MSG_ERROR)
		server.free()
		return -1
	server.port = port
	server.max_clients = max_clients
	server.code = code
	get_tree().root.add_child(server)
	var chosen_port = server.init()
	if chosen_port == -1:
		debug("Failed to open a server on ports " + str(port_min) + "-" + str(port_max) + ".", MSG_ERROR)
		server.free()
		return -1
	debug("Successfully opened a server on port " + str(chosen_port) + ".", MSG_OK)
	return chosen_port
