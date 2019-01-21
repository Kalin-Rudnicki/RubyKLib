
module Boolean; end

module KLib
	
	module ArgumentChecking
		
		class InvalidValidationError < ArgumentError; end
		
		class ArgumentCheckError < ArgumentError; end
		
		class TypeCheckError < ArgumentCheckError; end
		
		class EnumCheckError < ArgumentCheckError; end
		
		class RespondToCheckError < ArgumentCheckError; end
		
		class NilCheckError < ArgumentCheckError; end
		
		class << self
			
			def check(&block)
				CheckBuilderManager.new(&block)
				true
			end
			
			def type_check(obj, name, *valid_types, &block)
				raise InvalidValidationError.new("Parameter 'name'. No explicit conversion of [#{name.class.inspect}] to [String, NilClass].") unless name.is_a?(String) || name.nil?
				raise InvalidValidationError.new("Parameter 'valid_types' must have a length > 0.") unless valid_types.length > 0
				valid_types = valid_types[0] if valid_types.length == 1 && valid_types[0].is_a?(Enumerable)
				valid_types = valid_types.map { |t| t == Boolean ? [TrueClass, FalseClass] : [t] }.flatten(1)
				valid_types.each_with_index { |t, i| raise InvalidValidationError.new("Parameter 'valid_types[#{i}]'. No explicit conversion of [#{t.class.inspect}] to [Module].") unless t.is_a?(Module) }
				valid_types.each { |t| return true if obj.is_a?(t) }
				block ||= proc { |actual_obj, obj_name, types| TypeCheckError.new("#{obj_name.nil? ? '' : "Parameter '#{obj_name}'. "}No explicit conversion of [#{actual_obj.class.inspect}] to #{types.length > 1 ? 'one of ' : ''}#{types.inspect}.") }
				throw_error(obj, name, valid_types, &block)
				false
			end
			
			def type_check_each(obj, name, *valid_types, &block)
				raise InvalidValidationError.new("Parameter 'name'. No explicit conversion of [#{name.class.inspect}] to [String, NilClass].") unless name.is_a?(String) || name.nil?
				raise InvalidValidationError.new("Parameter 'valid_types' must have a length > 0.") unless valid_types.length > 0
				valid_types = valid_types.map { |t| t == Boolean ? [TrueClass, FalseClass] : [t] }.flatten(1)
				valid_types.each_with_index { |t, i| raise InvalidValidationError.new("Parameter 'valid_types[#{i}]'. No explicit conversion of [#{t.class.inspect}] to [Module].") unless t.is_a?(Module) }
				type_check(obj, name, Enumerable)
				pass = true
				obj.each_with_index { |element, index| pass &&= type_check(element, name.nil? ? nil : "#{name}[#{index}]", *valid_types, &block) }
				pass
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
			
			def enum_check_each(obj, name, *valid_enums, &block)
				raise InvalidValidationError.new("Parameter 'name'. No explicit conversion of [#{name.class.inspect}] to [String, NilClass].") unless name.is_a?(String) || name.nil?
				raise InvalidValidationError.new("Parameter 'valid_enums' must have a length > 0.") unless valid_enums.length > 0
				type_check(obj, name, Enumerable)
				pass = true
				obj.each_with_index { |element, index| pass &&= enum_check(element, name.nil? ? nil : "#{name}[#{index}]", *valid_enums, &block) }
				pass
			end
			
			def respond_to_check(obj, name, *methods, &block)
				raise InvalidValidationError.new("Parameter 'name'. No explicit conversion of [#{name.class.inspect}] to [String, NilClass].") unless name.is_a?(String) || name.nil?
				raise InvalidValidationError.new("Parameter 'methods' must have a length > 0.") unless methods.length > 0
				methods = methods[0] if methods.length == 1 && methods[0].is_a?(Enumerable)
				missing = methods.select { |m| !obj.respond_to?(m) }
				return true if missing.empty?
				block ||= proc { |actual, obj_name, all_methods, missing_methods| RespondToCheckError.new("#{name.nil? ? '' : "Parameter '#{obj_name}'. "}[#{actual.class.inspect}] is missing methods #{missing_methods.inspect}, required: #{all_methods.inspect}.") }
				throw_error(obj, name, methods, missing, &block)
				false
			end
			
			def nil_check(obj, name, &block)
				raise InvalidValidationError.new("Parameter 'name'. No explicit conversion of [#{name.class.inspect}] to [String, NilClass].") unless name.is_a?(String) || name.nil?
				return true unless obj.nil?
				block ||= proc { |obj_name| NilCheckError.new("Parameter #{obj_name.nil? ? '' : "'#{obj_name}' "}can not be nil.") }
				throw_error(name, &block)
				false
			end
			
			def boolean_check(obj, name, &block)
				type_check(obj, name, Boolean, &block)
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
							raise InvalidValidationError.new('When throwing an error, your block must: Raise an error yourself, or return on of [KLib::ArgumentChecking::ArgumentCheckError, String, NilClass].')
					end
				end
		
		end
	
		class CheckBuilderManager < BasicObject
			
			def initialize(&block)
				::Kernel.raise ::KLib::ArgumentChecking::InvalidValidationError.new("You must supply a block to initialize a CheckBuilderManager") unless ::Kernel.block_given?
				@binding = block.binding
				@variables = []
				block.call(self)
				
				errors = []
				@variables.each do |var|
					var.__checks.each_pair do |method, args|
						begin
							unless ::KLib::ArgumentChecking.send(method, @binding.local_variable_get(var.__name), var.__name.to_s, *args)
								errors << "Failed to validate: ArgumentChecking.#{method}(#{var.__name.to_s}, '#{var.__name.to_s}'#{args.map { |arg| ", #{arg.inspect}" }})"
							end
						rescue ::KLib::ArgumentChecking::ArgumentCheckError => e
							errors << e.message
						end
					end
				end
				if errors.any?
					::Kernel.raise ::KLib::ArgumentChecking::ArgumentCheckError.new("Failed to validate:\n#{errors.join("\n")}")
				end
			end
			
			def method_missing(sym, &block)#, *args)
				::Kernel.raise ::KLib::ArgumentChecking::InvalidValidationError.new("No local variable defined: '#{sym}'") unless @binding.local_variable_defined?(sym)
				#::Kernel.raise ::KLib::ArgumentChecking::InvalidValidationError.new("No local variable defined: '#{sym}'") if args.any?
				added = CheckBuilder.new(sym, &block)
				@variables << added
				added
			end
			
			class CheckBuilder < BasicObject
				
				def initialize(name, &block)
					@name = name
					@checks = {}
					block.call(self) unless block.nil?
				end
				
				def method_missing(sym, *args)
					::KLib::ArgumentChecking.type_check(sym, 'sym', ::Symbol)
					::Kernel.raise ::KLib::ArgumentChecking::InvalidValidationError.new("You can not re-call 'check'") if sym == :check
					::Kernel.raise ::KLib::ArgumentChecking::InvalidValidationError.new("KLib::ArgumentChecking does not have method '#{sym}'") unless ::KLib::ArgumentChecking.methods.include?(sym)
					@checks[sym] = args
					self
				end
				
				def __name
					@name
				end
				
				def __checks
					@checks
				end
				
			end
			
		end
		
	end

end
