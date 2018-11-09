
Dir.chdir(File.dirname(__FILE__)) do
	require './ArgumentChecking'
end

module KLib

	module HashNormalizer
		
		DEFAULT_SETTINGS = {
			:a => nil
		}
		
		class NormalizerManager < BasicObject
		
			def initialize
				@args = []
			end
			
			def __args
				@args
			end
			
			def method_missing(sym, *alternatives)
				raise ArgumentError.new('Your values can not end in =') if sym.to_s[-1] == '='
				ArgumentChecking.type_check_each(alternatives, 'alternatives', String, Symbol)
				arg = Arg.new(sym, args)
				@args << arg
				arg
			end
			
			class Arg
				
				def initialize(destination, additional)
					@destination = destination
					@additional = additional
				end
				
				# Defaults
				
				def no_default
				
				end
				
				def required
				
				end
				
				def default_value(value)
				
				end
				
				def default_from_key(key)
				
				end
				
				# Argument Checking
				
				def type_check(*valid_args)
				
				end
				
				def type_check_each(*valid_args)
				
				end
				
				def enum_check(*valid_args)
				
				end
				
				def enum_check_each(*valid_args)
				
				end
				
				def respond_to_check(*required_args)
				
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
					manager.__args.each { |arg| puts arg.inspect }
					
					nil
				end
			
		end
	
	end

end
