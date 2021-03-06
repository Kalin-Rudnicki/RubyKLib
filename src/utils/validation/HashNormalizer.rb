
Dir.chdir(File.dirname(__FILE__)) do
	require 'set'
	require './ArgumentChecking'
	require './../formatting/CaseConversion'
	require './../general/RaiseNotMe'
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
			:name_proc => proc { |name| "hash_args[#{name.inspect}]" }
		}.freeze
		
		class NormalizerManager < BasicObject
		
			def initialize(hash_args = {}, &block)
				::Kernel.raise ::ArgumentError.new("You must supply a block to this method") unless ::Kernel.block_given?
				::KLib::ArgumentChecking.check do |check|
					check.hash_args.type_check(::Hash)
					check.hash_args(:keys).enum_check_each(::KLib::HashNormalizer::DEFAULT_SETTINGS.keys)
				end
				settings = ::KLib::HashNormalizer::DEFAULT_SETTINGS.merge(hash_args)
				::KLib::ArgumentChecking.check do |check|
					check.settings(:[], :allowed_casing).enum_check(:snake, :camel, :both, :either)
					check.settings(:[], :allowed_types).enum_check(:str, :string, :sym, :symbol, :both, :either)
					check.settings(:[], :allow_extras).boolean_check
					check.settings(:[], :remove_found).boolean_check
					check.settings(:[], :keys_as).enum_check(:sym, :symbol, :str, :string)
					check.settings(:[], :name_proc).type_check(::Proc)
				end
				
				@args = []
				@settings = settings
				
				block.call(self)
			end
			
			def __normalize(target, source)
				::KLib::ArgumentChecking.check do |check|
					check.target.respond_to_check(:[]=, :delete, :each_pair)
					check.source.respond_to_check(:[], :keys, :key?)
					# TODO => ArgumentChecking on hash_args
				end
				
				finalized_args = @args.map { |arg| arg.__finalize(@settings) }
				# Ensuring that there aren't multiple keys pointing to different places
				all_mappings = ::Set.new
				multi_mapped_keys = ::Set.new
				
				finalized_args.each do |arg|
					similar_keys = all_mappings & arg.search_keys
					multi_mapped_keys |= similar_keys.to_a
					all_mappings |= arg.search_keys
				end
				raise_not_me DuplicateMappedKeyError.new(multi_mapped_keys.to_a) if multi_mapped_keys.any?
				
				# Create hashes for referencing arguments
				from_to = finalized_args.map { |arg| arg.search_keys.map { |key| [key, arg.destination] } }.flatten(1).to_h
				mapped_by = finalized_args.map { |arg| [arg, nil] }.to_h
				
				# Ensure that there are not keys being mapped to things in multiple places
				extra_keys = []
				source.keys.each do |key|
					found = false
					finalized_args.each do |arg|
						if arg.search_keys.include?(key)
							mapped_by[arg] = key
							found = true
							break
						end
					end
					extra_keys << key unless found
				end
				::Kernel.raise_not_me IllegalExtraKeysError.new(extra_keys) if extra_keys.any? && !@settings[:allow_extras]
				
				# Split up args into found and not-found
				found_args = mapped_by.select { |k, v| !v.nil? }
				non_found_args = mapped_by.select { |k, v| v.nil? }.keys
				non_found_partition = { :no_default => [], :required => [], :default_value => [], :default_from_key => [] }
				non_found_args.each { |arg| non_found_partition[arg.missing[:mode]] << arg }
				
				# Make sure that all required arguments have been supplied
				::Kernel.raise_not_me MissingRequiredArgsError.new(non_found_partition[:required]) if non_found_partition[:required].any?
				
				# Make sure that there are not default_from_key's pointing at keys that are not guaranteed to exist
				valid_default_keys = {}
				found_args.each_pair { |arg, from_key| valid_default_keys[arg.destination] = source[from_key] }
				non_found_partition[:default_value].each { |arg| valid_default_keys[arg.destination] = arg.missing[:value] }
				illegal_default_key_args = non_found_partition[:default_from_key].select { |arg| !valid_default_keys.keys.include?(from_to[arg.missing[:value]]) }
				::Kernel.raise_not_me NoSuchDefaultFromKeyError.new(illegal_default_key_args) if illegal_default_key_args.any?
				
				# Do argument checking and validation
				found_args.each_pair do |arg, from_key|
					::KLib::RaiseNotMe.ignore_me do
						arg.checks.__checks.each_pair do |method, value|
							::KLib::ArgumentChecking.send(method, source[from_key], @settings[:name_proc].call(from_key), *value)
						end
					end
					unless arg.validate.nil? || arg.validate[:validator].call(source[from_key])
						::KLib::RaiseNotMe.raise_not_me NormalizerError.new(arg.validate[:on_fail].is_a?(::Proc) ? arg.validate[:on_fail].call(source[from_key]) : arg.validate[:on_fail])
					end
				end
				non_found_partition[:default_value].each do |arg|
					::KLib::RaiseNotMe.ignore_me do
						arg.checks.__checks.each_pair do |method, value|
							::KLib::ArgumentChecking.send(method, arg.missing[:value], "missing { :mode=>:default_value, :value=>#{arg.destination.inspect} }", *value)
						end
					end
					unless arg.validate.nil? || arg.validate[:validator].call(arg.missing[:value])
						::KLib::RaiseNotMe.raise_not_me NormalizerError.new(arg.validate[:on_fail].is_a?(::Proc) ? arg.validate[:on_fail].call(arg.missing[:value]) : arg.validate[:on_fail])
					end
				end
				non_found_partition[:default_from_key].each do |arg|
					::KLib::RaiseNotMe.ignore_me do
						arg.checks.__checks.each_pair do |method, value|
							::KLib::ArgumentChecking.send(method, valid_default_keys[from_to[arg.missing[:value]]], "missing { :mode=>:default_from_key, :value=>#{arg.missing[:value].inspect} }", *value)
						end
					end
					unless arg.validate.nil? || arg.validate[:validator].call(valid_default_keys[from_to[arg.missing[:value]]])
						::KLib::RaiseNotMe.raise_not_me NormalizerError.new(arg.validate[:on_fail].is_a?(::Proc) ? arg.validate[:on_fail].call(valid_default_keys[from_to[arg.missing[:value]]]) : arg.validate[:on_fail])
					end
				end
				
				# Transfer data
				found_args.each_pair do |arg, from_key|
					value = source[from_key]
					target.delete(from_key) if @settings[:remove_found]
					unless arg.transform.nil?
						value = arg.transform.call(value)
					end
					unless arg.normalize == nil
						arg.normalize.__normalize(value, value)
					end
					target[arg.destination] = value
				end
				non_found_partition[:default_value].each do |arg|
					value = arg.missing[:value]
					unless arg.transform.nil?
						value = arg.transform.call(value)
					end
					unless arg.normalize == nil
						arg.normalize.__normalize(value, value)
					end
					target[arg.destination] = value
				end
				non_found_partition[:default_from_key].each do |arg|
					value = valid_default_keys[from_to[arg.missing[:value]]]
					unless arg.transform.nil?
						value = arg.transform.call(value)
					end
					unless arg.normalize == nil
						arg.normalize.__normalize(value, value)
					end
					target[arg.destination] = value
				end
				
				extra_keys.each do |key|
					value = source[key]
					target.delete(key)
					target[key] = value
				end
				
				nil
			end
			
			def method_missing(sym, *alternatives, &block)
				::Kernel::raise ::ArgumentError.new('Your values can not end in =') if sym.to_s[-1] == '='
				::KLib::ArgumentChecking.type_check_each(alternatives, "#{sym}.alternatives", ::String, ::Symbol)
				arg = ::KLib::HashNormalizer::NormalizerManager::Arg.new(sym, alternatives, &block)
				@args << arg
				arg
			end
			
			class Arg < BasicObject
				
				# TODO: default missing action [:no_default, :required, :nil]
				def initialize(destination, additional, &block)
					@destination = destination
					@additional = additional
					@missing = {
						:mode => :no_default,
						:value => nil
					}
					@checks = ::KLib::ArgumentChecking::CheckBuilderManager::CheckBuilder.new(@destination)
					@validate = nil
					@transform = nil
					@normalize = nil
					
					block.call(self) unless block.nil?
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
									::Kernel.raise "[#{defaults[:allowed_casing]}] is not a valid value for :allowed_casing"
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
									::Kernel.raise "[#{defaults[:allowed_casing]}] is not a valid value for :allowed_casing"
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
									::Kernel.raise "[#{defaults[:allowed_casing]}] is not a valid value for :allowed_casing"
							end
						else
							::Kernel.raise "[#{defaults[:allowed_types]}] is not a valid value for :allowed_types"
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
					FinalizedArg.new(dest, vals, @missing, @checks, @validate, @transform, @normalize)
				end
				
				# Defaults
				
				def no_default
					@missing[:mode] = :no_default
					@missing[:value] = nil
					self
				end
				
				def required
					@missing[:mode] = :required
					@missing[:value] = nil
					self
				end
				
				def default_value(value)
					@missing[:mode] = :default_value
					@missing[:value] = value
					self
				end
				
				def default_from_key(key)
					@missing[:mode] = :default_from_key
					@missing[:value] = key
					self
				end
				
				# Argument Checking
				
				def method_missing(sym, *args)
					begin
						@checks.__send__(sym, *args)
					rescue ::NoMethodError
						::Kernel.raise ::NoMethodError.new("undefined method '#{sym}' in #{::Kernel.instance_method(:class).bind(self).call}")
					end
					self
				end
				
				# Other
				
				def validate(on_fail, &block)
					::Kernel.raise ::ArgumentError.new("You must supply a block for validation") unless ::Kernel.block_given?
					::KLib::ArgumentChecking.type_check(on_fail, 'on_fail', ::String, ::Proc)
					@validate = {
						:validator => block,
						:on_fail => on_fail
					}
					self
				end
				
				def transform(&block)
					::Kernel.raise ::ArgumentError.new("You must supply a block for transformation") unless ::Kernel.block_given?
					@transform = block
					self
				end
				
				# Recursive :)
				def normalize(hash_args = {}, &block)
					self.type_check(::Hash)
					@normalize = ::KLib::HashNormalizer::NormalizerManager.new(hash_args, &block)
					self
				end
				
			end
			
			class FinalizedArg
				
				attr_reader :destination, :search_keys, :missing, :checks, :validate, :transform, :normalize
				
				def initialize(destination, search_keys, missing, checks, validate, transform, normalize)
					@destination = destination
					@search_keys = search_keys
					@missing = missing
					@checks = checks
					@validate = validate
					@transform = transform
					@normalize = normalize
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
			
			def normalize_to(target, source, hash_args = {}, &block)
				ArgumentChecking.type_check(hash_args, 'hash_args', Hash)
				manager = NormalizerManager.new(hash_args, &block)
				
				manager.__normalize(target, source)
				
				target
			end
			
			def normalize!(source, hash_args = {}, &block)
				normalize_to(source, source, hash_args, &block)
			end
			
			# Not sure what to name this
			def normalize(source, hash_args = {}, &block)
				normalize_to(source.dup, source, hash_args, &block)
			end
			
			private
				
				def strip_hash_args(args)
					ArgumentChecking.type_check(args, 'args', Array)
					[args, (args.length > 0 && args[-1].is_a?(Hash)) ? args.delete_at(-1) : {}]
				end
			
		end
		
		class NormalizerError < RuntimeError; end
		
		class DuplicateMappedKeyError < NormalizerError
			
			attr_reader :keys
			
			def initialize(keys)
				@keys = keys
				super("Found key#{keys.length > 1 ? 's' : ''} that occur#{keys.length > 1 ? '' : 's'} multiple times in mappings: #{keys.sort.inspect}")
			end
			
		end
		
		class IllegalExtraKeysError < NormalizerError
			
			attr_reader :illegal_keys
			
			def initialize(illegal_keys)
				@illegal_keys = illegal_keys
				super("Found illegal extra key#{illegal_keys.length > 1 ? 's' : ''}: #{illegal_keys.inspect}")
			end
			
		end
		
		class MissingRequiredArgsError < NormalizerError
			
			attr_reader :missing_args
			
			def initialize(missing_args)
				@missing_args = missing_args
				super("Could not find required arguments:#{missing_args.map { |arg| "\n    {#{arg.search_keys.inspect} => #{arg.destination.inspect}}" }.join(', ')}.")
			end
			
		end
		
		class NoSuchDefaultFromKeyError < NormalizerError
			
			attr_reader :illegal_missing_args
			
			def initialize(illegal_missing_args)
				@illegal_missing_args = illegal_missing_args
				super("Found arguments whose 'default_from_key' references keys which do not exist: #{illegal_missing_args.map { |arg| "{#{arg.missing[:value].inspect} => #{arg.destination.inspect}}" }.join(', ')}.")
			end
			
		end
	
	end

end
