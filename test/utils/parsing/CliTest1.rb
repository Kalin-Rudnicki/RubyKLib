
require_relative '../../../src/utils/parsing/cli/parse_class'

module Ex1
	
	cli_spec do |spec|
		spec.sub_spec(:sub_aaa) do |spec_2|
			spec_2.string(:string_1, aliases: [:alias], short: :s).required
			spec_2.string(:string_2, short: :S).optional
			spec_2.boolean(:bool_1)
			spec_2.flag(:flag_1)
			
			spec_2.execute do
				show_params
			end
		end
		spec.sub_spec(:sub_bbb) do |spec_2|
			spec_2.symbol(:symbol_1, short: :s).required
			spec_2.symbol(:symbol_2, short: :S).optional
			
			spec_2.execute do
				show_params
			end
		end
	end
	
end

$run_count = 0
def run(argv)
	$run_count += 1
	puts
	puts("> run ##{$run_count}")
	begin
		Ex1.parse(argv)
		puts("completed successfully")
	rescue SystemExit => e
		$stderr.puts("[run ##{$run_count}] Caught exit(#{e.status})")
	rescue StandardError => e
		$stderr.puts("[run ##{$run_count}] Caught error: #{e.inspect}")
		e.backtrace.each { |t| $stderr.puts(t) }
	end
end

run(%w{s})
run(['s-a', '--bad key'])
run(%w{s-a --bad--key})
run(%w{s-a --Bad-Key})
run(%w{s-a --Bad-Key})
run(%w{s-a --alias=1})
run(%w{s-a --alias 1})
run(%w{s-a --str=0})
run(%w{s-a --str-1=1 -s=1 --str-2 2 -S 2})
