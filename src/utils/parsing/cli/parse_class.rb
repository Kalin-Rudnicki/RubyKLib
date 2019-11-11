
require_relative 'spec_generator'
require_relative 'spec_stubs'
require_relative '../../validation/ArgumentChecking'

module KLib
	
	module CLI
		
		SHORT_REGEX_BOOL = /^[A-Za-z]_[A-Za-z]$/
		SHORT_REGEX_OTHER = /^[A-Za-z]$/
		
		LOWER_REGEX = /^[a-z][a-z]*(_([a-z]+|[0-9]+))*$/
		UPPER_REGEX = /^[A-Z][a-z]*([A-Z][a-z]*|[0-9]+)*$/
		
		class Blueprint
			
			LONG_BLACKLIST = [:help, :help_extra, :argv, :parse_data]
			SHORT_BLACKLIST = [:h, :H]
			
			BAD_PARAM = /^--([a-z]+(-[a-z]+)*)/
			PARAM = /^--([a-z]+(-[a-z]+)*)$/
			PARAM_W_ARG = /^--([a-z]+(-[a-z]+)*)=(.*)$/
			
			def initialize(spec_gen, parent_mod = nil)
				ArgumentChecking.type_check(spec_gen, :spec_gen, SpecGenerator)
				ArgumentChecking.type_check(parent_mod, :parent_mod, NilClass, Module)
				mod, execute, specs, sub_specs, extra_argv, illegal_keys, parent_spec = spec_gen.__data
				
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
				inst = @mod.const_set(:Instance, Class.new(Parser::Instance))
				@mod.instance_variable_set(:@instance, inst)
				@mod.instance_variable_set(:@blueprint, self)
				
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
				
				puts
				puts("params:")
				@params.each_pair { |k, v| puts("    #{k} => #{v.inspect}") }
				puts("long_mappings:")
				@long_mappings.each_pair { |k, v| puts("    #{k} => #{v}") }
				puts("short_mappings:")
				@short_mappings.each_pair { |k, v| puts("    #{k} => #{v}") }
				puts("values:")
				@values.each_pair { |k, v| puts("    #{k} => #{v}") }
				
				nil
			end
			
			def parse(argv)
				
			end
			
		end
		
		module Parser
			
			# Called in order to specify arguments
			def spec(*args, **hash_args, &block)
				spec_gen = SpecGenerator.new(self, *args, **hash_args, &block)
				spec_gen.__generate
				nil
			end
			
			def parse(argv)
				ArgumentChecking.type_check(argv, :argv, Array)
				ArgumentChecking.type_check_each(argv, :argv, String) 
				# @instance.new(nil)
			end
			
			def show_params(instance)
				raise ArgumentError.new("Must be given an instance of #{self}::Instance") unless instance.is_a?(@instance)
			end
			
			class Instance
				
				attr_reader :help, :help_extra
				
				def initialize(data)
					show_params
				end
				
				def show_params
					self.class.const_get(:Mod).show_params(self)
				end
				
			end
		
		end
		
	end
	
end
