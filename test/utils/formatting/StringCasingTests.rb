
Dir.chdir(File.dirname(__FILE__)) do
	require './../../../src/utils/formatting/StringCasing'
end

if File.expand_path(__FILE__ ) == File.expand_path($0)

	def test(str)
		puts("< testing > str: #{str}")
		puts("str.snake:       #{str.to_snake}")
		puts("str.snake.snake: #{str.to_snake.to_snake}")
		puts("str.camel.snake: #{str.to_camel.to_snake}")
		puts("str.camel:       #{str.to_camel}")
		puts("str.snake.camel: #{str.to_snake.to_camel}")
		puts("str.camel.camel: #{str.to_camel.to_camel}")
		puts
	end
	
	test('hello')
	test('ok_then')
	test('who_are_you_bro')
	test('whyTho')
	test('mix_itUp')

end
