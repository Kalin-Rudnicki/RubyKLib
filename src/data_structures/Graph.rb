
require_relative '../utils/validation/ArgumentChecking'
require 'set'

module KLib
	
	class Graph
		
		DEFAULT_GRAPH_TYPE = :graph
		DEFAULT_GRAPH_DIRECTED = false
		
		attr_reader :type, :directed, :order, :size
		
		def initialize(type = DEFAULT_GRAPH_TYPE, directed = DEFAULT_GRAPH_DIRECTED, auto_add_default: true)
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
		
		def self.generate(graph_data)
			ArgumentChecking.type_check(graph_data, :graph_data, String)
			begin
				data_line, *lines = graph_data.split("\n")
				raise "Invalid graph format (data line: '$ type directed')" if data_line.nil? || (match = /^[$](?:[ \t]+(?<type>[a-zA-Z_]+))?(?:[ \t]+(?<directed>[a-zA-Z_]+))?[ \t]*$/.match(data_line)).nil?
				graph = Graph.new(match[1].nil? ? DEFAULT_GRAPH_TYPE : match[1].downcase.to_sym, match[2].nil? ? DEFAULT_GRAPH_DIRECTED : Boolean.parse(match[2].downcase))
				
				lines.each_with_index do |line, line_no|
					next if line.strip.length == 0
					raise "Invalid graph format #{line.inspect} (line #{line_no + 2}: from to weight=1)" if (match = /^[ \t]*(?<from>[A-Za-z0-9_]+)[ \t]+(?<to>[A-Za-z0-9_]+)(?:[ \t]+(?<weight>(\d+)))?[ \t]*$/.match(line)).nil?
					if match[3].nil?
						graph.join(match[1], match[2])
					else
						graph.join(match[1], match[2], match[3].to_i)
					end
				end
				
				graph
			rescue => e
				err = RuntimeError.new("Error generating graph: #{e.message}")
				err.set_backtrace(e.backtrace)
				raise err
			end
		end
		
		def self.read(path)
			ArgumentChecking.type_check(path, :path, String)
			ArgumentChecking.path_check(path, :path, :file)
			generate(File.read(path))
		end
		
		def write(path)
			ArgumentChecking.type_check(path, :path, String)
			path_parent = File.expand_path(File.join(path, '..'))
			ArgumentChecking.path_check(path_parent, :path_parent, :dir)
			File.open(path, 'w') { |file| file.write(self.to_s) }
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
		
		def neighbors(v_name, auto_add: @auto_add_default, **hash_args)
			v = self[v_name, auto_add: auto_add]
			v.neighbors(**hash_args)
		end
		
		def vertices
			@vertices.values
		end
		def each_vertex(&block)
			vertices.each(&block)
		end
		
		def edges
			@vertices.values.map { |vertex| vertex.edge_list_1 }.flatten
		end
		def each_edge(&block)
			edges.each(&block)
		end
		
		def to_s
			str = "$ #{@type} #{@directed}"
			each_edge do |edge|
				v1 = edge.v1.name.to_s
				v2 = edge.v2.name.to_s
				raise "Vertex #{v1.to_s} contains un-savable name" unless /^[A-Za-z0-9_]+$/.match?(v1)
				raise "Vertex #{v2.to_s} contains un-savable name" unless /^[A-Za-z0-9_]+$/.match?(v2)
				str << "\n#{v1} #{v2}#{edge.weight == 1 ? "" : " #{edge.weight}"}"
			end
			str
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
			
			def neighbors(weights: false)
				ArgumentChecking.boolean_check(weights, :weights)
				n = Set[]
				if weights
					@edge_list_1.each { |e| n << { vertex: e.v2, weight: e.weight } }
					@edge_list_2.each { |e| n << { vertex: e.v1, weight: e.weight } }
				else
					@edge_list_1.each { |e| n << e.v2 }
					@edge_list_2.each { |e| n << e.v1 }
				end
				n
			end
			
			def adjacent?(vertex)
				ArgumentChecking.type_check(vertex, :vertex, Vertex)
				raise "vertex is not from same graph" unless self.graph == vertex.graph
				@edge_list_1.each { |e| return true if e.v2 == vertex }
				@edge_list_2.each { |e| return true if e.v1 == vertex }
				false
			end
			
			def to_s
				"#<#{self.class}; @name=#{@name.inspect} neighbors=#{neighbors(weights: true).map { |n| n[:vertex] = n[:vertex].name; n[:weight] > 1 ? n : n[:vertex] }.inspect}>"
			end
			
		end
		
		class Edge
			
			attr_reader :graph, :v1, :v2, :weight
			
			def initialize(graph, v1, v2, weight)
				ArgumentChecking.type_check(graph, :graph, Graph)
				raise "can not have loops in non-pseudo-graph" if v1 == v2 && graph.type != :pseudo_graph
				raise "vertices not in same graph as edge" unless graph == v1.graph && graph == v2.graph
				@graph = graph
				@v1 = v1
				@v2 = v2
				self.weight = weight
				nil
			end
			
			def weight= (weight)
				ArgumentChecking.type_check(weight, :weight, Integer)
				raise ArgumentError.new("param 'weight' must be > 0") if weight <= 0
				raise "weight can not be > 1 in a graph. Edge: #{@v1.name.inspect}-#{@v2.name.inspect}" if @graph.type == :graph && weight > 1
				@weight = weight
			end
			
			def to_s
				"#<#{self.class}; @v1=#{@v1.name.inspect} @v2=#{@v2.name.inspect}>"
			end
			
		end
		
	end
	
end
