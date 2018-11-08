
module KLib
	
	module ArgumentChecking
		
		class InvalidValidationError < ArgumentError; end
		
		class ArgumentCheckError < ArgumentError; end
		
		class TypeCheckError < ArgumentCheckError; end
		
		class EnumCheckError < ArgumentCheckError; end
		
		class << self
			
			def check(&block)
				raise InvalidValidationError.new('You must supply when checking...') unless block_given?
				ArgumentChecking.module_eval(&block)
			end
			
			def type_check(obj, name, *valid_types, &blockW)
				raise InvalidValidationError.new("Parameter 'name'. No explicit conversion of [#{name.class.inspect}] to [String, NilClass].") unless name.is_a?(String) || name.nil?
				raise InvalidValidationError.new("Parameter 'valid_types' must have a length > 0.") unless valid_types.length > 0
				valid_types = valid_types[0] if valid_types.length == 1 && valid_types[0].is_a?(Enumerable)
				valid_types.each_with_index { |t, i| raise InvalidValidationError.new("Parameter 'valid_types[#{i}]'. No explicit conversion of [#{t.class.inspect}] to [Module].") unless t.is_a?(Module) }
				valid_types.each { |t| return true if obj.is_a?(t) }
				block ||= proc { |actual_obj, obj_name, types| TypeCheckError.new("#{obj_name.nil? ? '' : "Parameter '#{obj_name}'. "}No explicit conversion of [#{actual_obj.class.inspect}] to #{types.length > 1 ? 'one of ' : ''}#{types.inspect}.") }
				throw_error(obj, name, valid_types, &block)
				false
			end
			
			def enum_check(obj, name, *valid_enums, &block)
				raise InvalidValidationError.new("Parameter 'name'. No explicit conversion of [#{name.class.inspect}] to [String, NilClass].") unless name.is_a?(String) || name.nil?
				raise InvalidValidationError.new("Parameter 'valid_enums' must have a length > 0.") unless valid_enums.length > 0
				valid_enums = valid_enums[0] if valid_enums.length == 1 && valid_enums[0].is_a?(Enumerable)
				return true if valid_enums.include?(obj)
				block ||= proc { |actual_obj, obj_name, enums| EnumCheckError.new("#{obj_name.nil? ? '' : "Parameter '#{obj_name}'. "}Value [#{actual_obj.inspect}] not found in valid values #{enums.inspect}.") }
				throw_error(obj, name, valid_enums, &block)
				false
			end
			
			
			
			private
				
				def throw_error(*args, &block)
					raise InvalidValidationError.new('You must supply a block when throwing an error...') unless block_given?
					result = block.(*args)
					case result
						when ArgumentCheckError
							raise result
						when String
							raise ArgumentCheckError.new(result)
						when NilClass
							# Do nothing on purpose
						else
							raise InvalidValidationError.new('When throwing an error, your block must: Raise an error yourself, or return on of [ArgumentChecking::ArgumentCheckError, String, NilClass].')
					end
				end
		
		end
	
	end
	
end

if File.expand_path(__FILE__ ) == File.expand_path($0)

	ArgumentChecking.type_check(5, 'my_arg', String, Symbol)
	
end