
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
			tmp -= 1 while idx > 0 && @string[idx - 1] != "\n"
			tmp
		end
		def line_no_of(idx)
			ArgumentChecking.type_check(idx, :idx, Integer)
			raise ArgumentError.new("idx out of bounds 0 <= #{idx} <= #{@length}") if idx < 0 || idx > @length
			line_no = @line_starts.length - 1
			line_no -= 1 while idx < @line_starts[line_no]
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
					if start_idx > tmp.end_idx
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
		SPAN_LINE_START = "**** "
		EOF_LINE_START = "**** "
		def dump(only_message_lines = true, io: $stdout, color_start: 0)
			ArgumentChecking.boolean_check(only_message_lines, :only_message_lines)
			ArgumentChecking.type_check(io, :io, IO)
			ArgumentChecking.type_check(color_start, :color_start, Integer)
			raise ArgumentError.new("color_start must be >= 0, given: #{color_start}") if color_start < 0
			
			color_idx = color_start
			if @span_messages.empty?
				io.print(@string)
				io.puts
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
						io.print("#{tmp.nil? ? "" : "\e[0m"}#{line_no_of(idx).to_s.rjust(4)}: #{tmp.nil? ? "" : "\e[#{tmp}m"}")
						line_start_status = :not_start
					end
					if current_msg.nil? && !next_msg.nil? && idx == next_msg.start_idx
						current_msg = next_msg
						tmp = color_idx % MAX_COLOR + COLOR_OFFSET
						io.print("\e[#{tmp}m")
					end
					io.putc(ch)
					if !current_msg.nil? && idx == current_msg.end_idx
						messages_from_line << { message: current_msg.msg, color: tmp }
						current_msg = nil
						tmp = nil
						color_idx += 1
						io.print("\e[0m")
						next_msg_idx += 1
						next_msg = @span_messages[next_msg_idx]
					end
					if ch == "\n"
						line_start_status = :start
						messages_from_line.each do |message|
							io.puts("\e[#{message[:color]}m#{SPAN_LINE_START}#{message[:message]}")
						end
						if messages_from_line.any?
							io.print("\e[0m") if tmp.nil?
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
				io.print("#{tmp.nil? ? "" : "\e[0m"}#{line_no_of(idx).to_s.rjust(4)}: #{tmp.nil? ? "" : "\e[#{tmp}m"}") if line_start_status == :start
				io.puts unless line_start_status == :early_stop
			end
			@eof_messages.each do |msg|
				io.puts("\e[#{color_idx % MAX_COLOR + COLOR_OFFSET}m#{EOF_LINE_START}#{msg}")
			end
			io.print("\e[0m")
			
			nil
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
			
			def unmark
				@mark = nil
			end
			def mark(backup = 1)
				ArgumentChecking.type_check(backup, :backup, Integer)
				raise "backup must be >= 0" if backup < 0
				raise "backup past start" if backup > @idx
				@mark = @idx - backup
				nil
			end
			
			def mark?
				!@mark.nil?
			end
			
			def span(backup = 1)
				ArgumentChecking.type_check(backup, :backup, Integer)
				raise "No mark" if @mark.nil?
				raise "backup must be >= 0" if backup < 0
				raise "backup past mark" if @idx - backup < @mark
				[@mark, @idx - backup]
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
				unmark
				nil
			end
			
			def eof?
				@idx >= @source.length
			end
			
		end
		
	end
	
end
