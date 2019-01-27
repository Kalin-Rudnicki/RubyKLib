
Dir.chdir(File.dirname(__FILE__)) do
	require './../../../src/utils/remote_shell/master'
end

server = KLib::RemoteShell::Server.new('localhost', 2000)
server.run do |slave|

end
