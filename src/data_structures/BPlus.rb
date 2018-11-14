
module KLib

	class BPlus
	
		def initialize(node_size)
			@node_size = node_size
		end
	
		class Node
			
			def initialize(parent, size)
				@parent = parent
				@top = Array.new(size)
				@bottom = Array.new(size + 1)
			end
			
			class Element
				attr_reader :value
				attr_accessor :count
				def initialize(value)
					@value = value
					@count = 1
				end
			end
			
		end
		
		class TreeNode
			
			def set(key, value)
			
			end
			
			def remove(key)
			
			end
			
			def key?(key)
			
			end
			
			def count(key)
			
			end
			
		end
		
	end
	
end
