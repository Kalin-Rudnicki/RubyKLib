
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
			parameters += (method_info[:names] - parameters.map { |p| p.__param_name }).map { |p| MethodSpec::ParamSpec.new(p) }
			parameters.each { |p| puts p.inspect }
			
			booleans = parameters.select { |p| p.__arg_type == :boolean }
			
			puts parameters.map { |p| p.__param_name }.inspect
			puts booleans.map { |p| p.__param_name }.inspect
			
			names = parameters.map { |p| p.__arg_type == :boolean ? [[p.__param_name, p], [:"no_#{p.__param_name}", p]] : [[p.__param_name, p]] }.flatten(1)
			duplicate_long_names = names.map { |p| p[0] }.duplicates
			
			short_names = parameters.map { |p| [p.__short_name, p] }.select { |s| !s[0].nil? }
			puts short_names.map { |p| p[0] }.inspect
			
			raise DuplicateParameterDefinitionError.new(duplicate_long_names) if duplicate_long_names.any?
			
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
			
			def initialize(parameters)
				@parameters = parameters
				super("Found duplicate parameter definitions: #{parameters.inspect}")
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
					
					@min_args = 1
					@max_args = 1
					
					@arg_type = :string
					
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
				
				def arg_type(type)
					::KLib::ArgumentChecking.enum_check(type, 'type', :string, :boolean, :integer, :float)
					
					@arg_type = type
				end
				
				def alias
					raise 'TO-DO'
				end
				
				def explain(*messages)
					::KLib::ArgumentChecking.type_check_each(messages, 'messages', ::String)
					@explain = messages
				end
				
				def __param_name
					@param_name
				end
				
				def __short_name
					@short_name
				end
				
				def __min_args
					@min_args
				end
				
				def __max_args
					@max_args
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
				
				def inspect
					"{ParamSpec} { param_name: [#{@param_name.inspect}], short_name: [#{@short_name.inspect}], min_args: [#{@min_args.inspect}], max_args: [#{@max_args.inspect}], arg_type: [#{@arg_type.inspect}], default: [#{@default.inspect}], values: [#{@values.inspect}] }"
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
		s.param(:last_name)
		s.param(:first_name).accepts(2, 3).short_name(:a)
		s.param(:is_cool).arg_type(:boolean)
	end
	
	def self.main(first_name, last_name, age, is_cool)
		puts("I have been called: #{[first_name, last_name, age].inspect}")
	end
	
end

$stderr = $stdout
TestMod.parse(%w{--f Morena --l Iriart --a 19})
