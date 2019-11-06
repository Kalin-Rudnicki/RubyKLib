
Dir.chdir(File.dirname(__FILE__)) do
	require './../general/RaiseNotMe'
end

module Boolean; end

module KLib
	
	module ArgumentChecking
		
		class InvalidValidationError < ArgumentError; end
		
		class ArgumentCheckError < ArgumentError; end
		
		class TypeCheckError < ArgumentCheckError; end
		
		class EnumCheckError < ArgumentCheckError; end
		
		class RespondToCheckError < ArgumentCheckError; end
		
		class NilCheckError < ArgumentCheckError; end
		
		class PathCheckError < ArgumentCheckError; end
		
		class << self
			
			def check(&block)
				CheckBuilderManager.new(&block)
				true
			end
			
			def type_check(obj, name, *valid_types, &block)
				raise InvalidValidationError.new("Parameter 'name'. No explicit conversion of [#{name.class.inspect}] to [Symbol, String, NilClass].") unless [Symbol, String, NilClass].any? { |klass| name.is_a?(klass) }
				raise InvalidValidationError.new("Parameter 'valid_types' must have a length > 0.") unless valid_types.length > 0
				valid_types = valid_types[0] if valid_types.length == 1 && valid_types[0].is_a?(Enumerable)
				valid_types = valid_types.map { |t| t == Boolean ? [TrueClass, FalseClass] : [t] }.flatten(1)
				valid_types.each_with_index { |t, i| raise InvalidValidationError.new("Parameter 'valid_types[#{i}]'. No explicit conversion of [#{t.class.inspect}] to [Module].") unless t.is_a?(Module) }
				valid_types.each { |t| return true if Kernel.instance_method(:is_a?).bind(obj).call(t) }
				block ||= proc { |actual_obj, obj_name, types| TypeCheckError.new("#{obj_name.nil? ? '' : "Parameter '#{obj_name}'. "}No explicit conversion of [#{actual_obj.class.inspect}] to #{types.length > 1 ? 'one of ' : ''}#{types.inspect}.") }
				throw_error(obj, name, valid_types, &block)
				false
			end
			
			def type_check_each(obj, name, *valid_types, &block)
				raise InvalidValidationError.new("Parameter 'name'. No explicit conversion of [#{name.class.inspect}] to [Symbol, String, NilClass].") unless [Symbol, String, NilClass].any? { |klass| name.is_a?(klass) }
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
				raise InvalidValidationError.new("Parameter 'name'. No explicit conversion of [#{name.class.inspect}] to [Symbol, String, NilClass].") unless [Symbol, String, NilClass].any? { |klass| name.is_a?(klass) }
				raise InvalidValidationError.new("Parameter 'valid_enums' must have a length > 0.") unless valid_enums.length > 0
				type_check(obj, name, Enumerable)
				pass = true
				obj.each_with_index { |element, index| pass &&= enum_check(element, name.nil? ? nil : "#{name}[#{index}]", *valid_enums, &block) }
				pass
			end
			
			def respond_to_check(obj, name, *methods, &block)
				raise InvalidValidationError.new("Parameter 'name'. No explicit conversion of [#{name.class.inspect}] to [Symbol, String, NilClass].") unless [Symbol, String, NilClass].any? { |klass| name.is_a?(klass) }
				raise InvalidValidationError.new("Parameter 'methods' must have a length > 0.") unless methods.length > 0
				methods = methods[0] if methods.length == 1 && methods[0].is_a?(Enumerable)
				missing = methods.select { |m| !obj.respond_to?(m) }
				return true if missing.empty?
				block ||= proc { |actual, obj_name, all_methods, missing_methods| RespondToCheckError.new("#{name.nil? ? '' : "Parameter '#{obj_name}'. "}[#{actual.class.inspect}] is missing methods #{missing_methods.inspect}, required: #{all_methods.inspect}.") }
				throw_error(obj, name, methods, missing, &block)
				false
			end
			
			def nil_check(obj, name, &block)
				raise InvalidValidationError.new("Parameter 'name'. No explicit conversion of [#{name.class.inspect}] to [Symbol, String, NilClass].") unless [Symbol, String, NilClass].any? { |klass| name.is_a?(klass) }
				return true unless obj.nil?
				block ||= proc { |obj_name| NilCheckError.new("Parameter #{obj_name.nil? ? '' : "'#{obj_name}' "}can not be nil.") }
				throw_error(name, &block)
				false
			end
			
			def boolean_check(obj, name, &block)
				type_check(obj, name, Boolean, &block)
			end
			
			def path_check(path, name, type = :any, &block)
				valid_types = %i{any file dir exe}
				raise InvalidValidationError.new("Parameter 'path'. No explicit conversion of [#{path.class.inspect}] to [String].") unless path.is_a?(String)
				raise InvalidValidationError.new("Parameter 'name'. No explicit conversion of [#{name.class.inspect}] to [Symbol, String, NilClass].") unless [Symbol, String, NilClass].any? { |klass| name.is_a?(klass) }
				raise InvalidValidationError.new("Parameter 'type'. Value [#{type.inspect}] does not exist in #{valid_types.inspect}.") unless valid_types.include?(type)
				
				unless File.exists?(path)
					block ||= proc do |given_path, given_name, given_type|
						if given_path.tr('\\', '/') == File.expand_path(given_path)
							PathCheckError.new("Path #{given_name.nil? ? '' : "'#{given_name}' "}(#{given_path}) does not exist.")
						else
							PathCheckError.new("Path #{given_name.nil? ? '' : "'#{given_name}' "}(#{given_path}) does not exist in the scope of #{Dir.pwd}.")
						end
					end
					throw_error(path, name, :any, &block)
					return false
				end
				case type
					when :any
					when :file
						unless File.file?(path)
							block ||= proc { |given_path, given_name, given_type| PathCheckError.new("Path #{given_name.nil? ? '' : "'#{given_name}' "}(#{given_path}) is not a file.") }
							throw_error(path, name, type, &block)
							return false
						end
					when :dir
						unless File.directory?(path)
							block ||= proc { |given_path, given_name, given_type| PathCheckError.new("Path #{given_name.nil? ? '' : "'#{given_name}' "}(#{given_path}) is not a directory.") }
							throw_error(path, name, type, &block)
							return false
						end
					when :exe
						unless File.executable?(path)
							block ||= proc { |given_path, given_name, given_type| PathCheckError.new("Path #{given_name.nil? ? '' : "'#{given_name}' "}(#{given_path}) is not executable.") }
							throw_error(path, name, type, &block)
							return false
						end
					else
						raise "What is going on..."
				end
				true
			end
			
			private
				
				def throw_error(*args, &block)
					raise InvalidValidationError.new('You must supply a block when throwing an error...') unless block_given?
					result = block.(*args)
					case result
						when ArgumentCheckError
							raise_not_me result
						when String
							raise_not_me ArgumentCheckError.new(result)
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
							value = @binding.local_variable_get(var.__name)
							name = var.__name.to_s
							if var.__args.any?
								value = value.__send__(*var.__args)
								if var.__args[0] == :[]
									name = "#{name}[#{var.__args.length > 1 ? "#{var.__args[1..-1].map { |a| a.inspect }.join(', ')}" : ""}]"
								else
									name = "#{name}.#{var.__args[0]}#{var.__args.length > 1 ? "(#{var.__args[1..-1].map { |a| a.inspect }.join(', ')})" : ""}"
								end
							end
							unless ::KLib::ArgumentChecking.send(method, value, name, *args)
								errors << "Failed to validate: ArgumentChecking.#{method}(#{var.__name.to_s}, '#{var.__name.to_s}'#{args.map { |arg| ", #{arg.inspect}" }})"
							end
						rescue ::KLib::ArgumentChecking::ArgumentCheckError => e
							errors << e.message
						end
					end
				end
				if errors.any?
					::Kernel.raise_not_me ::KLib::ArgumentChecking::ArgumentCheckError.new("Failed to validate:\n#{errors.join("\n")}")
				end
			end
			
			def method_missing(sym, *args, &block)#, *args)
				::Kernel.raise ::KLib::ArgumentChecking::InvalidValidationError.new("No local variable defined: '#{sym}'") unless @binding.local_variable_defined?(sym)
				#::Kernel.raise ::KLib::ArgumentChecking::InvalidValidationError.new("No local variable defined: '#{sym}'") if args.any?
				added = CheckBuilder.new(sym, *args, &block)
				@variables << added
				added
			end
			
			class CheckBuilder < BasicObject
				
				def initialize(name, *args, &block)
					@name = name
					@args = args
					@checks = {}
					block.call(self) unless block.nil?
				end
				
				def method_missing(sym, *args)
					::KLib::ArgumentChecking.type_check(sym, 'sym', ::Symbol)
					::Kernel.raise ::NoMethodError.new("undefined method '#{sym}' for #{self.class}") unless (sym != :check && ::KLib::ArgumentChecking.methods.include?(sym))
					@checks[sym] = args
					self
				end
				
				def __name
					@name
				end
				
				def __args
					@args
				end
				
				def __checks
					@checks
				end
				
			end
			
		end
		
	end

end
