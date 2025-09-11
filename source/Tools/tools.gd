extends Node

func wait(milliseconds: int):
	await get_tree().create_timer(float(milliseconds)/1000).timeout
	return 0

func scan_for_port(min, max):
	for port in range(min,max+1):
		var peer = PacketPeerUDP.new()
		var res = peer.bind(port)
		if res == OK:
			peer.close()
			return port
		else:
			peer.close()
	return -1

func get_local_ip():
	var candidates = IP.get_local_addresses()
	var to_check = []
	
	for candidate in candidates:
		if (not String(candidate).begins_with("127")) and (not String(candidate).begins_with("fe80")) and (not String(candidate).begins_with("0")) and (not String(candidate).begins_with("169")) and (not String(candidate).contains(":")):
			to_check.append(candidate)
	
	var srt = func s(a,b):
		var o = [a,b]
		var o2 = []
		for i in o:
			var sc = 0
			var j = String(i)
			if j.begins_with("192"):
				pass
			elif j.begins_with("172"):
				sc = 1
			elif j.begins_with("10"):
				sc = 2
			else:
				sc = 3
			o2.append(sc)
		if o2[0] < o2[1]:
			return true
		return false
	to_check.sort_custom(srt)
	return to_check
