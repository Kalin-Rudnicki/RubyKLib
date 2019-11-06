
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
				# TODO
				self
			end
			
			def non_negative
				# TODO
				self
			end
			
			# =====| Misc |=====
			
			def one_of(*options)
				# TODO
				self
			end
			
		end
	
	
	end
	
end
