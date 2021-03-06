
require_relative '../validation/ArgumentChecking'

module KLib
	
	class Source
		
		attr_reader :string, :length
		
		def initialize(string)
			ArgumentChecking.type_check(string, :string, String)
			@string = string
			@length = string.length
			@line_starts = [nil, 0]
			@span_messages = []
			@eof_messages = []
			
			@string.length.times do |idx|
				@line_starts << (idx + 1) if @string[idx] == "\n"
			end
			
			nil
		end
		
		def reader
			Reader.new(self)
		end
		
		def [] (idx)
			@string[idx]
		end
		
		def start_of_line(idx)
			ArgumentChecking.type_check(idx, :idx, Integer)
			raise ArgumentError.new("idx out of bounds 0 <= #{idx} <= #{@length}") if idx < 0 || idx > @length
			tmp = idx
			tmp -= 1 while tmp > 0 && @string[tmp - 1] != "\n"
			tmp
		end
		def line_no_of(idx)
			ArgumentChecking.type_check(idx, :idx, Integer)
			raise ArgumentError.new("idx out of bounds 0 <= #{idx} <= #{@length}") if idx < 0 || idx > @length
			line_no = @line_starts.length - 1
			line_no -= 1 while line_no > 0 && idx < @line_starts[line_no]
			line_no
		end
		
		def post_span_message(msg, start_idx, end_idx)
			ArgumentChecking.type_check(msg, :msg, String)
			ArgumentChecking.type_check(start_idx, :start_idx, Integer)
			ArgumentChecking.type_check(end_idx, :end_idx, Integer)
			raise ArgumentError.new("start_idx must be >= 0, given: #{start_idx}") if start_idx < 0
			raise ArgumentError.new("end_idx must be < @length, given: #{end_idx}, #{@length}") if end_idx >= @length
			raise ArgumentError.new("start_idx must be <= end_idx, given: #{start_idx}, #{end_idx}") if start_idx > end_idx
			
			message = Message.new(msg, start_idx, end_idx)
			
			idx = 0
			loop do
				if idx >= @span_messages.length
					@span_messages << message
					break
				else
					tmp = @span_messages[idx]
					if start_idx == tmp.start_idx && end_idx == tmp.end_idx
						tmp.msg << "\n#{msg}"
						break
					elsif start_idx > tmp.end_idx
						idx += 1
					else 
						if start_idx < tmp.start_idx
							if end_idx >= tmp.start_idx
								$stderr.puts("Conflicting message spans, adding as eof message instead")
								post_eof_message("[CONFLICT]: " + msg)
							else
								@span_messages.insert(idx, message)
							end
						elsif start_idx >= tmp.start_idx
							$stderr.puts("Conflicting message spans, adding as eof message instead")
							post_eof_message("[CONFLICT]: " + msg)
						else
							raise "What is going on?"
						end
						break
					end
				end
			end
			
			nil
		end
		
		def post_length_message(msg, start_idx, length)
			ArgumentChecking.type_check(msg, :msg, String)
			ArgumentChecking.type_check(start_idx, :start_idx, Integer)
			ArgumentChecking.type_check(length, :length, Integer)
			raise ArgumentError.new("length must be >= 1, given: #{length}") if length < 1
			post_span_message(msg, start_idx, start_idx + length - 1)
		end
		
		def post_eof_message(msg)
			ArgumentChecking.type_check(msg, :msg, String)
			@eof_messages << msg
			nil
		end
		
		MAX_COLOR = 6
		COLOR_OFFSET = 31
		UNDERLINE_ENDS = [" ", "\t", "\n"]
		SPAN_LINE_START = "**** "
		EOF_LINE_START = "**** "
		NEWLINE_START = ">*** "
		def dump(*args, io: $stdout)
			ArgumentChecking.type_check(io, :io, IO)
			io.puts(self.to_s(*args))
		end
		def to_s(only_message_lines = true, color_start: 0)
			ArgumentChecking.boolean_check(only_message_lines, :only_message_lines)
			ArgumentChecking.type_check(color_start, :color_start, Integer)
			raise ArgumentError.new("color_start must be >= 0, given: #{color_start}") if color_start < 0
			
			strs = []
			
			color_idx = color_start
			if @span_messages.empty?
				strs << @string
			else
				idx = only_message_lines ? start_of_line(@span_messages[0].start_idx) : 0
				next_msg_idx = 0
				current_msg = nil
				next_msg = @span_messages[next_msg_idx]
				tmp = nil
				line_start_status = :start
				messages_from_line = []
				
				while idx < @length
					ch = @string[idx]
					if line_start_status == :start
						strs << "#{tmp.nil? ? "" : "\e[0m"}#{line_no_of(idx).to_s.rjust(4)}: #{tmp.nil? ? "" : "\e[#{tmp}m"}"
						line_start_status = :not_start
					end
					if current_msg.nil? && !next_msg.nil? && idx == next_msg.start_idx
						current_msg = next_msg
						tmp = color_idx % MAX_COLOR + COLOR_OFFSET
						strs << "\e[#{UNDERLINE_ENDS.include?(@string[current_msg.start_idx]) || UNDERLINE_ENDS.include?(@string[current_msg.end_idx]) ? "4;" : ""}#{tmp}m"
					end
					strs << ch
					if !current_msg.nil? && idx == current_msg.end_idx
						messages_from_line << { message: current_msg.msg, color: tmp }
						current_msg = nil
						tmp = nil
						color_idx += 1
						strs << "\e[0m"
						next_msg_idx += 1
						next_msg = @span_messages[next_msg_idx]
					end
					if ch == "\n"
						line_start_status = :start
						messages_from_line.each do |message|
							strs << "\e[#{message[:color]}m#{SPAN_LINE_START}#{message[:message].gsub("\n", "\n#{NEWLINE_START}")}\n"
						end
						if messages_from_line.any?
							strs << "\e[0m" if tmp.nil?
							messages_from_line = []
						end
						if current_msg.nil? && only_message_lines
							if next_msg.nil?
								line_start_status = :early_stop
								break
							end
							idx = start_of_line(next_msg.start_idx) - 1
						end
					end
					idx += 1
				end
				messages_from_line.each do |message|
					strs << "\n\e[#{message[:color]}m#{SPAN_LINE_START}#{message[:message].gsub("\n", "\n#{NEWLINE_START}")}"
				end
				strs << "#{tmp.nil? ? "" : "\e[0m"}#{line_no_of(idx).to_s.rjust(4)}: #{tmp.nil? ? "" : "\e[#{tmp}m"}" if line_start_status == :start
				strs << "\n" unless line_start_status == :early_stop
				
			end
			# TODO : print after last line
			strs << "\n"
			@eof_messages.each do |msg|
				strs << "\e[#{color_idx % MAX_COLOR + COLOR_OFFSET}m#{EOF_LINE_START}#{msg.gsub("\n", "\n#{NEWLINE_START}")}"
				color_idx += 1
			end
			strs << "\e[0m"
			
			strs.join('')
		end
		
		class Message
			
			attr_reader :start_idx, :end_idx, :msg
			
			def initialize(msg, start_idx, end_idx)
				ArgumentChecking.type_check(msg, :msg, String)
				ArgumentChecking.type_check(start_idx, :start_idx, Integer)
				ArgumentChecking.type_check(end_idx, :end_idx, Integer)
				raise ArgumentError.new("start_idx must be <= end_idx") if start_idx > end_idx
				
				@msg = msg
				@start_idx = start_idx
				@end_idx = end_idx
				nil
			end
			
		end
		
		class Reader
			
			attr_reader :source, :idx, :line_no
			
			def initialize(src)
				ArgumentChecking.type_check(src, :src, Source)
				@source = src
				self.restart
				nil
			end
			
			def get_c
				c = @source[@idx]
				@idx += 1
				@line_no += 1 if c == "\n"
				c
			end
			
			def pop_mark
				@mark.pop
			end
			def mark(backup = 1)
				ArgumentChecking.type_check(backup, :backup, Integer)
				raise "backup must be >= 0" if backup < 0
				raise "backup past start" if backup > @idx
				tmp_idx = @idx
				tmp_line_no = @line_no
				backup.times do
					tmp_idx -= 1
					tmp_line_no -= 1 if @source[tmp_idx] == "\n"
				end
				@mark << { idx: tmp_idx, line_no: tmp_line_no }
				nil
			end
			def back_to_mark
				raise "No mark to backup to" unless @mark
				@idx = pop_mark[:idx]
				nil
			end
			
			def mark?
				@mark.any?
			end
			
			def span(backup = 1, pop_mark: false)
				ArgumentChecking.type_check(backup, :backup, Integer)
				ArgumentChecking.boolean_check(pop_mark, :pop_mark)
				raise "No mark" unless mark?
				raise "backup must be >= 0" if backup < 0
				raise "backup past mark" if @idx - backup < @mark.last[:idx]
				span = [@mark.last[:idx], @idx - backup]
				self.pop_mark if pop_mark
				span
			end
			def line_no_span(backup = 1, pop_mark: false)
				ArgumentChecking.type_check(backup, :backup, Integer)
				ArgumentChecking.boolean_check(pop_mark, :pop_mark)
				raise "No mark" unless mark?
				raise "backup must be >= 0" if backup < 0
				raise "backup past mark" if @idx - backup < @mark.last[:idx]
				tmp_idx = @idx
				tmp_line_no = @line_no
				backup.times do
					tmp_idx -= 1
					tmp_line_no -= 1 if @source[tmp_idx] == "\n"
				end
				line_no_span = [@mark.last[:line_no], tmp_line_no]
				self.pop_mark if pop_mark
				line_no_span
			end
			
			def backup(dist = 1)
				ArgumentChecking.type_check(dist, :dist, Integer)
				raise ArgumentError.new("dist must be > 0, given: #{dist}") if dist <= 0
				raise ArgumentError.new("backup past start (#{dist} > #{@idx})") if dist > @idx
				@idx -= dist
				nil
			end
			
			def restart
				@idx = 0
				@line_no = 1
				@mark = []
				nil
			end
			
			def eof?
				@idx >= @source.length
			end
			
			def span_message(msg, *args)
				@source.post_span_message(msg, *self.span(*args))
			end
			
			def last_char_message(msg)
				@source.post_span_message(msg, @idx - 1, @idx - 1)
			end
			
			alias :original_method_missing :method_missing
			def method_missing(sym, *args, &block)
				if @source.respond_to?(sym)
					@source.send(sym, *args, &block)
				else
					original_method_missing(sym, *args, &block)
				end
			end
		end
		
	end
	
end
