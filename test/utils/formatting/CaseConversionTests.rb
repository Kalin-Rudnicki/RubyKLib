
Dir.chdir(File.dirname(__FILE__)) do
	require './../../../src/utils/formatting/CaseConversion'
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
	
	test('hi_1_ok')
	
	def casing_test(string)
		puts("testing string: '#{string}'")
		[true, false].each do |nums|
			puts("\t(:snake, #{nums}) => #{StringCasing.matches?(string, :snake, :nums => nums, :behavior => :boolean)}")
			[:either, :upcase, :downcase].each { |start| puts("\t(:camel, #{nums}, #{start}) => #{StringCasing.matches?(string, :camel, :nums => nums, :camel_start => start, :behavior => :boolean)}") }
		end
		puts
	end
	
	[
		'testing',
		'ok_then',
		'no way',
		'Sure',
		'test_1_2',
		'1_test',
		'ok5Now',
		'IfYa7SaySo'
	].each { |str| casing_test(str) }
	
end
