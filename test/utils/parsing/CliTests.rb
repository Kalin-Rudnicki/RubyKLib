
require_relative '../../../src/utils/parsing/cli/parse_class'

class Test < CmdArgParse::ParseClass
	
	spec(require_default: true) do |spec|
		spec.int(:a)
	end

end

class GenGraph < Evade::ParseClass
	
	spec do |spec|
		spec.integer(:min).required.positive.comment("Minimum graph size")
		spec.integer(:max).required.ge_t(:min).comment("Maximum graph size")
		spec.boolean(:require_connected).yes_no(:_dont).comment("Whether or not to only include connected graphs")
	end
	
	def execute
		puts("min:               #{@min}")
		puts("max:               #{@max}")
		puts("require connected: #{@require_connected}")
		
		nil
	end

end
