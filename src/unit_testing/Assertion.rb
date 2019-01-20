
Dir.chdir(File.dirname(__FILE__)) do
	require './../utils/validation/ArgumentChecking'
end

module KLib
	
	module UnitTest
		
		module Assertions
			
			class Assertion
				
				attr_reader :type, :passed, :message, :error
				
				def initialize(type, passed, message, error)
					ArgumentChecking.enum_check(type, 'type', :equal, :not_equal, :raised, :not_raised)
					ArgumentChecking.boolean_check(passed, 'passed')
					ArgumentChecking.type_check(message, 'message', NilClass, String)
					ArgumentChecking.type_check(error, 'error', NilClass, Exception)
					@type = type
					@passed = passed
					@message = message
					@error = error
				end
			
			end
			
			class EqualAssertion < Assertion
				
				attr_reader :actual, :expected
				
				def initialize(passed, message, expected, actual, error)
					super(:equal, passed, message, error)
					@expected = expected
					@actual = actual
				end
			
			end
			
			class NotEqualAssertion < Assertion
				
				attr_reader :actual, :expected
				
				def initialize(passed, message, expected, actual, error)
					super(:not_equal, passed, message, error)
					@expected = expected
					@actual = actual
				end
			
			end
			
			class RaisedAssertion < Assertion
				
				attr_reader :exception
				
				def initialize(passed, message, exception, error)
					super(:raised, passed, message, error)
					@exception = exception
				end
			
			end
			
			class NotRaisedAssertion < Assertion
				
				attr_reader :exception
				
				def initialize(passed, message, exception, error)
					super(:raised, passed, message, error)
					@exception = exception
				end
			
			end
			
		end
		
	end
	
end
