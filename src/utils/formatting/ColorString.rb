
Dir.chdir(File.dirname(__FILE__)) do
	require './../validation/HashNormalizer'
end

module KLib
	
	class ColorString
		
		INTER_STRING = '#{}'
		CLEAR_COLORS = "\e[0m"
		VALID_COLOR_MODES = [:basic, :none]
		if ENV.key?('KLIB_COLOR')
			value = ENV['KLIB_COLOR'].downcase.to_sym
			if VALID_COLOR_MODES.include?(value)
				COLOR_MODE = value
			else
				$stderr.puts("[WARNING]: 'KLIB_COLOR' environment variable has bad value '#{ENV['KLIB_COLOR']}', assuming 'NONE'. Options: #{VALID_COLOR_MODES.map { |m| "'#{m.to_s.upcase}'" }.join(', ')}.")
				COLOR_MODE = :none
			end
		else
			$stderr.puts("[INFO]:    No 'KLIB_COLOR' environment variable set, assuming 'BASIC'. Options: #{VALID_COLOR_MODES.map { |m| "'#{m.to_s.upcase}'" }.join(', ')}.")
			COLOR_MODE = :basic
		end
		
		COLORS = {
			:black =>   { :foreground => 30, :background => 40 },
			:red =>     { :foreground => 31, :background => 41 },
			:green =>   { :foreground => 32, :background => 42 },
			:yellow =>  { :foreground => 33, :background => 43 },
			:blue =>    { :foreground => 34, :background => 44 },
			:magenta => { :foreground => 35, :background => 45 },
			:cyan =>    { :foreground => 36, :background => 46 },
			:white =>   { :foreground => 37, :background => 47 },
			:default => { :foreground => 39, :background => 49 }
		}
		MODIFIERS = {
			:bright =>    1,
			:underline => 4
		}
		
	end
	
end

class String
	
	def colorize(hash_args = {})
		KLib::ColorString.new(self, hash_args)
	end
	
	def interpolate(*inter_strings)
		KLib::ColorString.new(self, *inter_strings)
	end
	
	KLib::ColorString::COLORS.keys.each do |col|
		define_method(col) { colorize(:foreground => col) }
	end
	
	KLib::ColorString::COLORS.keys.each do |col_1|
		KLib::ColorString::COLORS.keys.each do |col_2|
			define_method(:"#{col_1}_#{col_2}") { colorize(:foreground => col_1, :background => col_2) }
		end
	end
	
	def rjust(length, pad_str = ' ')
		KLib::ArgumentChecking.type_check(length, 'length', Integer)
		KLib::ArgumentChecking.type_check(pad_str, 'pad_str', String)
		raise ArgumentError.new("'pad_str' must have a length of 1") unless pad_str.length == 1
		
		my_length = self.length
		add_length = (length - my_length < 0 ? 0 : length - my_length)
		((pad_str * add_length) + self)
	end
	
	def ljust(length, pad_str = ' ')
		KLib::ArgumentChecking.type_check(length, 'length', Integer)
		KLib::ArgumentChecking.type_check(pad_str, 'pad_str', String)
		raise ArgumentError.new("'pad_str' must have a length of 1") unless pad_str.length == 1
		
		my_length = self.length
		add_length = (length - my_length < 0 ? 0 : length - my_length)
		(self + (pad_str * add_length))
	end
	
	def center(length, pad_str = ' ')
		KLib::ArgumentChecking.type_check(length, 'length', Integer)
		KLib::ArgumentChecking.type_check(pad_str, 'pad_str', String)
		raise ArgumentError.new("'pad_str' must have a length of 1") unless pad_str.length == 1
		
		my_length = self.length
		add_length = (length - my_length < 0 ? 0 : length - my_length)
		left = add_length / 2
		right = add_length - left
		((pad_str * left) + self + (pad_str * right))
	end
	
	alias :original_length :length
	def length
		self.de_color.original_length
	end
	
	def de_color
		# KLib::Trace.call_trace.each { |tr| puts(tr.inspect) }
		# exit
		self.gsub(/\e\[(\d+)(;\d+)*m/, '')
	end

end

module KLib
	
	class ColorString
		
		class Modifiers
			
			def initialize(hash_args = {})
				hash_args = HashNormalizer.normalize(hash_args) do |norm|
					norm.foreground(:text, :front).default_value(:default).enum_check(ColorString::COLORS.keys)
					norm.background(:back).default_value(:default).enum_check(ColorString::COLORS.keys)
					norm.bright.default_value(false).type_check(Boolean)
					norm.underline.default_value(false).type_check(Boolean)
				end
				
				modifiers = []
				modifiers << ColorString::MODIFIERS[:bright] if hash_args[:bright]
				modifiers << ColorString::MODIFIERS[:underline] if hash_args[:underline]
				modifiers << ColorString::COLORS[hash_args[:foreground]][:foreground]
				modifiers << ColorString::COLORS[hash_args[:background]][:background]
				@mod_string = "\e[#{modifiers.join(';')}m"
			end
			
			def to_s
				@mod_string
			end
			
		end
		
		def initialize(string, *inter_strings)
			if inter_strings.last.is_a?(Modifiers)
				modifiers = inter_strings[-1]
				inter_strings = inter_strings[0..-2]
			elsif inter_strings.last.is_a?(Hash)
				modifiers = Modifiers.new(inter_strings[-1])
				inter_strings = inter_strings[0..-2]
			else
				modifiers = Modifiers.new
			end
			ArgumentChecking.type_check(string, 'string', String)
			ArgumentChecking.type_check_each(inter_strings, 'inter_strings', ColorString)
			
			split_string = string.split('#{}')
			raise ArgumentError.new("You must pass in the same number of '\#{}' as strings") unless inter_strings.length == split_string.length - 1
			
			str = CLEAR_COLORS.dup
			inter_strings.length.times do |idx|
				str << modifiers.to_s << split_string[idx].gsub("\n", "#{CLEAR_COLORS}\n#{modifiers.to_s}") << inter_strings[idx].to_s
			end
			str << modifiers.to_s << split_string[-1].gsub("\n", "#{CLEAR_COLORS}\n#{modifiers.to_s}") <<  CLEAR_COLORS
			
			@str = COLOR_MODE == :none ? str.de_color : str
		end
		
		def method_missing(sym, *args)
			@str.send(sym, *args)
		end
		
		def inspect
			@str.inspect
		end
		
		def to_s
			@str
		end
	
	end

end
