
require 'set'

module KLib

	class UnionTree
	
		def initialize
			@elements = {}
		end
		
		def join(element_1, element_2)
			@elements[element_1] = Element.new(element_1) unless @elements.key?(element_1)
			@elements[element_2] = Element.new(element_2) unless @elements.key?(element_2)
			
			element_1 = @elements[element_1]
			element_2 = @elements[element_2]
			
			element_1.direct << element_2.element
			element_2.direct << element_1.element
			
			root_1 = element_1.node.root
			root_2 = element_2.node.root
			return nil if root_1 == root_2
			
			node = Node.merge(root_1, root_2)
			node.compress
			
			nil
		end
		
		def adjacent(element)
			return nil unless @elements.key?(element)
			@elements[element].direct
		end
		
		def networked(element)
			return nil unless @elements.key?(element)
			@elements[element].node.root.elements
		end
		
		def adjacent?(element_1, element_2)
			@elements[element_1].direct.include?(element_2)
		end
		
		def networked?(element_1, element_2)
			return nil unless @elements.key?(element_1) && @elements.key?(element_2)
			@elements[element_1].node.root == @elements[element_2].node.root
		end
		
		class Node
		
			attr_reader :elements, :children
			attr_accessor :parent
			
			def initialize(elements, children)
				@elements = elements
				@parent = nil
				@children = children
			end
			
			def self.merge(node_1, node_2)
				node = Node.new(node_1.elements | node_2.elements, Set[node_1, node_2])
				node_1.parent = node
				node_2.parent = node
				node
			end
			
			def root
				node = self
				node = node.parent until node.parent.nil?
				node
			end
			
			def compress(set = Set[], to = self)
				if @children.nil?
					set << self
					@parent = to
				else
					@children.each do |child|
						child.compress(set, to)
					end
				end
				@children = set if to == self
			end
		
		end
		
		class Element
			
			attr_reader :element, :direct, :node
			
			def initialize(element)
				@element = element
				@direct = Set[]
				@node = Node.new(Set[element], nil)
			end
			
		end
		
	end

end


