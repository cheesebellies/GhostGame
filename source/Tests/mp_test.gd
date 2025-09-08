extends Node

func _on_connect_pressed() -> void:
	#var client = load("res://Multiplayer/client.tscn").instantiate()
	#client.name = "Client"
	#add_child(client)
	#client.init()
	MultiplayerController.stop_server(10,true)
	#var scanner = load("res://Multiplayer/scanner.tscn").instantiate()
	#scanner.name = "Scanner"
	#add_child(scanner)
	#scanner.servers.connect(test)
	#var res = scanner.start_scan(54833,1)
	#print(res)

func _on_host_pressed() -> void:
	MultiplayerController.initialize_server(50000,50005,4)
	#if port != -1:
		#var scanner = load("res://Multiplayer/scanner.tscn").instantiate()
		#scanner.name = "Scanner"
		#add_child(scanner)
		#var res = scanner.start_broadcast(5001, 54833, 1)
		#print(res)

func test(ser):
	print(ser)
