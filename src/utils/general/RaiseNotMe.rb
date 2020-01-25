
require_relative '../parsing/TraceParse'

module KLib
	
	RAISE_IGNORE = []
	
	module RaiseNotMe
		
		def raise_not_me(exception)
			if exception.is_a?(String)
				exception = StandardError.new(exception)
			elsif exception.is_a?(Exception)
			else
				raise ArgumentError.new("No explicit conversion of [#{exception.class.inspect}] to one of [String, Exception].")
			end
			trace = KLib::Trace.call_trace
			
			ignore = ([trace[0].file] + RAISE_IGNORE).uniq
			KLib::RAISE_IGNORE.clear
			
			case KLib::Env[:raise_not_me]
				when :ALL
					trace.select! { |t| !ignore.include?(t.file) }
				when :START
					trace.shift while trace.any? && ignore.include?(trace.first.file)
				when :NONE
				else
					raise "What is going on?"
			end
			
			trace = trace.map { |t| t.str }
			exception.set_backtrace(trace)
			raise exception
		end
		
		def self.ignore_me(&block)
			raise ArgumentError.new("You must supply a block to this method.") unless block_given?
			begin
				RAISE_IGNORE.unshift(__FILE__).unshift(Trace.call_trace[0].file)
				block.call
			ensure
				RAISE_IGNORE.shift
				RAISE_IGNORE.shift
			end
			nil
		end
		
	end
	
end

class Object
	extend(KLib::RaiseNotMe)
	include(KLib::RaiseNotMe)
end

require_relative 'KLibEnv'
KLib::Env.var(:raise_not_me, :KL_RAISE_NOT_ME, :ALL, :START, :NONE, default: :START)