
require_relative 'spec_stubs'
require_relative '../../validation/ArgumentChecking'

module KLib
	
	module CLI
		
		class SpecGenerator
			
			def initialize(*args, **hash_args, &block)
				raise ArgumentError.new("Block is required for spec creation") unless block
				raise ArgumentError.new("No current usage for args or hash_args") if args.any? || hash_args.any?
				
				@specs = []
				block.call(self)
				
				nil
			end
			
			def sub_spec(name, *args, **hash_args, &block)
				sub_spec = SpecGenerator.new(*args, **hash_args, &block)
			end
			
			def integer(*args, **hash_args, &block)
				spec = IntegerSpec.new(*args, **hash_args)
				@specs << spec
				spec
			end
			
			def float(*args, **hash_args, &block)
				spec = FloatSpec.new(*args, **hash_args)
				@specs << spec
				spec
			end
			
			def boolean(*args, **hash_args, &block)
				spec = BooleanSpec.new(*args, **hash_args)
				@specs << spec
				spec
			end
			
			def flag(*args, **hash_args, &block)
				spec = FlagSpec.new(*args, **hash_args)
				@specs << spec
				spec
			end
			
			def symbol(*args, **hash_args, &block)
				spec = SymbolSpec.new(*args, **hash_args)
				@specs << spec
				spec
			end
			
			def string(*args, **hash_args, &block)
				spec = StringSpec.new(*args, **hash_args)
				@specs << spec
				spec
			end
			
			# =====| SuperClass |=====
			
			REGEX = /^[a-z]+(_[a-z]+)*$/
			
			class Spec
				
				def initialize(name, aliases)
					ArgumentChecking.type_check(name, :name, Symbol)
					ArgumentChecking.type_check(aliases, :aliases, Array)
					ArgumentChecking.type_check_each(aliases, :aliases, Symbol)
					raise ArgumentError.new("#{name.inspect} is not a valid name") unless SpecGenerator::REGEX.match?(name.to_s)
					aliases.each { |a| raise ArgumentError.new("#{a.inspect} is not a valid alias") unless SpecGenerator::REGEX.match?(a.to_s) }
					
					@name = name
					@aliases = aliases
					@default = { type: :optional }
					@validate_transform = []
					@comments = []
					nil
				end
				
				def comment(*comments)
					ArgumentChecking.type_check_each(comments, :comments, String)
					@comments += comments
					self
				end
				
				def self.stubs(stub_arr)
					ArgumentChecking.type_check_each(stub_arr, :stub_arr, Symbol)
					stub_arr.each do |method_name|
						# puts(Stubs.instance_method(method_name).inspect)
						define_method(method_name, Stubs.instance_method(method_name))
					end
				end
			
			end
			
			# =====| Classes |=====
			
			class IntegerSpec < Spec
				
				# required/optional/required_if/required_unless/default_value/default_from/default_proc
				# range(min, max), positive, non_negative
				# greater_than, less_than, greater_equal_to, less_equal_to; number/other param
				# one_of
				# validate
				# comment
				# alias 
				# array
				
				stubs(%i{
			auto_trim transform validate
			required optional default_value default_from required_if required_if_present required_if_bool
			positive non_negative
			one_of
					})
				
				def initialize(name, aliases: [], multi: :error, split: false, &block)
					super(name, aliases)
					
					ArgumentChecking.enum_check(multi, :multi, %i{error first last all})
					ArgumentChecking.boolean_check(split, :split)
					
					validate(proc { |val| "#{val.inspect} does not look like an integer" }) { |val| /^-?\d+$/.match?(val) }
					transform { |val| val.to_i }
					
					block.call(self) if block
					nil
				end
			
			end
			
			class FloatSpec < Spec
				
				# required/optional/required_if/required_unless/default_value/default_from/default_proc
				# range(min, max), positive, non_negative
				# greater_than, less_than, greater_equal_to, less_equal_to; number/other param
				# validate
				# comment
				# alias
				# array
				
				stubs(%i{
			auto_trim transform validate
			required optional default_value default_from required_if required_if_present required_if_bool
			positive non_negative
					})
				
				def initialize(name, aliases: [], multi: :error, split: false, &block)
					super(name, aliases)
					
					ArgumentChecking.enum_check(multi, :multi, %i{error first last all})
					ArgumentChecking.boolean_check(split, :split)
					
					validate(proc { |val| "#{val.inspect} does not look like a float" }) { |val| /^-?\d+(\.\d+)?$/.match?(val) }
					transform { |val| val.to_f }
					
					block.call(self) if block
					nil
				end
			
			end
			
			class BooleanSpec < Spec
				
				# required/optional/required_if/required_unless/default_value/default_from/default_proc
				# validate
				# yes_no
				# comment
				# alias
				
				stubs(%i{
			required optional default_value default_from required_if required_if_present required_if_bool
					})
				
				def initialize(name, aliases: [], multi: :error, positive: nil, negative: nil, &block)
					super(name, aliases)
					
					ArgumentChecking.enum_check(multi, :multi, %i{error first last})
					
					ArgumentChecking.type_check(positive, :positive, Symbol, NilClass)
					ArgumentChecking.type_check(negative, :negative, Symbol, NilClass)
					raise ArgumentError.new("positive and negative can not be the same") if positive == negative
					raise ArgumentError.new("#{positive.inspect} is not a valid positive") unless positive.nil? || SpecGenerator::REGEX.match?(positive.to_s)
					raise ArgumentError.new("#{negative.inspect} is not a valid negative") unless negative.nil? || SpecGenerator::REGEX.match?(negative.to_s)
					
					@positive = positive
					@negative = negative
					
					block.call(self) if block
					nil
				end
			
			end
			
			class FlagSpec < Spec
				
				# yes_no_default; .yes_no_default(:do_dont, true) # aka: assume true, --dont-thing will be a flag
				# validate
				# comment
				# alias
				
				stubs(%i{})
				
				def initialize(name, aliases: [], multi: :error, default: , positive: nil, negative: nil, &block)
					super(name, aliases)
					
					ArgumentChecking.enum_check(multi, :multi, %i{error ignore})
					
					ArgumentChecking.boolean_check(default, :default)
					ArgumentChecking.type_check(positive, :positive, Symbol, NilClass)
					ArgumentChecking.type_check(negative, :negative, Symbol, NilClass)
					raise ArgumentError.new("positive and negative can not be the same") if positive == negative
					raise ArgumentError.new("#{positive.inspect} is not a valid positive") unless positive.nil? || SpecGenerator::REGEX.match?(positive.to_s)
					raise ArgumentError.new("#{negative.inspect} is not a valid negative") unless negative.nil? || SpecGenerator::REGEX.match?(negative.to_s)
					
					# TODO : flag default
					@positive = positive
					@negative = negative
					
					block.call(self) if block
					nil
				end
			
			end
			
			class SymbolSpec < Spec
				
				# required/optional/required_if/required_unless/default_value/default_from/default_proc
				# one_of
				# validate
				# comment
				# alias
				# array
				
				stubs(%i{
			auto_trim transform validate
			required optional default_value default_from required_if required_if_present required_if_bool
			one_of
					})
				
				def initialize(name, aliases: [], multi: :error, split: false, &block)
					super(name, aliases)
					
					ArgumentChecking.enum_check(multi, :multi, %i{error first last all})
					ArgumentChecking.boolean_check(split, :split)
					
					transform { |val| val.to_sym }
					
					block.call(self) if block
					nil
				end
			
			end
			
			class StringSpec < Spec
				
				# required/optional/required_if/required_unless/default_value/default_from/default_proc
				# one_of
				# validate
				# comment
				# alias
				# array
				
				stubs(%i{
			auto_trim transform validate
			required optional default_value default_from required_if required_if_present required_if_bool
					})
				
				def initialize(name, aliases: [], multi: :error, split: false, &block)
					super(name, aliases)
					
					ArgumentChecking.enum_check(multi, :multi, %i{error first last all})
					ArgumentChecking.boolean_check(split, :split)
					
					block.call(self) if block
					nil
				end
			
			end
		
		end
	
	
	end
	
end
