
require_relative '../../src/utils/validation/ArgumentChecking'
require 'set'

module KLib
	
	class Graph
		
		attr_reader :type, :directed, :order, :size
		
		def initialize(type = :graph, directed = false, auto_add_default: true)
			ArgumentChecking.enum_check(type, :type, :graph, :multi_graph, :pseudo_graph)
			ArgumentChecking.boolean_check(directed, :directed)
			ArgumentChecking.boolean_check(auto_add_default, :auto_add_default)
			@type = type
			@directed = directed
			@vertices = {}
			@auto_add_default = auto_add_default
			@order = 0
			@size = 0
			nil
		end
		
		def [] (name, auto_add: @auto_add_default)
			if name.is_a?(Vertex) && name.graph == self
				name
			else
				if @vertices.key?(name)
					@vertices[name]
				else
					if auto_add
						@order += 1
						@vertices[name] = Vertex.new(self, name)
					else
						raise "No vertex by name: #{name.inspect}"
					end
				end
			end
		end
		
		def join(v1_name, v2_name, weight = 1, auto_add: @auto_add_default)
			v1 = self[v1_name, auto_add: auto_add]
			v2 = self[v2_name, auto_add: auto_add]
			v1.edge_list_1.each do |e|
				if e.v2 == v2
					e.weight += weight
					return
				end
			end
			unless @directed
				v2.edge_list_2.each do |e|
					if e.v1 == v2
						e.weight += weight
						return
					end
				end
			end
			edge = Edge.new(self, v1, v2, weight)
			@size += 1
			v1.edge_list_1 << edge
			v2.edge_list_2 << edge unless @directed || v1 == v2
			nil
		end
		
		def adjacent?(v1_name, v2_name, auto_add: @auto_add_default)
			v1 = self[v1_name, auto_add: auto_add]
			v2 = self[v2_name, auto_add: auto_add]
			v1.adjacent?(v2)
		end
		
		def neighbors(v_name, auto_add: @auto_add_default)
			v = self[v_name, auto_add: auto_add]
			v.neighbors
		end
		
		class Vertex
			
			attr_reader :name, :graph, :edge_list_1, :edge_list_2
			
			def initialize(graph, name)
				ArgumentChecking.type_check(graph, :graph, Graph)
				@graph = graph
				@name = name
				@edge_list_1 = []
				@edge_list_2 = []
				nil
			end
			
			def neighbors
				n = Set[]
				@edge_list_1.each { |e| n << e.v2 }
				@edge_list_2.each { |e| n << e.v1 }
				n
			end
			
			def adjacent?(vertex)
				ArgumentChecking.type_check(vertex, :vertex, Vertex)
				raise "vertex is not from same graph" unless self.graph == vertex.graph
				@edge_list_1.each { |e| return true if e.v2 == vertex }
				@edge_list_2.each { |e| return true if e.v1 == vertex }
				false
			end
			
		end
		
		class Edge
			
			attr_reader :graph, :v1, :v2, :weight
			
			def initialize(graph, v1, v2, weight)
				ArgumentChecking.type_check(graph, :graph, Graph)
				raise "can not have loops in non-pseudo-graph" if v1 == v2 && graph.type != :pseudo_graph
				raise "vertices not in same graph as edge" unless graph == v1.graph && graph == v2.graph
				@graph == graph
				@v1 = v1
				@v2 = v2
				self.weight = weight
				nil
			end
			
			def weight= (weight)
				ArgumentChecking.type_check(weight, :weight, Integer)
				raise ArgumentError.new("param 'weight' must be > 0") if weight <= 0
				raise "weight can not be > 0 in a graph" if @graph.type == :graph
				@weight = weight
			end
			
		end
		
	end
	
end
