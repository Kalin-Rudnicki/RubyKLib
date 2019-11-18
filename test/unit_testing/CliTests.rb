
require_relative '../../src/utils/parsing/cli/parse_class'
require_relative '../../src/unit_testing/TestClass'

# =====| Modules |=====

module Test1
	
	cli_spec do |spec|
		spec.int(:min).required.positive
		spec.int(:max).required.gt_et(:min)
		
		spec.execute { show_params }
	end

end

# =====| TestClass |=====

class CliParseTest < KLib::UnitTest::TestClass
	
	def initialize(mod)
		@mod = mod
	end
	
	def test_success(args, **results)
		inst = nil
		assert_not_raised(SystemExit) { inst = @mod.parse(args) }
		all = results.keys + inst.instance_variables.map { |var| var.to_s[1..-1].to_sym }
		puts("all: #{all.inspect}")
		all.each do |var|
			if results.key?(var)
				assert_true(inst.instance_variable_defined?(:"@#{var}"), "inst should not have variable '@#{var}'")
				assert_equal(results[var], inst.instance_variable_get(:"@#{var}"), "inst @#{var} should be: #{results[var].inspect}")
			else
				assert_false(inst.instance_variable_defined?(:"@#{var}"), "inst should have variable '@#{var}'")
			end
		end
	end
	
	def test_fail(args)
		assert_raised(SystemExit) { @mod.parse(args) }
	end

end

# =====| Tests |=====

CliParseTest.new(Test1).set do |methods|
	methods.test_fail(%w{})
	methods.test_fail(%w{--min})
	methods.test_fail(%w{--min 1 --max})
	methods.test_fail(%w{--min 1 --max 2 --other})
	methods.test_fail(%w{--min 1 --max 2 other})
	
	methods.test_fail(%w{--min 0 --max 1})
	methods.test_fail(%w{--min 1 --max 0})
	methods.test_fail(%w{--min 3 --max 2})
	
	methods.test_success(%w{--min 1 --max 2}, min: 1, max: 2)
	methods.test_success(%w{--min 10 --max 20}, min: 10, max: 20)
	methods.test_success(%w{--min=10 --max=20}, min: 10, max: 20)
	methods.test_success(%w{--min 0x10 --max 0x20}, min: 0x10, max: 0x20)
end
