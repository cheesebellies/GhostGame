extends Node

var client
var server
var create_server_ok = true
var create_client_ok = true

enum {MSG_INFO, MSG_ERROR, MSG_OK}
enum {SCENE_HUB_LOADING, SCENE_MAIN_MENU, SCENE_TEST_WORLD}

const scene_reference := {
	SCENE_HUB_LOADING: 'res://Tests/temp_loading.tscn',
	SCENE_MAIN_MENU: 'res://Menu/main_menu.tscn',
	SCENE_TEST_WORLD: 'res://Tests/asset_test.tscn'
}

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

func clear_data():
	var res
	var res2
	if server:
		res = stop_server()
	if client:
		res2 = close_client()
	return [res,res2]

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

func initialize_client(is_admin: bool, ip: String, port: int):
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

func initialize_server(port_target: int, port_max: int, max_clients: int):
	if not create_server_ok:
		debug("Failed to open a new server, as the previous server is still being closed.", MSG_ERROR)
		return -1
	if server:
		debug("Failed to open a new server, as there is already an open server in this session. (port " + str(server.chosen_port) + ").", MSG_ERROR)
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






func menu_singplayer():
	MultiplayerController.switch_scene(MultiplayerController.SCENE_HUB_LOADING)
	var res = MultiplayerController.initialize_server(50000,50000,1)
	if res != -1:
		var res2 = await MultiplayerController.initialize_client(true,'localhost',res)
		if res2 == 0:
			MultiplayerController.switch_scene(MultiplayerController.SCENE_TEST_WORLD)
			return 0
	MultiplayerController.clear_data()
	await Tools.wait(2000)
	MultiplayerController.switch_scene(MultiplayerController.SCENE_MAIN_MENU)
