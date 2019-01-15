
Dir.chdir(File.dirname(__FILE__)) do
	require 'set'
	require './../output/Logger'
	require './../validation/StringCasing'
	require './GnuMatch'
	require './../general/ArrayUtils'
end

$cli_log = KLib::Logging::Logger.new(:log_tolerance => :debug)
# $cli_log.set_log_tolerance(:info, :rule => :args)

module KLib

	module CliMod
	
		module Regexes
			LONG_REGEX = /^--([a-z]+)(-([a-z]+|\d+))*$/
			SHORT_REGEX = /^-[A-Za-z]+$/
			NAME_REGEX = /^([a-z]+)(-([a-z]+|\d+))*$/
		end
		
		def method_spec(method_name, &block)
			@method_specs  = {} unless self.instance_variable_defined?(:@method_specs)
			@method_specs[method_name] = nil
			$cli_log.log(:debug, "method_spec_keys: #{@method_specs.keys.inspect}", :rule => :random)
		end
		
		def parse(args = ARGV)
			@valid_methods = find_valid_methods
			valid_method_names = @valid_methods.values.map { |met| met[:name] }.sort
			
			@valid_mods = find_valid_mods
			valid_mod_names = @valid_mods.values.map { |mod| mod[:name] }.sort
			
			$cli_log.log(:info, "valid_methods: #{valid_method_names.inspect}")
			$cli_log.log(:info, "valid_mods: #{valid_mod_names.inspect}")
			
			begin
				ArgumentChecking.type_check_each(args, 'args', Argument)
				mapped_args = args
			rescue ArgumentChecking::TypeCheckError
				ArgumentChecking.type_check_each(args, 'args', String)
				invalid_names = []
				mapped_args = args.map do |arg|
					begin
						Argument.new(arg)
					rescue Argument::InvalidParameterNameError => e
						invalid_names << e.name
						nil
					end
				end
				if invalid_names.any?
					$cli_log.log(:fatal, "Incorrectly formatted parameter names: #{invalid_names.map { |n| "'#{n}'" }.join(', ')}")
					help
				end
			end
			
			if mapped_args.length > 0
				arg = mapped_args[0]
				if (arg.type == :short && arg.value.include?('h')) || (arg.type == :long && arg.value == 'help')
					help
				elsif (arg.type == :short && arg.value.include?('H')) || (arg.type == :long && arg.value == 'help_extra')
					help_extra
				end
			end
			
			$cli_log.log(:debug, "--- Arguments ---", :rule => :args)
			$cli_log.indent + 1
			mapped_args.each { |arg| $cli_log.log(:debug, arg.to_s, :rule => :args) }
			$cli_log.indent - 1
			
			if mapped_args.length > 0
				if mapped_args[0].type == :arg && Regexes::NAME_REGEX.match?(mapped_args[0].value)
					name = mapped_args[0].value.tr('-', '_')
					
					GnuMatch.multi_match(name, valid_method_names)
					method_matches = $gnu_matches.map { |m| [m, :method] }
					GnuMatch.multi_match(name, valid_mod_names)
					mod_matches = $gnu_matches.map { |m| [m, :mod] }
					
					matches = method_matches + mod_matches
					
					$cli_log.log(:detailed, "MethodMatches: #{method_matches.map { |m| m[0] }.inspect}")
					$cli_log.log(:detailed, "ModMatches: #{mod_matches.map { |m| m[0] }.inspect}")
					$cli_log.log(:detailed, "Matches: #{matches.inspect}")
					
					if matches.length == 1
						match = matches[0]
						if match[1] == :method
							return call_handler(match[0].to_sym, mapped_args[1..-1])
						elsif match[1] == :mod
							return @valid_mods[match[0].to_sym][:mod].parse(mapped_args[1..-1])
						else
							raise 'What is going on...'
						end
					end
				end
			end
			
			if @valid_methods.key?(:main)
				return call_handler(:main, mapped_args)
			else
				$cli_log.log(:fatal, "Unable to find method in '#{self}' with arguments: [#{mapped_args.map { |arg| "'#{arg.original}'" }.join(' ')}]")
				help
			end
			
			raise 'How did you make it here...'
		end
		
		private
			
			def call_handler(method_name, args)
			
			end
			
			def find_valid_methods
				valid_methods = {}
				
				self.methods(false).each do |met|
					method = self.method(met)
					invalid = []
					rest = nil
					
					# Validation
					if method.parameters.length == 0
						$cli_log.log(:error, "Method '#{met}' will be ignored... No parameters is not allowed")
						next
					end
					
					method.parameters.each do |param|
						invalid << param unless %i{req rest}.include?(param[0])
						rest = param[1] if param[0] == :rest
					end
					if invalid.any?
						$cli_log.log(:error, "Method '#{met}' will be ignored... Invalid parameters: #{invalid.map { |i| "#{i[1]} (#{i[0]})" }.join(', ')}")
						next
					end
					
					if rest && method.parameters[-1][0] != :rest
						$cli_log.log(:error, "Method '#{met}' will be ignored... ':rest' parameter is not last")
						next
					end
					
					valid_name = StringCasing.matches?(met.to_s, :snake, :behavior => :boolean, :nums => true)
					unless valid_name
						$cli_log.log(:error, "Method '#{met}' will be ignored... does not match: #{StringCasing::REGEX[:snake][true].inspect}")
						next
					end
					
					valid_methods[met] = {
						:name => met.to_s,
						:method => method,
						:names => method.parameters.select { |p| p[0] == :req }.map { |p| p[1] },
						:rest => rest
					}
				end
				
				valid_methods
			end
		
			def find_valid_mods
				valid_mods = {}
				
				self.constants(false).each do |const|
					const_value = self.const_get(const)
					if const_value.is_a?(Module)
						if const_value.is_a?(CliMod)
							valid_name = StringCasing.matches?(const.to_s, :camel, :behavior => :boolean, :camel_start => :upcase, :nums => false)
							if valid_name
								const = const.to_s.to_snake.to_sym
								if @valid_methods.key?(const)
									$cli_log.log(:error, "Module '#{const_value}' will be ignored... matches method '#{const}'")
								else
									valid_mods[const] = {
										:name => const.to_s,
										:mod => const_value
									}
								end
							else
								$cli_log.log(:error, "Module '#{const_value}' will be ignored... does not match: #{StringCasing::REGEX[:camel][:upcase][false].inspect}")
							end
						else
							$cli_log.log(:warning, "Module '#{const_value}' will be ignored... does not extend 'KLib::CliMod'")
						end
					end
				end
				
				valid_mods
			end
			
			def help
				$cli_log.log(:info, "\nTODO: Help")
				exit(-1)
			end
			
			def help_extra
				$cli_log.log(:info, "\nTODO: HelpExtra")
				exit(-1)
			end
			
			def method_help
				$cli_log.log(:info, "\nTODO: MethodHelp")
				exit(-1)
			end
			
			def method_help_extra
				$cli_log.log(:info, "\nTODO: MethodHelpExtra")
				exit(-1)
			end
		
		class Argument
			
			attr_reader :value, :type, :original
			
			def initialize(string)
				ArgumentChecking.type_check(string, 'string', String)
				@original = string
				if string.start_with?('@')
					@type = :arg
					@value = string[1..-1]
				elsif string.start_with?('--')
					raise InvalidParameterNameError.new(string) unless CliMod::Regexes::LONG_REGEX.match?(string)
					@type = :long
					@value = string[2..-1].tr('-', '_')
				elsif string.start_with?('-')
					raise InvalidParameterNameError.new(string) unless CliMod::Regexes::SHORT_REGEX.match?(string)
					@type = :short
					@value = string[1..-1].chars
				else
					@type = :arg
					@value = string
				end
			end
			
			def to_s
				"Argument: { type => #{@type.inspect}, value => #{@value.inspect} }"
			end
		
			class InvalidParameterNameError < RuntimeError
				attr_reader :name
				def initialize(name)
					@name = name
					super("Invalid parameter name: '#{name}'")
				end
			end
			
		end
		
	end

end
