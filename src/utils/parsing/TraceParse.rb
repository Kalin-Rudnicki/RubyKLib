
Dir.chdir(File.dirname(__FILE__)) do
	require './../validation/ArgumentChecking'
end

module KLib
	
	class Trace
		
		attr_reader :line_num, :method, :file
		
		def initialize(str)
			split = str.split(':in ')
			last_colon  = split[0].rindex(':')
			
			@file = split[0][0..(last_colon - 1)]
			@line_num = split[0][(last_colon + 1)..-1]
			@method = split.length > 1 ? split[1][1..-2] : '<main>'
		end
		
		def to_s
			"#{@file}:#{@line_num}"
		end
		
		def inspect
			"Trace { method: [#{@method}], line_num: [#{@line_num}], file: [#{@file}] }"
		end
		
		def self.call_trace
			caller[1..-1].map { |c| Trace.new(c) }
		end
		
	end

end