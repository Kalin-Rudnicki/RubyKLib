
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
			@method_specs[method_name] = MethodSpec.new(method_name, &block)
		end
		
		def parse(args = ARGV)
			@valid_methods = find_valid_methods
			valid_method_names = @valid_methods.values.map { |met| met[:name] }.sort
			
			@valid_mods = find_valid_mods
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
				help(1)
			end
			
			raise 'How did you make it here...'
		end
		
		private
			
			def call_handler(method_name, args)
				ArgumentChecking.type_check(method_name, 'method_name', Symbol)
				ArgumentChecking.type_check_each(args, 'args', Argument)
				
				method_info = @valid_methods[method_name]
				@method_specs ||= {}
				unless @method_specs.key?(method_name)
					@method_specs[method_name] = MethodSpec.new(method_name) {}
				end
				method_spec = @method_specs[method_name]
				method_spec.send(:build, method_info)
				
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
					return method_spec.parse(args)
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
			
			def help(exit_code)
				ArgumentChecking.enum_check(exit_code, 'exit_code', 0, 1, nil)
				str = "\n--- Help ---\nUsage: #{([File.basename($0, File.extname($0))] + self.inspect.split('::')[1..-1].map { |s| s.to_snake.tr('_', '-') } + ['[(method/mod)-name]', '[OPTIONS]']).join(' ')}"
				
				str << "\n\n    [Valid Methods]"
				@valid_methods.each_key { |k| str << "\n        #{k.to_s.tr('_', '-')}" }
				
				str << "\n\n    [Valid Mods]"
				@valid_mods.each_key { |k| str << "\n        #{k.to_s.tr('_', '-')}" }
				
				str << "\n"
				
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
				
				required, optional = method_spec.parameters.values.partition { |param| param.default[:type] == :required }
				
				
				str << "\n\n[REQUIRED]"
				required.each { |param| str << "\n    #{param.info}" }
				
				str << "\n\n[OPTIONAL]"
				optional.each { |param| str << "\n    #{param.info}" }
				
				str << "\n"
				
				if exit_code.nil?
					str
				else
					$cli_log.log(:info, str)
					exit(exit_code)
				end
			end
			
			def method_help_extra(method_spec, exit_code)
				$cli_log.log(:info, "MethodHelpExtra does nothing additional at this time")
				method_help(method_spec, exit_code)
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
			
			attr_reader :parameters, :method_name, :short_map, :long_map
			
			def initialize(method_name, &block)
				raise ArgumentError.new("You must supply a block to this method.") unless block_given?
				@method_name = method_name
				@parameters = {}
				@built = false
				
				block.call(self)
			end
			
			def int(param_name)
				param(param_name, :int)
			end
			
			def float(param_name)
				param(param_name, :float)
			end
			
			def boolean(param_name)
				param(param_name, :boolean)
			end
			
			def string(param_name)
				param(param_name, :string)
			end
			
			def symbol(param_name)
				param(param_name, :symbol)
			end
			
			def array(param_name)
				param(param_name, :array)
			end
			
			def hash(param_name)
				param(param_name, :hash)
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
				
				rest = []
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
						param.process
					rescue ParseError
						errors = true
					end
				end
				raise ParseError if errors
				
				@method_info[:method].call(*@method_info[:names].map { |name| @parameters[name].value }, *rest.map { |a| a.value })
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
				
				def param(param_name, type)
					ArgumentChecking.type_check(param_name, 'param_name', Symbol)
					raise AlreadyDefinedParameterError.new(param_name) if @parameters.key?(param_name)
					@parameters[param_name.to_s] = ParameterSpec.new(param_name, type)
				end
				
				def build(method_info)
					return if @built
					@method_info = method_info
					
					non_existent_parameters = @parameters.keys - method_info[:names]
					raise NonExistentParametersError.new(non_existent_parameters) if non_existent_parameters.any?
					
					# Assume types
					(method_info[:names] - @parameters.keys).each do |param|
						if %w{isnt is dont do no yes}.any? { |start| param.start_with?("#{start}_") }
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
							if param.long_name.start_with?('isnt_')
								mode = :_isnt
								flip = true
							elsif param.long_name.start_with?('is_')
								mode = :is_isnt
								flip = false
							elsif param.long_name.start_with?('dont_')
								mode = :_dont
								flip = true
							elsif param.long_name.start_with?('do_')
								mode = :do_dont
								flip = false
							elsif param.long_name.start_with?('no_')
								mode = :_no
								flip = true
							elsif param.long_name.start_with?('yes_')
								mode = :yes_no
								flip = false
							else
								mode = :_no
								flip = false
							end
							param.data(:force => false, :mode => mode, :flip => flip)
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
							param.data(:force => false, :pre => prc) unless prc.nil?
						elsif param.type == :int
							if %w{count}.any? { |inc| split.include?(inc) }
								param.data(:force => false, :post => proc { |val| val >= 0 })
							end
						end
					end
					
					# TODO: BooleanParam, StringParam, HashParam, ArrayParam, IntParam, FloatParam
					
					# Map long names
					long_map = @parameters.values.map do |param|
						if param.type == :boolean
							split = param.__data[:mode].to_s.split('_')
							[
								[split[0].length > 0 ? "#{split[0]}_#{param.base_name}" : param.base_name, { :param => param, :bool => !param.__data[:flip] }],
								[split[1].length > 0 ? "#{split[1]}_#{param.base_name}" : param.base_name, { :param => param, :bool => param.__data[:flip] }]
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
							short_map[start.downcase] = { :param => param, :bool => !param.__data[:flip] }
							short_map[start.upcase] = { :param => param, :bool => param.__data[:flip] }
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
				
				attr_reader :long_name, :base_name, :comments, :type, :default, :value, :defined
				
				def initialize(param_name, type)
					ArgumentChecking.type_check(param_name, 'param_name', Symbol)
					StringCasing.matches?(param_name.to_s, :snake, :behavior => :error, :nums => true)
					ArgumentChecking.enum_check(type, 'type', :string, :symbol, :boolean, :int, :float, :array, :hash)
					
					@long_name = param_name.to_s
					if type == :boolean
						%w{isnt is dont do yes no}.each do |start|
							if @long_name.start_with?("#{start}_")
								@base_name = @long_name[(start.length+1)..-1]
								break
							end
						end
						@base_name ||= @long_name
					else
						@base_name = @long_name
					end
					
					@type = type
					@data = {}
					data
					required
					
					@defined = false
					@value = nil
					
					@comments = []
				end
				
				def required
					@default = {
						:type => :required
					}
					self
				end
				
				def default_value(val)
					@default = {
						:type => :value,
						:value => val
					}
					self
				end
				
				def data(hash_args = {})
					# pre
					#   convert
					#     post
					#
					# err / default
					if @type == :string
						hash_args = HashNormalizer.normalize(hash_args) do |norm|
							norm.force.default_value(true).boolean_check
							
							norm.pre_convert_validate(:pre).no_default.type_check(Proc, NilClass)
							norm.post_convert_validate(:post).no_default.type_check(Proc, NilClass)
							norm.convert.no_default.type_check(Proc, NilClass)
						end
					elsif @type == :symbol
						hash_args = HashNormalizer.normalize(hash_args) do |norm|
							norm.force.default_value(true).boolean_check
							
							norm.pre_convert_validate(:pre).no_default.type_check(Proc, NilClass)
							norm.post_convert_validate(:post).no_default.type_check(Proc, NilClass)
							norm.convert.default_value(proc { |val| val.to_sym }).type_check(Proc, NilClass)
						end
					elsif @type == :boolean
						hash_args = HashNormalizer.normalize(hash_args) do |norm|
							norm.force.default_value(true).boolean_check
							
							norm.mode.no_default.enum_check(:is_isnt, :_isnt, :do_dont, :_dont, :yes_no, :_no)
							norm.flip.no_default.boolean_check
						end
					elsif @type == :int
						hash_args = HashNormalizer.normalize(hash_args) do |norm|
							norm.force.default_value(true).boolean_check
							
							norm.pre_convert_validate(:pre).default_value(proc { |val| /^-?\d+$/.match?(val) }).type_check(Proc, NilClass)
							norm.post_convert_validate(:post).no_default.type_check(Proc, NilClass)
							norm.convert.default_value(proc { |val| val.to_i }).type_check(Proc, NilClass)
						end
					elsif @type == :float
						hash_args = HashNormalizer.normalize(hash_args) do |norm|
							norm.force.default_value(true).boolean_check
							
							norm.pre_convert_validate(:pre).default_value(proc { |val| /^-?\d+(.\d+)?$/.match?(val) }).type_check(Proc, NilClass)
							norm.post_convert_validate(:post).no_default.type_check(Proc, NilClass)
							norm.convert.default_value(proc { |val| val.to_f }).type_check(Proc, NilClass)
						end
					elsif @type == :array
						hash_args = HashNormalizer.normalize(hash_args) do |norm|
							norm.force.default_value(true).boolean_check
							
							norm.pre_convert_validate(:pre).no_default.type_check(Proc, NilClass)
							norm.post_convert_validate(:post).no_default.type_check(Proc, NilClass)
							norm.convert.no_default.type_check(Proc, NilClass)
						end
					elsif @type == :hash
						hash_args = HashNormalizer.normalize(hash_args) do |norm|
							norm.force.default_value(true).boolean_check
							
							norm.normalize.no_default.type_check(Proc, NilClass)
						end
					else
						raise 'What is going on...'
					end
					if hash_args[:force]
						@data.merge!(hash_args.select { |k, v| k != :force }) { |key, old_val, new_val| new_val }
					else
						@data.merge!(hash_args.select { |k, v| k != :force }) { |key, old_val, new_val| old_val }
					end
					self
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
				
				def info
					if @type == :boolean
						if @data[:mode] == :_isnt
							"#{@short.any? ? "-[#{@short[false]}]#{@short[true]}, " : ''}--[isnt-]#{@base_name.tr('_', '-')}"
						elsif @data[:mode] == :is_isnt
							"#{@short.any? ? "-{#{@short[false]}/#{@short[true]}}, " : ''}--{isnt/is}-#{@base_name.tr('_', '-')}"
						elsif @data[:mode] == :_dont
							"#{@short.any? ? "-[#{@short[false]}]#{@short[true]}, " : ''}--[dont-]#{@base_name.tr('_', '-')}"
						elsif @data[:mode] == :do_dont
							"#{@short.any? ? "-{#{@short[false]}/#{@short[true]}}, " : ''}--{dont/do}-#{@base_name.tr('_', '-')}"
						elsif @data[:mode] == :_no
							"#{@short.any? ? "-[#{@short[false]}]#{@short[true]}, " : ''}--[no-]#{@base_name.tr('_', '-')}"
						elsif @data[:mode] == :yes_no
							"#{@short.any? ? "-{#{@short[false]}/#{@short[true]}}, " : ''}--{no/yes}-#{@base_name.tr('_', '-')}"
						else
							raise 'What is going on...'
						end
					else
						"#{@short.key?(nil) ? "-#{@short[nil]}, " : ''}--#{@base_name.tr('_', '-')} #{@base_name.upcase}"
					end
				end
				
				def process
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
							begin
								val = HashNormalizer.normalize(val, &@data[:normalize]) unless @data[:normalize].nil?
							rescue => e
								$cli_log.log(:fatal, "Error normalizing '#{@base_name.tr('_', '-')}'\n\t#{e.message}")
								raise ParseError.new
							end
						elsif @type == :boolean
						else
							unless @data[:pre_convert_validate].nil?
								unless @data[:pre_convert_validate].call(val)
									$cli_log.log(:fatal, "Failed to pre_validate parameter '#{@base_name.tr('_', '-')}'")
									raise ParseError.new
								end
							end
							
							unless @data[:convert].nil?
								val = @data[:convert].call(val)
							end
							
							unless @data[:post_convert_validate].nil?
								unless @data[:post_convert_validate].call(val)
									$cli_log.log(:fatal, "Failed to post_validate parameter '#{@base_name.tr('_', '-')}'")
									raise ParseError.new
								end
							end
						end
						
					else
						if @default[:type] == :required
							$cli_log.log(:fatal, "Missing required parameter '#{@base_name.tr('_', '-')}'")
							raise ParseError.new
						else
							val = @default[:value]
						end
					end
					
					@value = val
					nil
				end
				
				def value= (val)
					@defined = true
					@value = val
				end
				
				def __data
					@data
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
