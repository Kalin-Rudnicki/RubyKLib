
Dir.chdir(File.dirname(__FILE__)) do
	require 'set'
	require './../validation/ArgumentChecking'
	require './../validation/HashNormalizer'
end

module KLib

	module Logging
		
		class LogLevel
			
			attr_reader :priority, :name
			
			def initialize(priority, name)
				ArgumentChecking.type_check(priority, 'priority', Integer)
				ArgumentChecking.type_check(name, 'name', Symbol)
				@priority = priority
				@name = name
			end
			
			def <=> (other_level)
				other_level.is_a?(LogLevel) ? self.priority <=> other_level.priority : nil
			end
		
		end
		
		class LogLevelManager
			
			attr_reader :max_length
			
			def initialize(*levels)
				ArgumentChecking.type_check_each(levels, 'levels', Symbol)
				@levels = {}
				levels.each do |level_name|
					raise DuplicateLevelError.new(level_name) if @levels.key?(level_name)
					@levels[level_name] = LogLevel.new(@levels.size + 1, level_name)
				end
				@max_length = @levels.values.max { |l1, l2| l1.name.to_s.length <=> l2.name.to_s.length }.name.to_s.length
			end
			
			def [] (name)
				ArgumentChecking.type_check(name, 'name', Symbol)
				raise NoSuchLogLevelError.new(name) unless @levels.key?(name)
				@levels[name]
			end
			
			def valid_levels
				@levels.keys
			end
			
			class DuplicateLevelError < RuntimeError
				attr_reader :level_name
				def initialize(level_name)
					ArgumentChecking.type_check(level_name, 'level_name', Symbol)
					@level_name = level_name
					super("Level already exists: '#{level_name}'")
				end
			end
			
			class NoSuchLogLevelError < RuntimeError
				attr_reader :level_name
				def initialize(level_name)
					ArgumentChecking.type_check(level_name, 'level_name', Symbol)
					@level_name = level_name
					super("No such log level: '#{level_name}'")
				end
			end
			
		end
		
		DEFAULT_LOG_LEVEL_MANAGER = KLib::Logging::LogLevelManager.new(:never, :debug, :detailed, :info, :print, :important, :error, :fatal, :always)
		
		class Logger
			
			DEFAULT_INDENT = '    '
			
			attr_reader :indent
			
			def initialize(hash_args = {})
				hash_args = HashNormalizer.normalize(hash_args) do |norm|
					norm.level_manager.default_value(::KLib::Logging::DEFAULT_LOG_LEVEL_MANAGER).type_check(::KLib::Logging::LogLevelManager)
					norm.log_tolerance(:tolerance, :tol).required.type_check(::Symbol)
					
					norm.default_out(:out).default_value($stdout).type_check(::IO)
					norm.default_err(:err).default_value($stderr).type_check(::IO)
					
					norm.indent_string(:indent).default_value(::KLib::Logging::Logger::DEFAULT_INDENT).type_check(::String)
					
					norm.display_level.default_value(true).type_check(::Boolean)
					norm.display_thread.default_value(false).type_check(::Boolean)
					norm.display_time.default_value(true).type_check(::Boolean)
				end
				
				@log_level_manager = hash_args[:level_manager]
				@log_tolerances = {}
				@all_sources = Set.new
				@sources = [:out, :err].map { |target| [target, {}] }.to_h
				@display_params = {}
				@indent_string = hash_args[:indent_string]
				@indent = Indent.new
				
				set_log_tolerance(hash_args[:log_tolerance])
				set_display([:level, :thread, :time].map { |k| [k, hash_args["display_#{k}".to_sym]] }.to_h)
				add_source(hash_args[:default_out], :target => :out, :range => :over)
				add_source(hash_args[:default_err], :target => :err, :range => :over)
			end
			
			def set_log_tolerance(log_level_name, hash_args = {})
				ArgumentChecking.type_check(log_level_name, 'log_level_name', Symbol)
				hash_args = HashNormalizer.normalize(hash_args) do |norm|
					norm.rule.default_value(:default).type_check(::Symbol)
				end
				@log_tolerances[hash_args[:rule]] = @log_level_manager[log_level_name]
			end
			
			def set_display(hash_args = {})
				hash_args = HashNormalizer.normalize(hash_args) do |norm|
					norm.level.no_default.type_check(::Boolean)
					norm.thread.no_default.type_check(::Boolean)
					norm.time.no_default.type_check(::Boolean)
				end
				@display_params.merge!(hash_args)
			end
			
			def add_source(source, hash_args = {})
				ArgumentChecking.type_check(source, 'source', IO)
				hash_args = HashNormalizer.normalize(hash_args) do |norm|
					norm.target.required.enum_check(:out, :err)
					norm.range.required.enum_check(:always, :over, :under)
				end
				raise SourceAlreadyAddedError.new(source) if @all_sources.include?(source)
				@all_sources << source
				@sources[hash_args[:target]][source] = { :ranges => hash_args[:range] == :always ? [:over, :under] : [hash_args[:range]], :break => nil }
			end
			
			def valid_levels
				@log_level_manager.valid_levels
			end
			
			def valid_rules
				@log_tolerances.keys
			end
			
			def log(log_level_name, value, hash_args = {})
				time = Time.now
				ArgumentChecking.type_check(log_level_name, 'log_level_name', Symbol)
				hash_args = HashNormalizer.normalize(hash_args) do |norm|
					norm.target(:to).default_value(:out).enum_check(:out, :err)
					norm.rule.default_value(:default).type_check(::Symbol)
				end
				raise NoSuchRuleError.new(hash_args[:rule]) unless @log_tolerances.key?(hash_args[:rule])
				log_tolerance = @log_tolerances[hash_args[:rule]]
				log_level = @log_level_manager[log_level_name]
				
				range = (log_level <=> log_tolerance) >= 0 ? :over : :under
				
				header_1, header_2 = log_headers(log_level, time)
				idt_str = @indent_string * @indent.value
				value = "#{header_1}#{idt_str}#{value.gsub("\n", "\n#{header_2}#{idt_str}")}"
				@sources[hash_args[:target]].each_pair do |src, src_hash|
					if src_hash[:ranges].include?(range)
						unless src_hash[:break].nil?
							#TODO: break time
							src.puts("#{header_2}")
							src_hash[:break] = nil
						end
						src.puts(value)
					end
				end
			end
			
			def break(hash_args = {})
				hash_args = HashNormalizer.normalize(hash_args) do |norm|
					norm.type.default_value(:normal).enum_check(:normal, :close, :open)
				end
				case hash_args[:type]
					when :normal
						@sources.each_value do |target|
							target.each_value do |src_hash|
								src_hash[:break] = :normal unless src_hash[:break] == :open
							end
						end
					when :open
						@sources.each_value do |target|
							target.each_value do |src_hash|
								src_hash[:break] = :open
							end
						end
					when :close
						@sources.each_value do |target|
							target.each_value do |src_hash|
								src_hash[:break] = src_hash[:break] == :open ? nil : :normal
							end
						end
				end
			end
		
			class SourceAlreadyAddedError < RuntimeError
				attr_reader :source
				def initialize(source)
					@source = source
					super("Source already added: #{source}")
				end
			end
			class NoSuchRuleError < RuntimeError
				attr_reader :rule_name
				def initialize(rule_name)
					@rule_name = rule_name
					super("No such rule: '#{rule_name}'")
				end
			end
			
			private
			
				class HeaderBuilder
					
					def initialize
						@str = '['
					end
					
					def << (item)
						@str << ' | ' unless @str.length == 1
						@str << item
					end
					
					def build
						str = "#{@str}] "
						return str, "[#{' ' * (str.length - 3)}] "
					end
					
				end
				
				class Indent < BasicObject
					
					def initialize
						@indent = 0
					end
					
					def value
						@indent
					end
					
					def + (val)
						::KLib::ArgumentChecking.type_check(val, 'val', ::Integer)
						::Kernel::raise ::RuntimeError.new("Resulting indent must be >= 0, #{@indent} + #{val} = #{@indent + val}") unless @indent + val >= 0
						@indent += val
						nil
					end
					
					def - (val)
						::KLib::ArgumentChecking.type_check(val, 'val', ::Integer)
						self + -val
					end
					
				end
				
				def log_headers(level, time)
					if @display_params.any? { |k, v| v }
						header = HeaderBuilder.new
						header << level.name.to_s.upcase.ljust(@log_level_manager.max_length) if @display_params[:level]
						header << "T_#{Thread.current.object_id}" if @display_params[:thread]
						header << time.strftime('%m/%d/%y - %I:%M:%S.%L %p') if @display_params[:time]
						return header.build
					else
						return '', ''
					end
				end
			
		end
		
	end

end
