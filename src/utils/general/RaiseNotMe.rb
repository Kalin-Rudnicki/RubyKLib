
Dir.chdir(File.dirname(__FILE__)) do
	require './../parsing/TraceParse'
end

module KLib
	
	RAISE_IGNORE = []
	
	module RaiseNotMe
		
		def raise_not_me(exception)
			if exception.is_a?(String)
				exception = RuntimeError.new(exception)
			elsif exception.is_a?(Exception)
			else
				raise ArgumentError.new("No explicit conversion of [#{exception.class.inspect}] to one of [String, Exception].")
			end
			puts Trace.call_trace(false)
			trace = KLib::Trace.call_trace
			
			ignore = ([trace[0].file] + RAISE_IGNORE).uniq
			KLib::RAISE_IGNORE.clear
			
			puts("ignoring: #{ignore.inspect}")
			
			if !ENV.key?('RAISE_NOT_ME') && trace.any? { |t| !ignore.include?(t.file) }
				trace = trace.select { |t| !ignore.include?(t.file) }
			end
			trace = trace.map { |t| t.str }
			exception.set_backtrace(trace)
			raise exception
		end
		
		def self.ignore_me(&block)
			raise ArgumentError.new("You must supply a block to this method.") unless block_given?
			RAISE_IGNORE.unshift(__FILE__).unshift(Trace.call_trace[0].file)
			block.call
			RAISE_IGNORE.shift
			RAISE_IGNORE.shift
			nil
		end
		
	end
	
end

class Object
	extend(KLib::RaiseNotMe)
	include(KLib::RaiseNotMe)
end
