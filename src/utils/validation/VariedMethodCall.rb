
Dir.chdir(File.dirname(__FILE__)) do
	require './ArgumentChecking'
	require './../version_compat/BasicObject'
end

module KLib
	
	module VariedMethodCall
		
		def self.parse(args, &block)
			ArgumentChecking.type_check(args, 'args', Array)
			parser = Parser.new(&block)
			options = parser.__options
			
			options.each do |opt|
				next unless opt.length?(args.length)
				valid = true
				opt.before.length.times do |idx|
					arg = args[idx]
					exp = opt.before[idx]
					case exp
						when :any
						when Module
							unless arg.is_a?(exp)
								valid = false
								break
							end
						when Array
							unless exp.any? { |a| arg.is_a?(a) }
								valid = false
								break
							end
						else
							raise "Whats going on..."
					end
				end
				if valid
					opt.after.length.times do |idx|
						arg = args[args.length - opt.after.length + idx]
						exp = opt.after[idx]
						case exp
							when :any
							when Module
								unless arg.is_a?(exp)
									valid = false
									break
								end
							when Array
								unless exp.any? { |a| arg.is_a?(a) }
									valid = false
									break
								end
							else
								raise "Whats going on..."
						end
					end
				end
				return opt.proc.call(args) if valid
			end
			raise NoValidOptions.new(args, options) unless parser.__default
			parser.__default.call(args)
		end
		
		class NoValidOptions < RuntimeError
		
			def initialize(args, options)
				@args = args
				@options = options
				super("No valid options for: #{args.inspect}")
			end
			
		end
		
		class Parser < BasicObject
			
			def initialize(&block)
				::Kernel::raise ::ArgumentError.new("You must supply a block to initialize the Parser.") unless ::Kernel::block_given?
				@options = []
				@default_proc = nil
				block.(self)
			end
			
			def on(*args, &block)
				::Kernel::raise ::ArgumentError.new("You must supply a block depicting the array you would like to receive.") unless ::Kernel::block_given?
				invalid = []
				args.each do |arg|
					next if arg == :any || arg == :args
					next if arg.is_a?(::Module)
					next if arg.is_a?(::Array) && arg.any? && arg.select { |a| !a.is_a?(::Module) }.empty?
					invalid << arg
				end
				::Kernel::raise ::ArgumentError.new("Invalid args configuration... Invalid: #{invalid.inspect}") if invalid.any?
				num_args = args.count { |arg| arg == :args }
				::Kernel::raise ::ArgumentError.new("You can only have up to 1 ':args', you supplied #{num_args}") if num_args > 1
				@options << Option.new(args, block)
			end
			
			def default(&block)
				@default_proc = block
			end
			
			def __options
				@options
			end
			
			def __default
				@default_proc
			end
			
			class Option
				
				attr_reader :proc, :before, :after, :args
				
				def initialize(args, proc)
					args = args.dup
					@before = []
					@before << args.shift while args.any? && args.first != :args
					@args = args.any?
					args.shift
					@after = args
					@length = @before.length + @after.length
					@proc = proc
				end
				
				def length?(length)
					@args ? length >= @length : length == @length
				end
				
			end
			
		end
	
	end
	
end


