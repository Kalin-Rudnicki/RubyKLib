
module KLib
	
	module CLI
		
		module Stubs
			
			# =====|  |=====
			
			# =====| General |=====
			
			def auto_trim(val = true)
				ArgumentChecking.boolean_check(val, :val)
				@auto_trim = val
				self
			end
			
			def transform(on_fail = nil, &block)
				# TODO
				self
			end
			
			def validate(on_fail = nil, &block)
				# TODO
				self
			end
			
			def is_array(val = true)
				ArgumentChecking.boolean_check(val, :val)
				@is_array = val
				self
			end
			
			# =====| Required/Optional/Defaults |=====
			
			def required
				# TODO
				self
			end
			
			def optional
				# TODO
				self
			end
			
			def default_value(val)
				# TODO
				self
			end
			
			def default_from(other_param)
				# TODO
				self
			end
			
			def required_if(&block)
				raise ArgumentError.new("This method requires a block") unless block
				# TODO
				self
			end
			
			def required_if_present(key)
				ArgumentChecking.type_check(key, :key, Symbol)
				# TODO
				self
			end
			
			def required_if_bool(key, val = true)
				ArgumentChecking.type_check(key, :key, Symbol)
				ArgumentChecking.boolean_check(val, :val)
				# TODO
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
				ArgumentChecking.type_check(options, :options, Array)
				validate(proc { |val, name| "#{name} must be one of #{options.join(', ')}, given: #{val}" }) { |val| options.include?(val) }
				self
			end
			
		end
	
	
	end
	
end
