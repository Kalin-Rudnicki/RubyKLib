
Dir.chdir(File.dirname(__FILE__)) do
	require './../utils/validation/HashNormalizer'
	require './../utils/parsing/TraceParse'
	require './../utils/output/IoManipulation'
	require './../utils/general/ClassObjectUtils'
	require './Assertion'
end

module KLib

	module UnitTest
		
		class TestClass
			
			@inherited = []
			
			class << self
				
				attr_reader :created_instances, :paused_methods
				
				def inherited(inheritor)
					puts("Inherited [#{inheritor}] from '#{Trace.call_trace[0].file}'")
					self.superclass(Object).inherited_classes << inheritor
				end
				
				alias :__original_new :new
				def new(*args, &block)
					created = __original_new(*args, &block)
					@created_instances ||= []
					@created_instances << created
					manager = (self.instance_variable_defined?(:@__method_manager) ? @__method_manager.__dup : MethodManager.new)
					
					created.instance_variable_set(:@__assertions, Hash.new { |h, k| h[k] = [] })
					created.instance_variable_set(:@__method_manager, manager)
					
					manager
				end
				
				def inherited_classes
					@inherited
				end
				
				def method_added(met)
					puts("added #{met.inspect} to #{self.inspect}")
				end
			
			end
			
			private
			
				# Equal
				def assert_equal(expected, actual, message = nil)
					raise "You can not call assertions until your initializer has finished" unless self.instance_variable_defined?(:@__assertions)
					ArgumentChecking.type_check(message, 'message', NilClass, String)
					
					begin
						equal = (expected == actual)
					rescue Exception => e
						equal = false
						error = e
					else
						error = nil
					end
					@__assertions[Trace.call_trace[0].method] << Assertions::EqualAssertion.new(equal, message, expected, actual, error)
					
					equal
				end
				
				# Not Equal
				def assert_not_equal(expected, actual, message = nil)
					raise "You can not call assertions until your initializer has finished" unless self.instance_variable_defined?(:@__assertions)
					ArgumentChecking.type_check(message, 'message', NilClass, String)
					
					begin
						unequal = (expected != actual)
					rescue Exception => e
						unequal = false
						error = e
					else
						error = nil
					end
					@__assertions[Trace.call_trace[0].method] << Assertions::NotEqualAssertion.new(unequal, message, expected, actual, error)
					
					unequal
				end
				
				# Raised
				def assert_raised(exception, message = nil, &block)
					raise "You can not call assertions until your initializer has finished" unless self.instance_variable_defined?(:@__assertions)
					raise ArgumentError.new("You must supply a block to 'assert_raised'") unless block_given?
					ArgumentChecking.type_check(message, 'message', NilClass, String)
					
					begin
						block.call
					rescue exception
						raised = true
						error = nil
					rescue Exception => e
						raised = false
						error = e
					else
						raised = false
						error = nil
					end
					@__assertions[Trace.call_trace[0].method] << Assertions::RaisedAssertion.new(raised, message, exception, error)
					
					raised
				end
				
				# Not raised
				def assert_not_raised(exception, message = nil, &block)
					raise "You can not call assertions until your initializer has finished" unless self.instance_variable_defined?(:@__assertions)
					raise ArgumentError.new("You must supply a block to 'assert_raised'") unless block_given?
					ArgumentChecking.type_check(message, 'message', NilClass, String)
					
					begin
						block.call
					rescue exception => e
						raised = true
						error = e
					rescue Exception => e
						raised = false
						error = e
					else
						raised = false
						error = nil
					end
					@__assertions[Trace.call_trace[0].method] << Assertions::NotRaisedAssertion.new(!raised, message, exception, error)
					
					raised
				end
			
			class MethodManager < BasicObject
				
				def initialize
					@methods = {}
				end
				
				def set(method_to_values = nil, &block)
					::KLib::ArgumentChecking.type_check(method_to_values, 'method_to_values', ::NilClass, ::Hash)
					::Kernel.raise ::ArgumentError.new("You must supply a Hash or a Block.") if method_to_values.nil? && block.nil?
					::Kernel.raise ::ArgumentError.new("You can only supply a Hash or a Block.") if !method_to_values.nil? && !block.nil?
					
					if !method_to_values.nil?
						::KLib::ArgumentChecking.type_check_each(method_to_values.values, 'method_to_values.values', ::NilClass, ::Array)
						method_to_values.each_pair do |key, value|
							if value.nil?
								disable(key)
							else
								enable(key, *value)
							end
						end
					elsif !block.nil?
						block.call(self)
					end
					
					self
				end
				
				def disable(method_name)
					::KLib::ArgumentChecking.type_check(method_name, 'method_name', ::Symbol)
					@methods[method_name] = nil
					self
				end
				
				def enable(method_name, *args)
					::KLib::ArgumentChecking.type_check(method_name, 'method_name', ::Symbol)
					@methods[method_name] = args
					self
				end
				
				def method_missing(method_name, *args)
					enable(method_name, *args)
				end
				
				def __methods
					@methods
				end
				
				def __dup
					MethodManager.new.set(@methods)
				end
				
				def to_s
					@methods.to_s
				end
				def inspect
					@methods.inspect
				end
				
			end
		
		end
		
	end

end

class Test1 < KLib::UnitTest::TestClass

	def initialize(stuff)
		@stuff = stuff
	end
	
	def info
		puts("stuff: #{@stuff.inspect}")
		assert_equal(1, 2)
	end
	
	def info2
	
	end
	
end

class Test2 < Test1

end

test_classes = KLib::UnitTest::TestClass.inherited_classes

Test1.new(:a).set(:a => []).set do |methods|
	methods.disable(:b)
	methods.enable(:c, 1, 2, 3)
	methods.test('oh ya..')
end

Test1.new(:b)

Test2.new(:c)

test_classes.each do |t|
	t.instance_methods(false).each do |met|
		t.alias_method(:"__original_#{met}", met)
		t.define_method(met) do |*args|
			puts("Calling: '#{met}'")
			self.send(:"__original_#{met}", *args)
		end
	end
	puts(t.inspect)
	insts = t.created_instances
	insts.each do |i|
		puts("    #{i.inspect}")
		t.instance_methods(false).each do |met|
			i.send(met)
		end
		puts("    #{i.inspect}")
	end
end

# === Coverage report ===
# whether each method was expected to pass-fail
# permutation report
# (T, T), (T, F), (T, F), (F, T) => 75%, missing (F, F)
#
# obj.method_name(:pass/:fail, *args)
#
#
