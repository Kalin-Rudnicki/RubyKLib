
require_relative '../../../src/utils/formatting/CaseConversion'

if File.expand_path(__FILE__ ) == File.expand_path($0)

	def test(str)
		errors = 0
		puts("< testing > str: #{str}")
		snakes = [str.to_snake, str.to_snake.to_snake, str.to_camel.to_snake]
		camels = [str.to_camel, str.to_snake.to_camel, str.to_camel.to_camel]
		if snakes.uniq.length > 1
			puts("\e[31m=====| Mismatched snake-case |=====\e[0m")
			errors += 1
		end
		puts("str.snake:       #{snakes[0]}")
		puts("str.snake.snake: #{snakes[1]}")
		puts("str.camel.snake: #{snakes[2]}")
		if camels.uniq.length > 1
			puts("\e[31m=====| Mismatched camel-case |=====\e[0m")
			errors += 1
		end
		puts("str.camel:       #{camels[0]}")
		puts("str.snake.camel: #{camels[1]}")
		puts("str.camel.camel: #{camels[2]}")
		puts
		errors
	end
	
	def run_tests(*strs)
		strs = strs.flatten
		err_count = strs.sum { |str| test(str) }
		puts("\e[31mFound #{err_count} errors in #{strs.length} tests\e[0m") if err_count > 0
	end
	
	run_tests(
		'hello',
		'ok_then',
		'who_are_you_bro',
		'whyTho',
		'mix_itUp',
		'hi_1_ok',
		'MyClass2',
		'MyClass23',
		'MyClass23Yep',
		'AClass4UTho',
		'OKThen' # TODO : What to do about this?
	)
	
end
