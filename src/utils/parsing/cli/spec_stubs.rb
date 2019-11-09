
require_relative 'parse_class'
require_relative 'spec_generator'
require_relative '../../validation/ArgumentChecking'

module KLib
	
	module CLI
		
		class CliParseError < StandardError; end
		
		class Transform
			
			def initialize(on_err, &transform)
				ArgumentChecking.type_check(on_err, :on_err, NilClass, String, Proc)
				raise ArgumentError.new("You must supply a block to this method") unless transform
				
				@on_err = on_err
				@transform = transform
				nil
			end
			
			def transform(val, name, already_parsed)
				begin
					@transform.(val, already_parsed)
				rescue CliParseError => e
					raise e
				rescue => e
					case @on_err
						when NilClass
							raise e
						when String
							raise CliParseError.new(@on_err)
						when Proc
							raise CliParseError.new(@on_err.(val, name, already_parsed, e))
						else
							raise "What is going on?"
					end
				end
			end
			
		end
		
		class Validate
			
			def initialize(on_invalid, on_err, &validate)
				ArgumentChecking.type_check(on_invalid, :on_invalid, NilClass, String, Proc)
				ArgumentChecking.type_check(on_err, :on_err, NilClass, String, Proc)
				raise ArgumentError.new("You must supply a block to this method") unless validate
				
				@on_invalid = on_invalid
				@on_err = on_err
				@validate = validate
				nil
			end
			
			def validate(val, name, already_parsed)
				begin
					valid = @validate.(val, already_parsed)
					raise "result of validation is not true/false" unless valid.is_a?(Boolean)
					unless valid
						case @on_invalid
							when NilClass
								raise CliParseError.new("Argument '#{name}' is invalid")
							when String
								raise CliParseError.new(@on_invalid)
							when Proc
								raise CliParseError.new(@on_invalid.(val, name, already_parsed))
							else
								raise "What is going on?"
						end
					end
					valid
				rescue CliParseError => e
					raise e
				rescue => e
					case @on_err
						when NilClass
							raise e
						when String
							raise CliParseError.new(@on_err)
						when Proc
							raise CliParseError.new(@on_err.(val, name, already_parsed, e))
						else
							raise "What is going on?"
					end
				end
			end
			
		end
		
		module Stubs
			
			# =====|  |=====
			
			# =====| General |=====
			
			def auto_trim(val = true)
				ArgumentChecking.boolean_check(val, :val)
				@auto_trim = val
				self
			end
			
			def transform(on_err: nil, &block)
				@validate_transform << Transform.new(on_err, &block)
				self
			end
			
			def validate(on_invalid = nil, on_err: nil, &block)
				@validate_transform << Validate.new(on_invalid, on_err, &block)
				self
			end
			
			# =====| Required/Optional/Defaults |=====
			
			def required
				@default = { type: :required }
				self
			end
			
			def optional
				@default = { type: :optional }
				self
			end
			
			def default_value(val)
				@default = { type: :default_value, value: val }
				self
			end
			
			def default_from(other_param, get_when: :post)
				ArgumentChecking.type_check(other_param, :other_param, Symbol)
				raise ArgumentError.new("Param 'other_param' (#{other_param}) is not a valid param name") unless CLI::LOWER_REGEX.match?(other_param.to_s)
				ArgumentChecking.enum_check(get_when, :get_when, :pre, :post)
				
				@default = { type: :default_from, from: other_param, get_when: get_when }
				self
			end
			
			def required_if(*priority, &block)
				raise ArgumentError.new("This method requires a block") unless block
				
				@default = { type: :required_if, if: block, priority: priority }
				self
			end
			
			def required_if_present(other_param)
				required_if(other_param) { |already_parsed| already_parsed.key?(other_param) }
			end
			def required_if_absent(other_param)
				required_if(other_param) { |already_parsed| !already_parsed.key?(other_param) }
			end
			
			def required_if_bool(other_param, val = true, missing: false)
				ArgumentChecking.type_check(other_param, :other_param, Symbol)
				raise ArgumentError.new("Param 'other_param' (#{other_param}) is not a valid param name") unless CLI::LOWER_REGEX.match?(other_param.to_s)
				ArgumentChecking.boolean_check(val, :val)
				ArgumentChecking.type_check(missing, :missing, NilClass, Boolean)
				
				required_if(other_param) do |already_parsed|
					if already_parsed.key?(other_param)
						already_parsed[other_param] == val
					else
						if missing.nil?
							# TODO : What is this? Should nil even be a thing
						else
							missing
						end
					end
				end
				self
			end
			
			# =====| Numbers |=====
			
			def positive
				validate(proc { |val, name| "#{name} must be positive, given: #{val}" }) { |val| val > 0 }
				self
			end
			
			def non_negative
				validate(proc { |val, name| "#{name} must be non-negative, given: #{val}" }) { |val| val >= 0 }
				self
			end
			
			def greater_than(key)
				ArgumentChecking.type_check(key, :key, Symbol)
				validate(proc { |val, name, hash| "#{name} must be greater than #{key} (#{hash[key]}), given: #{val}" }) { |val, hash| val > hash[key] }
				self
			end
			alias :gt :greater_than
			
			def greater_than_equal_to(key)
				ArgumentChecking.type_check(key, :key, Symbol)
				validate(proc { |val, name, hash| "#{name} must be greater than or equal to #{key} (#{hash[key]}), given: #{val}" }) { |val, hash| val >= hash[key] }
				self
			end
			alias :gt_et :greater_than_equal_to
			
			def less_than(key)
				ArgumentChecking.type_check(key, :key, Symbol)
				validate(proc { |val, name, hash| "#{name} must be less than #{key} (#{hash[key]}), given: #{val}" }) { |val, hash| val < hash[key] }
				self
			end
			alias :lt :less_than
			
			def less_than_equal_to(key)
				ArgumentChecking.type_check(key, :key, Symbol)
				validate(proc { |val, name, hash| "#{name} must be less than or equal to #{key} (#{hash[key]}), given: #{val}" }) { |val, hash| val <= hash[key] }
				self
			end
			alias :lt_et :less_than_equal_to
			
			# =====| Misc |=====
			
			def one_of(*options)
				options = options[0] if options.length == 1 && options[0].is_a?(Array)
				validate(proc { |val, name| "#{name} must be one of #{options.join(', ')}, given: #{val}" }) { |val| options.include?(val) }
				self
			end
			
		end
	
	
	end
	
end
