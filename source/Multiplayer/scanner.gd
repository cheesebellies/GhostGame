extends Node

var scan_port: int
var chosen_port: int
var players: int
var max_players: int
var description: String
var peer: PacketPeerUDP

signal servers(info)

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

func close():
	peer.close()

func start_broadcast(chosen_port: int, bind_port: int, broadcast_port: int, broadcast_interval: float):
	$Broadcast.wait_time = broadcast_interval
	self.scan_port = broadcast_port
	self.chosen_port = chosen_port
	peer = PacketPeerUDP.new()
	peer.set_broadcast_enabled(true)
	peer.set_dest_address('255.255.255.255', self.scan_port)
	peer.bind(bind_port)
	_broadcast()
	$Broadcast.start()
	return 0

func _scan() -> void:
	var pcount = peer.get_available_packet_count()
	if pcount > 0:
		var fs = []
		for i in range(pcount):
			var packet = peer.get_packet()
			var fip = peer.get_packet_ip()
			var fport = packet.decode_u32(0)
			var fplayers = packet.decode_u32(4)
			var fmax = packet.decode_u32(8)
			var fdesc = packet.slice(12).get_string_from_ascii()
			if fip != "":
				fs.append([fip,fport,fdesc,fplayers,fmax])
		servers.emit(fs)


func _broadcast() -> void:
	var status = PackedByteArray()
	status.resize(12)
	status.encode_u32(0, chosen_port)
	status.encode_u32(4, players)
	status.encode_u32(8, max_players)
	status += description.to_ascii_buffer()
	peer.put_packet(status)
