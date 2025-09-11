extends Control

func _ready():
	print(await Tools.get_local_ip())

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
	pass # Replace with function body.

func _on_create_pressed() -> void:
	var player_max = int($Host/HBoxContainer2/MaxPlayers.value)
	var description = String($Host/HBoxContainer3/Description.text)
	var private = bool($Host/HBoxContainer4/Private.button_pressed)
	var code = int($Host/HBoxContainer4/Code.value)
	Persist.menu_host_game(player_max,description,private,code)

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
	var code = int($Join/HBoxContainer3/Code.value)
	var port = int($Join/HBoxContainer3/HBoxContainer3/Port.value)
	Persist.menu_join_game(ip, port, code)

func _on_join_return_pressed() -> void:
	$Join.visible = false
	$MP.visible = true
