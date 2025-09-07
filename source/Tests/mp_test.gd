extends Node


func _on_connect_pressed() -> void:
	var client = load("res://Multiplayer/client.tscn").instantiate()
	client.name = "Client"
	add_child(client)

func _on_host_pressed() -> void:
	var server = load("res://Multiplayer/server.tscn").instantiate()
	server.name = "Server"
	add_child(server)
