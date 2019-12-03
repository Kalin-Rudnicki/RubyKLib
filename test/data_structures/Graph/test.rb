
require_relative '../../../src/data_structures/Graph'

Dir.chdir(File.dirname(__FILE__)) do
	graph = KLib::Graph.read('test.graph')
	puts(graph)
	graph.write('test_ok.graph/ok')
end
