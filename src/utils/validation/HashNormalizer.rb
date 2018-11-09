
Dir.chdir(File.dirname(__FILE__)) do
	require './ArgumentChecking'
	require './../formatting/StringCasing'
	require './../version_compat/BasicObject'
end

module KLib

	module HashNormalizer
		
		DEFAULT_SETTINGS = {
			:allowed_casing => :snake, #as_is ?
			:allowed_types => :both, #as_is ?
			:allow_extras => false,
			:remove_found => true,
			:keys_as => :symbol,
			:checking => :post_default,
			:name => proc { |name| "hash_args[#{name.inspect}]" }
		}.freeze
		
		class NormalizerManager < BasicObject
		
			def initialize
				@args = []
			end
			
			def __args(defaults)
				@args.map { |arg| arg.__finalize(defaults) }
			end
			
			def method_missing(sym, *alternatives)
				::Kernel::puts("missing: #{sym}(#{alternatives.join(' ')})")
				::Kernel::raise ::ArgumentError.new('Your values can not end in =') if sym.to_s[-1] == '='
				::KLib::ArgumentChecking.type_check_each(alternatives, 'alternatives', ::String, ::Symbol)
				arg = ::KLib::HashNormalizer::NormalizerManager::Arg.new(sym, alternatives)
				@args << arg
				arg
			end
			
			class Arg < BasicObject
				
				def initialize(destination, additional)
					@destination = destination
					@additional = additional
					@settings = {
						:missing => {
							:mode => :no_default,
							:value => nil
						},
						:checks => {}
					}
				end
				
				def __finalize(defaults)
					vals = [@destination, *@additional]
					case defaults[:allowed_types]
						when :string, :str
							case defaults[:allowed_casing]
								when :snake
									vals.map! { |val| [val.to_s.to_snake] }
								when :camel
									vals.map! { |val| [val.to_s.to_camel] }
								when :both, :either
									vals.map! { |val| [val.to_s.to_snake, val.to_s.to_camel] }
								else
									raise "[#{defaults[:allowed_casing]}] is not a valid value for :allowed_casing"
							end
						when :symbol, :sym
							case defaults[:allowed_casing]
								when :snake
									vals.map! { |val| [val.to_s.to_snake.to_sym] }
								when :camel
									vals.map! { |val| [val.to_s.to_camel.to_sym] }
								when :both, :either
									vals.map! { |val| [val.to_s.to_snake.to_sym, val.to_s.to_camel.to_sym] }
								else
									raise "[#{defaults[:allowed_casing]}] is not a valid value for :allowed_casing"
							end
						when :both, :either
							case defaults[:allowed_casing]
								when :snake
									vals.map! { |val| [val.to_s.to_snake.to_sym, val.to_s.to_snake] }
								when :camel
									vals.map! { |val| [val.to_s.to_camel.to_sym, val.to_s.to_camel] }
								when :both, :either
									vals.map! { |val| [val.to_s.to_snake.to_sym, val.to_s.to_camel.to_sym, val.to_s.to_snake, val.to_s.to_camel] }
								else
									raise "[#{defaults[:allowed_casing]}] is not a valid value for :allowed_casing"
							end
						else
							raise "[#{defaults[:allowed_types]}] is not a valid value for :allowed_types"
					end
					vals.flatten!(1).uniq!
					case defaults[:keys_as]
						when :symbol, :sym
							dest = @destination.to_sym
						when :string, :str
							dest = @destination.to_s
						else
							raise "[#{defaults[:keys_as]}] is not a valid value for :keys_as"
					end
					FinalizedArg.new(dest, vals, @settings[:missing], @settings[:checks])
				end
				
				# Defaults
				
				def no_default
					@settings[:missing][:mode] = :no_default
					@settings[:missing][:value] = nil
				end
				
				def required
					@settings[:missing][:mode] = :required
					@settings[:missing][:value] = nil
				end
				
				def default_value(value)
					@settings[:missing][:mode] = :default_value
					@settings[:missing][:value] = value
				end
				
				def default_from_key(key)
					@settings[:missing][:mode] = :default_from_key
					@settings[:missing][:value] = key
				end
				
				# Argument Checking
				
				def type_check(*valid_args)
					@settings[:checks][:type_check] = valid_args
				end
				
				def type_check_each(*valid_args)
					@settings[:checks][:type_check_each] = valid_args
				end
				
				def enum_check(*valid_args)
					@settings[:checks][:enum_check] = valid_args
				end
				
				def enum_check_each(*valid_args)
					@settings[:checks][:enum_check_each] = valid_args
				end
				
				def respond_to_check(*required_args)
					@settings[:checks][:respond_to_check] = required_args
				end
				
			end
			
			class FinalizedArg
				
				attr_reader :destination, :search_keys, :missing, :checks
				
				def initialize(destination, search_keys, missing, checks)
					@destination = destination
					@search_keys = search_keys
					@missing = missing
					@checks = checks
				end
				
			end
		
		end
		
		class << self
			
			def hash_args_strip!(args)
				strip_hash_args(args)[1]
			end
			
			def hash_args_strip(args)
				strip_hash_args(args.dup)
			end
			
			def normalize(target, source, hash_args = {}, &block)
				ArgumentChecking.type_check(hash_args, 'hash_args', Hash)
				settings = DEFAULT_SETTINGS.merge(hash_args)
				extras = settings.keys - DEFAULT_SETTINGS.keys
				raise ArgumentError.new("Extra keys are not allowed in settings, found extra: #{extras.inspect}") if extras.any?
				hash_normalize(target, source, settings, &block)
			end
			
			def normalize!(source, hash_args = {}, &block)
				normalize(source, source, hash_args, &block)
			end
			
			private
				
				def strip_hash_args(args)
					ArgumentChecking.type_check(args, 'args', Array)
					[args, (args.length > 0 && args[-1].is_a?(Hash)) ? args.delete_at(-1) : {}]
				end
				
				def hash_normalize(target, source, hash_args, &block)
					raise ArgumentError.new("You must supply a block in order to normalize.") unless block_given?
					ArgumentChecking.type_check(hash_args, 'hash_args', Hash)
					ArgumentChecking.enum_check_each(hash_args.keys, 'hash_args.keys', DEFAULT_SETTINGS.keys)
					ArgumentChecking.respond_to_check(target, 'target', :[]=, :delete)
					ArgumentChecking.respond_to_check(source, 'source', :[], :keys, :key?)
					puts hash_args.inspect
					
					manager = NormalizerManager.new
					block.call(manager)
					puts("=== args ===")
					manager.__args(hash_args).each { |arg| puts arg.inspect }
					
					nil
				end
			
		end
	
	end

end
