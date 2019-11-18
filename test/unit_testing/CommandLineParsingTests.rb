
Dir.chdir(File.dirname(__FILE__)) do
	require './../../src/utils/parsing/CommandLineParsing'
	require './../../src/unit_testing/TestClass'
end

class CommandLineParsingTests < KLib::UnitTest::TestClass
	
	def initialize(str)
		@str = str
	end
	
	def test_split(expected)
		split = KLib::CommandLineParsing.split(@str)
		puts("split (#{split.length}):")
		split.each_with_index { |e, i| puts("[#{i}]: #{e.inspect}") }
		assert_equal(expected, split)
	end
	
	def test_parse_arg(expected)
		assert_equal(expected, KLib::CommandLineParsing.parse_arg(@str))
	end
	
	def test_parse_hash_arg(expected)
		assert_equal(expected, KLib::CommandLineParsing.parse_hash_arg(@str))
	end
	
end

CommandLineParsingTests.new('a b c d').set do |methods|
	methods.test_split(%w{a b c d})
end

CommandLineParsingTests.new('a   b   c   d').set do |methods|
	methods.test_split(%w{a b c d})
end

CommandLineParsingTests.new('  a   b   c   d   ').set do |methods|
	methods.test_split(%w{a b c d})
end

CommandLineParsingTests.new("a \t b\tc\t \td").set do |methods|
	methods.test_split(%w{a b c d})
end

CommandLineParsingTests.new('"a b" c d').set do |methods|
	methods.test_split(['a b', 'c', 'd'])
end

CommandLineParsingTests.new('"a   b"   c d').set do |methods|
	methods.test_split(['a   b', 'c', 'd'])
end

CommandLineParsingTests.new('"a   b"   "c  d"  ').set do |methods|
	methods.test_split(['a   b', 'c  d'])
end

CommandLineParsingTests.new('a"b c"d').set do |methods|
	methods.test_split(['a', 'b c', 'd'])
end

CommandLineParsingTests.new('a {b => c} d').set do |methods|
	methods.test_split(['a', '{b => c}', 'd'])
end

CommandLineParsingTests.new('a "{b => c}" d').set do |methods|
	methods.test_split(['a', '{b=>c}', 'd'])
end
