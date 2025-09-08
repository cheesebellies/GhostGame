extends RigidBody3D
@export var display_name: String = "Object"

func get_interact_label() -> String:
	return "Grab %s [LMB]" % display_name
