
require_relative '../../../src/utils/parsing/cli/parse_class'

class Test < KLib::CLI::ParseClass
	
	spec(require_default: true) do |spec|
		spec.int(:a)
	end
	
	def execute
		puts("a: #{@a}")
	end

end

Test.new(%w{--a 4})

class GenGraph < KLib::CLI::ParseClass
	
	spec do |spec|
		spec.integer(:min).required.positive.comment("Minimum graph size")
		spec.integer(:max).required.gt_et(:min).comment("Maximum graph size")
		spec.boolean(:require_connected, negative: :dont).comment("Whether or not to only include connected graphs")
	end
	
	def execute
		puts("min:               #{@min}")
		puts("max:               #{@max}")
		puts("require connected: #{@require_connected}")
		
		nil
	end

end

GenGraph.new(%w{--min 3 --max 5 --dont-require-connected})
