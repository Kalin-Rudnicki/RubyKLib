
Dir.chdir(File.dirname(__FILE__)) do
	require 'set'
	require '../../utils/validation/HashNormalizer'
	require '../../utils/parsing/GnuMatch'
	require '../../utils/general/ArrayUtils'
end

module KLib
	
	
	
	module CliMod
		
		module CliRegex
			
			NAME_REGEX = /^[a-z]+(-[a-z]+)*$/
			LONG_PARAM_REGEX = /^-(-[a-z]+)+$/
			SHORT_PARAM_REGEX = /^-[A-Za-z]+$/
		
		end
		
		def parse(args = ARGV)
			ArgumentChecking.type_check_each(args, 'args', String)
			
			if args.length == 1 && (args.first == '--help' || args.first == '-h')
				$stdout.puts(help)
				exit(0)
			end
			
			# === Settings ===
			
			method_warnings = @method_warnings.nil? ? true : @method_warnings
			mod_warnings = @mod_warnings.nil? ? true : @mod_warnings
			help_messages = @help_messages.nil? ? true : @help_messages
			
			# === Validation ===
			
			@warning_count = 0
			@valid_methods = find_valid_methods(method_warnings)
			@valid_mods = find_valid_mods(mod_warnings)
			
			@valid_methods.each_key do |method_name|
				@valid_mods.each_key do |mod_name|
					raise EquallyNameMethodAndModError.new(method_name) if method_name == mod_name
				end
			end
			
			if help_messages && @warning_count > 0
				$stderr.puts("[INFO]:    To toggle warnings... #{self}.warnings(:methods => true/false, :mods => true/false)")
			end
			
			if args.length > 0 && CliRegex::NAME_REGEX.match?(args.first)
				given = args.first.to_sym
				remaining_args = args[1..-1]
				if @valid_methods.key?(given)
					return call_handler(given, remaining_args)
				elsif @valid_mods.key?(given)
					return @valid_mods[given].parse(remaining_args)
				else
					$stderr.puts("[FATAL]:   No method or mod '#{given}'")
					$stderr.puts(help)
					exit(1)
				end
			else
				if @valid_methods.key?(:main)
					return call_handler(:main, args)
				elsif @default_method.nil?
					$stderr.puts("[FATAL]:   No method specified, and no default method is defined.")
					if help_messages
						$stderr.puts("[INFO]:    To set a default method... #{self}.default_method(:method_name) or define 'main'")
					end
					$stderr.puts(help)
					exit(1)
				elsif @valid_methods.key?(@default_method)
					return call_handler(@default_method, args)
				else
					$stderr.puts("[FATAL]:   No such method named '#{method_name}'")
					$stderr.puts(help)
					exit(1)
				end
			end
		end
		
		def find_valid_methods(method_warnings)
			valid_methods = {}
			
			mets = self.methods(false).map { |met| self.method(met) }
			mets.each do |met|
				
				adjusted_name = met.name.to_s.gsub('_', '-')
				unless CliRegex::NAME_REGEX.match?(adjusted_name)
					if method_warnings
						@warning_count += 1
						$stderr.puts("[WARNING]: method '#{self}:#{met.name}' will be ignored (method names must conform to #{CliRegex::NAME_REGEX.inspect}, with '-' as '_', found: '#{adjusted_name}')")
						next
					end
				end
				
				param_types = met.parameters.map { |p| p[0] }
				param_names = met.parameters.map { |p| p[1] }
				
				if param_types.length == 0
					if method_warnings
						@warning_count += 1
						$stderr.puts("[WARNING]: method '#{self}:#{met.name}' will be ignored (methods must have parameters)")
					end
					next
				end
				
				rest = nil
				if param_types.last == :rest
					rest = param_names.last
					param_types = param_types[0..-2]
					param_names = param_names[0..-2]
				end
				
				invalid = []
				param_types.length.times do |idx|
					type = param_types[idx]
					name = param_names[idx]
					
					if name == :help
						if method_warnings
							@warning_count += 1
							$stderr.puts("[WARNING]: method '#{met.name}' will be ignored (you can not name a parameter 'help')")
							invalid = true
						end
					end
					
					invalid << [type, name] unless type == :req
				end
				if invalid == true || invalid.any?
					if method_warnings
						@warning_count += 1
						$stderr.puts("[WARNING]: method '#{self}:#{met.name}' will be ignored (all parameters must be required, with an optional *args at the end)")
						$stderr.puts("           { #{invalid.map { |inv| "#{inv[1]} => #{inv[0].inspect}" }.join(', ')} }")
					end
					next
				end
				
				valid_methods[adjusted_name.to_sym] = { :names => param_names, :rest => rest, :method => met }
			
			end
			
			valid_methods
		end
		
		def find_valid_mods(mod_warnings)
			valid_mods = {}
			
			self.constants(false).each do |const_name|
				
				adjusted_name = const_name.to_s.to_snake.gsub('_', '-')
				unless CliRegex::NAME_REGEX.match?(adjusted_name)
					if mod_warnings
						@warning_count += 1
						$stderr.puts("[WARNING]: method '#{self}:#{const_name}' will be ignored (mod names must conform to #{CliRegex::NAME_REGEX.inspect}, as converted to snake_case, found: '#{adjusted_name}')")
						next
					end
				end
				
				const = self.const_get(const_name)
				if const.is_a?(Module)
					if const.is_a?(CliMod)
						valid_mods[adjusted_name.to_sym] = const
					else
						if mod_warnings
							@warning_count += 1
							$stderr.puts("[WARNING]: child module '#{const.inspect}' does not extend '#{CliMod.inspect}'")
						end
					end
				end
			end
			
			valid_mods
		end
		
		def warnings(hash_args = {})
			hash_args = HashNormalizer.normalize(hash_args) do |norm|
				norm.methods.no_default.type_check(Boolean)
				norm.mods.no_default.type_check(Boolean)
			end
			@method_warnings = hash_args[:methods] if hash_args.key?(:methods)
			@mod_warnings = hash_args[:mods] if hash_args.key?(:mods)
			
			nil
		end
		
		def default_method(method_name)
			ArgumentChecking.type_check(method_name, 'method_name', Symbol)
			@default_method = method_name
			
			nil
		end
		
		def method_spec(method_name, &block)
			raise ArgumentError.new("you must supply a block when creating a method spec") unless block_given?
			ArgumentChecking.type_check(method_name, 'method_name', Symbol)
			
			@method_specs ||= {}
			@method_specs[method_name] = MethodSpec.new(method_name, &block)
			nil
		end
		
		def call_handler(method_name, original_args)
			ArgumentChecking.type_check(method_name, 'method_name', Symbol)
			ArgumentChecking.type_check_each(original_args, 'original_args', String)
			
			args = original_args.map { |arg| Argument.new(arg) }
			method_info = @valid_methods[method_name]
			@method_specs ||= {}
			method_spec = @method_specs.key?(method_name) ? @method_specs[method_name] : MethodSpec.new(method_name)
			
			parameters = method_spec.__params.values
			
			non_existent_parameters = parameters.map { |p| p.__param_name } - method_info[:names]
			raise NonExistentParameterDefinitionError.new(non_existent_parameters) if non_existent_parameters.any?
			
			parameters += (method_info[:names] - parameters.map { |p| p.__param_name }).map { |p| MethodSpec::ParamSpec.new(p) }
			
			booleans, non_booleans = parameters.partition do |p|
				p.__arg_type == :boolean || (p.__arg_type == nil && %w{is isnt do dont yes no}.any? { |start| p.__param_name.to_s.start_with?("#{start}_") })
			end
			booleans.each do |bool|
				bool.arg_type(:boolean)
				if bool.__boolean_mode.nil?
					if bool.__param_name.to_s.start_with?('isnt_')
						bool.boolean_mode(:_isnt)
					elsif bool.__param_name.to_s.start_with?('is_')
						bool.boolean_mode(:is_isnt)
					elsif bool.__param_name.to_s.start_with?('dont_')
						bool.boolean_mode(:_dont)
					elsif bool.__param_name.to_s.start_with?('do_')
						bool.boolean_mode(:do_dont)
					elsif bool.__param_name.to_s.start_with?('yes_')
						bool.boolean_mode(:yes_no)
					else
						bool.boolean_mode(:_no)
					end
				end
				if bool.__boolean_flip.nil?
					bool.boolean_flip(%w{isnt dont no}.any? { |start| bool.__param_name.to_s.start_with?("#{start}_") })
				end
			end
			non_booleans.each { |p| p.arg_type(:string) if p.__arg_type.nil? }
			
			mapped_params = parameters.map do |param|
				if param.__arg_type == :boolean
					res = case param.__boolean_mode
						when :is_isnt
							if param.__param_name.to_s.start_with?('isnt_')
								base = param.__param_name.to_s[5..-1]
							elsif param.__param_name.to_s.start_with?('is_')
								base = param.__param_name.to_s[3..-1]
							else
								base = param.__param_name.to_s
							end
							[
								[:"is_#{base}", { :param => param, :bool => !param.__boolean_flip }],
								[:"isnt_#{base}", { :param => param, :bool => param.__boolean_flip }]
							]
						when :_isnt
							if param.__param_name.to_s.start_with?('isnt_')
								base = param.__param_name.to_s[5..-1]
							elsif param.__param_name.to_s.start_with?('is_')
								base = param.__param_name.to_s[3..-1]
							else
								base = param.__param_name.to_s
							end
							[
								[:"#{base}", { :param => param, :bool => !param.__boolean_flip }],
								[:"isnt_#{base}", { :param => param, :bool => param.__boolean_flip }]
							]
						when :do_dont
							if param.__param_name.to_s.start_with?('dont_')
								base = param.__param_name.to_s[5..-1]
							elsif param.__param_name.to_s.start_with?('do_')
								base = param.__param_name.to_s[3..-1]
							else
								base = param.__param_name.to_s
							end
							[
								[:"do_#{base}", { :param => param, :bool => !param.__boolean_flip }],
								[:"dont_#{base}", { :param => param, :bool => param.__boolean_flip }]
							]
						when :_dont
							if param.__param_name.to_s.start_with?('dont_')
								base = param.__param_name.to_s[5..-1]
							elsif param.__param_name.to_s.start_with?('do_')
								base = param.__param_name.to_s[3..-1]
							else
								base = param.__param_name.to_s
							end
							[
								[:"#{base}", { :param => param, :bool => !param.__boolean_flip }],
								[:"dont_#{base}", { :param => param, :bool => param.__boolean_flip }]
							]
						when :yes_no
							if param.__param_name.to_s.start_with?('no_')
								base = param.__param_name.to_s[3..-1]
							elsif param.__param_name.to_s.start_with?('yes_')
								base = param.__param_name.to_s[4..-1]
							else
								base = param.__param_name.to_s
							end
							[
								[:"yes_#{base}", { :param => param, :bool => !param.__boolean_flip }],
								[:"no_#{base}", { :param => param, :bool => param.__boolean_flip }]
							]
						when :_no
							if param.__param_name.to_s.start_with?('no_')
								base = param.__param_name.to_s[3..-1]
							elsif param.__param_name.to_s.start_with?('yes_')
								base = param.__param_name.to_s[4..-1]
							else
								base = param.__param_name.to_s
							end
							[
								[:"#{base}", { :param => param, :bool => !param.__boolean_flip }],
								[:"no_#{base}", { :param => param, :bool => param.__boolean_flip }]
							]
						else
							raise 'what is going on...'
					end
					param.__base_name = base
					res
				else
					[[param.__param_name, { :param => param, :bool => nil }]]
				end
			end.flatten(1)
			
			duplicate_param_mappings = ([:help] + mapped_params.map { |p| p[0] }).duplicates
			
			defined_short_names = parameters.map { |p| p.__short_name }.select { |p| !p.nil? }
			duplicate_short_names = ([:h] + defined_short_names).duplicates
			
			raise DuplicateParameterDefinitionError.new(duplicate_param_mappings + duplicate_short_names) if (duplicate_param_mappings + duplicate_short_names).any?
			
			used_short_names = [:h] + defined_short_names
			
			by_base_name_start = Hash.new { |h, k| h[k] = [] }
			parameters.select { |p| p.__short_name.nil? }.each { |p| by_base_name_start[p.__base_name[0].downcase] << p }
			
			by_base_name_start.each_pair do |start, using_start|
				([start.downcase, start.upcase] - used_short_names).each do |assign|
					if using_start.any?
						using_start.shift.short_name(assign.to_sym)
					end
				end
			end
			
			mapped_params = mapped_params.to_h
			mapped_short_names = parameters.select { |p| !p.__short_name.nil? }.map { |p| [p.__short_name, p] }.to_h
			
			puts("--- long ---")
			mapped_params.each_pair { |k, v| puts("#{k.inspect} => #{v.inspect}") }
			puts("--- short ---")
			mapped_short_names.each_pair { |k, v| puts("#{k.inspect} => #{v.inspect}") }
			
			nil
		end
		
		def help
			"TO-DO: Help"
		end
		
		def method_help(method_name)
			ArgumentChecking.type_check(method_name, 'method_name', Symbol)
			"TO-DO: MethodHelp => #{method_name.inspect}"
		end
		
		class Argument
			
			attr_reader :original, :value, :type
			
			def initialize(value)
				ArgumentChecking.type_check(value, 'value', String)
				@original = value
				if value.start_with?('@-')
					@value = value[1..-1]
					@type = :arg
				elsif CliMod::CliRegex::SHORT_PARAM_REGEX.match?(value)
					@value = value[1..-1].chars.map { |c| c.to_sym }
					@type = :short_key
				elsif CliMod::CliRegex::LONG_PARAM_REGEX.match?(value)
					@value = value[2..-1].gsub('-', '_').to_sym
					@type = :long_key
				else
					@value = value
					@type = :arg
				end
				
				nil
			end
			
			def inspect
				"{Argument} { value: <#{@value.inspect}>, type: <#{@type.inspect}> }"
			end
		
		end
		
		
		class EquallyNameMethodAndModError < RuntimeError
			attr_reader :given_name
			def initialize(given_name)
				@given_name = given_name
				super("Found method and mod with matching name: '#{given_name}'")
			end
		end
		
		class DuplicateParameterDefinitionError < RuntimeError
			attr_reader :parameters
			def initialize(parameters)
				@parameters = parameters
				super("Found duplicate parameter definitions: #{parameters.inspect}")
			end
		end
		
		class NonExistentParameterDefinitionError < RuntimeError
			attr_reader :parameters
			def initialize(parameters)
				@parameters = parameters
				super("Found defintions for parameters that dont exist: #{parameters.inspect}")
			end
		end
		
		
		class MethodSpec < BasicObject
			
			def initialize(method_name, &block)
				::KLib::ArgumentChecking.type_check(method_name, 'method_name', ::Symbol)
				
				@method_name = method_name
				@params = {}
				
				@locked = false
				block.call(self) if ::Kernel.block_given?
				@locked = true
				nil
			end
			
			def param(param_name)
				::Kernel.raise 'MethodSpec is locked...' if @locked
				::KLib::ArgumentChecking.type_check(param_name, 'param_name', ::Symbol)
				
				@params[param_name] = ParamSpec.new(param_name)
			end
			
			def __method_name
				@method_name
			end
			
			def __params
				@params
			end
			
			class ParamSpec < BasicObject
				
				def initialize(param_name)
					::KLib::ArgumentChecking.type_check(param_name, 'param_name', ::Symbol)
					
					@param_name = param_name
					@short_name = nil
					@base_name = param_name.to_s
					
					@min_args = 1
					@max_args = 1
					
					@arg_type = nil
					
					@boolean_mode = nil
					@boolean_flip = nil
					
					@on_missing = :required
					@on_zero = nil
					
					@explain = nil
					
					@checks = {}
				end
				
				
				def short_name(short_name)
					::KLib::ArgumentChecking.type_check(short_name, 'short_name', ::Symbol)
					::Kernel.raise ArgumentError.new('short_name must be a single character') unless /^[A-Za-z]$/.match?(short_name.to_s)
					
					@short_name = short_name
					self
				end
				
				def accepts(min_args, max_args)
					::KLib::ArgumentChecking.type_check(min_args, 'min_args', ::Integer)
					::KLib::ArgumentChecking.type_check(max_args, 'max_args', ::Integer, ::NilClass)
					::Kernel.raise ::ArgumentError.new("min_args must be >= 0") if min_args < 0
					::Kernel.raise ::ArgumentError.new("max_args must be nil or >= 0") if !max_args.nil? && max_args < 0
					::Kernel.raise ::ArgumentError.new("min_args must be >= max_args") if !max_args.nil? && min_args > max_args
					
					@min_args = min_args
					@max_args = max_args
					self
				end
				
				def boolean_mode(mode)
					::KLib::ArgumentChecking.enum_check(mode, 'mode', :is_isnt, :_isnt, :do_dont, :_dont, :yes_no, :_no)
					
					@boolean_mode = mode
					arg_type(:boolean)
				end
				
				def boolean_flip(value)
					::KLib::ArgumentChecking.boolean_check(value, 'value')
					
					@boolean_flip = value
					arg_type(:boolean)
				end
				
				def arg_type(type)
					::KLib::ArgumentChecking.enum_check(type, 'type', :string, :boolean, :integer, :float)
					
					accepts(0, 0) if type == :boolean
					@arg_type = type
					self
				end
				
				def explain(*messages)
					::KLib::ArgumentChecking.type_check_each(messages, 'messages', ::String)
					
					@explain = messages
					self
				end
				
				def __param_name
					@param_name
				end
				
				def __short_name
					@short_name
				end
				
				def __base_name= (base)
					@base_name = base
				end
				
				def __base_name
					@base_name
				end
				
				def __min_args
					@min_args
				end
				
				def __max_args
					@max_args
				end
				
				def __boolean_mode
					@boolean_mode
				end
				
				def __boolean_flip
					@boolean_flip
				end
				
				def __arg_type
					@arg_type
				end
				
				def __on_missing
					nil
				end
				
				def __on_zero
					nil
				end
				
				def __messages
					@explain
				end
				
				def inspect
					"{ParamSpec} { param_name: [#{@param_name.inspect}], short_name: [#{@short_name.inspect}], boolean_mode: [#{@boolean_mode.inspect}], boolean_flip: [#{@boolean_flip.inspect}], min_args: [#{@min_args.inspect}], max_args: [#{@max_args.inspect}], arg_type: [#{@arg_type.inspect}], default: [#{@default.inspect}], values: [#{@values.inspect}] }"
				end
				alias :to_s :inspect
			
			end
		
		end
		
	end
	
end

module TestMod
	extend KLib::CliMod
	
	module Compile
		extend KLib::CliMod
		
		def self.new(database_name)
			puts(database_name.inspect)
		end
		
	end
	
	method_spec(:main) do |s|
		s.param(:is_fun).short_name(:i)
	end
	
	def self.main(is_fun, dont_print, isnt_cool, puts, printing)
	end
	
end

$stderr = $stdout
TestMod.parse()
