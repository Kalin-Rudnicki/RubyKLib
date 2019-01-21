
Dir.chdir(File.dirname(__FILE__)) do
	require './../utils/validation/ArgumentChecking'
end

module KLib
	
	module UnitTest
		
		module Assertions
			
			class AssertionReport
				
				attr_reader :fails, :passes, :errors
				
				def initialize(passes, fails, errors)
					@passes = passes
					@fails = fails
					@errors = errors
				end
				
				def total
					@passes + @fails
				end
				
				def join(other_report)
					ArgumentChecking.type_check(other_report, 'other_report', AssertionReport)
					AssertionReport.new(self.passes + other_report.passes, self.fails + other_report.fails, self.errors + other_report.errors)
				end
				
				def self.join(reports)
					ArgumentChecking.type_check_each(reports, 'reports', AssertionReport)
					passes = 0
					fails = 0
					errors = 0
					reports.each do |report|
						passes += report.passes
						fails += report.fails
						errors += report.errors
					end
					AssertionReport.new(passes, fails, errors)
				end
				
				def inspect
					"#<AssertionReport: @passes=#{@passes.inspect}, @fails=#{@fails.inspect}, @errors=#{@errors.inspect}>"
				end
			
			end
			
			class Assertion
				
				attr_reader :type, :passed, :message, :error
				
				def initialize(type, passed, message, error)
					ArgumentChecking.enum_check(type, 'type', :equal, :not_equal, :raised, :not_raised, :true, :false)
					ArgumentChecking.boolean_check(passed, 'passed')
					ArgumentChecking.type_check(message, 'message', NilClass, String)
					ArgumentChecking.type_check(error, 'error', NilClass, Exception)
					@type = type
					@passed = passed
					@message = message
					@error = error
				end
				
				def inspect
					"#<#{self.class.name.split('::')[-1]}#{self.instance_variables.any? ? ": #{self.instance_variables.map { |var| "#{var}=#{self.instance_variable_get(var).inspect}" }.join(', ')}" : ""}>"
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
			
			class TrueAssertion < Assertion
				def initialize(passed, message, error)
					super(:true, passed, message, error)
				end
			end
			
			class FalseAssertion < Assertion
				def initialize(passed, message, error)
					super(:false, passed, message, error)
				end
			end
			
		end
		
	end
	
end
