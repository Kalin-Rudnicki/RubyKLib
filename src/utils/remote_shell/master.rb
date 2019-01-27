
require 'socket'
Dir.chdir(File.dirname(__FILE__)) do
	require './codes'
	require './../validation/ArgumentChecking'
	require './../validation/HashNormalizer'
end

module KLib
	
	module RemoteShell
		
		class Slave
			
			attr_reader :session_id
			
			def initialize(client, session_id)
				@client = client
				@session_id = session_id
			end
			
			def notify
				write(7.chr, :print)
			end
			
			def write(message, mode = :puts)
				ArgumentChecking.type_check(message, 'message', String)
				ArgumentChecking.enum_check(mode, 'mode', :print, :puts)
				@client.puts(Codes.encode(Codes::WRITE, mode == :print ? Codes::PRINT : Codes::PUTS).to_s)
				send_string(message)
			end
			
			def read(hash_args = {})
				hash_args = HashNormalizer.normalize(hash_args) do |norm|
					norm.message.required.type_check(String)
					norm.message_mode.default_value(:print).enum_check(:print, :puts)
					norm.multiline(:multi).default_value(false).boolean_check
					norm.confirm.default_value(nil).type_check(NilClass, TrueClass, String)
					norm.encrypt.default_value(false).boolean_check
					norm.hidden.default_value(false).boolean_check
				end
				@client.puts(Codes.encode(
					Codes::READ,
					hash_args[:message_mode] == :print ?  Codes::PRINT :   Codes::PUTS,
					hash_args[:multiline] ?               Codes::MULTI :   Codes::SINGLE,
					hash_args[:confirm] ?                 Codes::CONFIRM : Codes::NO_CONFIRM,
					hash_args[:hidden] ?                  Codes::HIDDEN  : Codes::NON_HIDDEN,
					hash_args[:encrypt] ?                 Codes::ENCRYPT : Codes::NO_ENCRYPT
				).to_s)
				send_string(hash_args[:message])
				send_string(hash_args[:confirm].is_a?(String) ? hash_args[:confirm] : hash_args[:message]) if hash_args[:confirm]
				read_string
			end
			
			def read_secret(hash_args = {})
				hash_args = HashNormalizer.normalize(hash_args) do |norm|
					norm.message
					norm.message_mode
					norm.multiline(:multi)
					norm.confirm
					norm.encrypt.default_value(true)
					norm.hidden.default_value(true)
				end
				read(hash_args)
			end
			
			private
			
				def send_string(string)
					split = string.split("\n")
					@client.puts(split.length.to_s)
					split.each { |s| @client.puts(s) }
					nil
				end
			
				def read_string
					lines = []
					@client.gets.chomp.to_i.times { lines << @client.gets.chomp }
					lines
				end
		
		end
		
		class Server
			
			def initialize(hostname, port)
				@hostname = hostname
				@port = port
			end
			
			def run(&block)
				raise "You must supply 'run' with a block" unless block_given?
				
				puts("Starting server on '#{@hostname}:#{@port}'")
				server = TCPServer.new(@hostname, @port)
				puts("Success!")
				puts
				
				counter = 0
				mutex = Mutex.new
				begin
					loop do
						Thread.new(server.accept) do |client|
							session_id = nil
							mutex.synchronize do
								counter += 1
								session_id = counter
							end
							
							begin
								puts("Starting Connection ##{session_id}")
								block.call(Slave.new(client, session_id))
							rescue Interrupt => e
								client.close
								raise e
							rescue Errno::EPIPE
								puts("Lost connection to client")
							rescue => e
								puts("Error with Connection ##{session_id}. #{e.class} => #{e.message}")
							else
								client.close
							end
							puts("Connection ##{session_id} has been terminated")
						end
					end
				rescue Interrupt
					puts("Request received to stop server...")
				rescue => e
					puts("[UNCAUGHT ERROR]")
					puts("#{e.class} => #{e.message}")
				end
				server.close
				puts("Server closed")
				
				nil
			end
		
		end
	
	end
	
end
