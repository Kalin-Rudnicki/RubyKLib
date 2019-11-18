
Dir.chdir(File.dirname(__FILE__)) do
	require './../../src/utils/validation/ArgumentChecking'
	require './../../src/unit_testing/TestClass'
end

class ArgumentCheckingTest < KLib::UnitTest::TestClass
	
	def initialize(object)
		@object = object
	end
	
	def test_type(should_pass, *types)
		assert_raised(KLib::ArgumentChecking::InvalidValidationError) { KLib::ArgumentChecking.type_check(@object, '@object') }
		if should_pass
			assert_not_raised(KLib::ArgumentChecking::ArgumentCheckError) { KLib::ArgumentChecking.type_check(@object, '@object', *types) }
			assert_true(KLib::ArgumentChecking.type_check(@object, '@object', *types))
			assert_true(KLib::ArgumentChecking.type_check(@object, '@object', *types) {})
		else
			assert_raised(KLib::ArgumentChecking::InvalidValidationError) { KLib::ArgumentChecking.type_check(@object, '@object', *types) { :fail } }
			assert_raised(KLib::ArgumentChecking::ArgumentCheckError) { KLib::ArgumentChecking.type_check(@object, '@object', *types) { "fail" } }
			assert_raised(KLib::ArgumentChecking::ArgumentCheckError) { KLib::ArgumentChecking.type_check(@object, '@object', *types) }
			assert_false(KLib::ArgumentChecking.type_check(@object, '@object', *types) {})
		end
	end
	
	def test_type_each(should_pass, *types)
	
	end
	
	def test_enum(should_pass, *enums)
	
	end
	
	def test_enum_each(should_pass, *enums)
	
	end
	
end

ArgumentCheckingTest.new("Kalin").set do |methods|
	methods.test_type(true, String)
end

ArgumentCheckingTest.new("Kalin").set do |methods|
	methods.test_type(false, Integer)
end

ArgumentCheckingTest.new("Kalin").set do |methods|
	methods.test_type(true, Integer, String)
end
