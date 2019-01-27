
Dir.chdir(File.dirname(__FILE__)) do
	require './../../../src/utils/remote_shell/master'
end


class Message
	
	attr_reader :time, :message, :to, :from
	
	def initialize(from, to, message)
		@time = Time.now
		@from = from
		@to = to
		@message = message
		
		@seen = false
	end
	
	def saw
		@seen = true
	end
	
	def seen?
		@seen
	end

end

class User
	
	attr_reader :username, :received_messages, :sent_messages, :password
	
	def initialize(username, password)
		@username = username
		@password = password
		
		@sent_messages = []
		@received_messages = []
	end
	
end

users = {}

server = KLib::RemoteShell::Server.new('localhost', 2000)
server.run do |slave|
	user = nil
	
	loop do
		if user.nil?
			slave.write("\noptions: #{%w{login create exit}.map { |s| "[#{s}]" }.join(' ')}")
		else
			slave.write("\noptions: #{%w{info send read read:unread read:sent logout exit}.map { |s| "[#{s}]" }.join(' ')}")
		end
		
		action = slave.read(:message => "> ")
		puts("Connection ##{slave.session_id} action: #{action.inspect}")
		if action == 'exit'
			puts("Connection ##{slave.session_id} wishes to exit")
			slave.write("Exiting...")
			break
		else
			if user.nil?
				case action
					when 'create'
						slave.write("=== Create User ===")
						username = slave.read(:message => 'username: ')
						
						if users.key?(username)
							slave.write("User already exists with username: #{username.inspect}")
						else
							password = slave.read_secret(:message => 'password: ', :confirm => 'confirm:  ')
							users[username] = User.new(username, password)
							slave.write("Successfully created user #{username.inspect}")
						end
					when 'login'
						slave.write("=== Login ===")
						username = slave.read(:message => 'username: ')
						password = slave.read_secret(:message => 'password: ')
						
						if users.key?(username)
							tmp_user = users[username]
							if tmp_user.password == password
								user = tmp_user
								slave.write("Successfully logged in!")
							else
								slave.write("Incorrect password for #{username.inspect}")
							end
						else
							slave.write("No such user #{username.inspect}")
						end
					else
						puts("Unknown command from Connection ##{slave.session_id}, #{action.inspect}")
						slave.write("Invalid command: #{action.inspect}")
				end
			else
				case action
					when 'info'
						slave.write("Username: #{user.username.inspect}")
						slave.write("Sent: #{user.sent_messages.length}")
						slave.write("Unread: #{user.received_messages.select { |m| !m.seen? }.length}")
						slave.write("Read: #{user.received_messages.select { |m| m.seen? }.length}")
					when 'send'
						slave.write("=== Compose ===")
						send_to = slave.read(:message => "recipient: ")
						if users.key?(send_to)
							message = slave.read(:message => "message:", :message_mode => :puts, :multi => true)
							msg = Message.new(user, users[send_to], message)
							
							msg.from.sent_messages << msg
							msg.to.received_messages << msg
							slave.write("Sent!")
						else
							slave.write("No such user: #{send_to.inspect}")
						end
					when 'read'
						user.received_messages.each do |msg|
							msg.saw
							slave.write("From: #{msg.from.username}")
							slave.write("To:   #{msg.to.username}")
							slave.write("Time: #{msg.time.inspect}")
							slave.write("Message:\n#{msg.message}")
							slave.write("")
						end
					when 'read:unread'
						user.received_messages.select { |msg| !msg.seen? }.each do |msg|
							msg.saw
							slave.write("From: #{msg.from.username}")
							slave.write("To:   #{msg.to.username}")
							slave.write("Time: #{msg.time.inspect}")
							slave.write("Message:\n#{msg.message}")
							slave.write("")
						end
					when 'read:sent'
						user.sent_messages.each do |msg|
							slave.write("From: #{msg.from.username}")
							slave.write("To:   #{msg.to.username}")
							slave.write("Time: #{msg.time.inspect}")
							slave.write("Message:\n#{msg.message}")
							slave.write("")
						end
					when 'logout'
						user = nil
						slave.write("You have successfully logged out")
					else
						puts("Unknown command from Connection ##{slave.session_id}, #{action.inspect}")
						slave.write("Invalid command: #{action.inspect}")
				end
			end
		end
	end
end
