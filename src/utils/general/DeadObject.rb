
require_relative '../version_compat/BasicObject'

module KLib
	
	class DeadObject < BasicObject
		
		def indent(*args, &block)
			block.()
			nil
		end
		
		def method_missing(sym, *args, **hash_args, &block)
			self
		end
		
	end
	
end
