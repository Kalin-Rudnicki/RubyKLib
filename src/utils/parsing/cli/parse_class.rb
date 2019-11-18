
require_relative 'spec_generator'
require_relative 'spec_stubs'
require_relative '../GnuMatch'
require_relative '../../validation/ArgumentChecking'
require_relative '../../../data_structures/TopologicalSort'

module KLib
	
	module CLI
		
		SHORT_REGEX_BOOL = /^[A-Za-z]_[A-Za-z]$/
		SHORT_REGEX_OTHER = /^[A-Za-z]$/
		
		LOWER_REGEX = /^[a-z][a-z]*(_([a-z]+|[0-9]+))*$/
		UPPER_REGEX = /^[A-Z][a-z]*([A-Z][a-z]*|[0-9]+)*$/
		
		BASE_10_INT = /^\d+$/
		BASE_16_INT = /^0x[0-9a-fA-F]+$/
		
		class Blueprint
			
			SPLIT = /[-_]/
			
			LONG_BLACKLIST = [:help, :help_extra, :argv, :parse_data]
			SHORT_BLACKLIST = [:h, :H]
			
			SUB_SPEC = /^[a-z]+(-[a-z]+)*$/
			BAD_PARAM = /^--(.*)$/
			PARAM = /^--([a-z]+(?:-(?:[a-z]+|\d+))*)$/
			PARAM_W_ARG = /^--([a-z]+(?:-(?:[a-z]+|\d+)+)*)=(.*)$/
			BAD_SHORT_PARAM= /^-([A-Za-z].*)/
			SHORT_PARAM= /^-([A-Za-z])$/
			SHORT_PARAM_W_ARG = /^-([A-Za-z])=(.*)$/
			
			LONG_PROC = proc { |p| "--#{p.tr('_', '-')}" }
			SHORT_PROC = proc { |p| "-#{p}" }
			
			def initialize(spec_gen, parent_mod = nil)
				ArgumentChecking.type_check(spec_gen, :spec_gen, SpecGenerator)
				ArgumentChecking.type_check(parent_mod, :parent_mod, NilClass, Module)
				mod, execute, specs, sub_specs, extra_argv, illegal_keys, bad_keys = spec_gen.__data
				
				raise "You can not have non-sub-specs without an execute" if specs.any? && execute.nil?
				raise "ParseClass with no specs or argv" if specs.empty? && sub_specs.empty? && !extra_argv
				
				if mod.is_a?(Module)
					@mod = mod
				elsif mod.is_a?(Symbol)
					@mod = parent_mod.const_set(mod.to_s.to_camel(false).to_sym, Module.new)
					@mod.extend(Parser)
				else
					raise "What is going on?"
				end
				@instance = @mod.const_set(:Instance, Class.new(Parser::Instance))
				@mod.instance_variable_set(:@instance, @instance)
				@mod.instance_variable_set(:@blueprint, self)
				@instance.instance_variable_set(:@mod, @mod)
				@instance.instance_variable_set(:@blueprint, self)
				@instance.define_method(:execute, &execute) if execute
				
				@sub_specs = {}
				@sub_spec_aliases = {}
				
				sub_specs.each do |sub|
					raise "Already used sub_spec '#{sub[:name]}', #{sub[:name]} => #{@sub_spec_aliases[sub[:name]]}" if @sub_spec_aliases.key?(sub[:name])
					@sub_spec_aliases[sub[:name]] = sub[:name]
					sub[:aliases].each do |a|
						raise "Already used sub_spec '#{a}', #{a} => #{@sub_spec_aliases[a]}" if @sub_spec_aliases.key?(a)
						@sub_spec_aliases[a] = sub[:name]
					end
					@sub_specs[sub[:name]] = Blueprint.new(sub[:spec], @mod)
				end
				
				@params = {}
				@params_by_name = {}
				@long_mappings = {}
				@short_mappings = {}
				@values = {}
				
				specs.each do |spec|
					name = spec.instance_variable_get(:@name)
					raise "Already have param '#{name}'" if @params_by_name.key?(name)
					@params_by_name[name] = spec
					
					spec.instance_variable_get(:@mappings).each_pair do |k, v|
						raise "Mapping '#{k}' is blacklisted" if LONG_BLACKLIST.include?(k)
						raise "Already used mapping '#{k}', #{k} => #{@long_mappings[k]}" if @long_mappings.key?(k)
						@long_mappings[k] = v[:to]
						@params[k] = v[:spec] if v.key?(:spec)
						@values[k] = v[:val] if v.key?(:val)
					end
					
					spec.instance_variable_get(:@short).each_pair do |k, v|
						raise "Short mapping '#{k}' is blacklisted" if SHORT_BLACKLIST.include?(k)
						raise "Already used short mapping '#{k}', #{k} => #{@short_mappings[k]}" if @short_mappings.key?(k)
						@short_mappings[k] = v
					end
				end
				
				@all_subs = @sub_spec_aliases.keys.map { |k| k.to_s }
				@all_long = @long_mappings.keys.map { |k| k.to_s }
				@all_short = @short_mappings.keys.map { |k| k.to_s }
				@all_base = @params_by_name.keys.map { |k| k.to_s }
				
				@extra_argv = extra_argv
				@illegal_keys = illegal_keys
				@bad_keys = bad_keys
				
				# help
				
				@help = 'help'
				@help_extra = 'help_extra'
				
				# priority
				
				sorter = TopologicalSort.new
				@params_by_name.each_value do |param|
					name, dft, priority, vt = %i{name default priority validate_transform}.map { |var| param.instance_variable_get(:"@#{var}") }
					sorter[name] = priority
					sorter[name] = dft[:priority] if dft.key?(:priority)
					vt.each do |_vt|
						sorter[name] = _vt.priority if _vt.priority.any?
					end
				end
				
				@order = sorter.sort
				
				nil
			end
			
			def parse(argv)
				current = nil
				new_argv = []
				parsed = @params_by_name.values.map { |v| [v, []] }.to_h
				
				if argv.length > 0
					if SUB_SPEC.match?(argv[0])
						match = GnuMatch.multi_match(argv[0], @all_subs, split: SPLIT)
						if match
							match = @sub_spec_aliases[match.to_sym]
							return @mod.const_get(match.to_s.to_camel(false).to_sym).parse(argv[1..-1])
						elsif @extra_argv
						elsif $gnu_matches.any?
							$stderr.puts("Ambiguous call '#{argv[0]}': #{$gnu_matches.map { |mat| mat.tr('_', '-') }.join(', ')}")
							exit(1)
						end
					end
				end
				
				argv.each do |arg|
					if current
						current[:arg] = arg
						parsed[current[:spec]] << current
						current.delete(:spec)
						current = nil
					else
						if (match = PARAM_W_ARG.match(arg))
							param = match[1]
							val = match[2]
							if (match = search(arg, param, @all_base, new_argv, &LONG_PROC))
								spec = @params_by_name[match]
								auto_trim = spec.instance_variable_get(:@auto_trim)
								val = val.strip if auto_trim
								if spec.is_a?(SpecGenerator::BooleanSpec)
									if /^(t|T|true|TRUE)$/.match?(val)
										val = true
									elsif /^(f|F|false|FALSE)$/.match?(val)
										val = false
									else
										$stderr.puts("Arg must look like /^(t|T|true|TRUE|f|F|false|FALSE)$/ when specifying booleans in the format of --param=val")
										exit(1)
									end
								elsif spec.is_a?(SpecGenerator::FlagSpec)
									$stderr.puts("You can not specify flags in the form of --param=val")
									exit(1)
								end
								parsed[spec] << { param: LONG_PROC.(param) + '=', arg: val }
							end
						elsif (match = SHORT_PARAM_W_ARG.match(arg))
							param = match[1]
							val = match[2]
							if (match = search(arg, param, @all_short, new_argv, &SHORT_PROC))
								spec = @params[@long_mappings[@short_mappings[match]]]
								auto_trim = spec.instance_variable_get(:@auto_trim)
								val = val.strip if auto_trim
								if spec.is_a?(SpecGenerator::BooleanSpec) || spec.is_a?(SpecGenerator::FlagSpec)
									$stderr.puts("You can not specify booleans or flags in the form of -p=val")
									exit(1)
								end
								parsed[spec] << { param: SHORT_PROC.(param) + '=', arg: val }
							end
						elsif (match = PARAM.match(arg))
							param = match[1]
							if (match = search(arg, param, @all_long, new_argv, &LONG_PROC))
								spec = @params[@long_mappings[match]]
								if @values.key?(@long_mappings[match])
									parsed[spec] << { param: LONG_PROC.(param), arg: @values[@long_mappings[match]] }
								else
									current = { spec: spec, param: LONG_PROC.(param) }
								end
							end
						elsif (match = SHORT_PARAM.match(arg))
							param = match[1]
							if (match = search(arg, param, @all_short, new_argv, &SHORT_PROC))
								spec = @params[@long_mappings[@short_mappings[match]]]
								if @values.key?(@long_mappings[@short_mappings[match]])
									parsed[spec] << { param: SHORT_PROC.(param), arg: @values[@long_mappings[@short_mappings[match]]] }
								else
									current = { spec: spec, param: SHORT_PROC.(param) }
								end
							end
						elsif (match = BAD_PARAM.match(arg)) || (match = BAD_SHORT_PARAM.match(arg))
							case @bad_keys
								when :error
									$stderr.puts("Bad key '#{arg}'")
									exit(1)
								when :illegal
									case @illegal_keys
										when :error
											$stderr.puts("Bad key '#{arg}'")
											exit(1)
										when :warn
											if @extra_argv
												$stderr.puts("Bad key '#{arg}' treated as ARGV")
												new_argv << arg
											else
												$stderr.puts("No ARGV for bad key '#{arg}'")
												exit(1)
											end
										when :no_warn
											if @extra_argv
												new_argv << arg
											else
												$stderr.puts("No ARGV for bad key '#{arg}'")
												exit(1)
											end
										else
											raise "What is going on?"
									end
								else
									raise "What is going on?"
							end
						else
							if @extra_argv
								new_argv << arg
							else
								$stderr.puts("No ARGV for arg '#{arg}'")
								exit(1)
							end
						end
					end
				end
				if current
					$stderr.puts("Failed to specify argument for '#{current[:param]}'")
					exit(1)
				end
				
				results = @extra_argv ? { argv: new_argv } : {}
				@order.each do |var|
					param = @params_by_name[var]
					spec = @params_by_name[var]
					vals = parsed[spec]
					val = nil
					if vals.any?
						if vals.length > 1
							%i{
							error error_different first last all flatten
							error error_different first last
							error ignore
							}
							case param.multi
								when :error
									$stderr.puts("Param '#{param.name}' specified multiple times: #{vals.map { |v| v[:param] }.join(', ')}")
									exit(1)
								when :error_different
									if vals.map { |v| v[:arg] }.uniq.length > 1
										$stderr.puts("Param '#{param.name}' specified multiple times with different values: #{vals.map { |v| v[:param] }.join(', ')}")
										exit(1)
									else
										val = vals.first[:arg]
									end
								when :first, :ignore
									val = vals.first[:arg]
								when :last
									val = vals.last[:arg]
								when :all
									val = vals.map { |v| v[:arg] }
								when :flatten
									val = vals.map { |v| v[:arg] }
								else
									raise "What is going on?"
							end
						else
							case param.multi
								when :error, :error_different, :first, :last, :ignore
									val = vals.first[:arg]
								when :all, :flatten
									val = vals.map { |v| v[:arg] }
								else
									raise "What is going on?"
							end
						end
						if param.split
							case param.multi
								when :error, :error_different, :first, :last, :ignore
									val = val.split(param.split)
									param.validate_transform.each do |vt|
										case vt
											when Validate
												begin
													val.each { |v| vt.validate(v,  param.name, results) }
												rescue CliParseError => e
													$stderr.puts(e.message)
													exit(1)
												end
											when Transform
												begin
													val = val.map { |v| vt.transform(v,  param.name, results) }
												rescue CliParseError => e
													$stderr.puts(e.message)
													exit(1)
												end
											else
												raise "What is going on?"
										end
									end
								when :all
									val = val.map { |v| v.split(param.split) }
									param.validate_transform.each do |vt|
										case vt
											when Validate
												begin
													val.each { |v1| v1.each { |v2| vt.validate(v2, param.name, results) } }
												rescue CliParseError => e
													$stderr.puts(e.message)
													exit(1)
												end
											when Transform
												begin
													val = val.map { |v1| v1.map { |v2| vt.transform(v2,  param.name, results) } }
												rescue CliParseError => e
													$stderr.puts(e.message)
													exit(1)
												end
											else
												raise "What is going on?"
										end
									end
								when :flatten
									val = val.map { |v| v.split(param.split) }.flatten
									param.validate_transform.each do |vt|
										case vt
											when Validate
												begin
													val.each { |v| vt.validate(v,  param.name, results) }
												rescue CliParseError => e
													$stderr.puts(e.message)
													exit(1)
												end
											when Transform
												begin
													val = val.map { |v| vt.transform(v,  param.name, results) }
												rescue CliParseError => e
													$stderr.puts(e.message)
													exit(1)
												end
											else
												raise "What is going on?"
										end
									end
								else
									raise "What is going on?"
							end
						else
							case param.multi
								when :error, :error_different, :first, :last, :ignore
									param.validate_transform.each do |vt|
										case vt
											when Validate
												begin
													vt.validate(val,  param.name, results)
												rescue CliParseError => e
													$stderr.puts(e.message)
													exit(1)
												end
											when Transform
												begin
													val = vt.transform(val,  param.name, results)
												rescue CliParseError => e
													$stderr.puts(e.message)
													exit(1)
												end
											else
												raise "What is going on?"
										end
									end
								when :all
									param.validate_transform.each do |vt|
										case vt
											when Validate
												begin
													val.each { |v| vt.validate(v,  param.name, results) }
												rescue CliParseError => e
													$stderr.puts(e.message)
													exit(1)
												end
											when Transform
												begin
													val = val.map { |v| vt.transform(v,  param.name, results) }
												rescue CliParseError => e
													$stderr.puts(e.message)
													exit(1)
												end
											else
												raise "What is going on?"
										end
									end
								when :flatten
									raise "What is going on?"
								else
									raise "What is going on?"
							end
						end
						
						results[param.name] = val
					else
						case param.default[:type]
							when :required
								$stderr.puts("Missing required arg '#{param.name}'")
								exit(1)
							when :required_if
								begin
									if param.default[:if].(results)
										$stderr.puts("Missing conditionally required arg '#{param.name}'")
										exit(1)
									end
								rescue => e
									$stderr.puts("UNCAUGHT ERROR with '#{param.name}'")
									exit(1)
								end
							when :optional
							when :default_value
								# TODO : adapt to multi/split
								results[param.name] = param.default[:value]
							when :default_from
								results[param.name] = results[param.default[:from]]
							when :default_proc
								results[param.name] = param.default[:proc].(results)
							else
								raise "What is going on?"
						end
					end
				end
				
				@instance.new(results)
			end
			
			def show_params(instance)
				raise ArgumentError.new("Must be given an instance of #{@instance}") unless instance.is_a?(@instance)
				
				puts("=====| params |=====")
				len = (@params_by_name.keys + (@extra_argv ? [:argv] : [])).map { |k| k.to_s.length }.max + 1
				puts("#{'@argv'.ljust(len)} = #{instance.instance_variable_get(:@argv).inspect}") if @extra_argv
				@params_by_name.each_key do |param|
					var = :"@#{param}"
					if instance.instance_variable_defined?(var)
						puts("#{var.to_s.ljust(len)} = #{instance.instance_variable_get(var).inspect}")
					else
						puts("#{var.to_s.ljust(len)} = <UNDEF>")
					end
				end
			end
			
			def search(arg, param, opts, new_argv, &funct)
				if (match = GnuMatch.multi_match(param, opts, split: SPLIT))
					match.to_sym
				else
					case @illegal_keys
						when :error
							if $gnu_matches.any?
								$stderr.puts("Ambiguous key '#{funct.(param)}': #{$gnu_matches.map { |mat| "#{funct.(mat)}" }.join(', ')}")
							else
								$stderr.puts("Unmatched key '#{funct.(param)}'")
							end
							exit(1)
						when :warn
							if @extra_argv
								if $gnu_matches.any?
									$stderr.puts("Ambiguous key '#{funct.(param)}': #{$gnu_matches.map { |mat| "#{funct.(mat)}" }.join(', ')} treated as ARGV")
								else
									$stderr.puts("Unmatched key '#{funct.(param)}' treated as ARGV")
								end
								new_argv << arg
								nil
							else
								if $gnu_matches.any?
									$stderr.puts("No ARGV for ambiguous key '#{funct.(param)}': #{$gnu_matches.map { |mat| "#{funct.(mat)}" }.join(', ')}")
								else
									$stderr.puts("No ARGV for unmatched key '#{funct.(param)}'")
								end
								exit(1)
							end
						when :no_warn
							if @extra_argv
								new_argv << arg
							else
								if $gnu_matches.any?
									$stderr.puts("No ARGV for ambiguous key '#{funct.(param)}': #{$gnu_matches.map { |mat| "#{funct.(mat)}" }.join(', ')}")
								else
									$stderr.puts("No ARGV for unmatched key '#{funct.(param)}'")
								end
								exit(1)
							end
						else
							raise "What is going on?"
					end
					nil
				end
			end
			
		end
		
		module Parser
			
			# Called in order to specify arguments
			def spec(*args, **hash_args, &block)
				spec_gen = SpecGenerator.new(self, *args, **hash_args, &block)
				spec_gen.__generate
				nil
			end
			
			def parse(argv = ARGV)
				ArgumentChecking.type_check(argv, :argv, Array)
				ArgumentChecking.type_check_each(argv, :argv, String) 
				
				@blueprint.parse(argv)
			end
			
			class Instance
				
				def initialize(data)
					data.each_pair { |k, v| self.instance_variable_set(:"@#{k}", v) }
					self.execute
				end
				
				def show_params
					self.class.instance_variable_get(:@blueprint).show_params(self)
				end
				
			end
		
		end
		
	end
	
end

class Module
	
	def cli_spec(*args, **hash_args, &block)
		self.extend(KLib::CLI::Parser)
		self.spec(*args, **hash_args, &block)
	end

end
