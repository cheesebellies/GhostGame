extends StaticBody3D

@export var item_id: String
@export var display_name: String = "Item"

func get_interact_label() -> String:
	return "Pick up %s [E]" % display_name

func on_interact(player):
	player.pick_up_node(self, display_name)
