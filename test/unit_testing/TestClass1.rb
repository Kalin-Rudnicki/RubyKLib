
Dir.chdir(File.dirname(__FILE__)) do
	require './../../src/unit_testing/TestClass'
end

class TestClass1 < KLib::UnitTest::TestClass

	@__method_manager = MethodManager.new.set do |methods|
		methods.test_length
	end
	
	def initialize(str, length)
		@str = str
		@length = length
	end
	
	def test_length
		if assert_equal(@str.length, @length)
			puts("Success!")
		else
			$stderr.puts("Failure")
		end
	end
	
	def length_less_or_equal
	
	end

end

module Tmp
	
	class TestClass2 < KLib::UnitTest::TestClass
	
	end
	
end

TestClass1.new("Kalin", 5).disable(:length_less_or_equal)
TestClass1.new("Janine", 5)
