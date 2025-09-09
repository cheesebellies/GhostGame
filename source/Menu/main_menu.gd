extends Control

func _on_singleplayer_pressed() -> void:
	MultiplayerController.menu_singplayer()

func _on_multiplayer_pressed() -> void:
	$Main.visible = false
	$MP.visible = true

func _on_settings_pressed() -> void:
	pass

func _on_exit_pressed() -> void:
	MultiplayerController.clear_data()
	get_tree().quit()

func _on_host_pressed() -> void:
	pass # Replace with function body.

func _on_join_pressed() -> void:
	pass # Replace with function body.

func _on_discover_pressed() -> void:
	pass # Replace with function body.
