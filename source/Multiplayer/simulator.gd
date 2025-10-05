extends Node

var active := false
var client_info : Dictionary = {}

var current_scene: Node
var spawn_positions: Array[Vector3]
var interactables: Array[Node]

enum {MSG_INFO, MSG_ERROR, MSG_OK}
enum gs {
	HUB,
	MCGUFFEYS
}

var gs_ref: Dictionary = {
	# TODO: SWITCH THESE OUT FOR VISUAL-CULLED VERSIONS
	gs.HUB: "res://World/hub/hub.tscn",
	gs.MCGUFFEYS: "res://World/Houses/McGuffeys/McGuffeys.tscn"
}


func get_scene_information():
	var worker = func w(n,r):
		for c in n.get_children(true):
			if "playerspawn" in c.get_groups():
				spawn_positions.append(c.global_position)
			if "interactable" in c.get_groups():
				interactables.append(c)
			r.call(c,r)
	worker.call(current_scene,worker)
	

func add_client(id: int, info: Dictionary):
	if client_info.has(id):
		return -1
	client_info[id] = info
	

func load_scene(scene: int):
	if not gs.has(scene):
		return -1
	if active:
		return -2
	current_scene = load(gs_ref[scene]).instantiate()
	add_child(current_scene)
	get_scene_information()
	active = true
	debug("Scanner loaded scene " + str(gs.find_key(scene)) + ".", MSG_OK)
	return 0

func debug(msg, type: int):
	var color = ""
	match type:
		0:
			color = "dark_gray"
		1:
			color = "indian_red"
		2:
			color = "light_green"
	print_rich("[color=" + color + "][Simulator][/color] " + str(msg))
