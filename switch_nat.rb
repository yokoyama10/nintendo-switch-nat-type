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
	nncs1.remote_sock = UDPSocket.new
	typea.remote_sock = nncs1.remote_sock
	nncs2.remote_sock =
		if %i[A B].include?(TYPE)
			nncs1.remote_sock
		else
			UDPSocket.new
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

				renew_remote.call unless TYPE == :C

				# to open port
				puts "say hi to #{typea.destaddr}:#{typea.destport}"
				typea.send_remote('Hi')
			end

			ff.send_remote(data)
			puts "forward from local to remote #{ff.destaddr}:#{ff.destport} using port #{ff.remote_sock.local_address.ip_port}"
		end
	end
end
