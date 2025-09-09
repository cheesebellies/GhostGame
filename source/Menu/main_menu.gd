extends Control


func _on_singleplayer_pressed() -> void:
	MultiplayerController.switch_scene(MultiplayerController.SCENE_HUB_LOADING)
	MultiplayerController.initialize_server(50000,50100,1)
	MultiplayerController

func _on_multiplayer_pressed() -> void:
	pass # Replace with function body.

func _on_settings_pressed() -> void:
	pass # Replace with function body.

func _on_exit_pressed() -> void:
	pass # Replace with function body.

func _on_host_pressed() -> void:
	pass # Replace with function body.

func _on_join_pressed() -> void:
	pass # Replace with function body.

func _on_discover_pressed() -> void:
	pass # Replace with function body.
