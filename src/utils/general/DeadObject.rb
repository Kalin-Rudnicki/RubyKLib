
Dir.chdir(File.dirname(__FILE__)) do
	require './../version_compat/BasicObject'
end

module KLib
	
	class DeadObject < BasicObject
		
		def method_missing(sym, *args)
			self
		end
		
	end
	
end
