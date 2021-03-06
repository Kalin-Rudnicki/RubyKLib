
require_relative 'parse_class'
require_relative 'spec_stubs'
require_relative '../../validation/HashNormalizer'
require_relative '../../validation/ArgumentChecking'

module KLib
	
	module CLI
		
		class SpecGenerator
			
			attr_reader :comments
			
			def initialize(mod, *args, **hash_args, &block)
				raise ArgumentError.new("Block is required for spec creation") unless block
				ArgumentChecking.type_check(mod, :mod, Module, Symbol)
				raise ArgumentError.new("No current usage for args") if args.any?
				hash_args = HashNormalizer.normalize(hash_args) do |norm|
					norm.require_default.default_value(false).boolean_check
					norm.extra_argv.default_value(false).boolean_check # Collect into @argv = []
					norm.illegal_keys.default_value(:error).enum_check(:error, :warn, :no_warn) # ['--illegal-key'] => error: (error, illegal key), arg: (pretends it doesnt look like a key)
					norm.bad_keys.default_value(:error).enum_check(:error, :illegal)
					norm.comments(:comment).default_value([]).type_check(Array).type_check_each(String)
				end
				
				@mod = mod
				@execute = nil
				@specs = []
				@sub_specs = []
				@require_default = hash_args[:require_default]
				@extra_argv = hash_args[:extra_argv]
				@illegal_keys = hash_args[:illegal_keys]
				@bad_keys = hash_args[:bad_keys]
				@comments = hash_args[:comments]
				block.call(self)
				
				nil
			end
			
			def execute(&block)
				raise ArgumentError.new("You must supply a block to this method") unless block
				@execute = block
				nil
			end
			
			def sub_spec(name, *args, comment: [], aliases: [], **hash_args, &block)
				comment = Array(comment)
				
				ArgumentChecking.type_check(name, :name, Symbol)
				ArgumentChecking.type_check_each(aliases, :aliases, Symbol)
				ArgumentChecking.type_check(comment, :comment, String, NilClass, Array)
				ArgumentChecking.type_check_each(comment, :comment, String)
				raise ArgumentError.new("#{name.inspect} is not a valid sub_spec") unless CLI::LOWER_REGEX.match?(name.to_s)
				aliases.each { |a| raise ArgumentError.new("#{a.inspect} is not a valid alias") unless CLI::LOWER_REGEX.match?(a.to_s) }
				
				sub_spec = SpecGenerator.new(name, *args, **hash_args, &block)
				@sub_specs << { name: name, spec: sub_spec, aliases: aliases, comment: comment }
				nil
			end
			
			def integer(name, *args, **hash_args, &block)
				spec = IntegerSpec.new(name, @require_default, *args, **hash_args, &block)
				@specs << spec
				spec
			end
			alias :int :integer
			
			def float(name, *args, **hash_args, &block)
				spec = FloatSpec.new(name, @require_default, *args, **hash_args, &block)
				@specs << spec
				spec
			end
			
			def boolean(name, *args, **hash_args, &block)
				spec = BooleanSpec.new(name, @require_default, *args, **hash_args, &block)
				@specs << spec
				spec
			end
			
			def flag(name, *args, **hash_args, &block)
				spec = FlagSpec.new(name, *args, **hash_args, &block)
				@specs << spec
				spec
			end
			
			def symbol(name, *args, **hash_args, &block)
				spec = SymbolSpec.new(name, @require_default, *args, **hash_args, &block)
				@specs << spec
				spec
			end
			
			def string(name, *args, **hash_args, &block)
				spec = StringSpec.new(name, @require_default, *args, **hash_args, &block)
				@specs << spec
				spec
			end
			
			def __data
				[@mod, @execute, @specs, @sub_specs, @extra_argv, @illegal_keys, @bad_keys]
			end
			
			def __generate
				Blueprint.new(self)
			end
			
			# =====| SuperClass |=====
			
			class Spec
				
				DEFAULT_SPLIT = /\s*,\s*/
				attr_reader :name, :aliases, :default, :short, :comments, :comments_extra
				attr_reader :multi, :split
				attr_reader :validate_transform
				
				def initialize(name, deft_req, aliases)
					ArgumentChecking.type_check(name, :name, Symbol)
					ArgumentChecking.type_check(aliases, :aliases, Array)
					ArgumentChecking.type_check(deft_req, :deft_req, Boolean, Hash)
					ArgumentChecking.type_check_each(aliases, :aliases, Symbol)
					raise ArgumentError.new("#{name.inspect} is not a valid name") unless CLI::LOWER_REGEX.match?(name.to_s)
					aliases.each { |a| raise ArgumentError.new("#{a.inspect} is not a valid alias") unless CLI::LOWER_REGEX.match?(a.to_s) }
					
					@name = name
					@aliases = aliases
					@mappings = { @name => { to: @name, spec: self } }
					@aliases.each { |a| @mappings[a] = { to: @name } }
					
					@auto_trim = false
					@default = case deft_req
									  when true
										  { type: :required }
									  when false
										  { type: :optional }
									  when Hash
										  deft_req
									  else
										  raise "What is going on?"
								  end
					@priority = []
					@validate_transform = []
					@comments = []
					@comments_extra = []
					nil
				end
				
				def priority(*other_keys)
					ArgumentChecking.type_check_each(other_keys, :other_keys, Symbol)
					other_keys.each { |a| raise ArgumentError.new("#{a.inspect} is not a valid key") unless CLI::LOWER_REGEX.match?(a.to_s) }
					@priority.concat(other_keys)
					self
				end
				
				def comment(*comments)
					ArgumentChecking.type_check_each(comments, :comments, String)
					@comments += comments
					self
				end
				
				def help_name
					"#{@short.any? ? "#{"-#{@short.keys.first.to_s}".cyan}, " : ""}#{"--#{@name.to_s.tr('_', '-')}".cyan} #{@name.to_s.upcase.blue}"
				end
				
				def __parse(instance, parsed)
					raise "TODO"
				end
				
				def self.stubs(stub_arr)
					ArgumentChecking.type_check_each(stub_arr, :stub_arr, Symbol)
					stub_arr.each do |method_name|
						# puts(Stubs.instance_method(method_name).inspect)
						define_method(method_name, Stubs.instance_method(method_name))
					end
				end
			
			end
			
			# =====| Classes |=====
			
			class IntegerSpec < Spec
				
				stubs(%i{
			auto_trim transform validate
			required optional default_value default_from default_proc required_if required_if_present required_if_absent required_if_bool
			positive non_negative greater_than gt greater_than_equal_to gt_et less_than lt less_than_equal_to lt_et
			one_of
					})
				
				def initialize(name, deft_req, aliases: [], multi: :error, split: false, short: nil, &block)
					super(name, deft_req, aliases)
					
					ArgumentChecking.enum_check(multi, :multi, %i{error error_different first last all flatten})
					ArgumentChecking.type_check(split, :split, Boolean, String, Regexp)
					ArgumentChecking.type_check(short, :short, NilClass, Symbol)
					raise ArgumentError.new("short must be a single upper or lower case letter") unless short.nil? || /^[A-Za-z]$/.match?(short.to_s)
					raise ArgumentError.new("{ multi: :flatten } only allowed when { split: true }") if split == false && multi == :flatten
					split = DEFAULT_SPLIT if split == true
					
					@multi = multi
					@split = split
					
					validate(proc { |val| "#{val.inspect} does not look like an integer" }) { |val| /^-?(0x)?\d+$/.match?(val) }
					transform do |val|
						case val
							when /^-?0x\d+$/
								val.to_i(16)
							when /^-?\d+$/
								val.to_i(10)
							else
								raise "What is going on?"
						end
					end
					
					@short = short.nil? ? {} : { short => @name }
					@comments_extra << "Integer"
					
					block.call(self) if block
					nil
				end
			
			end
			
			class FloatSpec < Spec
				
				stubs(%i{
			auto_trim transform validate
			required optional default_value default_from default_proc required_if required_if_present required_if_absent required_if_bool
			positive non_negative greater_than gt greater_than_equal_to gt_et less_than lt less_than_equal_to lt_et
					})
				
				def initialize(name, deft_req, aliases: [], multi: :error, split: false, short: nil, &block)
					super(name, deft_req, aliases)
					
					ArgumentChecking.enum_check(multi, :multi, %i{error error_different first last all flatten})
					ArgumentChecking.type_check(split, :split, Boolean, String, Regexp)
					ArgumentChecking.type_check(short, :short, NilClass, Symbol)
					raise ArgumentError.new("short must be a single upper or lower case letter") unless short.nil? || /^[A-Za-z]$/.match?(short.to_s)
					raise ArgumentError.new("{ multi: :flatten } only allowed when { split: true }") if split == false && multi == :flatten
					split = DEFAULT_SPLIT if split == true
					
					@multi = multi
					@split = split
					
					validate(proc { |val| "#{val.inspect} does not look like a float" }) { |val| /^-?\d+(\.\d+)?$/.match?(val) }
					transform { |val| val.to_f }
					
					@short = short.nil? ? {} : { short => @name }
					@comments_extra << "Float"
					
					block.call(self) if block
					nil
				end
			
			end
			
			class BooleanSpec < Spec
				
				stubs(%i{
			validate
			required optional default_value default_from default_proc required_if required_if_present required_if_absent required_if_bool
					})
				
				def initialize(name, deft_req, aliases: [], multi: :error, positive: nil, negative: :no, short: nil, &block)
					super(name, deft_req, aliases)
					
					ArgumentChecking.enum_check(multi, :multi, %i{error error_different first last})
					
					ArgumentChecking.type_check(positive, :positive, Symbol, NilClass)
					ArgumentChecking.type_check(negative, :negative, Symbol, NilClass)
					ArgumentChecking.type_check(short, :short, NilClass, Symbol)
					raise ArgumentError.new("short must be a single upper or lower case letter") unless short.nil? || /^[A-Za-z]?_[A-Za-z]?$/.match?(short.to_s)
					raise ArgumentError.new("positive and negative can not be the same") if positive == negative
					raise ArgumentError.new("#{positive.inspect} is not a valid positive") unless positive.nil? || CLI::LOWER_REGEX.match?(positive.to_s)
					raise ArgumentError.new("#{negative.inspect} is not a valid negative") unless negative.nil? || CLI::LOWER_REGEX.match?(negative.to_s)
					
					@multi = multi
					
					@positive = positive
					@negative = negative
					
					@pos = @positive.nil? ? @name : :"#{@positive}_#{@name}"
					@neg = @negative.nil? ? @name : :"#{@negative}_#{@name}"
					
					@short = {}
					unless short.nil?
						t, f = short.to_s.split('_')
						raise "positive-short can not equal negative-short" if t == f
						@short[t.to_sym] = @pos if t.length > 0
						@short[f.to_sym] = @neg if f.length > 0
					end
					
					@mappings = {}
					@mappings[@pos] = { to: @pos, val: true, spec: self }
					if @positive.nil?
						@aliases.each { |a| @mappings[a] = { to: @pos } }
					else
						@aliases.each { |a| @mappings[:"#{@positive}_#{a}"] = { to: @pos } }
					end
					@mappings[@neg] = { to: @neg, val: false, spec: self }
					if @negative.nil?
						@aliases.each { |a| @mappings[a] = { to: @neg } }
					else
						@aliases.each { |a| @mappings[:"#{@negative}_#{a}"] = { to: @neg } }
					end
					
					@comments_extra << "Boolean"
					
					block.call(self) if block
					nil
				end
				
				def help_name
					short = nil
					if @short.any?
						inv = @short.invert
						if @positive
							if @negative
								short = "-(#{inv[@pos]}/#{inv[@neg]})"
							else
								short = "-[#{inv[@pos]}]#{inv[@neg]}"
							end
						else
							if @negative
								short = "-[#{inv[@neg]}]#{inv[@pos]}"
							else
								raise "What is going on?"
							end
						end
					end
					long = ""
					if @positive
						if @negative
							long = "--(#{@positive.to_s.tr('_', '-')}/#{@negative.to_s.tr('_', '-')}})-#{@name.to_s.tr('_', '-')}"
						else
							long = "--[#{@positive.to_s.tr('_', '-')}-]#{@name.to_s.tr('_', '-')}"
						end
					else
						if @negative
							long = "--[#{@negative.to_s.tr('_', '-')}-]#{@name.to_s.tr('_', '-')}"
						else
							raise "What is going on?"
						end
					end
					"#{short.nil? ? "" : "#{short.cyan}, "}#{long.cyan}"
				end
				
			end
			
			class FlagSpec < Spec
				
				stubs(%i{
			validate
						})
				
				def initialize(name, aliases: [], multi: :error, default: false, positive: nil, negative: :no, short: nil, &block)
					# TODO[LOW] : default multi might make more sense as ignore?
					super(name, { type: :default_value, value: default }, aliases)
					
					ArgumentChecking.enum_check(multi, :multi, %i{error ignore})
					
					ArgumentChecking.boolean_check(default, :default)
					ArgumentChecking.type_check(positive, :positive, Symbol, NilClass)
					ArgumentChecking.type_check(negative, :negative, Symbol, NilClass)
					ArgumentChecking.type_check(short, :short, NilClass, Symbol)
					raise ArgumentError.new("short must be a single upper or lower case letter") unless short.nil? || /^[A-Za-z]?_[A-Za-z]?$/.match?(short.to_s)
					raise ArgumentError.new("positive and negative can not be the same") if positive == negative
					raise ArgumentError.new("#{positive.inspect} is not a valid positive") unless positive.nil? || CLI::LOWER_REGEX.match?(positive.to_s)
					raise ArgumentError.new("#{negative.inspect} is not a valid negative") unless negative.nil? || CLI::LOWER_REGEX.match?(negative.to_s)
					
					@multi = multi
					
					@dft = default
					@positive = positive
					@negative = negative
					
					@pos = @positive.nil? ? @name : :"#{@positive}_#{@name}"
					@neg = @negative.nil? ? @name : :"#{@negative}_#{@name}"
					
					@short = {}
					unless short.nil?
						t, f = short.to_s.split('_')
						if @dft
							@short[f.to_sym] = @neg if f.length > 0
						else
							@short[t.to_sym] = @pos if t.length > 0
						end
					end
					
					@mappings = {}
					if @dft
						@mappings[@neg] = { to: @neg, val: false, spec: self }
						if @negative.nil?
							@aliases.each { |a| @mappings[a] = { to: @neg } }
						else
							@aliases.each { |a| @mappings[:"#{@negative}_#{a}"] = { to: @neg } }
						end
					else
						@mappings[@pos] = { to: @pos, val: true, spec: self }
						if @positive.nil?
							@aliases.each { |a| @mappings[a] = { to: @pos } }
						else
							@aliases.each { |a| @mappings[:"#{@positive}_#{a}"] = { to: @pos } }
						end
					end
					
					@comments_extra << "Flag"
					
					block.call(self) if block
					nil
				end
				
				def help_name
					short = @short.any? ? "-#{@short.keys.first}" : nil
					if @dft
						if @negative
							long = "--#{@negative.to_s.tr('_', '-')}-#{@name.to_s.tr('_', '-')}"
						else
							long = "--#{@name.to_s.tr('_', '-')}"
						end
					else
						if @positive
							long = "--#{@positive.to_s.tr('_', '-')}-#{@name.to_s.tr('_', '-')}"
						else
							long = "--#{@name.to_s.tr('_', '-')}"
						end
					end
					"#{short.nil? ? "" : "#{short.cyan}, "}#{long.cyan}"
				end
			
			end
			
			class SymbolSpec < Spec
				
				stubs(%i{
			auto_trim transform validate
			required optional default_value default_from default_proc required_if required_if_present required_if_absent required_if_bool
			one_of
					})
				
				def initialize(name, deft_req, aliases: [], multi: :error, split: false, short: nil, &block)
					super(name, deft_req, aliases)
					
					ArgumentChecking.enum_check(multi, :multi, %i{error error_different first last all flatten})
					ArgumentChecking.type_check(split, :split, Boolean, String, Regexp)
					ArgumentChecking.type_check(short, :short, NilClass, Symbol)
					raise ArgumentError.new("short must be a single upper or lower case letter") unless short.nil? || /^[A-Za-z]$/.match?(short.to_s)
					raise ArgumentError.new("{ multi: :flatten } only allowed when { split: true }") if split == false && multi == :flatten
					split = DEFAULT_SPLIT if split == true
					
					@multi = multi
					@split = split
					
					transform { |val| val.to_sym }
					
					@short = short.nil? ? {} : { short => @name }
					@comments_extra << "String"
					
					block.call(self) if block
					nil
				end
			
			end
			
			class StringSpec < Spec
				
				stubs(%i{
			auto_trim transform validate
			required optional default_value default_from default_proc required_if required_if_present required_if_absent required_if_bool
					})
				
				def initialize(name, deft_req, aliases: [], multi: :error, split: false, short: nil, &block)
					super(name, deft_req, aliases)
					
					ArgumentChecking.enum_check(multi, :multi, %i{error error_different first last all flatten})
					ArgumentChecking.type_check(split, :split, Boolean, String, Regexp)
					ArgumentChecking.type_check(short, :short, NilClass, Symbol)
					raise ArgumentError.new("short must be a single upper or lower case letter") unless short.nil? || /^[A-Za-z]$/.match?(short.to_s)
					raise ArgumentError.new("{ multi: :flatten } only allowed when { split: true }") if split == false && multi == :flatten
					split = DEFAULT_SPLIT if split == true
					
					@multi = multi
					@split = split
					
					@short = short.nil? ? {} : { short => @name }
					@comments_extra << "String"
					
					block.call(self) if block
					nil
				end
				
				def is_path
					validate(proc { |val, name| "#{name} is not a valid path, given: #{val}" }) { |val| File.exist?(val) }
					transform { |val| val.gsub("\\", "/") }
					self
				end
				
				def is_dir
					is_path
					validate(proc { |val, name| "#{name} is not a directory, given: #{val}" }) { |val| File.directory?(val) }
					self
				end
				
				def is_file(file_ext = nil)
					ArgumentChecking.type_check(file_ext, :file_ext, String, NilClass)
					validate(proc { |val, name| "File extension for #{name} must end in '#{file_ext}', given: '#{File.extname(val)}'" }) { |val| File.extname(val) == file_ext } unless file_ext.nil?
					is_path
					validate(proc { |val, name| "#{name} is not a file, given: #{val}" }) { |val| File.file?(val) }
					self
				end
				
				def has_parent_dir(file_ext = nil)
					ArgumentChecking.type_check(file_ext, :file_ext, String, NilClass)
					validate(proc { |val, name| "File extension for #{name} must end in '#{file_ext}', given: '#{File.extname(val)}'" }) { |val| File.extname(val) == file_ext } unless file_ext.nil?
					validate(proc { |val, name| "#{name} does not have a valid parent directory: #{File.expand_path(File.join(val, '..'))}" }) do |val|
						parent = File.expand_path(File.join(val, '..'))
						File.exist?(parent) && File.directory?(parent)
					end
					self
				end
			
			end
		
		end
	
	
	end
	
end
