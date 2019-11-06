
Dir.chdir(File.dirname(__FILE__)) do
	require 'set'
	require './../validation/ArgumentChecking'
	require './../validation/HashNormalizer'
	require './../formatting/ColorString'
end

module KLib
	
	class LogLevel
		
		attr_reader :priority, :name
		
		def initialize(priority, name)
			ArgumentChecking.type_check(priority, 'priority', Integer)
			ArgumentChecking.type_check(name, 'name', Symbol)
			@priority = priority
			@name = name
			self.output_name = name
			@color = :default
		end
		
		def output_name= (name)
			ArgumentChecking.type_check(name, 'name', Symbol)
			@output_name = name.to_s
			nil
		end
		
		def output_name
			@output_name
		end
		
		def output
			@output_name.send(@color)
		end
		
		def color= (color_name)
			ArgumentChecking.type_check(color_name, 'color_name', Symbol)
			@color = color_name
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
			calc_max_length
		end
		
		def [] (name)
			ArgumentChecking.type_check(name, 'name', Symbol)
			raise NoSuchLogLevelError.new(name) unless @levels.key?(name)
			@levels[name]
		end
		
		def valid_levels
			@levels.keys
		end
		
		def alias_levels(aliases = {})
			ArgumentChecking.check do |check|
				check.aliases.type_check(Hash)
				check.aliases(:keys).type_check_each(Symbol)
				check.aliases(:values).type_check_each(Symbol)
			end
			
			aliases.each_pair do |level_name, aliased_name|
				raise ArgumentError.new("No such level '#{level_name}'") unless @levels.key?(level_name)
				
				@levels[level_name].output_name = aliased_name
				calc_max_length
			end
			
			nil
		end
		
		def color_levels(colors = {})
			ArgumentChecking.check do |check|
				check.colors.type_check(Hash)
				check.colors(:keys).type_check_each(Symbol)
				check.colors(:values).type_check_each(Symbol)
			end
			colors.each_pair do |level_name, color_name|
				raise ArgumentError.new("No such level '#{level_name}'") unless @levels.key?(level_name)
				
				@levels[level_name].color = color_name
			end
			
			nil
		end
		
		private
			
			def calc_max_length
				@max_length = @levels.values.max { |l1, l2| l1.output_name.length <=> l2.output_name.length }.output_name.length
				nil
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
	
	class LogLevelManager
		
		DEFAULT_LOG_LEVELS = %i{never debug detailed info print important warning error fatal always off}
		DEFAULT_LOG_LEVEL_MANAGER = LogLevelManager.new(*DEFAULT_LOG_LEVELS)
		
		DEFAULT_LOG_LEVEL_MANAGER.alias_levels(
			:never => :NEVER,
			:debug => :DEBUG,
			:detailed => :DETLD,
			:info => :INFO,
			:print => :PRINT,
			:important => :IMPRT,
			:error => :ERROR,
			:warning => :WARN,
			:fatal => :FATAL,
			:always => :ALWYS,
			:off => :OFF
		)
		
		DEFAULT_LOG_LEVEL_MANAGER.color_levels(
			:never => :blue,
			:debug => :cyan,
			:detailed => :green,
			:info => :green,
			:print => :default,
			:important => :yellow,
			:warning => :yellow,
			:error => :red,
			:fatal => :red,
			:always => :default,
			:off => :blue
		)
	
	end
	
	class Logger < BasicObject
		
		attr_reader :indent
		
		def initialize(hash_args = {})
			hash_args = HashNormalizer.normalize(hash_args) do |norm|
				norm.level_manager.default_value(::KLib::LogLevelManager::DEFAULT_LOG_LEVEL_MANAGER).type_check(::KLib::LogLevelManager)
				norm.log_tolerance(:tolerance, :tol).required.type_check(::Symbol)
				
				norm.default_out(:out).default_value($stdout).type_check(::IO, ::String)
				norm.default_err(:err).default_value($stderr).type_check(::IO, ::String)
				
				norm.indent_string(:indent).default_value('    ').type_check(::String)
				
				norm.display_level.default_value(true).type_check(::Boolean)
				norm.display_thread.default_value(false).type_check(::Boolean)
				norm.display_time.default_value(false).type_check(::Boolean)
			end
			
			@log_level_manager = hash_args[:level_manager]
			@log_tolerances = {}
			@all_sources = ::Set.new
			@sources = [:out, :err].map { |target| [target, {}] }.to_h
			@display_params = {}
			@indent_string = hash_args[:indent_string]
			@indent = Indent.new
			
			@mutex = ::Mutex.new
			
			set_log_tolerance(hash_args[:log_tolerance])
			set_display([:level, :thread, :time].map { |k| [k, hash_args["display_#{k}".to_sym]] }.to_h)
			add_source(hash_args[:default_out], :target => :out, :range => :over)
			add_source(hash_args[:default_err], :target => :err, :range => :over)
		end
		
		def set_log_tolerance(log_level_name, hash_args = {})
			::KLib::ArgumentChecking.type_check(log_level_name, 'log_level_name', ::Symbol)
			hash_args = ::KLib::HashNormalizer.normalize(hash_args) do |norm|
				norm.rule.default_value(:default).type_check(::Symbol)
			end
			@log_tolerances[hash_args[:rule]] = @log_level_manager[log_level_name]
		end
		
		def set_display(hash_args = {})
			hash_args = ::KLib::HashNormalizer.normalize(hash_args) do |norm|
				norm.level.no_default.type_check(::Boolean)
				norm.thread.no_default.type_check(::Boolean)
				norm.time.no_default.type_check(::Boolean)
			end
			@display_params.merge!(hash_args)
		end
		
		def add_source(source, hash_args = {})
			::KLib::ArgumentChecking.type_check(source, 'source', ::IO, ::String)
			if source.is_a?(::String)
				begin
					File.new(source, 'w').close
				rescue => e
					raise ::RuntimeError.new("Issue creating file '#{source}'. [#{e.class.inspect}]")
				end
			end
			hash_args = ::KLib::HashNormalizer.normalize(hash_args) do |norm|
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
			::KLib::ArgumentChecking.type_check(log_level_name, 'log_level_name', ::Symbol)
			hash_args = ::KLib::HashNormalizer.normalize(hash_args) do |norm|
				norm.target(:to).default_value(:out).enum_check(:out, :err)
				norm.rule.default_value(:default).type_check(::Symbol)
				norm.time.default_value(::Time.now).type_check(::Time)
			end
			
			log_tolerance = @log_tolerances.key?(hash_args[:rule]) ? @log_tolerances[hash_args[:rule]] : @log_tolerances[:default]
			log_level = @log_level_manager[log_level_name]
			
			range = (log_level <=> log_tolerance) >= 0 ? :over : :under
			
			@mutex.synchronize do
				header_1, header_2 = log_headers(log_level, hash_args[:time])
				idt_str = @indent_string * @indent.value
				value = "#{header_1}#{idt_str}#{value.gsub("\n", "\n#{header_2}#{idt_str}")}"
				@sources[hash_args[:target]].each_pair do |src, src_hash|
					if src_hash[:ranges].include?(range)
						if src.is_a?(::String)
							auto_close = true
							src = ::File.new(src, 'a')
						else
							auto_close = false
						end
						unless src_hash[:break].nil?
							#TODO: break time
							src.puts("#{header_2}")
							src_hash[:break] = nil
						end
						src.puts(value)
						src.close if auto_close
					end
				end
			end
		end
		
		def break(hash_args = {})
			hash_args = ::KLib::HashNormalizer.normalize(hash_args) do |norm|
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
					@indent + 1
					@sources.each_value do |target|
						target.each_value do |src_hash|
							src_hash[:break] = :open
						end
					end
				when :close
					@indent - 1
					@sources.each_value do |target|
						target.each_value do |src_hash|
							src_hash[:break] = src_hash[:break] == :open ? nil : :normal
						end
					end
			end
		end
		
		def method_missing(sym, *args, &block)
			if @log_level_manager.valid_levels.include?(sym)
				log(sym, *args, &block)
			else
				::Kernel.raise ::NoMethodError.new("No such method or log-level '#{sym}'")
			end
		end
		
		class SourceAlreadyAddedError < ::RuntimeError
			attr_reader :source
			def initialize(source)
				@source = source
				super("Source already added: #{source}")
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
					return str, "[#{' ' * (str.gsub(/\e\[(\d+)(;\d+)*m/, '').length - 3)}] "
				end
			
			end
			
			class Indent < ::BasicObject
				
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
					header << (level.output.to_s + (' ' * (@log_level_manager.max_length - level.output_name.length))) if @display_params[:level]
					header << "T_#{::Thread.current.object_id}" if @display_params[:thread]
					header << time.strftime('%m/%d/%y - %I:%M:%S.%L %p') if @display_params[:time]
					header.build
				else
					['', '']
				end
			end
	
	end

end
