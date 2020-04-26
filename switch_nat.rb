require 'socket'
require 'resolv'

TYPE = ARGV.first.upcase.to_sym
raise 'specify NAT type: a b c d f' unless %i[A B C D F].include?(TYPE)

$from_addr = '0.0.0.0'
$from_port = 0

class Connection
	attr_accessor :listen, :destaddr, :destport, :local_sock, :remote_sock

	def initialize(listen, destaddr, destport)
		@listen = listen
		@destaddr = destaddr
		@destport = destport
		@local_sock = UDPSocket.new
		@local_sock.bind('0.0.0.0', @listen)
	end

	def bind_remote(addition)
		old_port = remote_sock&.local_address&.ip_port || 0
		@remote_sock = UDPSocket.new
		old_port = Random.rand(20000...40000) if old_port == 0

		port = old_port + addition
		begin
			remote_sock.bind('0.0.0.0', port)
		rescue Errno::EADDRINUSE => _
		end

		if port != remote_sock.local_address.ip_port
			puts 'Warning: port bind failed. NAT type result may be changed.'
		end
	end

	def send_local(data)
		local_sock.send(data, 0, $from_addr, $from_port)
	end

	def send_remote(data)
		remote_sock.send(data, 0, destaddr, destport)
	end
end

nncs1 = Connection.new(18825, Resolv.getaddress('nncs1-lp1.n.n.srv.nintendo.net'), 10025)
nncs2 = Connection.new(19925, Resolv.getaddress('nncs2-lp1.n.n.srv.nintendo.net'), 10025)
typea = Connection.new(50920, nncs1.destaddr, 50920)

renew_remote = proc do
	port_difference = Random.rand(1...10)
	nncs1.bind_remote(port_difference)
	typea.remote_sock = nncs1.remote_sock
	if %i[A B].include?(TYPE)
		nncs2.remote_sock = nncs1.remote_sock  # Endpoint-Independent Mapping
	elsif TYPE == :C
		nncs2.bind_remote(port_difference)  # port number difference is same to nncs1, predictable
	else
		nncs2.bind_remote(port_difference + 1)  # port number is unpredictable
	end
end

renew_remote.call

loop do
	con = [nncs1, nncs2, typea]
	sel = IO.select(con.map(&:local_sock) + con.map(&:remote_sock))
	next if sel.nil?
	sel[0].each do |s|
		data, from = s.recvfrom(65536)
		if con.map(&:remote_sock).include?(s)
			ff = con.select { |c| from[3] == c.destaddr && from[1] == c.destport }.first

			# Type A NAT does not filter the packets from new port (50920)
			if TYPE != :F && (ff != typea || TYPE == :A)
				puts "forward from remote #{from[3]}:#{from[1]} to local"
				ff.send_local(data)
			else
				puts "ignore from remote #{from[3]}:#{from[1]}"
			end
		else
			ff = con.select { |c| s == c.local_sock }.first
			if $from_addr != from[3] || $from_port != from[1]
				puts "\n***** new local #{from[3]}:#{from[1]} *****"
				$from_addr = from[3]
				$from_port = from[1]

				renew_remote.call

				# open port 50920 to avoid Port-Dependent Filter
				puts "say hi to #{typea.destaddr}:#{typea.destport}"
				typea.send_remote('Hi')
			end

			ff.send_remote(data)
			puts "forward from local to remote #{ff.destaddr}:#{ff.destport} using port #{ff.remote_sock.local_address.ip_port}"
		end
	end
end
