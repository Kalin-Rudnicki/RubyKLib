
Dir.chdir(File.dirname(__FILE__)) do
	require './../../../src/data_structures/UnionTree'
end

class TestClass
	
	def initialize
		@union_tree = KLib::UnionTree.new
	end
	
	def exec(line)
		split = line.split(' ')
		case
			when split.length == 1
				if split[0] == '___'
					@union_tree.instance_variable_get(:@elements).keys.sort.each do |e|
						puts("< #{e} >")
						puts("\t[Adjacent]  => #{@union_tree.adjacent(e).inspect}")
						puts("\t[Networked] => #{@union_tree.networked(e).inspect}")
					end
				else
					puts("[Adjacent]  => #{@union_tree.adjacent(split[0]).inspect}")
					puts("[Networked] => #{@union_tree.networked(split[0]).inspect}")
				end
			when split.length == 3 && split[1] == '|'
				puts(@union_tree.networked?(split[0], split[2]).inspect)
			when split.length == 3 && split[1] == '&'
				puts(@union_tree.adjacent?(split[0], split[2]).inspect)
			when split.length == 3 && split[1] == '+'
				@union_tree.join(split[0], split[2])
			when split.length == 2 && split[0] == 'Load:'
				unless File.exist?(split[1]) && File.file?(split[1])
					puts("Whatchu doing bro?")
					return
				end
				file = File.new(split[1])
				loop do
					
					line = file.gets
					break if line.nil?
					line.chomp!
					
					if line.to_s.start_with?('Load: ')
						puts("No loading from other files silly...")
						next
					end
					
					exec(line)
					
				end
			else
				puts("Invalid Option...")
		end
	end
	
end

test_class = TestClass.new

loop do
	
	print('> ')
	line = gets
	break if line.nil?
	line.chomp!
	break if line.length < 1
	
	test_class.exec(line)
	
end
