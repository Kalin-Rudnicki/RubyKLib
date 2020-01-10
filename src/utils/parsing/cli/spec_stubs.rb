
require_relative 'parse_class'
require_relative 'spec_generator'
require_relative '../../validation/ArgumentChecking'

module KLib
	
	module CLI
		
		class CliParseError < StandardError; end
		
		class Transform
			
			attr_reader :priority
			
			def initialize(priority, on_err, &transform)
				priority = Array(priority)
				ArgumentChecking.type_check_each(priority, :priority, Symbol)
				ArgumentChecking.type_check(on_err, :on_err, NilClass, String, Proc)
				raise ArgumentError.new("You must supply a block to this method") unless transform
				
				@priority = priority
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
			
			attr_reader :priority
			
			def initialize(on_invalid, priority, on_err, &validate)
				priority = Array(priority)
				ArgumentChecking.type_check_each(priority, :priority, Symbol)
				ArgumentChecking.type_check(on_invalid, :on_invalid, NilClass, String, Proc)
				ArgumentChecking.type_check(on_err, :on_err, NilClass, String, Proc)
				raise ArgumentError.new("You must supply a block to this method") unless validate
				
				@on_invalid = on_invalid
				@priority = priority
				@on_err = on_err
				@validate = validate
				nil
			end
			
			def validate(val, name, already_parsed)
				begin
					valid = @validate.(val, already_parsed)
					raise "result of validation '#{name}' (#{valid.class}) is not true/false" unless valid == true || valid == false
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
			
			def transform(priority: [], on_err: nil, &block)
				@validate_transform << Transform.new(priority, on_err, &block)
				self
			end
			
			def validate(on_invalid = nil, priority: [], on_err: nil, &block)
				@validate_transform << Validate.new(on_invalid, priority, on_err, &block)
				self
			end
			
			# =====| Required/Optional/Defaults |=====
			
			def required
				@comments_extra << "Required"
				@default = { type: :required }
				self
			end
			
			def optional
				@comments_extra << "Optional"
				@default = { type: :optional }
				self
			end
			
			def default_value(val)
				@comments_extra << "Default: #{val}"
				@default = { type: :default_value, value: val }
				self
			end
			
			def default_from(other_param)
				ArgumentChecking.type_check(other_param, :other_param, Symbol)
				raise ArgumentError.new("Param 'other_param' (#{other_param}) is not a valid param name") unless CLI::LOWER_REGEX.match?(other_param.to_s)
				
				@help_extra << "Default: #{other_param.to_s.upcase}"
				@default = { type: :default_from, priority: [other_param], from: other_param }
				self
			end
			
			def default_proc(*priority, message: , &block)
				raise ArgumentError.new("This method requires a block") unless block
				ArgumentChecking.type_check_each(priority, :priority, Symbol)
				
				@help_extra << "Default: #{message}"
				@default = { type: :default_proc, priority: priority, proc: block }
				self
			end
			
			def required_if(*priority, message: , &block)
				ArgumentChecking.type_check(message, :message, String)
				raise ArgumentError.new("This method requires a block") unless block
				
				@help_extra << "Required if #{message}"
				@default = { type: :required_if, if: block, priority: priority }
				self
			end
			
			def required_if_present(other_param)
				required_if(other_param, message: "#{other_param.to_s.upcase} is present") { |already_parsed| already_parsed.key?(other_param) }
			end
			def required_if_absent(other_param)
				required_if(other_param, message: "#{other_param.to_s.upcase} is absent") { |already_parsed| !already_parsed.key?(other_param) }
			end
			
			def required_if_bool(other_param, val = true, missing: false)
				ArgumentChecking.type_check(other_param, :other_param, Symbol)
				raise ArgumentError.new("Param 'other_param' (#{other_param}) is not a valid param name") unless CLI::LOWER_REGEX.match?(other_param.to_s)
				ArgumentChecking.boolean_check(val, :val)
				ArgumentChecking.type_check(missing, :missing, NilClass, Boolean)
				
				required_if(other_param, message: "#{other_param.to_s.upcase} == #{val}") do |already_parsed|
					if already_parsed.key?(other_param)
						already_parsed[other_param] == val
					else
						if missing.nil?
							# TODO : What is this? Should nil even be a thing
							raise "? TODO ?"
						else
							missing
						end
					end
				end
				self
			end
			
			# =====| Numbers |=====
			
			def positive
				@comments_extra << "#{@name.to_s.upcase} > 0"
				validate(proc { |val, name| "#{name.to_s.upcase} must be positive, given: #{val}" }) { |val| val > 0 }
				self
			end
			
			def non_negative
				@comments_extra << "#{@name.to_s.upcase} >= 0"
				validate(proc { |val, name| "#{name.to_s.upcase} must be non-negative, given: #{val}" }) { |val| val >= 0 }
				self
			end
			
			def greater_than(obj)
				ArgumentChecking.type_check(obj, :obj, Integer, Symbol)
				@comments_extra << "#{@name.to_s.upcase} > #{obj.to_s.upcase}"
				case obj
					when Symbol
						validate(proc { |val, name, hash| "#{name.to_s.upcase} must be greater than #{obj.to_s.upcase} (#{hash[obj]}), given: #{val}" }, priority: obj) { |val, hash| val > hash[obj] }
					when Integer
						validate(proc { |val, name, hash| "#{name.to_s.upcase} must be greater than #{obj}, given: #{val}" }) { |val, hash| val > obj }
					else
						raise "What is going on?"
				end
				self
			end
			alias :gt :greater_than
			
			def greater_than_equal_to(obj)
				ArgumentChecking.type_check(obj, :obj, Integer, Symbol)
				@comments_extra << "#{@name.to_s.upcase} >= #{obj.to_s.upcase}"
				case obj
					when Symbol
						validate(proc { |val, name, hash| "#{name.to_s.upcase} must be greater than or equal to #{obj.to_s.upcase} (#{hash[obj]}), given: #{val}" }, priority: obj) { |val, hash| val >= hash[obj] }
					when Integer
						validate(proc { |val, name, hash| "#{name.to_s.upcase} must be greater than or equal to #{obj}, given: #{val}" }) { |val, hash| val >= obj }
					else
						raise "What is going on?"
				end
				self
			end
			alias :gt_et :greater_than_equal_to
			
			def less_than(obj)
				ArgumentChecking.type_check(obj, :obj, Integer, Symbol)
				@comments_extra << "#{@name.to_s.upcase} < #{obj.to_s.upcase}"
				case obj
					when Symbol
						validate(proc { |val, name, hash| "#{name.to_s.upcase} must be less than #{obj.to_s.upcase} (#{hash[obj]}), given: #{val}" }, priority: obj) { |val, hash| val < hash[obj] }
					when Integer
						validate(proc { |val, name, hash| "#{name.to_s.upcase} must be less than #{obj}, given: #{val}" }) { |val, hash| val < obj }
					else
						raise "What is going on?"
				end
				self
			end
			alias :lt :less_than
			
			def less_than_equal_to(obj)
				ArgumentChecking.type_check(obj, :obj, Integer, Symbol)
				@comments_extra << "#{@name.to_s.upcase} <= #{obj.to_s.upcase}"
				case obj
					when Symbol
						validate(proc { |val, name, hash| "#{name.to_s.upcase} must be less than or equal to #{obj.to_s.upcase} (#{hash[obj]}), given: #{val}" }, priority: obj) { |val, hash| val <= hash[obj] }
					when Integer
						validate(proc { |val, name, hash| "#{name.to_s.upcase} must be less than or equal to #{obj}, given: #{val}" }) { |val, hash| val <= obj }
					else
						raise "What is going on?"
				end
				self
			end
			alias :lt_et :less_than_equal_to
			
			# =====| Misc |=====
			
			def one_of(*options)
				options = options[0] if options.length == 1 && options[0].is_a?(Array)
				@comments_extra << "Values: #{options.join(', ')}"
				validate(proc { |val, name| "#{name.to_s.upcase} must be one of #{options.join(', ')}, given: #{val}" }) { |val| options.include?(val) }
				self
			end
			
		end
	
	
	end
	
end
