
Dir.chdir(File.dirname(__FILE__)) do
	require './../../../src/utils/validation/ArgumentChecking'
	
	require 'set'
	require 'test/unit'
end

VALID_RESULTS = [:pass, :exit, :fail, :err]
RESULTS = {}

def test(exp_result, &block)
	raise ArgumentError.new("You must supply a block for testing!!!") unless block_given?
	raise ArgumentError.new("result #{exp_result.inspect} is not one of #{VALID_RESULTS}") unless VALID_RESULTS.include?(exp_result)
	act_result = nil
	begin
		block.call()
		act_result = :pass
	rescue SystemExit => e
		puts("Exit: #{e.status}")
		act_result = :exit
	rescue => e
		puts("Error: #{e.class.inspect} => #{e.message}")
		act_result = :fail
	end
	if act_result != exp_result
		puts("\e[31mFAIL\e[0m")
	else
		puts("\e[35mPASS\e[0m")
	end
	puts
	
	RESULTS[act_result == exp_result] += 1
	
	nil
end

def run_tests(&block)
	RESULTS[true] = 0
	RESULTS[false] = 0
	
	block.call()
	
	puts("Passes: #{RESULTS[true]}")
	puts("Fails:  #{RESULTS[false]}")
end

class ArgumentCheckingTests < Test::Unit::TestCase
	
	@counter = 0
	
	class << self
		
		attr_accessor :counter
		
		def exp(exp_result, &block)
			raise ArgumentError.new("You must supply a block for testing!!!") unless block_given?
			raise ArgumentError.new("result #{exp_result.inspect} is not one of #{VALID_RESULTS}") unless VALID_RESULTS.include?(exp_result)
			Exp.new(exp_result, &block)
		end
		
		def run_test(&block)
			act_result = nil
			err = nil
			begin
				block.call()
				act_result = :pass
			rescue SystemExit => e
				err = e
				act_result = :exit
			rescue KLib::ArgumentChecking::ArgumentCheckError => e
				err = e
				act_result = :fail
			rescue => e
				err = e
				act_result = :err
			end
			Result.new(act_result, err)
		end
		
	end
	
	def validate_res(exp, res, type)
		puts("=== #{type} ===")
		puts("[ERROR] #{res.err.class.inspect} => #{res.err.message}") unless res.act == :pass
		puts("Expected: #{exp.inspect}")
		puts("Actual:   #{res.act.inspect}")
		puts
		assert_equal(exp, res.act)
	end
	
	class Result
		
		attr_reader :act, :err
		
		def initialize(act, err)
			@act = act
			@err = err
		end
	
	end
	
	class Exp
		
		def initialize(exp, &block)
			raise ArgumentError.new("You must supply a block for testing!!!") unless block_given?
			@exp = exp
			instance_eval(&block)
		end
		
		def type_check(*args, &block)
			ArgumentCheckingTests.counter += 1
			exp = @exp
			ArgumentCheckingTests.define_method(:"test_#{ArgumentCheckingTests.counter.to_s.rjust(2, '0')}___type_check") do
				res = ArgumentCheckingTests.run_test do
					KLib::ArgumentChecking.type_check(*args, &block)
				end
				validate_res(exp, res, 'type_check')
			end
		end
		
		def type_check_each(*args, &block)
			ArgumentCheckingTests.counter += 1
			exp = @exp
			ArgumentCheckingTests.define_method(:"test_#{ArgumentCheckingTests.counter.to_s.rjust(2, '0')}___type_check_each") do
				res = ArgumentCheckingTests.run_test do
					KLib::ArgumentChecking.type_check_each(*args, &block)
				end
				validate_res(exp, res, 'type_check_each')
			end
		end
		
		def enum_check(*args, &block)
			ArgumentCheckingTests.counter += 1
			exp = @exp
			ArgumentCheckingTests.define_method(:"test_#{ArgumentCheckingTests.counter.to_s.rjust(2, '0')}___enum_check") do
				res = ArgumentCheckingTests.run_test do
					KLib::ArgumentChecking.enum_check(*args, &block)
				end
				validate_res(exp, res, 'enum_check')
			end
		end
		
		def enum_check_each(*args, &block)
			ArgumentCheckingTests.counter += 1
			exp = @exp
			ArgumentCheckingTests.define_method(:"test_#{ArgumentCheckingTests.counter.to_s.rjust(2, '0')}___enum_check") do
				res = ArgumentCheckingTests.run_test do
					KLib::ArgumentChecking.enum_check_each(*args, &block)
				end
				validate_res(exp, res, 'enum_check')
			end
		end
		
	end
	
end

ArgumentCheckingTests.exp(:pass) do
	
	type_check('my_str', 'my_str', String)
	type_check(:my_sym, 'my_sym', Symbol)
	type_check(5, 'my_int', Integer)
	type_check(5, 'my_int', Numeric)
	
	type_check_each([], 'my_arr', String)
	type_check_each(['a', 'b', 'c'], 'my_arr', String)
	
	enum_check(:b, 'my_sym', :a, :b, :c)
	enum_check(:b, 'my_sym', Set[:a, :b, :c])
	
	enum_check_each([], 'my_arr', :a, :b, :c)
	enum_check_each([:a, :a, :b, :b, :c, :c], 'my_arr', :a, :b, :c)

end

ArgumentCheckingTests.exp(:fail) do
	
	type_check(nil, 'my_str', String)
	type_check(nil, 'my_sym', Symbol)
	type_check(nil, 'my_int', Integer)
	type_check(nil, 'my_int', Numeric)
	
	type_check_each(nil, 'my_arr', String)
	type_check_each('my_arr', 'my_arr', String)
	type_check_each([:a, 'b', 'c'], 'my_arr', String)
	type_check_each([:a, :b, :c], 'my_arr', String)
	
	enum_check(:d, 'my_sym', :a, :b, :c)
	enum_check(:d, 'my_sym', Set[:a, :b, :c])
	enum_check(nil, 'my_sym', :a, :b, :c)
	enum_check(nil, 'my_sym', Set[:a, :b, :c])

end

ArgumentCheckingTests.exp(:err) do
	
	type_check()
	type_check(nil, nil)
	type_check(nil, :nil, NilClass)
	
	type_check_each([], 'my_arr', :a, :b, :c)
	type_check_each([:a, :a, :b, :b, :c, :c], 'my_arr', :a, :b, :c)
	
	enum_check()
	enum_check(nil, nil)
	enum_check(nil, :nil, nil)
	
	type_check_each([], 'my_arr')
	
end
