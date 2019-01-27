
module KLib
	
	module CommandLineParsing
	
		class << self
		
			def split(str)
				ArgumentChecking.type_check(str, 'str', String)
				found = []
				
				exp_stack = []
				char_queue = ''
				
				str.each_char do |c|
					if exp_stack.empty?
						if [" ", "\t"].include?(c)
							if char_queue.length > 0
								found << char_queue
								char_queue = ''
							end
						elsif c == ?"
							if char_queue.length > 0
								found << char_queue
								char_queue = ''
							end
							exp_stack.unshift(?")
						else
							char_queue << c
						end
					elsif exp_stack.first == ?"
						if c == ?"
							if char_queue.length > 0
								found << char_queue
								char_queue = ''
							end
							exp_stack.shift
						else
							char_queue << c
						end
					end
				end
				if exp_stack.any?
					raise ParseError.new("Unclosed: #{exp_stack.inspect}")
				elsif char_queue.length > 0
					found << char_queue
				end
				
				found
			end
			
			def parse_arg(str)
				ArgumentChecking.type_check(str, 'str', String)
				nil
			end
			
			def parse_hash_arg(str)
				ArgumentChecking.type_check(str, 'str', String)
				nil
			end
		
		end
	
		class ParseError < RuntimeError; end
		
	end
	
end
