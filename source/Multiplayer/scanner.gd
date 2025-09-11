extends Node

var scan_port: int
var chosen_port: int
var peer: PacketPeerUDP

signal servers(servers: Array)

func start_scan(scan_port: int, scan_interval: float):
	$Scan.wait_time = scan_interval
	self.scan_port = scan_port
	peer = PacketPeerUDP.new()
	var err = peer.bind(self.scan_port)
	if err != 0:
		return err
	_scan()
	$Scan.start()
	return 0

func stop_scan():
	$Scan.stop()

func start_broadcast(chosen_port: int, broadcast_port: int, broadcast_interval: float):
	$Broadcast.wait_time = broadcast_interval
	self.scan_port = broadcast_port
	self.chosen_port = chosen_port
	peer = PacketPeerUDP.new()
	peer.set_broadcast_enabled(true)
	peer.set_dest_address('255.255.255.255', self.scan_port)
	#var err = peer.bind(self.chosen_port)
	#if err != 0:
		#return err
	_broadcast()
	$Broadcast.start()
	return 0

func _scan() -> void:
	var pcount = peer.get_available_packet_count()
	if pcount > 0:
		var found_servers = []
		for i in range(pcount):
			var packet = peer.get_packet()
			var ip = peer.get_packet_ip()
			var port = packet.decode_u32(0)
			if ip != "":
				found_servers.append([ip,port])
		servers.emit(found_servers)


func _broadcast() -> void:
	var status = PackedByteArray()
	status.resize(4)
	status.encode_u32(0, chosen_port)
	peer.put_packet(status)
