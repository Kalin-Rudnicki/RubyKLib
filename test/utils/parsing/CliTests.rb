
require_relative '../../../src/utils/parsing/cli/parse_class'
require_relative '../../../src/utils/output/Logger'

module Test
	extend KLib::CLI::Parser
	
	spec(require_default: true) do |spec|
		spec.int(:a)
		
		spec.execute do
			show_args
		end
	end
	
end

Test.parse(%w{--a 4})

module GenGraph
	extend KLib::CLI::Parser
	
	spec do |spec|
		spec.integer(:min).required.positive.comment("Minimum graph size")
		spec.integer(:max).required.gt_et(:min).comment("Maximum graph size")
		spec.boolean(:require_connected, negative: :dont).comment("Whether or not to only include connected graphs")
		
		spec.execute do
			show_args
		end
	end

end

GenGraph.parse(%w{--min 3 --max 5 --dont-require-connected})

module Sylce
	extend KLib::CLI::Parser
	
	spec do |spec|
		spec.sub_spec(:gen) do |spec_2|
			spec_2.string(:lexer, short: :l).required.is_file
			spec_2.string(:grammar, short: :g).required.is_file
			spec_2.string(:out, short: :o).required.has_parent_dir
			spec_2.symbol(:log_level, short: :L).default_value(:warning).one_of(KLib::LogLevelManager::DEFAULT_LOG_LEVELS - [])
			
			spec_2.execute do
				show_args
			end
		end
		spec.sub_spec(:parse) do |spec_2|
			spec_2.string(:spec).required.is_file
			spec_2.flag(:show_tokens, default: false, negative: :dont)
			spec_2.flag(:show_tree, default: false, negative: :dont)
			spec_2.string(:token_output).optional.has_parent_dir
			spec_2.string(:tree_output).optional.has_parent_dir
			
			spec_2.sub_spec(:thing, extra_argv: true) do |spec_3|
			end
			
			spec_2.execute do
				show_args
			end
		end
	end
	
end

module Test2
	
	
	
end
