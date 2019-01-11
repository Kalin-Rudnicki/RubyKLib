
Dir.chdir(File.dirname(__FILE__)) do
	require './../utils/validation/ArgumentChecking'
	require 'set'
end

module KLib

	class TopologicalSort
	
		def initialize
			@elements = {}
		end
		
		def self.sort(hash)
			sorter = TopologicalSort.new
			sorter[hash]
			sorter.sort
		end
		
		def []= (k, v)
			ArgumentChecking.type_check(k, 'k', Symbol)
			ArgumentChecking.type_check_each(v, 'v', Symbol)
			@elements[k] ||= []
			@elements[k] |= v
			nil
		end
		
		def [] (h)
			ArgumentChecking.type_check(h, 'h', Hash)
			h.each_pair { |k, v| self[k]= v }
		end
		
		def sort
			all = (@elements.keys + @elements.values.flatten).uniq
			needed = all.map { |key| [key, @elements.key?(key) ? Set.new(@elements[key]) : Set.new] }.to_h
			options = Set.new(all)
			used = Set.new
			
			order = []
			
			loop do
				found = Set.new
				
				options.each { |opt| found << opt if (needed[opt] - used).empty? }
				break unless found.any?
				found.each { |f| order << f }
				options -= found
				used += found
			end
			
			raise CircularReferenceError.new(options.to_a) if options.any?
			
			order
		end
		
		class CircularReferenceError < RuntimeError
			attr_reader :problems
			def initialize(problems)
				@problems = problems
				super("Error sorting: #{problems.inspect}")
			end
		end
	
	end

end
