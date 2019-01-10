
Dir.chdir(File.dirname(__FILE__)) do
	require './../version_compat/BasicObject'
end

module KLib

	class DoConfig < BasicObject
	
	
	
	end

end

KLib::DoConfig.__send__(:define_method, :test_1) {}
KLib::DoConfig.__send__(:define_singleton_method, :test_2) {}

KLib::DoConfig.new.test_1
KLib::DoConfig.test_2