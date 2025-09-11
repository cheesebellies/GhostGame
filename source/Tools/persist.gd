extends Node

func menu_join_game(ip: String, port: int, code):
	MultiplayerController.switch_scene(MultiplayerController.SCENE_HUB_LOADING)
	var res = await MultiplayerController.initialize_client(false, ip, port, code)

func menu_singleplayer():
	MultiplayerController.switch_scene(MultiplayerController.SCENE_HUB_LOADING)
	var res = MultiplayerController.initialize_server(1)
	if res != -1:
		var res2 = await MultiplayerController.initialize_client(true,'localhost',res)
		if res2 == 0:
			MultiplayerController.switch_scene(MultiplayerController.SCENE_HUB_WORLD)
			return 0
	MultiplayerController.clear_data()
	await Tools.wait(2000)
	MultiplayerController.switch_scene(MultiplayerController.SCENE_MAIN_MENU)

func menu_host_game(player_max,description,private=false,code=''):
	MultiplayerController.switch_scene(MultiplayerController.SCENE_HUB_LOADING)
	var res = MultiplayerController.initialize_server(player_max,description,code)
	if res != -1:
		var res2 = await MultiplayerController.initialize_client(true,'localhost',res, code)
		if res2 == 0:
			MultiplayerController.switch_scene(MultiplayerController.SCENE_HUB_WORLD)
			if not private:
				MultiplayerController.initialize_scanner()
				MultiplayerController.scanner_start_broadcast()
