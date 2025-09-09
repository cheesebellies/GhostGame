extends Node

func wait(milliseconds: int):
	await get_tree().create_timer(float(milliseconds)/1000).timeout
	return 0
