
Dir.chdir(File.dirname(__FILE__)) do
	require './src/utils/project_management/LibRequire'
end

k_lib_src_root = File.join(File.dirname(__FILE__ ), 'src').gsub(/[\/\\]/, '/')
KLib::LibRequire::PATH << k_lib_src_root unless KLib::LibRequire::PATH.include?(k_lib_src_root)

KLibRequired = File.dirname(__FILE__ ).gsub(/[\/\\]/, '/')

unless defined?(KLibRequired)
	if ENV.key?('KLibRoot')
		main_load = File.join(ENV['KLibRoot'], 'k_lib.rb').gsub(/[\/\\]/, '/')
		begin
			require main_load
		rescue LoadError
			$stderr.puts("Failed to load 'KLibRoot' ('#{main_load}')")
		end
	else
		$stderr.puts("'KLibRoot' Environment Variable is not defined.")
	end
	unless defined?(KLibRequired)
		$stderr.puts("KLib has not been loaded.")
		exit(-1)
	end
end
