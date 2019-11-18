
require_relative '../../../src/utils/parsing/cli/parse_class'
require_relative '../../../src/utils/formatting/ColorString'

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
		puts("completed successfully".green)
	rescue SystemExit => e
		puts("[run ##{$run_count}] Caught exit(#{e.status})".red)
	rescue StandardError => e
		puts("[run ##{$run_count}] Caught error: #{e.inspect}".red)
		e.backtrace.reverse.each { |t| puts(t.red) }
	end
	$stdout.flush
	$stderr.flush
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
run(%w{s-a --b=true --b=false})
run(%w{s-a --f=true})
run(%w{s-a --str-1})
