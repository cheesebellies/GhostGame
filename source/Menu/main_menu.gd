extends Control

const gra = Color('#d4d4d4')
const whi = Color('#ffffff')

var servers = {}

func _handle_detected_servers(servers):
	for server in servers:
		_add_server_to_list(server[0],server[1],server[2],server[3],server[4])

func _add_server_to_list(ip, port, desc, players, playermax):
	var id = (ip + ":" + str(port))
	var nserv
	if id in servers.keys():
		nserv = servers[id]
	else:
		nserv = $Discover/HBoxContainer/ScrollContainer/ServerBox/STEMP.duplicate()
		servers[id] = nserv
	var nip = nserv.get_node("HBoxContainer/IP")
	var ndesc = nserv.get_node("Desc")
	var npcount = nserv.get_node("HBoxContainer/PCount")
	nip.text = id
	ndesc.text = desc
	npcount.text = str(players) + "/" + str(playermax)
	nserv.visible = true
	$Discover/HBoxContainer/ScrollContainer/ServerBox.add_child(nserv)
	var idx = nserv.get_index()
	nserv.focus_entered.connect(_on_sitem_focus_entered.bind(idx))
	nserv.focus_exited.connect(_on_sitem_focus_exited.bind(idx))

func _on_singleplayer_pressed() -> void:
	Persist.menu_singleplayer()

func _on_multiplayer_pressed() -> void:
	$Main.visible = false
	$MP.visible = true

func _on_settings_pressed() -> void:
	$Main.visible = false
	$Settings.visible = true

func _on_exit_pressed() -> void:
	MultiplayerController.clear_data()
	get_tree().quit()

func _on_host_pressed() -> void:
	$MP.visible = false
	$Host.visible = true

func _on_join_pressed() -> void:
	$Join.visible = true
	$MP.visible = false

func _on_discover_pressed() -> void:
	var res = MultiplayerController.initialize_scanner()
	if res == -1:
		return
	var sig = MultiplayerController.scanner_start_scan()
	sig.connect(_handle_detected_servers)
	$MP.visible = false
	$Discover.visible = true

func _on_create_pressed() -> void:
	var player_max = int($Host/HBoxContainer2/MaxPlayers.value)
	var description = String($Host/HBoxContainer3/Description.text)
	var private = bool($Host/HBoxContainer4/Private.button_pressed)
	var code = String($Host/HBoxContainer4/Code.text)
	Persist.menu_host_game(player_max,description,private,code if private else '')

func _on_settings_return_pressed() -> void:
	$Settings.visible = false
	$Main.visible = true

func _on_min_port_value_changed(value: float) -> void:
	MultiplayerController.port_min = int(value)

func _on_max_port_value_changed(value: float) -> void:
	MultiplayerController.port_max = int(value)

func _on_mp_return_pressed() -> void:
	$MP.visible = false
	$Main.visible = true

func _on_host_return_pressed() -> void:
	$Host.visible = false
	$MP.visible = true

func _on_join_game_pressed() -> void:
	var ip = String($Join/HBoxContainer2/IP.text)
	var code = String($Join/HBoxContainer4/Code.text)
	var port = int($Join/HBoxContainer3/Port.value)
	Persist.menu_join_game(ip, port, code)

func _on_join_return_pressed() -> void:
	$Join.visible = false
	$MP.visible = true

func _on_private_pressed() -> void:
	$Host/HBoxContainer4/Label2.visible = not $Host/HBoxContainer4/Label2.visible
	$Host/HBoxContainer4/Code.visible = not $Host/HBoxContainer4/Code.visible

func _on_refresh_pressed() -> void:
	servers = {}

func _on_discover_join_pressed() -> void:
	var sit = get_viewport().gui_get_focus_owner()
	if (not sit) or sit is not VBoxContainer:
		return
	var dat = sit.get_node("HBoxContainer/IP").text
	var ip = dat.split(":")[0]
	var port = dat.split(":")[1]
	Persist.menu_join_game(ip,port,'')
	

func _on_discover_return_pressed() -> void:
	MultiplayerController.close_scanner()
	$Discover.visible = false
	$MP.visible = true

func _on_sitem_focus_entered(id) -> void:
	var sit = $Discover/HBoxContainer/ScrollContainer/ServerBox.get_children()[id]
	sit.modulate = whi

func _on_sitem_focus_exited(id) -> void:
	var sit = $Discover/HBoxContainer/ScrollContainer/ServerBox.get_children()[id]
	sit.modulate = gra
