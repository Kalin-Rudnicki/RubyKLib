
require_relative '../../../src/utils/general/Source'

string = nil
Dir.chdir(File.dirname(__FILE__)) do
	string = File.read('SourceTests-1.txt')
end

source = KLib::Source.new(string)

OPS = %w{+ - * /}
CHARS = ('a'..'z').to_a
NUMS = ('0'..'9').to_a
WHITESPACE = [" ", "\t", "\n"]

errors = 0
idx = 0
type = nil
reader = source.reader
until reader.eof?
	ch = reader.get_c
	
	if OPS.include?(ch)
		case type
			when nil
			when :chars
				source.post_span_message("Variable", idx, reader.idx - 1)
			when :num
				source.post_span_message("Number", idx, reader.idx - 1)
			else
				nil
		end
		source.post_length_message("Operator", reader.idx - 1, 1)
		type = nil
	elsif CHARS.include?(ch)
		case type
			when nil
				idx = reader.idx - 1
			when :chars
			when :num
				source.post_span_message("Number", idx, reader.idx - 1)
				idx = reader.idx - 1
			else
				nil
		end
		type = :chars
	elsif NUMS.include?(ch)
		case type
			when nil
				idx = reader.idx - 1
			when :chars
				source.post_span_message("Variable", idx, reader.idx - 1)
				idx = reader.idx - 1
			when :num
			else
				nil
		end
		type = :num
	elsif WHITESPACE.include?(ch)
		case type
			when nil
			when :chars
				source.post_span_message("Variable", idx, reader.idx - 1)
			when :num
				source.post_span_message("Number", idx, reader.idx - 1)
			else
				nil
		end
		type = nil
	else
		errors += 1
		source.post_length_message("Illegal character", reader.idx - 1, 1)
	end
end
if errors == 0
	source.post_eof_message("Successful")
else
	source.post_eof_message("Found #{errors} error#{errors == 1 ? "" : "s"}")
end

source.dump(false)
