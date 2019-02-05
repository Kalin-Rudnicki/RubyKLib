
Dir.chdir(File.dirname(__FILE__)) do
	require 'set'
	require './../output/Logger'
	require './../validation/StringCasing'
	require './GnuMatch'
	require './../general/ArrayUtils'
end

$cli_log = KLib::Logger.new(:log_tolerance => :debug)
# $cli_log.set_log_tolerance(:info, :rule => :args)

module KLib

	module CliMod
	
		module Regexes
			LONG_REGEX = /^--([a-z]+)(-([a-z]+|\d+))*$/
			SHORT_REGEX = /^-[A-Za-z]+$/
			NAME_REGEX = /^([a-z]+)(-([a-z]+|\d+))*$/
		end
		
		def method_spec(method_name, &block)
			@method_specs = {} unless self.instance_variable_defined?(:@method_specs)
			@method_specs[method_name] = MethodSpec.new(method_name, &block)
		end
		
		def parse(args = ARGV)
			
			__build
			valid_method_names = @valid_methods.values.map { |met| met[:name] }.sort
			valid_mod_names = @valid_mods.values.map { |mod| mod[:name] }.sort
			
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
					help(1)
				end
			end
			
			if mapped_args.length > 0
				arg = mapped_args[0]
				if (arg.type == :short && arg.value.include?('h')) || (arg.type == :long && arg.value == 'help')
					help(0)
				elsif (arg.type == :short && arg.value.include?('H')) || (arg.type == :long && arg.value == 'help_extra')
					help_extra(0)
				end
			end
			
			if mapped_args.length > 0
				if mapped_args[0].type == :arg && Regexes::NAME_REGEX.match?(mapped_args[0].value)
					name = mapped_args[0].value.tr('-', '_')
					
					GnuMatch.multi_match(name, valid_method_names)
					method_matches = $gnu_matches.map { |m| [m, :method] }
					GnuMatch.multi_match(name, valid_mod_names)
					mod_matches = $gnu_matches.map { |m| [m, :mod] }
					
					matches = method_matches + mod_matches
					
					# TODO: Ambiguous warning
					
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
			
			if mapped_args.length > 0 && mapped_args[0].type == :arg && mapped_args.any? { |a| a.type != :arg }
				$cli_log.log(:fatal, "Could not find method or mod '#{mapped_args[0].value}'")
				help(1)
			else
				if @valid_methods.key?(:main)
					return call_handler(:main, mapped_args)
				else
					$cli_log.log(:fatal, "Unable to find method in '#{self}' with arguments: [#{mapped_args.map { |arg| "'#{arg.original}'" }.join(' ')}]")
					help(1)
				end
			end
			
			raise 'How did you make it here...'
		end
		
		private
			
			def call_handler(method_name, args)
				ArgumentChecking.type_check(method_name, 'method_name', Symbol)
				ArgumentChecking.type_check_each(args, 'args', Argument)
				
				method_spec = @method_specs[method_name]
				
				args.each do |arg|
					if arg.type == :short
						if arg.value.include?('H')
							method_help_extra(method_spec, 0)
						elsif arg.value.include?('h')
							method_help(method_spec, 0)
						end
					elsif arg.type == :long
						if arg.value == 'help_extra'
							method_help_extra(method_spec, 0)
						elsif arg.value == 'help'
							method_help(method_spec, 0)
						end
					end
				end
				
				begin
					return method_spec.send(:parse, args)
				rescue MethodSpec::ParseError
					method_help(method_spec, 1)
				end
			end
			
			def find_valid_methods
				valid_methods = {}
				
				self.methods(false).each do |met|
					method = self.method(met)
					invalid = []
					rest = nil
					
					# Validation
					
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
						:names => method.parameters.select { |p| p[0] == :req }.map { |p| p[1].to_s },
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
			
			def __build
				return if @built
				@valid_methods = find_valid_methods
				@valid_mods = find_valid_mods
				@method_specs = {} unless self.instance_variable_defined?(:@method_specs)
				
				(@valid_methods.keys - @method_specs.keys).each do |name|
					@method_specs[name] = MethodSpec.new(name) {}
				end
				@method_specs.each_pair do |name, spec|
					raise "'#{name}' is not a valid method" unless @valid_methods.key?(name)
					info = @valid_methods[name]
					spec.send(:build, info)
					$name = name
					$spec = spec
					class << self
						
						name = $name
						spec = $spec
						self.alias_method(:"__original_#{name}", name)
						
						normalizer = spec.send(:__normalizer)
						self.define_method(name) do |hash_args = {}|
							target = {}
							normalizer.__normalize(target, hash_args)
							
							self.method(:"__original_#{name}").call(*spec.method_info[:names].map { |n| target[n.to_sym] }, *(spec.method_info[:rest].nil? ? [] : target[spec.method_info[:rest]]))
						end
					
					end
					info[:method] = self.method(name)
				end
				
				@built = true
				nil
			end
			
			def help(exit_code)
				ArgumentChecking.enum_check(exit_code, 'exit_code', 0, 1, nil)
				str = "\n--- Help ---\nUsage: #{([File.basename($0, File.extname($0))] + self.inspect.split('::')[1..-1].map { |s| s.to_snake.tr('_', '-') } + ['[(method/mod)-name]', '[OPTIONS]']).join(' ')}"
				
				str << "\n\n    [#{'Valid Methods'.cyan}]"
				@valid_methods.each_key { |k| str << "\n        #{k.to_s.tr('_', '-')}" }
				
				str << "\n\n    [#{'Valid Mods'.cyan}]"
				@valid_mods.each_key { |k| str << "\n        #{k.to_s.tr('_', '-')}" }
				
				str << "\n"
				
				if @valid_methods.key?(:main)
					method_info = @valid_methods[:main]
					@method_specs ||= {}
					unless @method_specs.key?(:main)
						@method_specs[:main] = MethodSpec.new(:main) {}
					end
					method_spec = @method_specs[:main]
					method_spec.send(:build, method_info)
					
					str << method_help(method_spec, nil)
				end
				
				if exit_code.nil?
					str
				else
					$cli_log.log(:info, str)
					exit(exit_code)
				end
			end
			
			def help_extra(exit_code)
				$cli_log.log(:info, "HelpExtra does nothing additional at this time")
				help(exit_code)
			end
			
			def method_help(method_spec, exit_code)
				ArgumentChecking.enum_check(exit_code, 'exit_code', 0, 1, nil)
				
				str = "\n--- MethodHelp ---\nUsage: #{([File.basename($0, File.extname($0))] + self.inspect.split('::')[1..-1].map { |s| s.to_snake.tr('_', '-') } + [method_spec.method_name.to_s.tr('_', '-'), '[OPTIONS]']).join(' ')}"
				
				required, optional = method_spec.parameters.values.partition { |param| Object.instance_method(:instance_variable_get).bind(param.__send__(:__arg)).call(:@missing)[:mode] == :required }
				
				
				str << "\n\n[#{'REQUIRED'.red}]"
				required.each { |param| str << param.send(:__info, false) }
				
				str << "\n\n[#{'OPTIONAL'.green}]"
				optional.each { |param| str << param.send(:__info, false) }
				
				str << "\n"
				
				if exit_code.nil?
					str
				else
					$cli_log.log(:info, str)
					exit(exit_code)
				end
			end
			
			def method_help_extra(method_spec, exit_code)
				ArgumentChecking.enum_check(exit_code, 'exit_code', 0, 1, nil)
				
				str = "\n--- MethodHelpExtra ---\nUsage: #{([File.basename($0, File.extname($0))] + self.inspect.split('::')[1..-1].map { |s| s.to_snake.tr('_', '-') } + [method_spec.method_name.to_s.tr('_', '-'), '[OPTIONS]']).join(' ')}"
				
				required, optional = method_spec.parameters.values.partition { |param| Object.instance_method(:instance_variable_get).bind(param.__send__(:__arg)).call(:@missing)[:mode] == :required }
				
				str << "\n\n[#{'REQUIRED'.red}]"
				required.each { |param| str << param.__info(true) }
				
				str << "\n\n[#{'OPTIONAL'.green}]"
				optional.each { |param| str << param.__info(true) }
				
				str << "\n"
				
				if exit_code.nil?
					str
				else
					$cli_log.log(:info, str)
					exit(exit_code)
				end
			end
			
		class NonExistentParametersError < RuntimeError
			attr_reader :params
			def initialize(params)
				@params = params
				super("Found parameter definitions for params that dont exist in method: #{params.join(', ')}")
			end
		end
		
		class ParameterNameOverlapErr < RuntimeError
			attr_reader :param_names
			def initialize(param_names)
				@param_names = param_names
				super("Multiple definitions of parameters: #{param_names.inspect}")
			end
		end
			
		class MethodSpec
			
			attr_reader :parameters, :method_name, :short_map, :long_map, :method_info
			
			def initialize(method_name, &block)
				raise ArgumentError.new("You must supply a block to this method.") unless block_given?
				@method_name = method_name
				@parameters = {}
				@built = false
				
				block.call(self)
			end
			
			def int(param_name, &block)
				param(param_name, :int, &block)
			end
			
			def float(param_name, &block)
				param(param_name, :float, &block)
			end
			
			def boolean(param_name, &block)
				param(param_name, :boolean, &block)
			end
			
			def string(param_name, &block)
				param(param_name, :string, &block)
			end
			
			def symbol(param_name, &block)
				param(param_name, :symbol, &block)
			end
			
			def array(param_name, &block)
				param(param_name, :array, &block)
			end
			
			def hash(param_name, &block)
				param(param_name, :hash, &block)
			end
			
			class ParseError < RuntimeError
			end
			
			class MissingRequiredError < RuntimeError
			end
			
			class PreValidationError < RuntimeError
			end
			
			class PostValidationError < RuntimeError
			end
			
			class ConversionError < RuntimeError
			end
			
			private
				
				def __normalizer
					normalizer = HashNormalizer::NormalizerManager.new {}
					Object.instance_method(:instance_variable_set).bind(normalizer).call(:@args, @parameters.values.map { |param| param.__arg })
					normalizer.__send__(@method_info[:rest]).default_value([]).type_check(Array) unless @method_info[:rest].nil?
					
					normalizer
				end
				
				def parse(args)
					raise "You have not yet built MethodSpec '#{@method_name}'" unless @built
					ArgumentChecking.type_check_each(args, 'args', Argument)
					
					used_params = Set.new
					
					current_param = nil
					values = []
					
					args.each do |arg|
						if arg.type == :arg
							if current_param.nil? || %i{array hash}.include?(current_param.type)
								values << arg
							else
								current_param.value = arg
								current_param = nil
								values = []
							end
						else
							if current_param.nil?
								if values.any?
									$cli_log.log(:fatal, "No parameter to apply args to: #{values.map { |a| "'#{a.value}'" }.join(', ')}")
									raise ParseError.new
								end
							else
								if %i{array hash}.include?(current_param.type)
									current_param.value = values
									current_param = nil
									values = []
								else
									unless values.any?
										$cli_log.log(:fatal, "No arguments to submit to parameter '#{current_param.base_name.tr('_', '-')}'")
										raise ParseError.new
									end
								end
							end
							if arg.type == :long
								param = GnuMatch.multi_match(arg.value, @long_map.keys)
								if param.is_a?(String)
									param = @long_map[param]
									if used_params.include?(param[:param])
										$cli_log.log(:fatal, "You already used parameter '#{param[:param].base_name.tr('_', '-')}'")
										raise ParseError.new
									end
									used_params << param[:param]
									if param[:bool].nil?
										current_param = param[:param]
									else
										param[:param].value = param[:bool]
									end
								elsif $gnu_matches.empty?
									$cli_log.log(:fatal, "Could not match parameter '--#{arg.value.tr('_', '-')}'")
									raise ParseError.new
								else
									$cli_log.log(:fatal, "Parameter '--#{arg.value.tr('_', '-')}' is ambiguous: #{$gnu_matches.map { |mat| "'--#{mat.tr('_', '-')}'" }.join(', ')}")
									raise ParseError.new
								end
							elsif arg.type == :short
								errors = false
								param = arg.value.map { |p| [p, @short_map[p]] }
								param.each do |p|
									if p[1].nil?
										errors = true
										$cli_log.log(:fatal, "Could not find parameter '-#{p[0]}'")
									elsif used_params.include?(p[1][:param])
										errors = true
										$cli_log.log(:fatal, "You already used parameter '-#{p[0]}'")
									elsif param.length > 1 && p[1][:param].type != :boolean
										errors = true
										$cli_log.log(:fatal, "You can only supply boolean short parameters together, '-#{p[0]}' is not a boolean")
									end
									used_params << p[1][:param] unless p[1].nil?
								end
								raise ParseError.new if errors
								
								if param.any? { |p| p[1][:param].type == :boolean }
									param.each do |p|
										p[1][:param].value = p[1][:bool]
									end
								else
									current_param = param[0][1][:param]
								end
							else
								raise 'What is going on...'
							end
						end
					end
					
					if current_param.nil?
						if values.any? && !@method_info[:rest]
							$cli_log.log(:fatal, "No parameter to apply args to: #{values.map { |a| "'#{a.value}'" }.join(', ')}")
							raise ParseError.new
						else
							rest = values
						end
					else
						if values.any? || %i{array hash}.include?(current_param.type)
							current_param.value = values
							rest = []
						else
							$cli_log.log(:fatal, "No arguments to submit to parameter '#{current_param.base_name.tr('_', '-')}'")
							raise ParseError.new
						end
					end
					
					errors = false
					@method_info[:names].map { |name| @parameters[name] }.each do |param|
						begin
							param.send(:__process)
						rescue ParseError
							errors = true
						end
					end
					raise ParseError if errors
					
					values = {}
					@parameters.values.select { |param| param.instance_variable_defined?(:@value) }.each do |param|
						values[param.long_name] = param.instance_variable_get(:@value)
					end
					if @method_info[:rest]
						values[@method_info[:rest]] = rest.map { |r| r.value }
					end
					
					@method_info[:method].call(values)
				end
				
				def param(param_name, type, &block)
					ArgumentChecking.type_check(param_name, 'param_name', Symbol)
					raise AlreadyDefinedParameterError.new(param_name) if @parameters.key?(param_name)
					@parameters[param_name.to_s] = ParameterSpec.new(param_name, type, &block)
				end
				
				def build(method_info)
					return if @built
					@method_info = method_info
					
					non_existent_parameters = @parameters.keys - method_info[:names]
					raise NonExistentParametersError.new(non_existent_parameters) if non_existent_parameters.any?
					
					# Assume types
					(method_info[:names] - @parameters.keys).each do |param|
						if MethodSpec::ParameterSpec::BOOLEAN_MAPPINGS.keys.any? { |start| param.start_with?("#{start}_") }
							param(param.to_sym, :boolean)
						elsif %w{int num count}.any? { |inc| param.split('_').include?(inc) }
							param(param.to_sym, :int)
						elsif %w{arr array}.any? { |inc| param.split('_').include?(inc) }
							param(param.to_sym, :array)
						elsif %w{hash}.any? { |inc| param.split('_').include?(inc) }
							param(param.to_sym, :hash)
						else
							param(param.to_sym, :string)
						end
					end
					
					# Figure out boolean mode, flip, and basename
					@parameters.each_value do |param|
						split = param.long_name.split('_')
						if param.type == :boolean
							found = false
							mode = nil
							flip = nil
							MethodSpec::ParameterSpec::BOOLEAN_MAPPINGS.each_pair do |start, mapping|
								if param.long_name.start_with?("#{start}_")
									mode = mapping
									flip = mapping.to_s.start_with?('_')
									found = true
									break
								end
							end
							unless found
								mode = :_no
								flip = false
							end
							param.boolean_data(:mode => mode, :flip => flip)
						elsif param.type == :string
							prc = nil
							if %w{file}.any? { |inc| split.include?(inc) }
								prc = proc { |str| File.exists?(str) && File.file?(str) }
							elsif %w{dir directory}.any? { |inc| split.include?(inc) }
								prc = proc { |str| File.exists?(str) && File.directory?(str) }
							elsif %w{exe}.any? { |inc| split.include?(inc) }
								prc = proc { |str| File.exists?(str) && File.executable?(str) }
							elsif %w{path}.any? { |inc| split.include?(inc) }
								prc = proc { |str| File.exists?(str) }
							end
							param.pre_validate(proc { |val| "Error validating path '#{val}'" }, &prc) unless prc.nil?
						elsif param.type == :int
							if %w{count}.any? { |inc| split.include?(inc) }
								param.validate(proc { |val| "#{val} must be >= 0" }){ |val| val >= 0 }
							end
						end
					end
					
					# Map long names
					long_map = @parameters.values.map do |param|
						if param.type == :boolean
							split = param.__boolean_data[:mode].to_s.split('_')
							[
								[split[0].length > 0 ? "#{split[0]}_#{param.base_name}" : param.base_name, { :param => param, :bool => !param.__boolean_data[:flip] }],
								[split[1].length > 0 ? "#{split[1]}_#{param.base_name}" : param.base_name, { :param => param, :bool => param.__boolean_data[:flip] }]
							]
						else
							[[param.long_name, { :param => param, :bool => nil }]]
						end
					end.flatten(1)
					
					long_name_duplicates = long_map.map { |info| info[0] }.duplicates
					raise ParameterNameOverlapErr.new(long_name_duplicates) if long_name_duplicates.any?
					
					long_map = long_map.to_h
					
					# Map short names
					short_map = {}
					used_short_names = Set['h', 'H']
					
					@parameters.values.select { |param| param.type == :boolean }.each do |param|
						start = param.base_name[0]
						unless used_short_names.include?(start.downcase) || used_short_names.include?(start.upcase)
							used_short_names << start.downcase << start.upcase
							short_map[start.downcase] = { :param => param, :bool => !param.__boolean_data[:flip] }
							short_map[start.upcase] = { :param => param, :bool => param.__boolean_data[:flip] }
						end
					end
					
					@parameters.values.select { |param| param.type != :boolean }.each do |param|
						start = param.base_name[0]
						if !used_short_names.include?(start.downcase)
							used_short_names << start.downcase
							short_map[start.downcase] = { :param => param, :bool => nil }
						elsif !used_short_names.include?(start.upcase)
							used_short_names << start.upcase
							short_map[start.upcase] = { :param => param, :bool => nil }
						end
					end
					
					@long_map = long_map
					@short_map = short_map
					
					@parameters.each_value do |param|
						param.instance_variable_set(:@short, @short_map.select { |k, v| v[:param] == param }.transform_values { |v| v[:bool] }.invert)
					end
					
					@built = true
					nil
				end
			
			class ParameterSpec
				
				# :start => :mode
				BOOLEAN_MAPPINGS = {
					:is => :is_isnt,
					:isnt => :_isnt,
					:do => :do_dont,
					:dont => :_dont,
					:yes => :yes_no,
					:no => :_no,
					:can => :can_cant,
					:cant => :_cant,
					:will => :will_wont,
					:wont => :_wont
				}
				
				attr_reader :long_name, :base_name, :comments, :type, :default, :value, :defined, :pre_validate, :transform
				
				def initialize(param_name, type, &block)
					ArgumentChecking.type_check(param_name, 'param_name', Symbol)
					StringCasing.matches?(param_name.to_s, :snake, :behavior => :error, :nums => true)
					ArgumentChecking.enum_check(type, 'type', :string, :symbol, :boolean, :int, :float, :array, :hash)
					
					@long_name = param_name.to_s
					if type == :boolean
						BOOLEAN_MAPPINGS.keys.map { |k| k.to_s }.each do |start|
							if @long_name.start_with?("#{start}_")
								@base_name = @long_name[(start.length+1)..-1]
								break
							end
						end
						@base_name ||= @long_name
						@boolean_data = {}
					else
						@base_name = @long_name
					end
					
					@arg = HashNormalizer::NormalizerManager::Arg.new(@long_name.to_sym, []).required
					
					@type = type
					
					@pre_validate = nil
					@pre_transform = nil
					
					@defined = false
					@value = nil
					
					@comments = []
					
					if type == :boolean
						validate(proc { |me| "No explicit conversion of parameter '#{@long_name}' [#{me.class.inspect}] to one of [#{type.to_s.to_snake}]" }) { |me| ArgumentChecking.type_check(me, @long_name, Boolean) {} }
					elsif type == :hash
						validate(proc { |me| "No explicit conversion of parameter '#{@long_name}' [#{me.class.inspect}] to one of [#{type.to_s.to_snake}]" }) { |me| ArgumentChecking.type_check(me, @long_name, Hash) {} }
					elsif type == :array
						validate(proc { |me| "No explicit conversion of parameter '#{@long_name}' [#{me.class.inspect}] to one of [#{type.to_s.to_snake}]" }) { |me| ArgumentChecking.type_check(me, @long_name, Array) {} }
					elsif type == :int
						pre_validate(proc { |me| "'#{me}' does not match Integer format" }) { |me| /^-?\d+$/.match?(me) }
						pre_transform { |me| me.to_i }
						validate(proc { |me| "No explicit conversion of parameter '#{@long_name}' [#{me.class.inspect}] to one of [#{type.to_s.to_snake}]" }) { |me| ArgumentChecking.type_check(me, @long_name, Integer) {} }
					elsif type == :float
						pre_validate(proc { |me| "'#{me}' does not match Integer format" }) { |me| /^-?\d+(\.\d+)?$/.match?(me) }
						pre_transform { |me| me.to_i }
						validate(proc { |me| "No explicit conversion of parameter '#{@long_name}' [#{me.class.inspect}] to one of [#{type.to_s.to_snake}]" }) { |me| ArgumentChecking.type_check(me, @long_name, Float) {} }
					elsif type == :string
						validate(proc { |me| "No explicit conversion of parameter '#{@long_name}' [#{me.class.inspect}] to one of [#{type.to_s.to_snake}]" }) { |me| ArgumentChecking.type_check(me, @long_name, String) {} }
					elsif type == :symbol
						pre_transform { |me| me.to_sym }
						validate(proc { |me| "No explicit conversion of parameter '#{@long_name}' [#{me.class.inspect}] to one of [#{type.to_s.to_snake}]" }) { |me| ArgumentChecking.type_check(me, @long_name, Symbol) {} }
					end
					
					block.call(self) unless block.nil?
				end
				
				def pre_validate(on_fail = nil, &block)
					raise ArgumentError.new("You must supply a block for validation") unless block_given?
					ArgumentChecking.type_check(on_fail, 'on_fail', NilClass, String, Proc)
					@pre_validate = {
						:validator => block,
						:on_fail => on_fail
					}
					self
				end
				
				def pre_transform(on_fail = nil, &block)
					raise ArgumentError.new("You must supply a block for transformation") unless block_given?
					ArgumentChecking.type_check(on_fail, 'on_fail', NilClass, String, Proc)
					@pre_transform = {
						:converter => block,
						:on_fail => on_fail
					}
					self
				end
				
				def boolean_data(hash_args = {})
					raise ArgumentError.new("method 'boolean_data' is only for type boolean") unless @type == :boolean
					hash_args = HashNormalizer.normalize(hash_args) do |norm|
						norm.mode.no_default.enum_check(BOOLEAN_MAPPINGS.values)
						norm.flip.no_default.boolean_check
					end
					@boolean_data.merge!(hash_args)
					self
				end
				
				def comments(*comments)
					if comments.any?
						ArgumentChecking.type_check_each(comments, 'comments', String)
						@comments = comments
						self
					else
						@comments
					end
				end
				
				def method_missing(sym, *args, &block)
					begin
						@arg.__send__(sym, *args, &block)
						self
					rescue NoMethodError
						raise NoMethodError.new("undefined method '#{sym}' for #{self.class}")
					end
				end
				
				def self.try_convert(val, default_sym)
					if /^-?\d+$/.match?(val)
						val.to_i
					elsif /^-?\d+(.\d+)?$/.match?(val)
						val.to_f
					elsif /^'.*'$/.match?(val)
						val[1..-2].to_s
					elsif /^:.+$/.match?(val)
						val[1..-1].to_sym
					elsif /^\[[^\[\]]*\]$/.match?(val)
						val[1..-2].split(',').map { |v| try_convert(v.strip, false) }
					else
						default_sym ? val.to_sym : val.to_s
					end
				end
				
				WIDTH_1 = 10
				WIDTH_2 = 30
				WIDTH_3 = 4
				
				def __info(extra_info)
					if @type == :boolean
						split = @boolean_data[:mode].to_s.split('_')
						if split[0].length == 0
							param = [
								@short.any? ? "-[#{@short[@boolean_data[:flip]]}]#{@short[!@boolean_data[:flip]]}".magenta : nil,
								"--[#{split[1]}-]#{@base_name.tr('_', '-')}".magenta,
								nil
							]
						else
							param = [
								@short.any? ? "-{#{@short[@boolean_data[:flip]]}/#{@short[!@boolean_data[:flip]]}}".magenta : nil,
								"--{#{split[1]}/#{split[0]}}#{@base_name.tr('_', '-')}".magenta,
								nil
							]
						end
					else
						param = [@short.key?(nil) ? "-#{@short[nil]}".magenta : nil, "--#{@base_name.tr('_', '-')}".magenta, (%i{hash array}.include?(@type) ? "#{@base_name}..." : @base_name).upcase.blue]
					end
					
					if param[0].nil? || param[2].nil? || (param[1].length + param[2].length + 1) <= WIDTH_2
						params = ["#{(param[0].nil? ? '' : "#{param[0]}, ").rjust(WIDTH_1)}#{"#{param[1]}#{param[2].nil? ? '' : " #{param[2]}"}".ljust(WIDTH_2)}"]
					else
						params = [
							"#{''.rjust(WIDTH_1)}#{param[1]}",
							"#{"#{param[0]}  ".rjust(WIDTH_1 - 1)}#{param[2]},"
						]
					end
					
					remaining_comments = @comments.dup
					if extra_info
						missing = Object.instance_method(:instance_variable_get).bind(@arg).call(:@missing)
						extra = [
							"Type: #{@type}",
							%i{default_value}.include?(missing[:mode]) ? "Default: #{missing[:value].inspect}" : nil
						]
						remaining_comments = extra.select { |i| !i.nil? } + remaining_comments #.map { |c| "    #{c}" }
					end
					
					first_line = true
					str = ''
					until params.empty? && remaining_comments.empty?
						tmp = (params.empty? ? '' : "#{params.shift}").ljust(WIDTH_1 + WIDTH_2)
						if remaining_comments.any? && tmp.length == (WIDTH_1 + WIDTH_2)
							tmp << (' ' * WIDTH_3) << (first_line ? '' : ' ' * WIDTH_3) << remaining_comments.shift
						end
						str << "\n" << tmp
						first_line = false
					end
					
					(extra_info ? "\n" : "") + str
				end
				
				def __process
					missing = Object.instance_method(:instance_variable_get).bind(@arg).call(:@missing)
					if @defined
						if @value.nil?
							val = nil
						elsif @value == true || @value == false
							val = @value
						elsif @value.is_a?(Argument)
							val = @value.value
						else
							val = @value.map { |v| v.value }
						end
					
						if @type == :hash
							val = val.map { |v| v.split('=>').map { |s| s.strip } }
							errors = false
							val.each_with_index do |v, i|
								if v.length == 2
									v[0] = ParameterSpec.try_convert(v[0], true)
									v[1] = ParameterSpec.try_convert(v[1], false)
								else
									$cli_log.log(:fatal, "'#{@base_name.tr('_', '-')}'[#{i}] is malformatted")
									errors = true
								end
							end
							raise ParseError.new if errors
							val = val.to_h
						elsif type == :array
							val = val.map { |v| ParameterSpec.try_convert(v, false) }
						elsif @type == :boolean
						else
							unless @pre_validate.nil?
								unless @pre_validate[:validator].call(val)
									if @pre_validate[:on_fail].nil?
										$cli_log.log(:fatal, "Failed to validate parameter '#{@base_name.tr('_', '-')}'")
									elsif @pre_validate[:on_fail].is_a?(String)
										$cli_log.log(:fatal, @pre_validate[:on_fail])
									elsif @pre_validate[:on_fail].is_a?(Proc)
										$cli_log.log(:fatal, @pre_validate[:on_fail].call(val))
									end
									raise ParseError.new
								end
							end
							
							unless @pre_transform.nil?
								begin
									val = @pre_transform[:converter].call(val)
								rescue => e
									if @pre_transform[:on_fail].nil?
										$cli_log.log(:fatal, "Failed to convert parameter '#{@base_name.tr('_', '-')}'")
									elsif @pre_transform[:on_fail].is_a?(String)
										$cli_log.log(:fatal, @pre_validate[:on_fail])
									elsif @pre_transform[:on_fail].is_a?(Proc)
										$cli_log.log(:fatal, @pre_validate[:on_fail].call(val, e))
									end
									raise ParseError.new
								end
							end
						end
						
						@value = val
					else
						if missing[:mode] == :required
							$cli_log.log(:fatal, "Missing required parameter '#{@base_name.tr('_', '-')}'")
							raise ParseError.new
						else
							self.remove_instance_variable(:@value)
						end
					end
					
					nil
				end
				
				def value= (val)
					@defined = true
					@value = val
				end
				
				def __arg
					@arg
				end
				
				def __boolean_data
					@boolean_data
				end
				
			end
			
			class AlreadyDefinedParameterError < RuntimeError
				attr_reader :param_name
				def initialize(param_name)
					@param_name = param_name
					super("Already defined parameter '#{param_name}'")
				end
			end
		
		end
		
		class Argument
			
			attr_reader :value, :type, :original, :escaped
			
			def initialize(string)
				ArgumentChecking.type_check(string, 'string', String)
				@original = string
				@escaped = false
				if string.start_with?('@')
					@type = :arg
					@value = string[1..-1]
					@escaped = true
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
