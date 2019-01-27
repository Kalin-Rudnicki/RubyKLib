
Dir.chdir(File.dirname(__FILE__)) do
	require './../../../src/utils/remote_shell/slave'
end

KLib::RemoteShell::Master.new('localhost', 2000).run
