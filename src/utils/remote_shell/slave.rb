
require 'socket'
require 'io/console'
require 'digest'

Dir.chdir(File.dirname(__FILE__)) do
	require './codes'
end

module KLib
	
	module RemoteShell
		
		class Master
			
			def initialize(hostname, port)
				@hostname = hostname
				@port = port
			end
			
			def run
				@server = TCPSocket.new(@hostname, @port)
				
				loop do
					code = @server.gets
					if code.nil?
						puts("No more connection with server")
						break
					else
						order = Codes.decode(code.chomp.to_i)
					end
					if order[:mode] == :write
						$stdout.send(order[:message_mode], read_string)
					elsif order[:mode] == :read
						message = read_string
						
						result = nil
						
						if order[:confirm]
							confirm = read_string
							
							loop do
								
								input_1 = get_input(message, order[:message_mode], order[:multi], order[:hidden])
								input_2 = get_input(confirm, order[:message_mode], order[:multi], order[:hidden])
								
								if input_1 == input_2
									result = input_1
									break
								else
									puts("Inputs do not match")
								end
							end
						else
							result = get_input(message, order[:message_mode], order[:multi], order[:hidden])
						end
						
						result = Digest::SHA2.hexdigest(result) if order[:encrypt]
						
						send_string(result)
					else
						raise "What is going on? #{order.inspect}"
					end
				end
				
				@server.close
			end
			
			private
				
				def get_input(message, message_mode, multi, hidden)
					$stdout.send(message_mode, message)
					if multi
						lines = []
						begin
							loop do
								if hidden
									line = $stdin.noecho(&:gets).chomp
									$stdout.puts
									lines << line
								else
									lines << $stdin.gets.chomp
								end
							end
						rescue Interrupt
							lines.join("\n")
						end
					else
						if hidden
							line = $stdin.noecho(&:gets).chomp
							$stdout.puts
							line
						else
							$stdin.gets.chomp
						end
					end
				end
				
				def send_string(string)
					split = string.split("\n")
					@server.puts(split.length.to_s)
					split.each { |s| @server.puts(s) }
					nil
				end
				
				def read_string
					lines = []
					@server.gets.chomp.to_i.times { lines << @server.gets.chomp }
					lines.join("\n")
				end
			
		end
		
	end
	
end
